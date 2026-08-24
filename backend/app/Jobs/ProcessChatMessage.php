<?php

declare(strict_types=1);

namespace App\Jobs;

use App\Ai\Agents\FinancialAssistant;
use App\Exceptions\AiProviderFailedException;
use App\Models\ActivityLog;
use App\Models\Message;
use App\Services\ChatService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Str;
use Laravel\Ai\Messages\AssistantMessage as AgentAssistantMessage;
use Laravel\Ai\Messages\Message as AgentMessage;
use Laravel\Ai\Messages\UserMessage as AgentUserMessage;
use Laravel\Ai\Responses\Data\ToolResult;

/**
 * Proses pesan chat secara async via queue (ARCHITECTURE §6 — queue-ready).
 * dipisah dari ChatService agar endpoint POST /chat return cepat.
 */
final class ProcessChatMessage implements ShouldQueue
{
    use Dispatchable, InteractsWithQueue, Queueable, SerializesModels;

    /** Retry 3x jika provider gagal sementara. */
    public int $tries = 3;

    /** Backoff: 10s, 30s, 60s antar retry. */
    public array $backoff = [10, 30, 60];

    public function __construct(
        public readonly int $assistantMessageId,
        public readonly int $sessionId,
        public readonly int $userId,
    ) {}

    /**
     * Eksekusi: update status → prompt agent → update message → log activity.
     */
    public function handle(ChatService $chat): void
    {
        /** @var Message|null $assistantMessage */
        $assistantMessage = Message::query()->find($this->assistantMessageId);
        if (! $assistantMessage) {
            return;
        }

        /** @var \App\Models\User|null $user */
        $user = \App\Models\User::query()->find($this->userId);
        if (! $user) {
            return;
        }

        // 1. Update status → processing.
        $assistantMessage->update(['status' => 'processing']);

        // 2. Prompt agent via ChatService::process().
        try {
            $result = $chat->process(
                $user,
                $this->sessionId,
                $assistantMessage,
            );
        } catch (AiProviderFailedException) {
            $assistantMessage->update([
                'status' => 'failed',
                'content' => 'Layanan AI sedang tidak tersedia. Coba lagi sebentar.',
            ]);

            return;
        }

        // 3. Log activity untuk setiap tool call (AI-8).
        $this->logActivities($user, $result['actions']);
    }

    /**
     * Handle provider gagal total setelah semua retry.
     */
    public function failed(\Throwable $exception): void
    {
        /** @var Message|null $assistantMessage */
        $assistantMessage = Message::query()->find($this->assistantMessageId);
        if ($assistantMessage) {
            $assistantMessage->update([
                'status' => 'failed',
                'content' => 'Terjadi kesalahan pemrosesan. Silakan coba lagi.',
            ]);
        }
    }

    /**
     * Log setiap action ke activity_logs table.
     *
     * @param array<int, array<string, mixed>> $actions
     */
    private function logActivities(\App\Models\User $user, array $actions): void
    {
        foreach ($actions as $action) {
            $subjectType = null;
            $subjectId = null;

            if (isset($action['transaction_id'])) {
                $subjectType = \App\Models\Transaction::class;
                $subjectId = $action['transaction_id'];
            }

            ActivityLog::create([
                'user_id' => $user->id,
                'action' => $action['action'],
                'subject_type' => $subjectType,
                'subject_id' => $subjectId,
                'payload' => $action['payload'] ?? null,
                'result' => $action['result'] ?? 'ok',
                'error_message' => $action['error'] ?? null,
            ]);
        }
    }
}
