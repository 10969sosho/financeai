# DATABASE — FinanceAI

> Skema resmi. Setiap perubahan skema WAJIB update file ini.

## Ringkasan Entitas

```text
users 1───* transactions *───1 categories
users 1───* chat_sessions 1───* messages
categories: user_id NULL = default global (seed)
```

## Tabel

### users

| Kolom | Tipe | Ket |
|---|---|---|
| id | bigint PK | |
| name | string(255) | |
| email | string(255) unique | login identifier |
| email_verified_at | timestamp nullable | fase berikutnya |
| password | string(255) | hash |
| created_at / updated_at | timestamps | |

### categories

| Kolom | Tipe | Ket |
|---|---|---|
| id | bigint PK | |
| user_id | foreignId nullable → users | NULL = default global |
| name | string(100) | unik per (user scope, type), case-insensitive |
| type | enum('income','expense') | |
| is_default | boolean default false | true untuk seed global |
| deleted_at | softDelete nullable | CT-5 |
| created_at / updated_at | timestamps | |

Index: `unique(user_id, name, type)` — perhatikan NULL user_id (global); di MySQL unique dengan NULL membolehkan duplikat global → enforce via Seeder idempotent + validasi FormRequest.

Seed default (CT-1):

- expense: Makanan, Minuman, Transportasi, Belanja, Hiburan, Tagihan, Lainnya
- income: Gaji, Project, Bonus, Transfer, Lainnya

### transactions

| Kolom | Tipe | Ket |
|---|---|---|
| id | bigint PK | |
| user_id | foreignId → users, cascadeOnDelete | IS-1 |
| category_id | foreignId → categories, restrictOnDelete | CT-5 |
| type | enum('income','expense') | TR-2 |
| amount | unsignedBigInteger | TR-1: rupiah bulat > 0 |
| description | string(255) | dari ucapan user |
| occurred_at | timestamp | TR-3/TR-4, default now, index utama laporan |
| source | enum('ai','manual','voice','image') default 'manual' | jejak asal input; ditulis eksplisit oleh Action layer |
| deleted_at | softDelete nullable | TR-5 |
| created_at / updated_at | timestamps | |

Index:

- `(user_id, occurred_at)` — laporan & mutasi per periode
- `(user_id, type, occurred_at)` — total income/expense
- `(user_id, category_id)` — breakdown kategori
- `(chat_session_id, created_at)` di tabel messages — konteks chat

Relasi tambahan (audit): `transaction.message_id` nullable → messages (pesan pencipta). Opsional fase 2 jika dibutuhkan trace penuh; MVP cukup `metadata.actions`.

### chat_sessions

| Kolom | Tipe | Ket |
|---|---|---|
| id | bigint PK | |
| user_id | foreignId → users, cascadeOnDelete | |
| title | string(255) nullable | auto dari pesan pertama |
| last_message_at | timestamp nullable | sorting daftar session |
| created_at / updated_at | timestamps | |

Index: `(user_id, last_message_at)`.

### messages

| Kolom | Tipe | Ket |
|---|---|---|
| id | bigint PK | |
| chat_session_id | foreignId → chat_sessions, cascadeOnDelete | CS-3: hapus session ikut hapus pesan |
| user_id | foreignId → users, cascadeOnDelete | isolasi |
| role | enum('user','assistant','system') | |
| content | text | isi pesan |
| metadata | json nullable | AI-8: `{actions:[{action,payload,result,transaction_id}]}` |
| created_at / updated_at | timestamps | |

## Konvensi

1. Semua migrasi bernama eksplisit: `create_transactions_table`, dst. Satu migrasi = satu perubahan logis.
2. Model memakai `$guarded = []` **hanya** jika fillable dikontrol ketat oleh Action/FormRequest; preferensi: `$fillable` eksplisit (sec-mass-assignment).
3. Cast wajib: `occurred_at` → datetime, `amount` → int, `metadata` → array, `is_default` → bool.
4. Global scope `BelongsToUser` diterapkan pada Transaction, ChatSession, Message, Category(custom) untuk menegakkan IS-1 — bukan di-andalkan pada controller saja.
5. Factory untuk semua model (testing cepat).
6. SQLite dev/test ↔ MySQL prod: hindari fitur DB-specific di MVP (tanpa raw SQL eksotis).

## Estimasi Pertumbuhan & Retensi

- Transaksi/user ≈ 20–50/bulan → jutaan baris masih ringan dengan index di atas.
- Messages tumbuh lebih cepat; pertimbangkan pruning pesan system > 12 bulan (eloquent-pruning) di fase hardening.
