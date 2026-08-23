<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Exceptions\AiProviderFailedException;
use App\Http\Controllers\Controller;
use App\Http\Requests\StoreChatRequest;
use App\Http\Resources\MessageResource;
use App\Http\Resources\TransactionResource;
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
     */
    public function store(StoreChatRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = Auth::user();

        try {
            ['message' => $message, 'transactions' => $transactions] = $this->chat->handle(
                $user,
                $request->filled('session_id') ? $request->integer('session_id') : null,
                $request->string('body')->toString(),
            );
        } catch (AiProviderFailedException) {
            // Pesan user tetap tersimpan; provider gagal → 503 pesan standar.
            return response()->json(['message' => 'Layanan AI sedang tidak tersedia. Coba lagi sebentar.'], 503);
        }

        return response()->json([
            'data' => [
                'message' => new MessageResource($message),
                'transactions' => TransactionResource::collection($transactions),
            ],
        ]);
    }
}
