<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\MessageResource;
use App\Models\ChatSession;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Gate;

final class MessageController extends Controller
{
    /**
     * GET /api/v1/sessions/{chat_session}/messages — riwayat pesan lama → baru.
     */
    public function index(ChatSession $chatSession): JsonResponse
    {
        Gate::authorize('view', $chatSession);

        $messages = $chatSession->messages()
            ->chronological()
            ->get();

        return response()->json([
            'data' => MessageResource::collection($messages),
        ]);
    }
}
