<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\Category;
use App\Models\ChatSession;
use App\Models\Message;
use App\Models\Transaction;
use App\Models\User;
use Database\Seeders\CategorySeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class ChatSessionTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(CategorySeeder::class);

        $this->user = User::factory()->create();
    }

    public function test_create_session_returns_201_with_null_title(): void
    {
        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/sessions')
            ->assertCreated()
            ->assertJsonPath('data.title', null)
            ->assertJsonStructure(['data' => ['id', 'title', 'last_message_at', 'created_at']]);

        $this->assertDatabaseHas('chat_sessions', ['user_id' => $this->user->id]);
    }

    public function test_sessions_listed_by_last_message_at_desc(): void
    {
        $old = ChatSession::factory()->for($this->user)->lastActiveAt(now()->subDays(2))->create();
        $new = ChatSession::factory()->for($this->user)->lastActiveAt(now())->create();
        $empty = ChatSession::factory()->for($this->user)->create(); // tanpa aktivitas

        $ids = collect($this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/sessions')
            ->json('data'))
            ->pluck('id')
            ->all();

        $this->assertSame([$new->id, $old->id, $empty->id], $ids);
    }

    public function test_messages_listed_chronologically_with_metadata(): void
    {
        $session = ChatSession::factory()->for($this->user)->create();

        Message::factory()->for($session, 'chatSession')->for($this->user)
            ->create(['content' => 'tadi makan 25 ribu']);
        Message::factory()->for($session, 'chatSession')->for($this->user)
            ->withMetadata(['actions' => [['action' => 'create_transaction', 'result' => 'ok', 'transaction_id' => 88]]])
            ->fromAssistant()
            ->create(['content' => 'Oke, dicatat ya: Makanan Rp25.000.']);

        $response = $this->actingAs($this->user, 'sanctum')
            ->getJson("/api/v1/sessions/{$session->id}/messages")
            ->assertOk()
            ->assertJsonCount(2, 'data');

        // Urut lama → baru berdasarkan waktu dibuat.
        $this->assertSame('tadi makan 25 ribu', $response->json('data.0.content'));
        $this->assertSame('user', $response->json('data.0.role'));
        $this->assertSame(null, $response->json('data.0.metadata'));

        $this->assertSame('assistant', $response->json('data.1.role'));
        $this->assertSame(
            88,
            $response->json('data.1.metadata.actions.0.transaction_id'),
        );
    }

    /**
     * CS-3: menghapus session tidak menghapus transaksi yang sudah tercipta.
     */
    public function test_cs_3_deleting_session_keeps_transactions(): void
    {
        $session = ChatSession::factory()->for($this->user)->create();
        Message::factory()->count(3)->for($session, 'chatSession')->for($this->user)->create();

        $category = Category::query()->where('name', 'Makanan')->firstOrFail();
        $transaction = Transaction::factory()->for($this->user, 'user')
            ->for($category, 'category')->create();

        $this->actingAs($this->user, 'sanctum')
            ->deleteJson("/api/v1/sessions/{$session->id}")
            ->assertOk()
            ->assertJson(['message' => 'Session deleted.']);

        // Pesan ikut terhapus (cascade), transaksi tetap aman.
        $this->assertDatabaseMissing('messages', ['chat_session_id' => $session->id]);
        $this->assertDatabaseHas('transactions', [
            'id' => $transaction->id,
            'deleted_at' => null,
        ]);
    }

    /**
     * IS-2: session milik user lain → 404 (bukan 403).
     */
    public function test_is_2_other_users_session_returns_404(): void
    {
        $other = User::factory()->create();
        $foreign = ChatSession::factory()->for($other)->create();
        Message::factory()->for($foreign, 'chatSession')->for($other)->create();

        $this->actingAs($this->user, 'sanctum')
            ->deleteJson("/api/v1/sessions/{$foreign->id}")
            ->assertNotFound()
            ->assertJson(['message' => 'Not found.']);

        $this->actingAs($this->user, 'sanctum')
            ->getJson("/api/v1/sessions/{$foreign->id}/messages")
            ->assertNotFound()
            ->assertJson(['message' => 'Not found.']);

        // Session & pesan milik user lain tidak terhapus/terbaca.
        $this->assertDatabaseHas('chat_sessions', ['id' => $foreign->id]);
        $this->assertDatabaseHas('messages', ['chat_session_id' => $foreign->id]);
    }
}
