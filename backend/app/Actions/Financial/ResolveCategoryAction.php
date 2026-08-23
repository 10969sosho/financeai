<?php

declare(strict_types=1);

namespace App\Actions\Financial;

use App\Models\Category;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * CT-4: resolve nama kategori free-text → Category milik user atau default global.
 * Custom user diprioritaskan di atas default; case-insensitive; per type.
 * Fallback = "Lainnya" sesuai type. DILARANG membuat kategori baru.
 */
final readonly class ResolveCategoryAction
{
    public function execute(User $user, string $type, ?string $name): Category
    {
        $type = in_array($type, ['income', 'expense'], true) ? $type : 'expense';
        $name = trim((string) $name);

        /** @var ?Category $category */
        $category = DB::transaction(function () use ($user, $type, $name): ?Category {
            if ($name !== '') {
                // 1) Kategori custom user (prioritas), case-insensitive.
                $custom = $user->categories()
                    ->where('type', $type)
                    ->whereNull('deleted_at')
                    ->whereRaw('LOWER(name) = LOWER(?)', [$name])
                    ->first();

                if ($custom !== null) {
                    return $custom;
                }

                // 2) Default global, case-insensitive.
                $global = Category::query()
                    ->whereNull('user_id')
                    ->where('type', $type)
                    ->whereRaw('LOWER(name) = LOWER(?)', [$name])
                    ->first();

                if ($global !== null) {
                    return $global;
                }
            }

            // 3) Fallback CT-4: "Lainnya" sesuai type.
            return Category::query()
                ->whereNull('user_id')
                ->where('type', $type)
                ->where('name', 'Lainnya')
                ->first();
        });

        if ($category === null) {
            // Seed belum jalan / data rusak — jangan buat kategori baru (CT-4).
            throw new \RuntimeException("Kategori fallback 'Lainnya' untuk type [{$type}] tidak ditemukan. Jalankan db:seed.");
        }

        return $category;
    }
}
