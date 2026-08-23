# API_REFERENCE — FinanceAI v1

> Kontrak endpoint. Perubahan endpoint WAJIB update file ini di commit yang sama.

## Umum

- Base URL: `http://localhost:8000/api/v1`
- Content-Type: `application/json`
- Auth: `Authorization: Bearer <sanctum-token>` (kecuali register/login)
- Timezone server: Asia/Jakarta; timestamp dikirim ISO8601 (`2026-08-23T10:00:00+07:00`)
- Uang: integer rupiah (`25000`), tampilan `Rp25.000`

### Bentuk error standar

```json
// 422 Validasi
{ "message": "The amount field must be at least 1.", "errors": { "amount": ["The amount field must be at least 1."] } }

// 401 / 404
{ "message": "Unauthenticated." }
{ "message": "Not found." }
```

---

## Auth

### POST /auth/register

```json
// Request
{ "name": "Budi", "email": "budi@mail.com", "password": "rahasia123", "password_confirmation": "rahasia123" }

// 201
{ "user": { "id": 1, "name": "Budi", "email": "budi@mail.com" }, "token": "1|xxxx..." }
```

### POST /auth/login

```json
// Request
{ "email": "budi@mail.com", "password": "rahasia123" }

// 200
{ "user": { "id": 1, "name": "Budi", "email": "budi@mail.com" }, "token": "2|yyyy..." }
```

### POST /auth/logout 🔒 → `{ "message": "Logged out." }` (token revoked)

### GET /me 🔒 → `{ "user": { "id": 1, "name": "Budi", "email": "budi@mail.com" } }`

---

## Chat

### GET /sessions 🔒

Daftar session user, urut `last_message_at` desc.

```json
{ "data": [ { "id": 5, "title": "Pengeluaran hari ini", "last_message_at": "...", "created_at": "..." } ] }
```

### POST /sessions 🔒 → 201 `{ "data": { "id": 6, "title": null } }` (New Session)

### DELETE /sessions/{id} 🔒 → 200 `{ "message": "Session deleted." }` (CS-3: transaksi tetap aman)

### GET /sessions/{id}/messages 🔒

```json
{
  "data": [
    { "id": 101, "role": "user",      "content": "tadi makan 25 ribu", "metadata": null, "created_at": "..." },
    { "id": 102, "role": "assistant", "content": "Oke, dicatat ya: Makanan Rp25.000.",
      "metadata": { "actions": [ { "action": "create_transaction", "result": "ok",
        "transaction_id": 88, "payload": { "type": "expense", "amount": 25000, "category": "Makanan" } } ] },
      "created_at": "..." }
  ]
}
```

### POST /chat 🔒 — **endpoint inti MVP**

```json
// Request (session_id opsional; tanpa session_id = buat/pakai session aktif terakhir)
{ "session_id": 5, "body": "beli kopi 20 ribu" }
```

```json
// 200 — respons assistant + efek data
{
  "data": {
    "message": {
      "id": 104, "role": "assistant",
      "content": "Sudah dicatat: Minuman Rp20.000.",
      "metadata": { "actions": [ { "action": "create_transaction", "result": "ok", "transaction_id": 89,
        "payload": { "type": "expense", "amount": 20000, "category": "Minuman", "description": "beli kopi" } } ] }
    },
    "transactions": [
      { "id": 89, "type": "expense", "amount": 20000, "description": "beli kopi",
        "category": { "id": 9, "name": "Minuman" }, "occurred_at": "..." }
    ]
  }
}
```

Perilaku:

- Ambigu (AI-3) → 200 dengan pertanyaan klarifikasi, `transactions: []`, tanpa action.
- Koreksi (AI-4) → action `update_transaction` pada transaction_id yang dirujuk.
- Rate limit 30 req/menit/user (IS-3) → 429.

---

## Transactions

### GET /transactions 🔒

Query params: `type` (`income|expense`), `from`, `to` (YYYY-MM-DD), `category_id`, `per_page` (default 20).

```json
{
  "data": [
    { "id": 88, "type": "expense", "amount": 25000, "description": "makan siang",
      "category": { "id": 7, "name": "Makanan" },
      "occurred_at": "2026-08-23T12:30:00+07:00", "source": "ai" }
  ],
  "meta": { "current_page": 1, "last_page": 3, "total": 52 }
}
```

### POST /transactions 🔒 (manual entry, tanpa AI)

```json
// Request
{ "type": "expense", "amount": 15000, "description": "parkir", "category_id": 9, "occurred_at": "2026-08-23T09:00:00+07:00" }
// 201 → object transaction (bentuk sama seperti item di atas)
```

Validasi: `amount` integer ≥ 1 (TR-1); `type` enum; `category_id` milik user atau default global.

### PUT /transactions/{id} 🔒 → 200 (partial update field mana pun)

### DELETE /transactions/{id} 🔒 → 200 `{ "message": "Transaction deleted." }` (soft delete, TR-5)

---

## Categories

### GET /categories 🔒 → gabungan default global + custom user

```json
{ "data": [
  { "id": 7, "name": "Makanan", "type": "expense", "is_default": true },
  { "id": 30, "name": "Kopi", "type": "expense", "is_default": false }
] }
```

### POST /categories 🔒

```json
// Request
{ "name": "Kopi", "type": "expense" }
// 201 → object category (CT-2: unik per user+type; duplikat → 422)
```

---

## Reports

### GET /reports/summary 🔒

Query param `period`: `today | week | month | year` (default `month`) atau `from` + `to`.

```json
{
  "data": {
    "period": { "from": "2026-08-01", "to": "2026-08-31" },
    "income": 12500000,
    "expense": 4250000,
    "net": 8250000
  }
}
```

### GET /reports/breakdown 🔒 — parameter sama dengan summary

```json
{
  "data": {
    "period": { "from": "2026-08-01", "to": "2026-08-31" },
    "expense_by_category": [
      { "category": { "id": 7, "name": "Makanan" },       "total": 1200000, "count": 24 },
      { "category": { "id": 10, "name": "Transportasi" }, "total": 500000,  "count": 18 },
      { "category": { "id": 11, "name": "Belanja" },      "total": 800000,  "count": 6 },
      { "category": { "id": 14, "name": "Lainnya" },      "total": 1750000, "count": 9 }
    ],
    "income_by_category": []
  }
}
```

---

## Daftar Endpoint (ringkas)

| Method | Path | Auth | Fungsi |
|---|---|---|---|
| POST | /auth/register | – | daftar |
| POST | /auth/login | – | masuk |
| POST | /auth/logout | 🔒 | keluar |
| GET | /me | 🔒 | profil |
| GET | /sessions | 🔒 | daftar session chat |
| POST | /sessions | 🔒 | session baru |
| DELETE | /sessions/{id} | 🔒 | hapus session |
| GET | /sessions/{id}/messages | 🔒 | riwayat pesan |
| POST | /chat | 🔒 | kirim pesan → AI action |
| GET | /transactions | 🔒 | daftar/filter transaksi |
| POST | /transactions | 🔒 | input manual |
| PUT | /transactions/{id} | 🔒 | ubah transaksi |
| DELETE | /transactions/{id} | 🔒 | hapus (soft) |
| GET | /categories | 🔒 | daftar kategori |
| POST | /categories | 🔒 | kategori custom |
| GET | /reports/summary | 🔒 | ringkasan periode |
| GET | /reports/breakdown | 🔒 | breakdown kategori |

🔒 = Bearer token Sanctum.
