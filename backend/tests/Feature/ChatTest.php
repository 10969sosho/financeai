<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Ai\Agents\FinancialAssistant;
use App\Jobs\ProcessChatMessage;
use App\Models\ActivityLog;
use App\Models\Category;
use App\Models\ChatSession;
use App\Models\Message;
use App\Models\Transaction;
use App\Models\User;
use Database\Seeders\CategorySeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Queue;
use Laravel\Ai\Exceptions\ProviderConnectionException;
use Laravel\Ai\Prompts\AgentPrompt;
use Laravel\Ai\Responses\Data\ToolCall;
use Tests\TestCase;

final class ChatTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(CategorySeeder::class);

        $this->user = User::factory()->create();
    }

    /**
     * POST /chat mengembalikan pending status dan dispatch job ke queue.
     * Queue::fake() mencegah job jalan — kita hanya verifikasi dispatch.
     */
    public function test_async_chat_returns_pending_status_and_dispatches_job(): void
    {
        Queue::fake();
        FinancialAssistant::fake(['Oke.']);

        $response = $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', ['body' => 'makan 25 ribu'])
            ->assertOk();

        $this->assertSame('pending', $response->json('data.message.status'));
        $this->assertSame('', $response->json('data.message.content'));
        $this->assertSame([], $response->json('data.transactions'));

        Queue::assertPushed(ProcessChatMessage::class);
    }

    /**
     * Full flow: sync queue menjalankan job langsung → transaksi tercipta.
     * Tanpa Queue::fake() — biarkan sync queue bekerja.
     */
    public function test_full_chat_flow_creates_transaction(): void
    {
        FinancialAssistant::fake([
            new ToolCall('call_1', 'CreateTransactionTool', [
                'type' => 'expense',
                'amount' => 25000,
                'description' => 'makan siang',
                'category' => 'Makanan',
            ]),
            'Oke, dicatat ya: Makanan Rp25.000.',
        ]);

        $response = $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', ['body' => 'tadi makan 25 ribu'])
            ->assertOk();

        // Sync queue sudah menjalankan job; cek DB langsung.
        $assistantMessage = Message::query()->where('role', 'assistant')->sole();
        $this->assertSame('completed', $assistantMessage->status);
        $this->assertNotEmpty($assistantMessage->content);

        // AI-1: transaksi tercipta via Action layer.
        $transaction = Transaction::query()->sole();
        $this->assertSame('expense', $transaction->type);
        $this->assertSame(25000, $transaction->amount);
        $this->assertSame('ai', $transaction->source);
        $this->assertSame('Makanan', $transaction->category->name);

        // Dua pesan tersimpan: user + assistant (CS-4).
        $this->assertDatabaseCount('messages', 2);
    }

    /**
     * AI-3: input ambigu → assistant bertanya balik, NOL transaksi dibuat.
     */
    public function test_ai_3_ambiguous_input_asks_back_without_mutation(): void
    {
        FinancialAssistant::fake([
            'Mau dicatat berapa nominalnya?',
        ]);

        $response = $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', ['body' => 'makan'])
            ->assertOk();

        // Sync queue sudah menjalankan job.
        $assistantMessage = Message::query()->where('role', 'assistant')->sole();
        $this->assertSame('completed', $assistantMessage->status);
        $this->assertStringContainsString('berapa', $assistantMessage->content);

        $this->assertSame(0, Transaction::query()->count());
    }

    /**
     * AI-4: koreksi ("bukan 25 tapi 30") meng-update transaksi yang dirujuk.
     */
    public function test_ai_4_correction_updates_referenced_transaction(): void
    {
        $makanan = Category::query()->where('name', 'Makanan')->firstOrFail();
        $transaction = Transaction::factory()->amount(25000)->for($this->user, 'user')
            ->for($makanan, 'category')->create();

        FinancialAssistant::fake([
            new ToolCall('call_1', 'UpdateTransactionTool', [
                'transaction_id' => $transaction->id,
                'amount' => 30000,
            ]),
            'Sudah diubah ya: Makanan Rp30.000.',
        ]);

        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', ['body' => 'tadi makan 25 ribu, bukan, 30 ribu'])
            ->assertOk();

        $this->assertDatabaseHas('transactions', [
            'id' => $transaction->id,
            'amount' => 30000,
        ]);
    }

    /**
     * AI-8: setiap eksekusi action tercatat di metadata.actions
     * dengan payload, result, dan transaction_id.
     */
    public function test_ai_8_metadata_actions_recorded_with_payload_result_and_transaction_id(): void
    {
        FinancialAssistant::fake([
            new ToolCall('call_1', 'CreateTransactionTool', [
                'type' => 'expense',
                'amount' => 20000,
                'description' => 'beli kopi',
                'category' => 'Minuman',
            ]),
            'Sudah dicatat: Minuman Rp20.000.',
        ]);

        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', ['body' => 'beli kopi 20 ribu'])
            ->assertOk();

        $assistantMessage = Message::query()->where('role', 'assistant')->sole();
        $actions = $assistantMessage->metadata['actions'] ?? [];

        $this->assertCount(1, $actions);
        $this->assertSame('create_transaction', $actions[0]['action']);
        $this->assertSame('ok', $actions[0]['result']);
        $this->assertSame(20000, $actions[0]['payload']['amount']);
        $this->assertArrayHasKey('transaction_id', $actions[0]);

        $transactionId = $actions[0]['transaction_id'];
        $this->assertDatabaseHas('messages', [
            'role' => 'assistant',
            'content' => 'Sudah dicatat: Minuman Rp20.000.',
            'status' => 'completed',
        ]);
        $this->assertNotNull(Transaction::query()->find($transactionId));
    }

    /**
     * Activity log tercatat setelah job selesai memproses tool call.
     */
    public function test_activity_log_recorded_after_chat_processing(): void
    {
        FinancialAssistant::fake([
            new ToolCall('call_1', 'CreateTransactionTool', [
                'type' => 'expense',
                'amount' => 25000,
                'description' => 'makan siang',
                'category' => 'Makanan',
            ]),
            'Oke.',
        ]);

        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', ['body' => 'makan 25 ribu'])
            ->assertOk();

        $transaction = Transaction::query()->sole();

        $this->assertDatabaseHas('activity_logs', [
            'user_id' => $this->user->id,
            'action' => 'create_transaction',
            'result' => 'ok',
            'subject_type' => Transaction::class,
            'subject_id' => $transaction->id,
        ]);
    }

    /**
     * Kontrak respons POST /chat persis API_REFERENCE (async shape).
     */
    public function test_chat_create_flow_returns_exact_api_reference_shape(): void
    {
        Queue::fake();
        FinancialAssistant::fake(['Oke.']);

        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', ['body' => 'beli kopi 20 ribu'])
            ->assertOk()
            ->assertJsonStructure([
                'data' => [
                    'message' => ['id', 'role', 'content', 'status', 'metadata', 'created_at'],
                    'transactions' => [],
                ],
            ]);
    }

    /**
     * CS-1 + auto-title: tanpa session_id → session baru berjudul dari pesan pertama.
     */
    public function test_session_auto_titled_from_first_user_message(): void
    {
        FinancialAssistant::fake(['Oke!']);

        $response = $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', ['body' => 'Pengeluaran hari ini: makan 25 ribu'])
            ->assertOk();

        $assistantMessageId = $response->json('data.message.id');
        $session = Message::query()->find($assistantMessageId)->chatSession;

        $this->assertNotNull($session);
        $this->assertNotNull($session->title);
        $this->assertSame('Pengeluaran hari ini: makan 25 ribu', $session->title);
        $this->assertNotNull($session->last_message_at);
    }

    /**
     * CS-2: konteks AI = maksimal 20 pesan terakhir session.
     */
    public function test_cs_2_context_window_limited_to_last_20_messages(): void
    {
        $session = ChatSession::factory()->for($this->user)->create();

        Message::factory()->count(25)->for($session, 'chatSession')->for($this->user)->create();

        FinancialAssistant::fake(['Siap.']);

        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', ['session_id' => $session->id, 'body' => 'lanjut'])
            ->assertOk();

        // Sync queue menjalankan job; assertPrompted mengecek prompt yang terekam.
        FinancialAssistant::assertPrompted(function (AgentPrompt $prompt): bool {
            /** @var array<int, \Laravel\Ai\Messages\Message> $context */
            $context = iterator_to_array($prompt->agent->messages(), false);

            // Konteks = 20 pesan terakhir (pending assistant excluded) + body dikirim sebagai prompt.
            return count($context) === 20
                && $context[19]->content === 'lanjut'
                && $prompt->prompt === 'lanjut';
        });
    }

    /**
     * CS-3: hapus session tidak menghapus transaksi yang sudah tercipta via chat.
     */
    public function test_cs_3_deleting_session_keeps_chat_created_transactions(): void
    {
        FinancialAssistant::fake([
            new ToolCall('call_1', 'CreateTransactionTool', [
                'type' => 'expense',
                'amount' => 15000,
                'description' => 'parkir',
            ]),
            'Dicatat: Lainnya Rp15.000.',
        ]);

        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', ['body' => 'parkir 15 ribu'])
            ->assertOk();

        $transaction = Transaction::query()->sole();
        $session = Message::query()->where('role', 'user')->sole()->chatSession;

        $this->actingAs($this->user, 'sanctum')
            ->deleteJson("/api/v1/sessions/{$session->id}")
            ->assertOk();

        // Pesan ikut terhapus (cascade), transaksi tetap aman.
        $this->assertDatabaseMissing('messages', ['chat_session_id' => $session->id]);
        $this->assertDatabaseHas('transactions', ['id' => $transaction->id, 'deleted_at' => null]);
    }

    /**
     * IS-2: session milik user lain → 404 saat dipakai di /chat.
     */
    public function test_is_2_cross_user_session_on_chat_returns_404(): void
    {
        $other = User::factory()->create();
        $foreignSession = ChatSession::factory()->for($other)->create();

        Queue::fake();
        FinancialAssistant::fake(['Oke.']);

        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', ['session_id' => $foreignSession->id, 'body' => 'halo'])
            ->assertNotFound()
            ->assertJson(['message' => 'Not found.']);

        // Tidak ada pesan yang ditulis ke session milik user lain.
        $this->assertSame(0, $foreignSession->messages()->count());
    }

    /**
     * IS-3: rate limit 30 req/menit/user → 429.
     */
    public function test_is_3_rate_limit_returns_429_after_30_requests_per_minute(): void
    {
        Queue::fake();
        FinancialAssistant::fake(['Oke.']);

        for ($i = 0; $i < 30; $i++) {
            $this->actingAs($this->user, 'sanctum')
                ->postJson('/api/v1/chat', ['body' => "pesan ke-{$i}"])
                ->assertOk();
        }

        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', ['body' => 'pesan ke-31'])
            ->assertStatus(429);
    }

    /**
     * Provider gagal → status message = failed (async, bukan 503).
     */
    public function test_provider_failure_sets_message_status_to_failed(): void
    {
        FinancialAssistant::fake(
            fn (): never => throw ProviderConnectionException::forProvider('openai'),
        );

        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', ['body' => 'makan 25 ribu'])
            ->assertOk();

        // Sync queue menjalankan job; provider gagal → status = failed.
        $assistantMessage = Message::query()->where('role', 'assistant')->sole();
        $this->assertSame('failed', $assistantMessage->status);
        $this->assertStringContainsString('AI', $assistantMessage->content);

        // Pesan user tetap tercatat (audit + konteks).
        $this->assertDatabaseHas('messages', [
            'user_id' => $this->user->id,
            'role' => 'user',
            'content' => 'makan 25 ribu',
        ]);
        $this->assertSame(0, Transaction::query()->count());
    }

    /**
     * Validasi request: body wajib.
     */
    public function test_chat_requires_body(): void
    {
        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/chat', [])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['body']);
    }
}
