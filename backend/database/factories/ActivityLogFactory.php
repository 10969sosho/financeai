<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\ActivityLog;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ActivityLog>
 */
final class ActivityLogFactory extends Factory
{
    protected $model = ActivityLog::class;

    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'action' => 'create_transaction',
            'subject_type' => null,
            'subject_id' => null,
            'payload' => ['type' => 'expense', 'amount' => 25000],
            'result' => 'ok',
            'error_message' => null,
        ];
    }

    public function failed(): static
    {
        return $this->state(fn (): array => [
            'result' => 'error',
            'error_message' => fake()->sentence(),
        ]);
    }
}
