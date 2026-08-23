<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Scopes\UserScope;
use Database\Factories\MessageFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

/**
 * CS-4: pesan tersimpan permanen (audit + konteks). AI-8: metadata.actions = jejak audit.
 */
final class Message extends Model
{
    /** @use HasFactory<MessageFactory> */
    use HasFactory;

    protected $fillable = [
        'chat_session_id',
        'user_id',
        'role',
        'content',
        'metadata',
    ];

    protected static function booted(): void
    {
        self::addGlobalScope(new UserScope);
    }

    protected function casts(): array
    {
        return [
            'metadata' => 'array',
        ];
    }

    public function chatSession(): BelongsTo
    {
        return $this->belongsTo(ChatSession::class);
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    /**
     * Konteks chat: pesan lama → baru (index chat_session_id, created_at).
     */
    public function scopeChronological(Builder $query): Builder
    {
        return $query->orderBy('created_at')->orderBy('id');
    }
}
