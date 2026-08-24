# CHANGELOG — FinanceAI

Format: [Keep a Changelog](https://keepachangelog.com) — versi semantik.

## [Unreleased]

### Added
- Suite dokumentasi awal: PROJECT_CONTEXT, ARCHITECTURE, BUSINESS_RULES, DATABASE, API_REFERENCE, CODING_STANDARDS, CHANGELOG.
- Keputusan teknis fondasi: Laravel 13 API-only, Sanctum auth, SQLite→MySQL, Laravel AI SDK agent+tools, Action layer untuk mutasi data.

## [0.3.0] — 2026-08-24

### Added
- **Queue async chat**: `ProcessChatMessage` job — POST /chat return segera dengan status `pending`, AI diproses via queue. Client poll `GET /sessions/{id}/messages` untuk cek status.
- **Activity log**: Tabel `activity_logs` — audit trail terstruktur untuk setiap tool execution AI. Polymorphic subject (Transaction, dll). Log otomatis via ProcessChatMessage job.
- Kolom `status` pada tabel messages: `pending`, `processing`, `completed`, `failed`.
- Factory baru: `ActivityLogFactory`.
- 14 test untuk async chat + activity log.

### Changed
- `ChatService` di-refactor: `handle()` (save + dispatch) terpisah dari `process()` (untuk job execution).
- `ChatController::store()` return segera tanpa menunggu AI response.
- `MessageResource` menyertakan field `status`.
- Context window AI (`contextMessagesFor`) exclude pending assistant messages.
- `process()` mengambil context langsung dari session (termasuk pesan baru), bukan dari parameter handle().

### Removed
- `POST /chat` tidak lagi return 503 saat provider gagal — cukup set status `failed` pada message.

## [0.2.0] — 2026-08-23

### Added
- Endpoint inti `POST /api/v1/chat`: simpan pesan → agent AI → tool loop → respons + transaksi terdampak (kontrak API_REFERENCE dipenuhi).
- Agent `FinancialAssistant` (laravel/ai v0.11) + system prompt Indonesia server-side; 6 tools finansial (create/update/delete/list transaction, balance, report) yang semuanya delegasi ke Action layer — AI tidak pernah menulis DB langsung (AI-1).
- `ResolveCategoryAction`: resolusi nama kategori bebas → custom user → default global → fallback "Lainnya" (CT-4).
- `ChatService`: session auto-title, konteks 20 pesan terakhir (CS-2), audit trail `metadata.actions` (AI-8), 503 saat provider gagal dengan pesan user tetap tersimpan.
- Rate limit chat 30 req/menit/user → 429 (IS-3).
- 12 test baru bernama sesuai ID aturan (AI/CS/IS); total **46 test / 294 assertions hijau**.
- Smoke test live end-to-end terhadap OpenAI: "makan" → kategori Makanan → transaksi tersimpan (`source=ai`) + audit trail.

### Changed
- ARCHITECTURE.md §5 disesuaikan realita API laravel/ai v0.11 (signature Tool/Agent, pola fake per-step).

## [0.1.0] — 2026-08-23

### Added
- Backend Laravel 13 API di `backend/`: Sanctum auth (register/login/logout/me), CRUD transaksi + kategori + session chat + messages, laporan summary & breakdown.
- Data layer: migrasi + index sesuai DATABASE.md, global scope user (IS-1), policy 404 lintas-user (IS-2), seeder 12 kategori default idempotent (CT-1).
- Domain layer: Actions/Financial (create/update/delete transaction), ReportService, DTO Period.
- Test suite: 34 test / 198 assertions hijau, bernama sesuai ID aturan BUSINESS_RULES (TR/CT/RP/CS/IS).
- Smoke test HTTP live: register → token → transaksi → summary math benar; error shape sesuai kontrak.

### Changed
- BUSINESS_RULES CT-2 diperjelas: nama kategori custom juga tidak boleh bentrok dengan default global.
- DATABASE `transactions.source` default = `manual` (ditulis eksplisit oleh Action layer).

### Roadmap
- Fase 2: chat + AI financial actions (text) — butuh API key OpenAI.
- Fase 3: laporan lanjutan & hardening.
- Fase 5: Flutter client.
