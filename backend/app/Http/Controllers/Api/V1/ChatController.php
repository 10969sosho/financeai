<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreChatRequest;
use App\Http\Resources\MessageResource;
use App\Models\User;
use App\Services\ChatService;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;

final class ChatController extends Controller
{
    public function __construct(
        private readonly ChatService $chat,
    ) {}

    /**
     * POST /api/v1/chat — endpoint inti MVP (API_REFERENCE).
     * Rate limit 30 req/menit/user (IS-3) via throttle:chat.
     *
     * Returns segera dengan status pending; AI diproses via queue.
     */
    public function store(StoreChatRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = Auth::user();

        ['message' => $message] = $this->chat->handle(
            $user,
            $request->filled('session_id') ? $request->integer('session_id') : null,
            $request->string('body')->toString(),
        );

        // Refresh message setelah sync processing
        $message->refresh();

        return response()->json([
            'data' => [
                'message' => new MessageResource($message),
                'transactions' => [],
            ],
        ]);
    }
}
