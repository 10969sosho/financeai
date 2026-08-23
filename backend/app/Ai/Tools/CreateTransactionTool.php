<?php

declare(strict_types=1);

namespace App\Ai\Tools;

use App\Actions\Financial\CreateTransactionAction;
use App\Actions\Financial\ResolveCategoryAction;
use App\Models\User;
use Illuminate\Contracts\JsonSchema\JsonSchema;
use Illuminate\Support\Carbon;
use Laravel\Ai\Contracts\Tool;
use Laravel\Ai\Tools\Request;
use Stringable;

/**
 * Tool AI untuk mencatat transaksi. Tipis: terjemahkan argumen model → Action layer.
 * AI TIDAK dipercaya — validasi ketat di sini sebelum menyentuh Actions (AI-1).
 * Selalu beroperasi pada User yang di-inject server, bukan dari output model (AI-6).
 */
final readonly class CreateTransactionTool implements Tool
{
    public function __construct(
        private User $user,
        private ResolveCategoryAction $resolveCategory,
        private CreateTransactionAction $createTransaction,
    ) {}

    public function description(): Stringable|string
    {
        return 'Catat transaksi keuangan user (pemasukan/pengeluaran). Gunakan hanya setelah nominal dan jenis sudah jelas.';
    }

    public function schema(JsonSchema $schema): array
    {
        return [
            'type' => $schema->string()->enum(['income', 'expense'])->required(),
            'amount' => $schema->integer()->min(1)->required(),
            'description' => $schema->string()->required(),
            'category' => $schema->string(),
            'occurred_at' => $schema->string()->format('ISO8601 datetime, mis. 2026-08-23T09:00:00+07:00'),
        ];
    }

    public function handle(Request $request): Stringable|string
    {
        // Validasi ketat — argumen model tidak dipercaya.
        $args = $request->all();

        $type = is_string($args['type'] ?? null) ? $args['type'] : '';

        if (! in_array($type, ['income', 'expense'], true)) {
            return ToolResult::fail('Type harus income atau expense.');
        }

        $amount = $args['amount'] ?? null;

        if (! is_numeric($amount) || (int) $amount != $amount || (int) $amount < 1) {
            return ToolResult::fail('Amount harus bilangan bulat rupiah lebih besar dari 0.');
        }

        $description = trim((string) ($args['description'] ?? ''));

        if ($description === '') {
            return ToolResult::fail('Description wajib diisi.');
        }

        $occurredAt = now();

        if (isset($args['occurred_at']) && is_string($args['occurred_at']) && trim($args['occurred_at']) !== '') {
            try {
                $occurredAt = Carbon::parse(trim($args['occurred_at']));
            } catch (\Throwable) {
                return ToolResult::fail('Format occurred_at tidak valid.');
            }

            // TR-4: toleransi masa depan maksimal 5 menit.
            if ($occurredAt->gt(now()->addMinutes(5))) {
                return ToolResult::fail('Tanggal transaksi tidak boleh di masa depan melebihi 5 menit.');
            }
        }

        try {
            $category = $this->resolveCategory->execute(
                $this->user,
                $type,
                isset($args['category']) && is_string($args['category']) ? $args['category'] : null,
            );

            $transaction = $this->createTransaction->execute($this->user, [
                'type' => $type,
                'amount' => (int) $amount,
                'description' => $description,
                'category_id' => $category->id,
                'occurred_at' => $occurredAt,
                'source' => 'ai',
            ]);
        } catch (\Throwable $e) {
            report($e);

            return ToolResult::fail('Gagal mencatat transaksi.');
        }

        return ToolResult::ok([
            'transaction_id' => $transaction->id,
            'type' => $transaction->type,
            'amount' => $transaction->amount,
            'category' => $category->name,
            'description' => $transaction->description,
            'occurred_at' => $transaction->occurred_at?->toIso8601String(),
        ]);
    }
}
