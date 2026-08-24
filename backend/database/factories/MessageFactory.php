<?php

declare(strict_types=1);

namespace Database\Factories;

use App\Models\ChatSession;
use App\Models\Message;
use App\Models\User;
use Illuminate\Database\Eloquent\Factories\Factory;

/**
 * @extends Factory<Message>
 */
final class MessageFactory extends Factory
{
    public function definition(): array
    {
        return [
            'chat_session_id' => ChatSession::factory(),
            'user_id' => User::factory(),
            'role' => 'user',
            'content' => fake()->sentence(),
            'metadata' => null,
            'status' => 'completed',
        ];
    }

    public function pending(): static
    {
        return $this->state(fn (): array => [
            'status' => 'pending',
            'content' => '',
        ]);
    }

    public function processing(): static
    {
        return $this->state(fn (): array => [
            'status' => 'processing',
        ]);
    }

    public function completed(): static
    {
        return $this->state(fn (): array => [
            'status' => 'completed',
        ]);
    }

    public function failed(): static
    {
        return $this->state(fn (): array => [
            'status' => 'failed',
        ]);
    }

    public function fromAssistant(): static
    {
        return $this->state(fn (): array => [
            'role' => 'assistant',
        ]);
    }

    public function withMetadata(array $metadata): static
    {
        return $this->state(fn (): array => [
            'metadata' => $metadata,
        ]);
    }
}
