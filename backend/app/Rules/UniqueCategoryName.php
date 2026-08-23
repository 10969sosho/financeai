<?php

declare(strict_types=1);

namespace App\Rules;

use App\Models\Category;
use Closure;
use Illuminate\Contracts\Validation\DataAwareRule;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Support\Facades\Auth;

/**
 * CT-2: nama kategori unik per user per type, case-insensitive.
 * Nama yang bentrok dengan default global juga ditolak agar resolusi kategori tidak ambigu.
 */
final class UniqueCategoryName implements DataAwareRule, ValidationRule
{
    /**
     * @var array<string, mixed>
     */
    private array $data = [];

    public function setData(array $data): static
    {
        $this->data = $data;

        return $this;
    }

    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        $type = $this->data['type'] ?? null;

        $duplicate = Category::query()
            ->whereNull('deleted_at')
            ->when($type !== null, fn ($query) => $query->where('type', $type))
            ->whereRaw('LOWER(name) = LOWER(?)', [(string) $value])
            ->where(function ($query): void {
                $query->whereNull('user_id')
                    ->orWhere('user_id', Auth::id());
            })
            ->exists();

        if ($duplicate) {
            $fail('The :attribute has already been taken.');
        }
    }
}
