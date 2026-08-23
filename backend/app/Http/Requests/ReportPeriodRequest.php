<?php

declare(strict_types=1);

namespace App\Http\Requests;

use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * Validasi parameter periode laporan (dipakai summary & breakdown).
 */
final class ReportPeriodRequest extends FormRequest
{
    public function authorize(): bool
    {
        return true;
    }

    /**
     * @return array<string, array<int, mixed>>
     */
    public function rules(): array
    {
        return [
            'period' => ['nullable', Rule::in(['today', 'week', 'month', 'year'])],
            'from' => ['required_with:to', 'nullable', 'date_format:Y-m-d'],
            'to' => ['required_with:from', 'nullable', 'date_format:Y-m-d', 'after_or_equal:from'],
        ];
    }

    /**
     * @return array{period?: string|null, from?: string|null, to?: string|null}
     */
    public function periodParams(): array
    {
        return [
            'period' => $this->input('period'),
            'from' => $this->input('from'),
            'to' => $this->input('to'),
        ];
    }
}
