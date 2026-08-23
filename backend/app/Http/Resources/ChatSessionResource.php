<?php

declare(strict_types=1);

namespace App\Http\Resources;

use App\Models\ChatSession;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * @mixin ChatSession
 */
final class ChatSessionResource extends JsonResource
{
    /**
     * @return array{id: int, title: ?string, last_message_at: ?string, created_at: string}
     */
    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'title' => $this->title,
            'last_message_at' => $this->last_message_at?->toIso8601String(),
            'created_at' => $this->created_at?->toIso8601String(),
        ];
    }
}
