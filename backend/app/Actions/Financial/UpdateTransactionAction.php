<?php

declare(strict_types=1);

namespace App\Actions\Financial;

use App\Models\Transaction;
use Illuminate\Support\Facades\DB;

/**
 * Update transaksi milik user (partial). Model sudah ter-scope user (IS-1).
 */
final readonly class UpdateTransactionAction
{
    public function execute(Transaction $transaction, array $data): Transaction
    {
        return DB::transaction(function () use ($transaction, $data): Transaction {
            $transaction->fill($data)->save();

            return $transaction->refresh();
        });
    }
}
