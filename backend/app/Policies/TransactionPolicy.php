<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\Transaction;
use App\Models\User;
use Illuminate\Auth\Access\Response;

/**
 * IS-2: transaksi milik user lain → 404 (bukan 403, agar tidak bocor keberadaan resource).
 */
final class TransactionPolicy
{
    public function view(User $user, Transaction $transaction): Response
    {
        return $transaction->user_id === $user->id
            ? Response::allow()
            : Response::denyAsNotFound();
    }

    public function update(User $user, Transaction $transaction): Response
    {
        return $transaction->user_id === $user->id
            ? Response::allow()
            : Response::denyAsNotFound();
    }

    public function delete(User $user, Transaction $transaction): Response
    {
        return $transaction->user_id === $user->id
            ? Response::allow()
            : Response::denyAsNotFound();
    }
}
