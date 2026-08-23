<?php

declare(strict_types=1);

namespace App\Http\Controllers\Api\V1;

use App\Http\Controllers\Controller;
use App\Http\Requests\StoreCategoryRequest;
use App\Http\Resources\CategoryResource;
use App\Models\Category;
use App\Models\User;
use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;

final class CategoryController extends Controller
{
    /**
     * GET /api/v1/categories — default global + custom user (CT-1 + CT-2),
     * sudah difilter global scope VisibleToUserScope (IS-1).
     */
    public function index(): JsonResponse
    {
        $categories = Category::query()
            ->orderBy('type')
            ->orderBy('name')
            ->get();

        return response()->json([
            'data' => CategoryResource::collection($categories),
        ]);
    }

    /**
     * POST /api/v1/categories — kategori custom user; duplikat → 422 (CT-2).
     * CT-3 tetap terjaga: endpoint ini hanya membuat kategori custom, tidak bisa menyentuh default.
     */
    public function store(StoreCategoryRequest $request): JsonResponse
    {
        /** @var User $user */
        $user = Auth::user();

        /** @var Category $category */
        $category = DB::transaction(fn (): Category => $user->categories()->create([
            'name' => $request->string('name')->toString(),
            'type' => $request->string('type')->toString(),
            'is_default' => false,
        ]));

        return response()->json([
            'data' => new CategoryResource($category),
        ], 201);
    }
}
