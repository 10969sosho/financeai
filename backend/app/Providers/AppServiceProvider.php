<?php

declare(strict_types=1);

namespace App\Providers;

use Illuminate\Cache\RateLimiting\Limit;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\RateLimiter;
use Illuminate\Support\ServiceProvider;

class AppServiceProvider extends ServiceProvider
{
    /**
     * Register any application services.
     */
    public function register(): void
    {
        //
    }

    /**
     * Bootstrap any application services.
     */
    public function boot(): void
    {
        // IS-3: rate limit endpoint chat 30 req/menit/user untuk melindungi biaya AI.
        RateLimiter::for('chat', function (Request $request): array {
            return [
                Limit::perMinute(30)->by($request->user()?->id ?: $request->ip()),
            ];
        });
    }
}
