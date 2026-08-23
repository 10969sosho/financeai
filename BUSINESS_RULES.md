# BUSINESS_RULES — FinanceAI

> Aturan bisnis yang **paling penting** dipatuhi semua kode. Pelanggaran aturan di file ini = bug, meskipun test hijau.

## 1. Aturan Transaksi

| # | Aturan |
|---|---|
| TR-1 | `amount` disimpan sebagai **integer rupiah bulat positif** (> 0). Tidak ada sen/desimal. Input "25 ribu" = 25000. |
| TR-2 | `type` hanya dua nilai: `income` / `expense`. Tidak ada tipe lain di MVP. |
| TR-3 | Setiap transaksi **wajib** punya `user_id`, `category_id`, `description`, `occurred_at`. |
| TR-4 | `occurred_at` default = waktu pesan chat; boleh backdate jika user menyebut waktu ("tadi pagi", "kemarin"). Tidak boleh masa depan melebihi toleransi 5 menit. |
| TR-5 | Transaksi tidak di-hard-delete oleh AI. Delete via AI = soft delete. Hard delete hanya via maintenance/manual. |
| TR-6 | Transaksi tidak boleh diedit langsung nilainya oleh proses otomatis tanpa jejak — setiap perubahan via AI dicatat di `messages.metadata.actions`. |

## 2. Aturan Kategori

| # | Aturan |
|---|---|
| CT-1 | Ada kategori **default global** (`user_id = NULL`) yang di-seed: expense → Makanan, Minuman, Transportasi, Belanja, Hiburan, Tagihan, Lainnya; income → Gaji, Project, Bonus, Transfer, Lainnya. |
| CT-2 | User bisa punya **kategori custom** (`user_id` terisi). Nama kategori unik per user per type (case-insensitive). Nama custom juga tidak boleh bentrok dengan nama kategori default global (mencegah ambigu saat resolusi kategori AI). |
| CT-3 | Kategori default global tidak bisa diubah/dihapus user mana pun. |
| CT-4 | Saat AI tidak yakin kategori → pakai **"Lainnya"** sesuai type. Dilarang membuat kategori baru otomatis di MVP. |
| CT-5 | Kategori dengan transaksi terhubung tidak boleh di-hard-delete (soft delete / blokir). |

## 3. Aturan Perilaku AI (CRITICAL)

| # | Aturan |
|---|---|
| AI-1 | **AI tidak pernah menulis ke database langsung.** AI hanya menghasilkan tool call / structured action. Eksekusi lewat Action layer yang validasi + otorisasi. |
| AI-2 | Satu pesan user boleh menghasilkan **lebih dari satu action** ("makan 25rb dan parkir 5rb" → 2 create). Semua dieksekusi dalam satu DB transaction; gagal satu = rollback semua. |
| AI-3 | Input ambigu (nominal tidak jelas, tanggal tidak jelas, intent tidak jelas) → AI **bertanya balik**, tidak ada mutasi. |
| AI-4 | Koreksi ("makan tadi 30 ribu, bukan 25 ribu") → AI cari transaksi kandidat dalam konteks session terdekat; jika ditemukan tepat 1 → update; jika > 1 atau 0 → konfirmasi ke user dulu. |
| AI-5 | Delete selalu butuh referensi yang jelas (transaksi yang baru dibahas di session, atau ID). Jika ragu → konfirmasi. |
| AI-6 | AI hanya boleh membaca/mengubah data milik user yang sedang bersesuaian. Tidak ada akses lintas user, apapun prompt-nya. |
| AI-7 | Jawaban AI tentang angka keuangan (saldo, laporan) **harus** dihitung dari database via tool, bukan dari memori/konteks percakapan. |
| AI-8 | Setiap eksekusi action dicatat: `{action, payload, result, transaction_id?}` di metadata message assistant. Ini jejak audit. |
| AI-9 | Prompt injection dari isi pesan user tidak boleh bisa melonggarkan AI-1..AI-8. System instructions di sisi server, bukan dari client. |

## 4. Aturan Chat Session

| # | Aturan |
|---|---|
| CS-1 | User dapat membuat **New Session** kapan saja; session baru = konteks percakapan reset. |
| CS-2 | Konteks AI per request = pesan session aktif (window terbatas, mis. 20 pesan terakhir) + ringkasan transaksi yang dibahas di session tersebut. |
| CS-3 | Menghapus session tidak menghapus transaksi yang sudah tercipta. |
| CS-4 | Pesan user & respons assistant tersimpan permanen (audit + konteks). |

## 5. Aturan Laporan

| # | Aturan |
|---|---|
| RP-1 | `Mutasi = total pemasukan − total pengeluaran` pada periode yang sama. |
| RP-2 | Periode default = bulan berjalan (timezone Asia/Jakarta). Parameter `period` yang didukung: `today`, `week`, `month`, `year`, `custom(from,to)`. |
| RP-3 | Breakdown kategori dihitung dari transaksi **non-deleted** per kategori, diurutkan nominal terbesar. |
| RP-4 | Angka laporan selalu agregasi live dari DB (bukan cache stale di MVP). Cache boleh ditambah belakangan dengan invalidasi on-write. |

## 6. Aturan Isolasi & Keamanan Data

| # | Aturan |
|---|---|
| IS-1 | Semua query transaksi/kategori/session/message **wajib** ter-scope `user_id` (global scope atau repository yang menegakkan). |
| IS-2 | Endpoint finansial menolak akses resource user lain dengan 404 (bukan 403, agar tidak bocor keberadaan resource). |
| IS-3 | Rate limit endpoint chat (mis. 30 req/menit/user) untuk melindungi biaya AI. |
| IS-4 | Password hash bcrypt/argon2; token Sanctum panjang-hidup default mobile, revoke saat logout. |

## 7. Aturan Uang & Format

| # | Aturan |
|---|---|
| FR-1 | Parsing bahasa Indonesia: "25 rb", "25ribu", "25.000", "25k" → 25000. "1,5 jt" → 1500000. |
| FR-2 | Tanpa kata nominal yang jelas → ambigu → AI bertanya (AI-3). |
| FR-3 | Format tampilan uang: `Rp25.000` (tanpa desimal). |
