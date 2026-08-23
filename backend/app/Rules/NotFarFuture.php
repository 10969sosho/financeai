<?php

declare(strict_types=1);

namespace App\Rules;

use Closure;
use Illuminate\Contracts\Validation\ValidationRule;
use Illuminate\Support\Carbon;

/**
 * TR-4: occurred_at tidak boleh masa depan melebihi toleransi 5 menit.
 */
final class NotFarFuture implements ValidationRule
{
    public function __construct(
        private readonly int $toleranceMinutes = 5,
    ) {}

    public function validate(string $attribute, mixed $value, Closure $fail): void
    {
        $date = Carbon::parse($value);

        if ($date->gt(now()->addMinutes($this->toleranceMinutes))) {
            $fail('The :attribute may not be more than '.$this->toleranceMinutes.' minutes in the future.');
        }
    }
}
