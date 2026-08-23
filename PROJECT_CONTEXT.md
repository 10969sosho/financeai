# PROJECT_CONTEXT — FinanceAI (Financial Chat App)

> Sumber kebenaran utama untuk memahami proyek ini secara umum.
> Brief asli: `brief.md`

## 1. Ringkasan

Aplikasi pencatatan keuangan personal yang menggunakan **chat sebagai interface utama**. User tidak mengisi form transaksi manual — user bicara natural ("tadi makan 25 ribu"), AI memahami maksud, dan backend mencatat transaksi.

**MVP harus membuktikan satu hal:**

> User bisa mencatat dan mengelola keuangan hanya melalui chat.

## 2. Tujuan Produk

| Prinsip | Arti |
|---|---|
| Simple | User tidak perlu belajar aplikasi finance |
| Conversational | Pencatatan seperti percakapan biasa |
| Reliable | AI tidak boleh sembarangan mengubah data |
| Fast | Transaksi sederhana tercatat dalam hitungan detik |
| Personal | Data & laporan setiap user terisolasi |

## 3. Scope MVP

Prioritas implementasi (urutan):

1. **Authentication** — register/login mobile (Sanctum token)
2. **Chat** — session + messages, kirim text
3. **Text transaction** — "beli kopi 20 ribu" → transaksi
4. **Transaction database** — schema + CRUD
5. **AI action** — create/update/delete/read transaction, get balance, get report
6. **Laporan sederhana** — pemasukan, pengeluaran, mutasi, breakdown kategori

### Di luar MVP (fase berikutnya)

- Voice input (speech-to-text → pipeline text yang sama)
- Image input (struk/nota → ekstraksi transaksi)
- Subscription / monetisasi
- Multi-wallet, budgeting, reminder tagihan

## 4. Core Navigation (3 menu)

1. **Chat** — interface utama; input text (MVP), voice & foto (fase 2)
2. **Laporan** — ringkasan + breakdown kategori + detail transaksi
3. **Profile** — pengaturan dasar user & aplikasi

## 5. Tech Stack

| Layer | Pilihan | Alasan |
|---|---|---|
| Backend | **Laravel 13 (PHP 8.3+)**, API-only | Ekosistem matang, cepat dikembangkan, scalable |
| Auth | Laravel Sanctum (token) | Standar untuk mobile client (Flutter) |
| Database | SQLite (dev/testing) → MySQL (production) | Cepat mulai, scalable saat produksi |
| AI | **Laravel AI SDK (`laravel/ai`)** — Agent + Tools | Intent → tool call terstruktur; backend tetap validasi |
| Queue | Database driver (MVP) → Redis (scale) | AI processing siap async tanpa refactor |
| Client (nanti) | Flutter | Sesuai keputusan owner |

## 6. Prinsip Arsitektur Kunci

1. **AI bukan database.** AI hanya menentukan intent/action. Semua mutasi data lewat Action layer yang melakukan validasi + otorisasi.
2. **API-first.** Backend murni JSON API; Flutter adalah consumer. Tidak ada Blade/view.
3. **User-scoped by default.** Semua query data finansial wajib ter-scope `user_id`.
4. **Testable.** AI di-fake di test (`Agent::fake()`); logic finansial di-test tanpa panggil provider sungguhan.

## 7. Fase Pengembangan

| Fase | Isi | Status |
|---|---|---|
| 0 | Dokumentasi suite | ✅ selesai |
| 1 | Scaffold Laravel API + Auth + DB + seed kategori | berikutnya |
| 2 | Chat + AI agent + financial actions (text) | - |
| 3 | Laporan + breakdown | - |
| 4 | Hardening: rate limit, queue async, logging aksi AI | - |
| 5 | Flutter app (Chat, Laporan, Profile) | - |
| 6 | Voice & image input | - |

## 8. Dokumentasi Terkait

- `ARCHITECTURE.md` — struktur sistem, pipeline AI, pola service/action
- `BUSINESS_RULES.md` — aturan finansial & aturan perilaku AI (**wajib baca**)
- `DATABASE.md` — skema tabel, index, seed
- `API_REFERENCE.md` — kontrak endpoint v1
- `CODING_STANDARDS.md` — standar penulisan kode
- `CHANGELOG.md` — riwayat perubahan signifikan
