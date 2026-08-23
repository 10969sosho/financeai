# CHANGELOG — FinanceAI

Format: [Keep a Changelog](https://keepachangelog.com) — versi semantik.

## [Unreleased]

### Added
- Suite dokumentasi awal: PROJECT_CONTEXT, ARCHITECTURE, BUSINESS_RULES, DATABASE, API_REFERENCE, CODING_STANDARDS, CHANGELOG.
- Keputusan teknis fondasi: Laravel 13 API-only, Sanctum auth, SQLite→MySQL, Laravel AI SDK agent+tools, Action layer untuk mutasi data.

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
