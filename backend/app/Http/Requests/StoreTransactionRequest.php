<?php

declare(strict_types=1);

namespace App\Http\Requests;

use App\Rules\NotFarFuture;
use App\Rules\UserOrDefaultCategory;
use Illuminate\Foundation\Http\FormRequest;
use Illuminate\Validation\Rule;

/**
 * TR-1: amount integer rupiah bulat positif (>= 1), tanpa sen/desimal.
 * TR-4: occurred_at tidak boleh masa depan > 5 menit.
 */
final class StoreTransactionRequest extends FormRequest
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
            'type' => ['required', Rule::in(['income', 'expense'])],
            // 'integer' menolak "25.5" & "abc"; min:1 menegaskan TR-1 (> 0).
            'amount' => ['required', 'integer', 'min:1'],
            'description' => ['required', 'string', 'max:255'],
            'category_id' => ['required', 'integer', new UserOrDefaultCategory],
            'occurred_at' => ['nullable', 'date', new NotFarFuture],
            'source' => ['sometimes', Rule::in(['ai', 'manual', 'voice', 'image'])],
        ];
    }

    /**
     * Payload siap eksekusi Action layer.
     *
     * @return array<string, mixed>
     */
    public function toPayload(): array
    {
        return [
            'type' => $this->string('type')->toString(),
            'amount' => $this->integer('amount'),
            'description' => $this->string('description')->toString(),
            'category_id' => $this->integer('category_id'),
            'occurred_at' => $this->filled('occurred_at') ? $this->date('occurred_at') : now(),
            'source' => $this->input('source', 'manual'),
        ];
    }
}
