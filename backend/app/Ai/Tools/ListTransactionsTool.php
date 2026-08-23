<?php

declare(strict_types=1);

namespace App\Ai\Tools;

use App\Data\Period;
use App\Models\User;
use Illuminate\Contracts\JsonSchema\JsonSchema;
use Laravel\Ai\Contracts\Tool;
use Laravel\Ai\Tools\Request;
use Stringable;

/**
 * AI-4/AI-5: daftar transaksi ringkas agar model bisa meresolve referensi
 * ("yang tadi", "makan kemarin") menjadi transaction_id eksplisit.
 */
final readonly class ListTransactionsTool implements Tool
{
    private const LIMIT = 20;

    public function __construct(
        private User $user,
    ) {}

    public function description(): Stringable|string
    {
        return 'Daftar transaksi user terbaru (id, jenis, nominal, deskripsi, kategori, waktu). Gunakan untuk menemukan transaction_id sebelum update/delete.';
    }

    public function schema(JsonSchema $schema): array
    {
        return [
            'period' => $schema->string()->enum(['today', 'week', 'month', 'year']),
            'from' => $schema->string()->format('YYYY-MM-DD'),
            'to' => $schema->string()->format('YYYY-MM-DD'),
            'type' => $schema->string()->enum(['income', 'expense']),
        ];
    }

    public function handle(Request $request): Stringable|string
    {
        $args = $request->all();

        try {
            $period = Period::fromParams([
                'period' => is_string($args['period'] ?? null) ? $args['period'] : null,
                'from' => is_string($args['from'] ?? null) ? $args['from'] : null,
                'to' => is_string($args['to'] ?? null) ? $args['to'] : null,
            ]);
        } catch (\Throwable) {
            return ToolResult::fail('Parameter periode tidak valid.');
        }

        $type = is_string($args['type'] ?? null) && in_array($args['type'], ['income', 'expense'], true)
            ? $args['type']
            : null;

        // IS-1: query lewat relasi user — hanya data milik user ini.
        $transactions = $this->user
            ->transactions()
            ->with('category')
            ->inPeriod($period->from, $period->to)
            ->when($type !== null, fn ($query) => $query->ofType($type))
            ->orderByDesc('occurred_at')
            ->orderByDesc('id')
            ->limit(self::LIMIT)
            ->get();

        return ToolResult::ok([
            'count' => $transactions->count(),
            'transactions' => $transactions->map(fn ($transaction): array => [
                'id' => $transaction->id,
                'type' => $transaction->type,
                'amount' => $transaction->amount,
                'description' => $transaction->description,
                'category' => $transaction->category?->name,
                'occurred_at' => $transaction->occurred_at?->toIso8601String(),
            ])->all(),
        ]);
    }
}
