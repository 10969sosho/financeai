<?php

declare(strict_types=1);

namespace App\Actions\Financial;

use App\Models\Transaction;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Satu operasi data = satu Action (ARCHITECTURE §5). AI TIDAK dipercaya —
 * validasi ketat terjadi di sini / di FormRequest sebelum masuk Action.
 */
final readonly class CreateTransactionAction
{
    public function execute(User $user, array $data): Transaction
    {
        /** @var Transaction */
        return DB::transaction(function () use ($user, $data): Transaction {
            return $user->transactions()->create([
                'type' => $data['type'],
                'amount' => (int) $data['amount'], // TR-1: integer rupiah > 0
                'description' => $data['description'],
                'occurred_at' => $data['occurred_at'] ?? now(),
                'category_id' => (int) $data['category_id'],
                'source' => $data['source'] ?? 'manual',
            ]);
        });
    }
}
