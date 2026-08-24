# ARCHITECTURE — FinanceAI

> Struktur sistem, pipeline AI, dan pola kode. Ikuti pola di sini untuk semua kode baru.

## 1. High-Level System

```text
Flutter App (mobile/)         cURL / Postman (testing fase backend)
      │  HTTPS + Bearer token (Sanctum)
      ▼
Laravel API (stateless, JSON only)
      │
      ├─ Auth (Sanctum)
      ├─ Chat Controller ──► ChatService ──► FinancialAgent (Laravel AI SDK)
      │                                            │  tool calls only
      │                                            ▼
      │                                    Financial Actions layer
      │                                    (validasi + otorisasi + DB transaction)
      ├─ Transaction/Category/Report Controllers ──► Services/Actions ──► DB
      ▼
Database: SQLite (dev/test) → MySQL (production)
Queue: database driver (MVP) → Redis (scale)
```

Prinsip: **AI menentukan intent; Action layer yang berkuasa atas data.** AI tidak pernah menyentuh Eloquent model secara langsung.

## 2. Keputusan Teknis & Alasan

| Keputusan | Pilihan | Alasan |
|---|---|---|
| Framework | Laravel 13, PHP 8.3+ | Terbaru, LTS-ish tooling, ekosistem besar |
| Jenis app | API-only (`--api`) | Flutter consumer; tanpa view/session cookie |
| Auth | Sanctum personal access token | Sederhana, cocok mobile, revocable |
| DB dev/prod | SQLite → MySQL | Mulai testing < 1 menit; MySQL saat produksi |
| AI | Laravel AI SDK (`laravel/ai`), agent `FinancialAssistant` + tools | Tool calling terstruktur, provider-agnostic, punya `::fake()` untuk test |
| Mutasi data | Action classes + DB transaction | Atomic, audit-able, testable |
| Queue MVP | `QUEUE_CONNECTION=database`, fitur chat sync dulu | Cepat; async streaming jadi upgrade path tanpa refactor besar |
| Timezone | `Asia/Jakarta` | Target user Indonesia |

## 3. Struktur Folder (feature-oriented, tetap idiomatik Laravel)

```text
app/
├── Ai/
│   ├── Agents/
│   │   └── FinancialAssistant.php      # Agent: instructions + tools
│   ├── Tools/                          # Tool = satu financial action intent
│   │   ├── CreateTransactionTool.php
│   │   ├── UpdateTransactionTool.php
│   │   ├── DeleteTransactionTool.php
│   │   ├── ListTransactionsTool.php
│   │   ├── GetBalanceTool.php
│   │   └── GetReportTool.php
│   └── Support/
│       └── SystemPrompt.php            # Instruksi sistem (server-side only)
├── Actions/
│   └── Financial/                      # Satu class = satu operasi data
│       ├── CreateTransactionAction.php
│       ├── UpdateTransactionAction.php
│       ├── DeleteTransactionAction.php
│       └── ResolveCategoryAction.php
├── Services/
│   ├── ChatService.php                 # Orkestrasi: handle() → pending + dispatch; process() → agent + audit
│   ├── ReportService.php               # Agregasi laporan
│   └── BalanceService.php
├── Jobs/
│   └── ProcessChatMessage.php          # Async queue job: prompt agent → update message → log activity
├── Http/
│   ├── Controllers/Api/V1/             # Thin controllers
│   ├── Requests/                       # Form requests (validasi)
│   └── Resources/                      # API resources (transform respons)
├── Models/
│   ├── User.php
│   ├── Category.php
│   ├── Transaction.php
│   ├── ChatSession.php
│   └── Message.php
├── Policies/                           # Otorisasi resource per-user
└── Data/                               # DTO ringan bila perlu (mis. MoneyAmount)
```

Aturan penempatan:

- Logika bisnis finansial → `Actions/Financial/*` (satu tanggung jawab, invokable).
- Orkestrasi multi-step → `Services/*`.
- Controller hanya: validasi (FormRequest) → panggil service/action → return API Resource.

## 4. Pipeline Pesan Chat (jalur paling penting)

```text
POST /api/v1/chat { session_id?, body }
  1. ChatService.handle :
     a. Simpan message role=user (CS-4)
     b. Buat pending assistant message (status=pending)
     c. Dispatch ProcessChatMessage ke queue → return segera
  2. ProcessChatMessage job (async via queue):
     a. Update status → processing
     b. Kumpulkan konteks: N pesan terakhir session + kandidat transaksi
     c. FinancialAssistant::prompt(context + body)
     d. Agent memutuskan: butuh tool call atau jawab biasa
  3. Tool call → Action layer:
     - ResolveCategoryAction : map nama → category_id (fallback "Lainnya")
     - CreateTransactionAction (mis.): validasi amount>0, type, occurred_at
       → DB::transaction → insert → return transaction
  4. Update assistant message:
     - content = respons AI
     - metadata.actions = jejak audit
     - status = completed (atau failed jika provider error)
  5. Log activity ke activity_logs table
```

Error path: tool/action gagal validasi → agent menerima hasil error sebagai observasi → AI menjelaskan/menanyakan ulang ke user (tidak crash). Kegagalan infrastruktur AI → status message = 'failed', pesan user tetap tersimpan. Client poll `GET /sessions/{id}/messages` untuk cek status.

## 5. Pola Kode Wajib

### Action class

```php
final class CreateTransactionAction
{
    public function execute(User $user, array $data): Transaction
    {
        // validasi ketat di sini — AI TIDAK dipercaya
        return DB::transaction(function () use ($user, $data): Transaction {
            $category = app(ResolveCategoryAction::class)->execute(
                $user, $data['type'], $data['category'],
            );

            return $user->transactions()->create([
                'type'        => $data['type'],
                'amount'      => $data['amount'],      // integer rupiah > 0
                'description' => $data['description'],
                'occurred_at' => $data['occurred_at'] ?? now(),
                'category_id' => $category->id,
                'source'      => 'ai',
            ]);
        });
    }
}
```

### Tool (AI SDK — laravel/ai v0.11)

> Catatan versi: SDK masih 0.x. Realita v0.11: Agent = class yang implement `Agent` + `Conversational` + `HasTools` dengan trait `Promptable` (`instructions()`, `messages()`, `tools()`). Tool = `description()` + `schema(JsonSchema)` + `handle(Laravel\Ai\Tools\Request): string|Stringable`. Nama tool = basename class. User TIDAK lewat argumen handle — user di-bind ke tool saat agent dibangun per-request (menegakkan AI-6).

```php
final class CreateTransactionTool implements Tool
{
    public function __construct(
        private readonly User $user, // di-inject ChatService per request
    ) {}

    public function description(): string
    {
        return 'Catat transaksi keuangan user. Gunakan setelah nominal & jenis jelas.';
    }

    public function schema(JsonSchema $schema): array
    {
        return [
            'type'        => $schema->string()->enum(['income', 'expense'])->required(),
            'amount'      => $schema->integer()->min(1)->required(),
            'description' => $schema->string()->required(),
            'category'    => $schema->string(),
            'occurred_at' => $schema->string(), // ISO8601 opsional
        ];
    }

    public function handle(Request $request): string
    {
        $result = app(CreateTransactionAction::class)
            ->execute($this->user, $request->all()); // validasi tetap di Action layer

        return json_encode(['ok' => true, 'transaction_id' => $result->id]);
    }
}
```

Kegagalan validasi tool dikembalikan sebagai observasi `{ok:false, error}` ke model (bukan exception) — hanya kegagalan infrastruktur provider (`AiException`) yang menjadi 503.

### Testing AI tanpa provider

```php
FinancialAssistant::fake(['Transaksi dicatat: Makanan Rp25.000']);
// ... panggil endpoint chat ...
FinancialAssistant::assertPrompted(fn ($prompt) => /* cek konteks CS-2 */ true);
```

Fake response dikonsumsi **per step**: fake berisi `ToolCall` membuat SDK mengeksekusi tool sungguhan lalu lanjut ke response fake berikutnya — sehingga pipeline chat→tool→Action→DB teruji penuh tanpa memanggil OpenAI.

## 6. Flutter App Structure

```text
mobile/
├── lib/
│   ├── config/
│   │   ├── api_config.dart          # Base URL, endpoints, timeout
│   │   └── theme.dart               # Material 3 theme (green finance)
│   ├── models/
│   │   ├── user.dart
│   │   ├── category.dart
│   │   ├── transaction.dart
│   │   ├── chat_session.dart
│   │   ├── message.dart
│   │   └── report.dart              # ReportSummary, CategoryBreakdown, ReportBreakdown
│   ├── services/
│   │   ├── api_client.dart          # Dio + auth interceptor + token storage
│   │   ├── auth_service.dart        # Login/register/logout + Riverpod providers
│   │   ├── chat_service.dart        # Sessions CRUD + messages + send
│   │   ├── transaction_service.dart # Transaction CRUD
│   │   ├── report_service.dart      # Summary + breakdown
│   │   └── category_service.dart    # Categories list + create
│   ├── screens/
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── chat/
│   │   │   ├── chat_list_screen.dart    # Session list + create/delete
│   │   │   └── chat_detail_screen.dart  # Messages + send + poll
│   │   ├── reports/
│   │   │   └── reports_screen.dart      # Summary + breakdown + period selector
│   │   ├── profile/
│   │   │   └── profile_screen.dart      # User info + settings + logout
│   │   └── home_screen.dart             # Bottom nav (Chat, Laporan, Profil)
│   └── main.dart                        # ProviderScope + FinanceAIApp
├── pubspec.yaml
└── test/
```

Prinsip Flutter:
- **Riverpod** untuk state management (auth state, data fetching).
- **Dio** untuk HTTP dengan auth interceptor (auto-attach token).
- **flutter_secure_storage** untuk token persistence.
- Navigation via `Navigator.push/pop` (state-driven routing).
- Material 3 dengan green finance seed color (`#2E7D32`).

## 7. Skalabilitas

Fase cepat → siap tumbuh:

1. **Stateless API** — bisa horizontal scale kapan saja (token auth, tanpa session server).
2. **Index tepat** — lihat DATABASE.md; query laporan memakai index `(user_id, occurred_at)`.
3. **Queue-ready** — ChatService.handle() dispatches ProcessChatMessage ke queue; job memanggil ChatService.process() secara async. Sync queue untuk testing, database/Redis untuk production.
4. **Provider failover** — AI SDK mendukung failover provider; konfigurasi di env.
5. **Agregasi laporan** — live query dulu; jika berat, tambah cache per-user-per-periode dengan invalidasi on-write.

## 8. Strategi Testing

| Level | Cakupan | Cara |
|---|---|---|
| Unit | parsing nominal, resolve kategori, mutasi rules | PHPUnit/Pest murni |
| Feature | endpoint auth, transactions CRUD, reports | HTTP test + database factory |
| AI pipeline | chat → action → response | `Agent::fake()` + assert prompt/tool; **tanpa** panggil provider nyata |
| Regression | BUSINESS_RULES.md | Setiap aturan punya minimal 1 test bernama sesuai ID aturan (mis. `test_ai_3_ambiguous_input_asks_back`) |

CI lokal: `php artisan test` harus hijau sebelum commit.
