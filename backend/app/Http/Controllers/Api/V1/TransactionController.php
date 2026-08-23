<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Actions\Financial\CreateTransactionAction;
use App\Actions\Financial\DeleteTransactionAction;
use App\Actions\Financial\UpdateTransactionAction;
use App\Http\Controllers\Controller;
use App\Http\Requests\ListTransactionsRequest;
use App\Http\Requests\StoreTransactionRequest;
use App\Http\Requests\UpdateTransactionRequest;
use App\Http\Resources\TransactionResource;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Gate;

final class TransactionController extends Controller
{
    public function __construct(
        private readonly CreateTransactionAction $createAction,
        private readonly UpdateTransactionAction $updateAction,
        private readonly DeleteTransactionAction $deleteAction,
    ) {}

    /**
     * GET /api/v1/transactions — filter type/from/to/category_id + pagination meta.
     */
    public function index(ListTransactionsRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = Auth::user();

        $query = $user
            ->transactions()
            ->with('category') // eager load — hindari N+1
            ->when($request->filled('type'), fn ($q) => $q->ofType($request->string('type')->toString()))
            ->when($request->filled('from'), fn ($q) => $q->whereDate('occurred_at', '>=', $request->string('from')->toString()))
            ->when($request->filled('to'), fn ($q) => $q->whereDate('occurred_at', '<=', $request->string('to')->toString()))
            ->when($request->filled('category_id'), fn ($q) => $q->where('category_id', $request->integer('category_id')))
            ->orderByDesc('occurred_at')
            ->orderByDesc('id');

        $perPage = $request->integer('per_page', 20);
        $paginator = $query->paginate(min(max($perPage, 1), 100));

        return response()->json([
            'data' => TransactionResource::collection($paginator->items()),
            'meta' => [
                'current_page' => $paginator->currentPage(),
                'last_page' => $paginator->lastPage(),
                'total' => $paginator->total(),
            ],
        ]);
    }

    /**
     * POST /api/v1/transactions → 201.
     */
    public function store(StoreTransactionRequest $request): JsonResponse
    {
        $transaction = $this->createAction->execute(
            Auth::user(),
            $request->toPayload(),
        );

        return response()->json([
            'data' => new TransactionResource($transaction->load('category')),
        ], 201);
    }

    /**
     * PUT /api/v1/transactions/{transaction} — partial update; milik user lain → 404 (IS-2).
     */
    public function update(UpdateTransactionRequest $request, Transaction $transaction): JsonResponse
    {
        Gate::authorize('update', $transaction);

        $updated = $this->updateAction->execute($transaction, $request->toPayload());

        return response()->json([
            'data' => new TransactionResource($updated->load('category')),
        ]);
    }

    /**
     * DELETE /api/v1/transactions/{transaction} — soft delete (TR-5).
     */
    public function destroy(Transaction $transaction): JsonResponse
    {
        Gate::authorize('delete', $transaction);

        $this->deleteAction->execute($transaction);

        return response()->json(['message' => 'Transaction deleted.']);
    }
}
