<?php

declare(strict_types=1);

namespace Database\Seeders;

use App\Models\Category;
use Illuminate\Database\Seeder;

/**
 * CT-1: kategori default global (user_id NULL). Idempotent via firstOrCreate.
 */
final class CategorySeeder extends Seeder
{
    private const DEFAULT_EXPENSE = ['Makanan', 'Minuman', 'Transportasi', 'Belanja', 'Hiburan', 'Tagihan', 'Lainnya'];

    private const DEFAULT_INCOME = ['Gaji', 'Project', 'Bonus', 'Transfer', 'Lainnya'];

    public function run(): void
    {
        foreach ([self::DEFAULT_EXPENSE, self::DEFAULT_INCOME] as $i => $names) {
            $type = $i === 0 ? 'expense' : 'income';

            foreach ($names as $name) {
                $category = Category::withTrashed()->firstOrCreate([
                    'user_id' => null,
                    'name' => $name,
                    'type' => $type,
                ], [
                    'is_default' => true,
                ]);

                if ($category->trashed()) {
                    $category->restore();
                }
            }
        }
    }
}
