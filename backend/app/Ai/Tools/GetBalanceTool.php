<?php

declare(strict_types=1);

namespace App\Ai\Tools;

use App\Data\Period;
use App\Models\User;
use App\Services\ReportService;
use Illuminate\Contracts\JsonSchema\JsonSchema;
use Laravel\Ai\Contracts\Tool;
use Laravel\Ai\Tools\Request;
use Stringable;

/**
 * AI-7: saldo/mutasi selalu dihitung dari database via ReportService.
 */
final readonly class GetBalanceTool implements Tool
{
    public function __construct(
        private User $user,
        private ReportService $reports,
    ) {}

    public function description(): Stringable|string
    {
        return 'Saldo/mutasi user: total income, expense, dan net (income − expense). Default periode: bulan berjalan.';
    }

    public function schema(JsonSchema $schema): array
    {
        return [
            'period' => $schema->string()->enum(['today', 'week', 'month', 'year']),
            'from' => $schema->string()->format('YYYY-MM-DD'),
            'to' => $schema->string()->format('YYYY-MM-DD'),
        ];
    }

    public function handle(Request $request): Stringable|string
    {
        $args = $request->all();

        try {
            $period = Period::fromParams([
                'period' => is_string($args['period'] ?? null) ? $args['period'] : null,
                'from' => is_string($args['from'] ?? null) ? $args['from'] : null,
                'to' => is_string($args['to'] ?? null) ? $args['to'] : null,
            ]);
        } catch (\Throwable) {
            return ToolResult::fail('Parameter periode tidak valid.');
        }

        return ToolResult::ok($this->reports->summary($this->user, $period));
    }
}
