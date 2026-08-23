<?php

declare(strict_types=1);

namespace App\Services;

use App\Data\Period;
use App\Models\User;
use Illuminate\Support\Collection;

/**
 * RP-1: mutasi = income − expense pada periode sama.
 * RP-3: breakdown per kategori dari transaksi non-deleted, urut nominal terbesar.
 * RP-4: agregasi live dari DB, tanpa cache.
 */
final readonly class ReportService
{
    /**
     * @return array{period: array{from: string, to: string}, income: int, expense: int, net: int}
     */
    public function summary(User $user, Period $period): array
    {
        $base = $this->inPeriod($user, $period);

        $income = (int) (clone $base)->ofType('income')->sum('amount');
        $expense = (int) (clone $base)->ofType('expense')->sum('amount');

        return [
            'period' => $period->toApiShape(),
            'income' => $income,
            'expense' => $expense,
            'net' => $income - $expense, // RP-1
        ];
    }

    /**
     * @return array{
     *     period: array{from: string, to: string},
     *     expense_by_category: Collection<int, array{category: array{id: int, name: string}, total: int, count: int}>,
     *     income_by_category: Collection<int, array{category: array{id: int, name: string}, total: int, count: int}>
     * }
     */
    public function breakdown(User $user, Period $period): array
    {
        return [
            'period' => $period->toApiShape(),
            'expense_by_category' => $this->byCategory($user, $period, 'expense'),
            'income_by_category' => $this->byCategory($user, $period, 'income'),
        ];
    }

    /**
     * @return Collection<int, array{category: array{id: int, name: string}, total: int, count: int}>
     */
    private function byCategory(User $user, Period $period, string $type): Collection
    {
        return $this->inPeriod($user, $period)
            ->ofType($type)
            ->with('category') // eager load — hindari N+1 saat memetakan nama kategori
            ->selectRaw('category_id, SUM(amount) as total, COUNT(*) as total_count')
            ->groupBy('category_id')
            ->orderByDesc('total') // RP-3: nominal terbesar dulu
            ->get()
            ->map(fn ($row): array => [
                'category' => [
                    'id' => $row->category->id,
                    'name' => $row->category->name,
                ],
                'total' => (int) $row->total,
                'count' => (int) $row->total_count,
            ])
            ->values();
    }

    private function inPeriod(User $user, Period $period)
    {
        return $user->transactions()
            ->inPeriod($period->from, $period->to);
    }
}
