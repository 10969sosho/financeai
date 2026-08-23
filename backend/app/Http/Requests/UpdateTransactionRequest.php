<?php

declare(strict_types=1);

namespace App\Http\Requests;

use App\Rules\NotFarFuture;
use App\Rules\UserOrDefaultCategory;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * PUT /transactions/{id}: partial update — semua field opsional (API_REFERENCE).
 */
final class UpdateTransactionRequest extends FormRequest
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
            'type' => ['sometimes', Rule::in(['income', 'expense'])],
            'amount' => ['sometimes', 'integer', 'min:1'],
            'description' => ['sometimes', 'string', 'max:255'],
            'category_id' => ['sometimes', 'integer', new UserOrDefaultCategory],
            'occurred_at' => ['sometimes', 'date', new NotFarFuture],
        ];
    }

    /**
     * Hanya field yang dikirim yang di-update.
     *
     * @return array<string, mixed>
     */
    public function toPayload(): array
    {
        $payload = [];

        if ($this->has('type')) {
            $payload['type'] = $this->string('type')->toString();
        }

        if ($this->has('amount')) {
            $payload['amount'] = $this->integer('amount');
        }

        if ($this->has('description')) {
            $payload['description'] = $this->string('description')->toString();
        }

        if ($this->has('category_id')) {
            $payload['category_id'] = $this->integer('category_id');
        }

        if ($this->has('occurred_at')) {
            $payload['occurred_at'] = $this->date('occurred_at');
        }

        return $payload;
    }
}
