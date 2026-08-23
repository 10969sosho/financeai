<?php

declare(strict_types=1);

namespace App\Data;

use Carbon\CarbonImmutable;
use Illuminate\Support\Carbon;
use InvalidArgumentException;

/**
 * RP-2: periode laporan — today|week|month|year atau custom(from,to); default bulan berjalan.
 * Timezone mengikuti aplikasi (Asia/Jakarta).
 */
final readonly class Period
{
    public function __construct(
        public CarbonImmutable $from,
        public CarbonImmutable $to,
    ) {}

    /**
     * @param  array{period?: string|null, from?: string|null, to?: string|null}  $params
     */
    public static function fromParams(array $params): self
    {
        $period = $params['period'] ?? null;
        $from = $params['from'] ?? null;
        $to = $params['to'] ?? null;

        if ($from !== null && $to !== null) {
            return new self(
                Carbon::parse($from)->startOfDay()->toImmutable(),
                Carbon::parse($to)->endOfDay()->toImmutable(),
            );
        }

        $now = Carbon::now();

        return match ($period) {
            'today' => new self($now->copy()->startOfDay()->toImmutable(), $now->copy()->endOfDay()->toImmutable()),
            'week' => new self($now->copy()->startOfWeek()->toImmutable(), $now->copy()->endOfWeek()->toImmutable()),
            'year' => new self($now->copy()->startOfYear()->toImmutable(), $now->copy()->endOfYear()->toImmutable()),
            null, '', 'month' => new self($now->copy()->startOfMonth()->toImmutable(), $now->copy()->endOfMonth()->toImmutable()),
            default => throw new InvalidArgumentException("Periode tidak didukung: {$period}."),
        };
    }

    /**
     * Bentuk respons API: { "from": "2026-08-01", "to": "2026-08-31" }.
     *
     * @return array{from: string, to: string}
     */
    public function toApiShape(): array
    {
        return [
            'from' => $this->from->toDateString(),
            'to' => $this->to->toDateString(),
        ];
    }
}
