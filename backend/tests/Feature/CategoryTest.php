<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\Category;
use App\Models\User;
use Database\Seeders\CategorySeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

final class CategoryTest extends TestCase
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
     * CT-1: 12 kategori default global ter-seed dan tampil untuk semua user.
     */
    public function test_ct_1_default_categories_are_seeded_and_listed(): void
    {
        $response = $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/categories')
            ->assertOk()
            ->assertJsonCount(12, 'data');

        $names = collect($response->json('data'))->pluck('name')->all();

        foreach (['Makanan', 'Minuman', 'Transportasi', 'Belanja', 'Hiburan', 'Tagihan', 'Lainnya'] as $expense) {
            $this->assertContains($expense, $names);
        }

        foreach (['Gaji', 'Project', 'Bonus', 'Transfer', 'Lainnya'] as $income) {
            $this->assertContains($income, $names);
        }

        // Semua default: is_default true.
        $items = collect($response->json('data'));
        $this->assertSame(12, $items->where('is_default', true)->count());
    }

    public function test_categories_list_merges_defaults_with_user_custom(): void
    {
        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/categories', ['name' => 'Kopi', 'type' => 'expense'])
            ->assertCreated()
            ->assertJsonPath('data.name', 'Kopi')
            ->assertJsonPath('data.type', 'expense')
            ->assertJsonPath('data.is_default', false);

        $items = collect($this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/categories')
            ->json('data'));

        $this->assertSame(13, $items->count());

        $kopi = $items->firstWhere('name', 'Kopi');
        $this->assertNotNull($kopi);
        $this->assertFalse($kopi['is_default']);
        $this->assertSame('expense', $kopi['type']);
    }

    /**
     * CT-2: nama kategori unik per user per type, case-insensitive → duplikat 422.
     */
    public function test_ct_2_duplicate_custom_category_rejected_case_insensitive(): void
    {
        $act = fn (string $name) => $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/categories', ['name' => $name, 'type' => 'expense']);

        $act('Kopi')->assertCreated();

        // Duplikat persis & beda kapitalisasi → 422.
        $act('Kopi')->assertUnprocessable()->assertJsonValidationErrors(['name']);
        $act('KOPI')->assertUnprocessable()->assertJsonValidationErrors(['name']);
        $act('kopi')->assertUnprocessable()->assertJsonValidationErrors(['name']);

        // Nama sama tapi type berbeda → boleh.
        $this->actingAs($this->user, 'sanctum')
            ->postJson('/api/v1/categories', ['name' => 'Kopi', 'type' => 'income'])
            ->assertCreated();

        // Bentrok dengan nama default global juga ditolak (mencegah ambiguitas resolusi).
        $act('MAKANAN')->assertUnprocessable()->assertJsonValidationErrors(['name']);
    }

    /**
     * IS-1/CT-2: user tidak melihat kategori custom milik user lain,
     * dan tidak bisa memakainya.
     */
    public function test_other_users_custom_categories_are_invisible(): void
    {
        $other = User::factory()->create();
        Category::factory()->forUser($other)->expense()->create(['name' => 'Rahasia']);

        $names = collect($this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/categories')
            ->json('data'))
            ->pluck('name');

        $this->assertContains('Makanan', $names); // default tetap terlihat
        $this->assertNotContains('Rahasia', $names);
    }
}
