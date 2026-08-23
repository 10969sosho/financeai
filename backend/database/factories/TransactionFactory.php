<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Category;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Transaction>
 */
final class TransactionFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'category_id' => Category::factory(),
            'type' => 'expense',
            'amount' => fake()->numberBetween(1000, 100000),
            'description' => fake()->sentence(3),
            'occurred_at' => now(),
            'source' => 'manual',
        ];
    }

    public function income(): static
    {
        return $this->state(fn (): array => [
            'type' => 'income',
        ]);
    }

    public function expense(): static
    {
        return $this->state(fn (): array => [
            'type' => 'expense',
        ]);
    }

    public function amount(int $amount): static
    {
        return $this->state(fn (): array => [
            'amount' => $amount,
        ]);
    }

    public function occurredAt(\DateTimeInterface|string $when): static
    {
        return $this->state(fn (): array => [
            'occurred_at' => $when,
        ]);
    }

    public function fromAi(): static
    {
        return $this->state(fn (): array => [
            'source' => 'ai',
        ]);
    }
}
