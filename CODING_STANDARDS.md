# CODING_STANDARDS — FinanceAI

> Standar untuk SEMUA kode baru di proyek ini.

## Bahasa & Runtime

- PHP 8.3+, Laravel 13. Gunakan fitur modern: constructor property promotion, readonly, enum, match.
- `declare(strict_types=1);` di semua file app baru.
- Nama variabel/method Inggris; komentar & pesan user-facing Indonesia bila perlu.

## Struktur & Pola

| Kebutuhan | Tempat |
|---|---|
| Operasi data finansial (satu operasi) | `app/Actions/Financial/*` — invokable/final |
| Orkestrasi multi-langkah | `app/Services/*` |
| Validasi HTTP | Form Request (`app/Http/Requests`) — jangan validasi di controller |
| Transform respons | API Resource (`app/Http/Resources`) |
| Intent AI | `app/Ai/Tools/*` — tipis, delegasi ke Action |
| Instruksi AI | `app/Ai/Support/SystemPrompt.php` — server-side only |

Aturan tegas:

1. Controller **thin**: inject FormRequest → panggil Service/Action → return Resource. Tanpa query builder di controller.
2. Tidak ada logika finansial di Tool AI. Tool hanya menerjemahkan argumen model → panggilan Action.
3. Semua mutasi multi-record memakai `DB::transaction`.
4. Eloquent: `$fillable` eksplisit, cast lengkap, relasi didefinisikan, eager loading (`with`) untuk hindari N+1.
5. Query berulang → scope pada model (`scopeInPeriod`, `scopeOfType`).
6. Otorisasi resource via Policy + global scope user (IS-1). Jangan percaya ID dari request.

## Database

- Migrasi eksplisit & reversible (`down()` benar).
- Index sesuai DATABASE.md; tambah index saat menambah pola query laporan.
- Factory untuk setiap model; seeder idempotent (`firstOrCreate`).

## Testing (WAJIB)

- Setiap aturan BUSINESS_RULES.md punya test dengan nama mengandung ID aturan: `test_tr_1_amount_must_be_positive_integer`.
- Test AI selalu pakai fake (`FinancialAssistant::fake()`); dilarang panggil provider nyata di test.
- Feature test untuk setiap endpoint (sukses + validasi gagal + akses lintas user → 404).
- `php artisan test` harus hijau sebelum commit. Gagal → perbaiki → ulangi sampai hijau.

## Git

- Branch: `feature/<nama>`, `fix/<nama>`, `refactor/<nama>`. Jangan commit langsung ke main kecuali typo/docs kecil.
- Commit message imperatif ringkas: `feat(chat): process text transaction via AI agent`.
- Satu commit = satu maksud logis; docs ikut commit terkait.
- Push setelah commit (jangan numpuk lokal).

## API

- Respons selalu lewat Resource; bentuk sesuai API_REFERENCE.md.
- Error 422 format Laravel standar; jangan ubah bentuk tanpa update docs.
- Endpoint baru → update API_REFERENCE.md di commit yang sama.

## Yang Dilarang

- ❌ Logika bisnis di controller/tool AI.
- ❌ Raw query tanpa parameter binding.
- ❌ Menyimpan nominal uang sebagai float/string.
- ❌ Mempercayai payload AI tanpa validasi Action layer.
- ❌ Commit dengan test merah atau docs tidak sinkron.
