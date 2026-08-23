<?php

declare(strict_types=1);

namespace App\Models\Scopes;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Scope;
use Illuminate\Support\Facades\Auth;

/**
 * IS-1: Global scope yang menegaskan semua query hanya menyentuh data
 * milik user yang sedang login.
 *
 * Scope dievaluasi lazily saat query dibangun; jika tidak ada user terautentikasi
 * (console, seeding, factory di test), scope dilewati — endpoint API finansial
 * selalu berada di belakang middleware auth:sanctum sehingga tetap aman.
 */
final class UserScope implements Scope
{
    public function apply(Builder $builder, Model $model): void
    {
        $userId = Auth::id();

        if ($userId !== null) {
            $builder->where($builder->getModel()->qualifyColumn('user_id'), $userId);
        }
    }
}
