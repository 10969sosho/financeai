<?php

declare(strict_types=1);

namespace App\Ai\Tools;

use App\Actions\Financial\ResolveCategoryAction;
use App\Actions\Financial\UpdateTransactionAction;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Contracts\JsonSchema\JsonSchema;
use Illuminate\Support\Carbon;
use Laravel\Ai\Contracts\Tool;
use Laravel\Ai\Tools\Request;
use Stringable;

/**
 * AI-4: koreksi transaksi via transaction_id eksplisit.
 * Ownership dijaga: query lewat relasi user (IS-1/IS-6) — transaction_id milik
 * user lain tidak akan ditemukan.
 */
final readonly class UpdateTransactionTool implements Tool
{
    public function __construct(
        private User $user,
        private ResolveCategoryAction $resolveCategory,
        private UpdateTransactionAction $updateTransaction,
    ) {}

    public function description(): Stringable|string
    {
        return 'Ubah transaksi yang sudah ada berdasarkan transaction_id. Gunakan setelah transaksi ditemukan via ListTransactionsTool.';
    }

    public function schema(JsonSchema $schema): array
    {
        return [
            'transaction_id' => $schema->integer()->min(1)->required(),
            'type' => $schema->string()->enum(['income', 'expense']),
            'amount' => $schema->integer()->min(1),
            'description' => $schema->string(),
            'category' => $schema->string(),
            'occurred_at' => $schema->string()->format('ISO8601 datetime'),
        ];
    }

    public function handle(Request $request): Stringable|string
    {
        $args = $request->all();

        $transactionId = $args['transaction_id'] ?? null;

        if (! is_numeric($transactionId) || (int) $transactionId < 1) {
            return ToolResult::fail('transaction_id wajib berupa angka.');
        }

        // IS-1: hanya transaksi milik user ini yang terlihat.
        /** @var ?Transaction $transaction */
        $transaction = $this->user->transactions()->find((int) $transactionId);

        if ($transaction === null) {
            return ToolResult::fail('Transaksi tidak ditemukan.');
        }

        $payload = [];

        if (isset($args['type']) && is_string($args['type'])) {
            if (! in_array($args['type'], ['income', 'expense'], true)) {
                return ToolResult::fail('Type harus income atau expense.');
            }

            $payload['type'] = $args['type'];
        }

        if (isset($args['amount'])) {
            $amount = $args['amount'];

            if (! is_numeric($amount) || (int) $amount != $amount || (int) $amount < 1) {
                return ToolResult::fail('Amount harus bilangan bulat rupiah lebih besar dari 0.');
            }

            $payload['amount'] = (int) $amount;
        }

        if (isset($args['description']) && is_string($args['description']) && trim($args['description']) !== '') {
            $payload['description'] = trim($args['description']);
        }

        if (isset($args['occurred_at']) && is_string($args['occurred_at']) && trim($args['occurred_at']) !== '') {
            try {
                $occurredAt = Carbon::parse(trim($args['occurred_at']));
            } catch (\Throwable) {
                return ToolResult::fail('Format occurred_at tidak valid.');
            }

            if ($occurredAt->gt(now()->addMinutes(5))) { // TR-4
                return ToolResult::fail('Tanggal transaksi tidak boleh di masa depan melebihi 5 menit.');
            }

            $payload['occurred_at'] = $occurredAt;
        }

        try {
            if (array_key_exists('category', $args) && is_string($args['category']) && trim($args['category']) !== '') {
                $payload['category_id'] = $this->resolveCategory
                    ->execute($this->user, $payload['type'] ?? $transaction->type, $args['category'])
                    ->id;
            }

            if ($payload === []) {
                return ToolResult::fail('Tidak ada field yang bisa diubah.');
            }

            $updated = $this->updateTransaction->execute($transaction, $payload);
        } catch (\Throwable $e) {
            report($e);

            return ToolResult::fail('Gagal mengubah transaksi.');
        }

        return ToolResult::ok([
            'transaction_id' => $updated->id,
            'type' => $updated->type,
            'amount' => $updated->amount,
            'description' => $updated->description,
            'occurred_at' => $updated->occurred_at?->toIso8601String(),
        ]);
    }
}
