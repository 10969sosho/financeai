<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Services\ReportService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Bentuk respons GET /reports/summary (API_REFERENCE).
 *
 * @mixin ReportService
 */
final class ReportSummaryResource extends JsonResource
{
    /**
     * Resource dibangun dari array hasil ReportService::summary().
     *
     * @return array<string, mixed>
     */
    public function toArray(Request $request): array
    {
        return [
            'period' => $this->resource['period'],
            'income' => $this->resource['income'],
            'expense' => $this->resource['expense'],
            'net' => $this->resource['net'],
        ];
    }
}
