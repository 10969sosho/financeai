<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Resources\ChatSessionResource;
use App\Models\ChatSession;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Gate;

final class ChatSessionController extends Controller
{
    /**
     * GET /api/v1/sessions — urut last_message_at desc.
     */
    public function index(): JsonResponse
    {
        /** @var User $user */
        $user = Auth::user();

        $sessions = $user->chatSessions()
            ->latestActivity()
            ->get();

        return response()->json([
            'data' => ChatSessionResource::collection($sessions),
        ]);
    }

    /**
     * POST /api/v1/sessions → 201 { data: { id, title: null } } (CS-1: New Session).
     */
    public function store(): JsonResponse
    {
        /** @var User $user */
        $user = Auth::user();

        /** @var ChatSession $session */
        $session = DB::transaction(fn (): ChatSession => $user->chatSessions()->create([
            'title' => null,
            'last_message_at' => null,
        ]));

        return response()->json([
            'data' => new ChatSessionResource($session),
        ], 201);
    }

    /**
     * DELETE /api/v1/sessions/{chat_session} — CS-3: transaksi tetap aman.
     */
    public function destroy(ChatSession $chatSession): JsonResponse
    {
        Gate::authorize('delete', $chatSession);

        DB::transaction(fn (): bool => (bool) $chatSession->delete());

        return response()->json(['message' => 'Session deleted.']);
    }
}
