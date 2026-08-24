<?php

declare(strict_types=1);

namespace App\Services;

use App\Ai\Agents\FinancialAssistant;
use App\Models\User;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\Auth;

/**
 * Extracts transaction data from receipt images using AI vision.
 */
final readonly class ReceiptExtractionService
{
    public function extract(UploadedFile $image): array
    {
        /** @var User $user */
        $user = Auth::user();

        $prompt = <<<'PROMPT'
Analisis struk/nota ini dan ekstrak data transaksi.
Return JSON dengan format:
{
    "merchant": "nama toko/merchant",
    "items": [{"name": "nama item", "price": harga}],
    "total": total_bayar,
    "date": "YYYY-MM-DD",
    "category": "kategori yang paling cocok (Makanan/Minuman/Transportasi/Belanja/Hiburan/Tagihan/Lainnya)",
    "type": "expense"
}
Jika ada yang tidak jelas, gunakan nilai terbaik yang bisa didapat. Total harus berupa integer rupiah.
Return ONLY the JSON object, no markdown fences.
PROMPT;

        $agent = new FinancialAssistant($user);
        $response = $agent->prompt($prompt, [$image]);

        $content = $response->text();

        // Try to extract JSON from the response
        $jsonMatch = [];
        if (preg_match('/\{[\s\S]*\}/', $content, $jsonMatch)) {
            $extracted = json_decode($jsonMatch[0], true);
        }

        if (! isset($extracted) || ! is_array($extracted) || ! isset($extracted['total'])) {
            throw new \RuntimeException('Tidak dapat mengekstrak data dari struk.');
        }

        return [
            'merchant' => $extracted['merchant'] ?? null,
            'items' => $extracted['items'] ?? [],
            'total' => (int) ($extracted['total'] ?? 0),
            'date' => $extracted['date'] ?? now()->format('Y-m-d'),
            'category' => $extracted['category'] ?? 'Lainnya',
            'type' => $extracted['type'] ?? 'expense',
        ];
    }
}
