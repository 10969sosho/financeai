<?php

declare(strict_types=1);

namespace App\Services;

use App\Ai\Agents\FinancialAssistant;
use App\Exceptions\AiProviderFailedException;
use App\Jobs\ProcessChatMessage;
use App\Models\ChatSession;
use App\Models\Message;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Ai\Exceptions\AiException;
use Laravel\Ai\Messages\AssistantMessage as AgentAssistantMessage;
use Laravel\Ai\Messages\Message as AgentMessage;
use Laravel\Ai\Messages\UserMessage as AgentUserMessage;
use Laravel\Ai\Responses\AgentResponse;
use Laravel\Ai\Responses\Data\ToolResult;

/**
 * Orkestrasi pipeline chat (ARCHITECTURE §4):
 * Fase 1 — handle(): simpan pesan user → buat pending assistant msg → dispatch job → return
 * Fase 2 — process(): prompt agent (+tool loop SDK) → update assistant msg → audit trail
 * dengan metadata.actions sebagai jejak audit (AI-8).
 */
final readonly class ChatService
{
    /** CS-2: konteks AI = maksimal N pesan terakhir session. */
    private const CONTEXT_WINDOW = 20;

    /**
     * Fase 1: Simpan user message + pending assistant message + dispatch job.
     *
     * @return array{message: Message, session: ChatSession}
     */
    public function handle(User $user, ?int $sessionId, string $body): array
    {
        $session = $this->resolveSession($user, $sessionId);

        // 1. Simpan pesan user (CS-4) — tetap tersimpan walau provider gagal.
        $userMessage = DB::transaction(function () use ($session, $body): Message {
            $message = $session->messages()->create([
                'user_id' => $session->user_id,
                'role' => 'user',
                'content' => $body,
            ]);

            $session->forceFill([
                'last_message_at' => $message->created_at,
                // Auto-title dari pesan user pertama (DATABASE.md chat_sessions.title).
                'title' => $session->title ?? Str::limit($body, 60),
            ])->save();

            return $message;
        });

        // 2. Buat pending assistant message — akan diupdate oleh job.
        $assistantMessage = DB::transaction(function () use ($session, $user): Message {
            $message = $session->messages()->create([
                'user_id' => $user->id,
                'role' => 'assistant',
                'content' => '',
                'status' => 'pending',
            ]);

            $session->forceFill(['last_message_at' => $message->created_at])->save();

            return $message;
        });

        // 3. Dispatch job ke queue — user tidak menunggu.
        ProcessChatMessage::dispatch(
            $assistantMessage->id,
            $session->id,
            $user->id,
        );

        return ['message' => $assistantMessage, 'session' => $session];
    }

    /**
     * Fase 2: Dipanggil oleh ProcessChatMessage job.
     * Prompt agent → update assistant message → return audit trail.
     *
     * @return array{actions: array<int, array<string, mixed>>, affectedIds: array<int, int>}
     */
    public function process(User $user, int $sessionId, Message $assistantMessage): array
    {
        /** @var ChatSession $session */
        $session = $user->chatSessions()->findOrFail($sessionId);

        // Ambil pesan user terakhir (body) untuk prompt.
        /** @var Message $lastUserMessage */
        $lastUserMessage = $session->messages()
            ->where('role', 'user')
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->first();

        // Konteks: N pesan terakhir session (CS-2).
        $context = $this->contextMessagesFor($session);

        // Prompt agent — SDK menjalankan tool loop; tool delegasi ke Action layer.
        $response = $this->promptAgent($user, $context, $lastUserMessage->content);

        // metadata.actions = jejak audit eksekusi tool (AI-8).
        [$actions, $affectedIds] = $this->buildAuditTrail($response);

        // Update assistant message dengan hasil.
        DB::transaction(function () use ($assistantMessage, $user, $response, $actions, $session): void {
            $assistantMessage->update([
                'content' => $response->text,
                'metadata' => ['actions' => $actions],
                'status' => 'completed',
            ]);

            $session->forceFill(['last_message_at' => $assistantMessage->fresh()->created_at])->save();
        });

        return ['actions' => $actions, 'affectedIds' => $affectedIds];
    }

    /**
     * Ambil transaksi terdampak untuk respons API.
     *
     * @param  array<int, int>  $affectedIds
     */
    public function getAffectedTransactions(User $user, array $affectedIds): Collection
    {
        if ($affectedIds === []) {
            return collect();
        }

        return $user->transactions()->with('category')->whereIn('id', $affectedIds)->get();
    }

    private function resolveSession(User $user, ?int $sessionId): ChatSession
    {
        if ($sessionId !== null) {
            // IS-1: global scope membuat session milik user lain → not found (IS-2).
            /** @var ChatSession */
            return $user->chatSessions()->findOrFail($sessionId);
        }

        // CS-1: tanpa session_id → buat session baru (konteks reset).
        /** @var ChatSession */
        return DB::transaction(fn (): ChatSession => $user->chatSessions()->create());
    }

    /**
     * @return array<int, AgentMessage>
     */
    private function contextMessagesFor(ChatSession $session): array
    {
        return $session->messages()
            ->where(function ($query): void {
                // Hanya user messages + assistant yang sudah selesai/failed (punya konten).
                $query->where('role', 'user')
                    ->orWhere(function ($q): void {
                        $q->where('role', 'assistant')
                            ->whereIn('status', ['completed', 'failed']);
                    });
            })
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->limit(self::CONTEXT_WINDOW)
            ->get()
            ->reverse()
            ->values()
            ->map(fn (Message $message): AgentMessage => match ($message->role) {
                'assistant' => new AgentAssistantMessage($message->content),
                default => new AgentUserMessage($message->content),
            })
            ->all();
    }

    private function promptAgent(User $user, array $context, string $body): AgentResponse
    {
        try {
            return (new FinancialAssistant($user, $context))->prompt($body);
        } catch (AiException|ConnectionException|\Illuminate\Http\Client\RequestException|\RuntimeException $e) {
            report($e);

            // Pesan user sudah tersimpan di atas; API merespons 503 (ARCHITECTURE §4).
            throw new AiProviderFailedException($e->getMessage(), previous: $e);
        }
    }

    /**
     * Susun metadata.actions dari tool calls & results (AI-8) dan kumpulkan
     * id transaksi terdampak.
     *
     * @return array{array<int, array<string, mixed>>, array<int, int>}
     */
    private function buildAuditTrail(object $response): array
    {
        $actions = [];
        $affectedIds = [];

        /** @var ToolResult $result */
        foreach ($response->toolResults as $result) {
            $decoded = json_decode((string) $result->result, true);
            $ok = is_array($decoded) && ($decoded['ok'] ?? false) === true;

            $action = [
                'action' => $this->actionNameFor($result->name),
                'payload' => $result->arguments,
                'result' => $ok ? 'ok' : 'error',
            ];

            if (! $ok && is_array($decoded) && isset($decoded['error'])) {
                $action['error'] = $decoded['error'];
            }

            if ($ok && isset($decoded['transaction_id']) && is_numeric($decoded['transaction_id'])) {
                $action['transaction_id'] = (int) $decoded['transaction_id'];
                $affectedIds[] = (int) $decoded['transaction_id'];
            }

            $actions[] = $action;
        }

        return [$actions, array_values(array_unique($affectedIds))];
    }

    /**
     * Map nama tool (class_basename) → nama aksi audit.
     */
    private function actionNameFor(string $toolName): string
    {
        return Str::snake(preg_replace('/Tool$/', '', $toolName) ?? $toolName);
    }
}
