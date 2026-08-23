<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Data\Period;
use App\Http\Controllers\Controller;
use App\Http\Requests\ReportPeriodRequest;
use App\Http\Resources\ReportBreakdownResource;
use App\Http\Resources\ReportSummaryResource;
use App\Models\User;
use App\Services\ReportService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;

final class ReportController extends Controller
{
    public function __construct(
        private readonly ReportService $reports,
    ) {}

    /**
     * GET /api/v1/reports/summary?period=today|week|month|year|from+to (RP-1/RP-2).
     */
    public function summary(ReportPeriodRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = Auth::user();

        return response()->json([
            'data' => new ReportSummaryResource(
                $this->reports->summary($user, Period::fromParams($request->periodParams())),
            ),
        ]);
    }

    /**
     * GET /api/v1/reports/breakdown — parameter sama dengan summary (RP-3).
     */
    public function breakdown(ReportPeriodRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = Auth::user();

        return response()->json([
            'data' => new ReportBreakdownResource(
                $this->reports->breakdown($user, Period::fromParams($request->periodParams())),
            ),
        ]);
    }
}
