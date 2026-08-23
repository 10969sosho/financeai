<?php

declare(strict_types=1);

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Bentuk respons GET /reports/breakdown (API_REFERENCE, RP-3).
 */
final class ReportBreakdownResource extends JsonResource
{
    /**
     * Resource dibangun dari array hasil ReportService::breakdown().
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'period' => $this->resource['period'],
            'expense_by_category' => $this->resource['expense_by_category'],
            'income_by_category' => $this->resource['income_by_category'],
        ];
    }
}
