<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\Category;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Category>
 */
final class CategoryFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => null,
            'name' => fake()->unique()->word(),
            'type' => 'expense',
            'is_default' => false,
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

    /**
     * Kategori custom milik user (CT-2).
     */
    public function forUser(User|UserFactory $user): static
    {
        return $this->state(fn (): array => [
            'user_id' => $user instanceof User ? $user->id : $user,
            'is_default' => false,
        ]);
    }

    /**
     * Kategori default global (CT-1).
     */
    public function globalDefault(): static
    {
        return $this->state(fn (): array => [
            'user_id' => null,
            'is_default' => true,
        ]);
    }
}
