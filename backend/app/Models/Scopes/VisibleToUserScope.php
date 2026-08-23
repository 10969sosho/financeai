<?php

declare(strict_types=1);

namespace App\Models\Scopes;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Scope;
use Illuminate\Support\Facades\Auth;

/**
 * IS-1 untuk Category: user hanya melihat kategori default global (user_id NULL)
 * ditambah kategori custom miliknya sendiri.
 */
final class VisibleToUserScope implements Scope
{
    public function apply(Builder $builder, Model $model): void
    {
        $userId = Auth::id();

        if ($userId !== null) {
            $column = $builder->getModel()->qualifyColumn('user_id');

            $builder->where(function (Builder $query) use ($column, $userId): void {
                $query->whereNull($column)->orWhere($column, $userId);
            });
        }
    }
}
