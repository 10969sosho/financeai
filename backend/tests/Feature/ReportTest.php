<?php

declare(strict_types=1);

namespace Tests\Feature;

use App\Models\Category;
use App\Models\Transaction;
use App\Models\User;
use Database\Seeders\CategorySeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Tests\TestCase;

final class ReportTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    private Category $makanan;

    private Category $transportasi;

    private Category $gaji;

    protected function setUp(): void
    {
        parent::setUp();

        $this->seed(CategorySeeder::class);

        $this->user = User::factory()->create();
        $this->makanan = Category::query()->where('name', 'Makanan')->firstOrFail();
        $this->transportasi = Category::query()->where('name', 'Transportasi')->firstOrFail();
        $this->gaji = Category::query()->where('name', 'Gaji')->firstOrFail();
    }

    /**
     * RP-1: net = total income − total expense pada periode yang sama.
     */
    public function test_rp_1_summary_net_is_income_minus_expense(): void
    {
        // Income: 5.000.000. Expense: 120.000 + 50.000 = 170.000 → net 4.830.000.
        Transaction::factory()->income()->amount(5000000)->for($this->user, 'user')
            ->for($this->gaji, 'category')->occurredAt(now())->create();
        Transaction::factory()->expense()->amount(120000)->for($this->user, 'user')
            ->for($this->makanan, 'category')->occurredAt(now())->create();
        Transaction::factory()->expense()->amount(50000)->for($this->user, 'user')
            ->for($this->transportasi, 'category')->occurredAt(now())->create();

        $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/reports/summary?period=month')
            ->assertOk()
            ->assertJsonPath('data.income', 5000000)
            ->assertJsonPath('data.expense', 170000)
            ->assertJsonPath('data.net', 4830000)
            ->assertJsonStructure(['data' => ['period' => ['from', 'to']]]);
    }

    /**
     * RP-2: default periode = bulan berjalan; transaksi bulan lalu tidak ikut.
     */
    public function test_rp_2_default_period_is_current_month(): void
    {
        Transaction::factory()->expense()->amount(100000)->for($this->user, 'user')
            ->for($this->makanan, 'category')->occurredAt(now())->create();

        Transaction::factory()->expense()->amount(777000)->for($this->user, 'user')
            ->for($this->makanan, 'category')
            ->occurredAt(Carbon::now()->subMonthNoOverflow()->startOfMonth()->addDays(2))
            ->create();

        // Tanpa parameter periode → default month.
        $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/reports/summary')
            ->assertOk()
            ->assertJsonPath('data.expense', 100000)
            ->assertJsonPath('data.period.from', now()->startOfMonth()->toDateString())
            ->assertJsonPath('data.period.to', now()->endOfMonth()->toDateString());
    }

    /**
     * RP-3: breakdown per kategori dari transaksi non-deleted, urut nominal terbesar.
     */
    public function test_rp_3_breakdown_groups_by_category_sorted_desc(): void
    {
        // Makanan: 2 transaksi = 150.000. Transportasi: 3 transaksi = 300.000.
        Transaction::factory()->expense()->amount(100000)->for($this->user, 'user')
            ->for($this->makanan, 'category')->occurredAt(now())->create();
        Transaction::factory()->expense()->amount(50000)->for($this->user, 'user')
            ->for($this->makanan, 'category')->occurredAt(now())->create();

        foreach ([100000, 100000, 100000] as $amount) {
            Transaction::factory()->expense()->amount($amount)->for($this->user, 'user')
                ->for($this->transportasi, 'category')->occurredAt(now())->create();
        }

        Transaction::factory()->income()->amount(2000000)->for($this->user, 'user')
            ->for($this->gaji, 'category')->occurredAt(now())->create();

        $response = $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/reports/breakdown?period=month')
            ->assertOk()
            ->assertJsonCount(2, 'data.expense_by_category');

        $expenses = collect($response->json('data.expense_by_category'));

        // Urut nominal terbesar (RP-3).
        $this->assertSame([300000, 150000], $expenses->pluck('total')->all());
        $this->assertSame('Transportasi', $expenses[0]['category']['name']);
        $this->assertSame(3, $expenses[0]['count']);
        $this->assertSame('Makanan', $expenses[1]['category']['name']);
        $this->assertSame(2, $expenses[1]['count']);

        $incomes = collect($response->json('data.income_by_category'));
        $this->assertSame([2000000], $incomes->pluck('total')->all());
        $this->assertSame('Gaji', $incomes[0]['category']['name']);
    }

    /**
     * RP-3: transaksi soft-deleted tidak masuk laporan.
     */
    public function test_rp_3_breakdown_excludes_soft_deleted_transactions(): void
    {
        $kept = Transaction::factory()->expense()->amount(80000)->for($this->user, 'user')
            ->for($this->makanan, 'category')->occurredAt(now())->create();
        $removed = Transaction::factory()->expense()->amount(999999)->for($this->user, 'user')
            ->for($this->makanan, 'category')->occurredAt(now())->create();
        $removed->delete();
        unset($kept);

        $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/reports/breakdown?period=month')
            ->assertOk()
            ->assertJsonPath('data.expense_by_category.0.total', 80000)
            ->assertJsonPath('data.expense_by_category.0.count', 1);
    }

    public function test_custom_period_from_to_is_supported(): void
    {
        Transaction::factory()->expense()->amount(25000)->for($this->user, 'user')
            ->for($this->makanan, 'category')->occurredAt(now())->create();

        // Periode lampau yang tidak memuat transaksi manapun.
        $from = Carbon::now()->subYear()->startOfMonth()->toDateString();
        $to = Carbon::now()->subYear()->endOfMonth()->toDateString();

        $this->actingAs($this->user, 'sanctum')
            ->getJson("/api/v1/reports/summary?from={$from}&to={$to}")
            ->assertOk()
            ->assertJsonPath('data.income', 0)
            ->assertJsonPath('data.expense', 0)
            ->assertJsonPath('data.net', 0)
            ->assertJsonPath('data.period.from', $from);
    }

    public function test_reports_are_user_scoped(): void
    {
        $other = User::factory()->create();
        Transaction::factory()->expense()->amount(1234567)->for($other, 'user')
            ->for($this->makanan, 'category')->occurredAt(now())->create();

        $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/reports/summary?period=month')
            ->assertOk()
            ->assertJsonPath('data.expense', 0);

        $this->actingAs($this->user, 'sanctum')
            ->getJson('/api/v1/reports/breakdown?period=month')
            ->assertOk()
            ->assertJsonCount(0, 'data.expense_by_category');
    }
}
