<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Transaction;
use App\Models\User;
use Database\Seeders\CategorySeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class TransactionTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    private Category $makanan;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(CategorySeeder::class);

        $this->user = User::factory()->create();
        $this->makanan = Category::query()->where('name', 'Makanan')->firstOrFail();
    }

    public function test_store_creates_transaction_and_returns_resource_shape(): void
    {
        $response = $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/transactions', [
                'type' => 'expense',
                'amount' => 25000,
                'description' => 'makan siang',
                'category_id' => $this->makanan->id,
            ]);

        $response->assertCreated()
            ->assertJsonPath('data.type', 'expense')
            ->assertJsonPath('data.amount', 25000)
            ->assertJsonPath('data.description', 'makan siang')
            ->assertJsonPath('data.category.id', $this->makanan->id)
            ->assertJsonPath('data.category.name', 'Makanan')
            ->assertJsonPath('data.source', 'manual');

        // Timestamp ISO8601 dengan offset +07:00 (API_REFERENCE).
        $response->assertJsonStructure(['data' => ['occurred_at']]);
        $this->assertMatchesRegularExpression(
            '/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+07:00$/',
            $response->json('data.occurred_at'),
        );

        $this->assertDatabaseHas('transactions', [
            'user_id' => $this->user->id,
            'type' => 'expense',
            'amount' => 25000,
        ]);
    }

    /**
     * TR-1: amount harus integer rupiah bulat positif (> 0).
     */
    public function test_tr_1_amount_must_be_positive_integer(): void
    {
        foreach ([0, -5000, 25.5, 'abc'] as $invalidAmount) {
            $this->actingAs($this->user, 'sanctum')
                ->postJson('/api/v1/transactions', [
                    'type' => 'expense',
                    'amount' => $invalidAmount,
                    'description' => 'test',
                    'category_id' => $this->makanan->id,
                ])
                ->assertUnprocessable()
                ->assertJsonValidationErrors(['amount']);
        }

        $this->assertDatabaseCount('transactions', 0);
    }

    /**
     * TR-4: occurred_at tidak boleh masa depan melebihi toleransi 5 menit.
     */
    public function test_tr_4_occurred_at_rejects_far_future_but_allows_small_tolerance(): void
    {
        $payload = fn (string $when): array => [
            'type' => 'expense',
            'amount' => 10000,
            'description' => 'test waktu',
            'category_id' => $this->makanan->id,
            'occurred_at' => $when,
        ];

        // Masa depan jauh → ditolak.
        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/transactions', $payload(now()->addHour()->toIso8601String()))
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['occurred_at']);

        // Dalam toleransi 5 menit & backdate → diterima.
        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/transactions', $payload(now()->addMinutes(2)->toIso8601String()))
            ->assertCreated();

        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/transactions', $payload(now()->subDay()->toIso8601String()))
            ->assertCreated();
    }

    public function test_store_rejects_category_owned_by_other_user(): void
    {
        $otherUser = User::factory()->create();
        $foreignCategory = Category::factory()->forUser($otherUser)->expense()->create();

        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/transactions', [
                'type' => 'expense',
                'amount' => 5000,
                'description' => 'test',
                'category_id' => $foreignCategory->id,
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['category_id']);
    }

    public function test_index_returns_paginated_meta_and_filters(): void
    {
        $minuman = Category::query()->where('name', 'Minuman')->firstOrFail();

        Transaction::factory()->count(3)->expense()->for($this->user, 'user')
            ->for($this->makanan, 'category')->create();
        Transaction::factory()->income()->amount(1000000)->for($this->user, 'user')
            ->for(Category::query()->where('name', 'Gaji')->firstOrFail(), 'category')->create();
        Transaction::factory()->expense()->amount(20000)->for($this->user, 'user')
            ->for($minuman, 'category')->create();

        // Tanpa filter: total 5 (3 makanan + 1 gaji + 1 minuman), per_page=2 → last_page 3.
        $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/transactions?per_page=2')
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.total', 5)
            ->assertJsonPath('meta.current_page', 1)
            ->assertJsonPath('meta.last_page', 3);

        // Filter type=expense → 4 transaksi expense? Tidak: 3 makanan + 1 minuman = 4 expense, income 1.
        $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/transactions?type=expense')
            ->assertOk()
            ->assertJsonPath('meta.total', 4);

        // Filter category_id.
        $this->actingAs($this->user, 'sanctum')
            ->getJson("/api/v1/transactions?category_id={$minuman->id}")
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.category.name', 'Minuman');

        // Filter from/to hari ini saja (semua dibuat now).
        $today = now()->toDateString();
        $this->actingAs($this->user, 'sanctum')
            ->getJson("/api/v1/transactions?from={$today}&to={$today}")
            ->assertOk()
            ->assertJsonPath('meta.total', 5);
    }

    public function test_index_does_not_leak_other_users_transactions(): void
    {
        $other = User::factory()->create();
        Transaction::factory()->for($other, 'user')->for($this->makanan, 'category')->create();

        $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/transactions')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    public function test_update_partial_fields_only(): void
    {
        $transaction = Transaction::factory()->amount(25000)->for($this->user, 'user')
            ->for($this->makanan, 'category')->create();

        $this->actingAs($this->user, 'sanctum')
            ->putJson("/api/v1/transactions/{$transaction->id}", [
                'description' => 'makan siang revisi',
            ])
            ->assertOk()
            ->assertJsonPath('data.description', 'makan siang revisi')
            ->assertJsonPath('data.amount', 25000); // field lain tidak berubah

        $this->assertDatabaseHas('transactions', [
            'id' => $transaction->id,
            'description' => 'makan siang revisi',
            'amount' => 25000,
        ]);
    }

    public function test_update_validates_amount_against_tr_1(): void
    {
        $transaction = Transaction::factory()->for($this->user, 'user')
            ->for($this->makanan, 'category')->create();

        $this->actingAs($this->user, 'sanctum')
            ->putJson("/api/v1/transactions/{$transaction->id}", ['amount' => -1])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['amount']);
    }

    /**
     * TR-5: delete via API = soft delete — baris masih ada di DB.
     */
    public function test_tr_5_delete_is_soft_delete(): void
    {
        $transaction = Transaction::factory()->for($this->user, 'user')
            ->for($this->makanan, 'category')->create();

        $this->actingAs($this->user, 'sanctum')
            ->deleteJson("/api/v1/transactions/{$transaction->id}")
            ->assertOk()
            ->assertJson(['message' => 'Transaction deleted.']);

        $this->assertDatabaseHas('transactions', ['id' => $transaction->id]);
        $this->assertSoftDeleted('transactions', ['id' => $transaction->id]);

        // Sudah tidak muncul di index.
        $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/transactions')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    /**
     * IS-2: resource milik user lain → 404, bukan 403.
     */
    public function test_is_2_cross_user_transaction_access_returns_404(): void
    {
        $other = User::factory()->create();
        $foreign = Transaction::factory()->for($other, 'user')
            ->for($this->makanan, 'category')->create();

        $this->actingAs($this->user, 'sanctum')
            ->putJson("/api/v1/transactions/{$foreign->id}", ['amount' => 999])
            ->assertNotFound()
            ->assertJson(['message' => 'Not found.']);

        $this->actingAs($this->user, 'sanctum')
            ->deleteJson("/api/v1/transactions/{$foreign->id}")
            ->assertNotFound()
            ->assertJson(['message' => 'Not found.']);

        // Data tidak berubah.
        $this->assertDatabaseHas('transactions', ['id' => $foreign->id, 'deleted_at' => null]);
    }
}
