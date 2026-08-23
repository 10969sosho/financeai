<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\ChatSession;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<ChatSession>
 */
final class ChatSessionFactory extends Factory
{
    public function definition(): array
    {
        return [
            'user_id' => User::factory(),
            'title' => null,
            'last_message_at' => null,
        ];
    }

    public function titled(string $title): static
    {
        return $this->state(fn (): array => [
            'title' => $title,
        ]);
    }

    public function lastActiveAt(\DateTimeInterface $when): static
    {
        return $this->state(fn (): array => [
            'last_message_at' => $when,
        ]);
    }
}
