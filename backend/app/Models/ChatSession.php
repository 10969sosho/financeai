<?php

declare(strict_types=1);

namespace App\Models;

use App\Models\Scopes\UserScope;
use Database\Factories\ChatSessionFactory;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

/**
 * CS-1: session baru = konteks reset. CS-3: hapus session tidak menyentuh transaksi.
 */
final class ChatSession extends Model
{
    /** @use HasFactory<ChatSessionFactory> */
    use HasFactory;

    protected $fillable = [
        'user_id',
        'title',
        'last_message_at',
    ];

    protected static function booted(): void
    {
        self::addGlobalScope(new UserScope);
    }

    protected function casts(): array
    {
        return [
            'last_message_at' => 'datetime',
        ];
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }

    public function messages(): HasMany
    {
        return $this->hasMany(Message::class);
    }

    /**
     * Daftar session diurut last_message_at desc (session kosong paling bawah).
     */
    public function scopeLatestActivity(Builder $query): Builder
    {
        return $query->orderByDesc('last_message_at')->orderByDesc('id');
    }
}
