<?php

declare(strict_types=1);

namespace App\Policies;

use App\Models\ChatSession;
use App\Models\User;
use Illuminate\Auth\Access\Response;

/**
 * IS-2: session milik user lain → 404.
 */
final class ChatSessionPolicy
{
    public function view(User $user, ChatSession $chatSession): Response
    {
        return $chatSession->user_id === $user->id
            ? Response::allow()
            : Response::denyAsNotFound();
    }

    public function delete(User $user, ChatSession $chatSession): Response
    {
        return $chatSession->user_id === $user->id
            ? Response::allow()
            : Response::denyAsNotFound();
    }
}
