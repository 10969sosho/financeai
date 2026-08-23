<?php

declare(strict_types=1);

namespace App\Ai\Tools;

use App\Actions\Financial\DeleteTransactionAction;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Contracts\JsonSchema\JsonSchema;
use Laravel\Ai\Contracts\Tool;
use Laravel\Ai\Tools\Request;
use Stringable;

/**
 * AI-5: delete butuh referensi jelas (transaction_id). Soft delete saja (TR-5).
 * Ownership dijaga via relasi user (IS-1).
 */
final readonly class DeleteTransactionTool implements Tool
{
    public function __construct(
        private User $user,
        private DeleteTransactionAction $deleteTransaction,
    ) {}

    public function description(): Stringable|string
    {
        return 'Hapus (soft delete) transaksi user berdasarkan transaction_id. Konfirmasi ke user bila referensinya tidak jelas.';
    }

    public function schema(JsonSchema $schema): array
    {
        return [
            'transaction_id' => $schema->integer()->min(1)->required(),
        ];
    }

    public function handle(Request $request): Stringable|string
    {
        $args = $request->all();

        $transactionId = $args['transaction_id'] ?? null;

        if (! is_numeric($transactionId) || (int) $transactionId < 1) {
            return ToolResult::fail('transaction_id wajib berupa angka.');
        }

        // IS-1: hanya transaksi milik user ini.
        /** @var ?Transaction $transaction */
        $transaction = $this->user->transactions()->find((int) $transactionId);

        if ($transaction === null) {
            return ToolResult::fail('Transaksi tidak ditemukan.');
        }

        try {
            $this->deleteTransaction->execute($transaction);
        } catch (\Throwable $e) {
            report($e);

            return ToolResult::fail('Gagal menghapus transaksi.');
        }

        return ToolResult::ok([
            'transaction_id' => $transaction->id,
            'deleted' => true,
            'description' => $transaction->description,
            'amount' => $transaction->amount,
        ]);
    }
}
