<?php

declare(strict_types=1);

namespace App\Rules;

use App\Models\Category;
use Closure;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Support\Facades\Auth;

/**
 * category_id harus milik user ATAU kategori default global (API_REFERENCE: Transactions).
 * Query langsung ke tabel (bukan lewat Eloquent global scope) supaya aturan eksplisit.
 */
final class UserOrDefaultCategory implements ValidationRule
{
    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        $exists = Category::query()
            ->where('id', (int) $value)
            ->whereNull('deleted_at')
            ->where(function ($query): void {
                $query->whereNull('user_id')
                    ->orWhere('user_id', Auth::id());
            })
            ->exists();

        if (! $exists) {
            $fail('The selected :attribute is invalid.');
        }
    }
}
