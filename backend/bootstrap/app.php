<?php

declare(strict_types=1);

use Illuminate\Auth\Access\AuthorizationException;
use Illuminate\Auth\AuthenticationException;
use Illuminate\Database\Eloquent\ModelNotFoundException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Exception\NotFoundHttpException;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->statefulApi();
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );

        // Unauthenticated → 401 JSON (bukan redirect ke route 'login')
        $exceptions->render(function (AuthenticationException $e, Request $request): ?Response {
            if ($request->is('api/*')) {
                return response()->json(['message' => 'Unauthenticated.'], 401);
            }

            return null;
        });

        // IS-2 / API_REFERENCE: 404 selalu { "message": "Not found." } — tanpa detail model.
        $exceptions->render(function (ModelNotFoundException|NotFoundHttpException $e, Request $request): ?Response {
            if ($request->is('api/*')) {
                return response()->json(['message' => 'Not found.'], 404);
            }

            return null;
        });

        // Policy denyAsNotFound() → 404 dengan bentuk standar (IS-2).
        $exceptions->render(function (AuthorizationException $e, Request $request): ?Response {
            if ($request->is('api/*') && $e->status() === 404) {
                return response()->json(['message' => 'Not found.'], 404);
            }

            return null;
        });
    })->create();
