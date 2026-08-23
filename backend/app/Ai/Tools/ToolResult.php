<?php

declare(strict_types=1);

namespace App\Ai\Tools;

/**
 * Bentuk hasil tool yang konsisten (JSON string) — sukses maupun gagal validasi.
 * Kegagalan validasi dikembalikan sebagai observasi ke agent (ARCHITECTURE §4 error path),
 * bukan exception yang membuat request gagal.
 */
final class ToolResult
{
    /**
     * @param  array<string, mixed>  $data
     */
    public static function ok(array $data): string
    {
        return json_encode(['ok' => true, ...$data], JSON_UNESCAPED_UNICODE);
    }

    public static function fail(string $error): string
    {
        return json_encode(['ok' => false, 'error' => $error], JSON_UNESCAPED_UNICODE);
    }
}
