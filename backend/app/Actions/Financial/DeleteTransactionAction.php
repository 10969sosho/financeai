<?php

declare(strict_types=1);

namespace App\Actions\Financial;

use App\Models\Transaction;
use Illuminate\Support\Facades\DB;

/**
 * TR-5: delete via API/AI = soft delete; hard delete hanya maintenance/manual.
 */
final readonly class DeleteTransactionAction
{
    public function execute(Transaction $transaction): void
    {
        DB::transaction(function () use ($transaction): void {
            $transaction->delete();
        });
    }
}
