<?php

declare(strict_types=1);

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('transactions', function (Blueprint $table): void {
            $table->id();
            $table->foreignId('user_id')->constrained()->cascadeOnDelete();
            $table->foreignId('category_id')->constrained()->restrictOnDelete();
            $table->enum('type', ['income', 'expense']);
            $table->unsignedBigInteger('amount');
            $table->string('description', 255);
            $table->timestamp('occurred_at')->index();
            $table->enum('source', ['ai', 'manual', 'voice', 'image'])->default('manual');
            $table->softDeletes();
            $table->timestamps();

            // Index laporan per DATABASE.md
            $table->index(['user_id', 'occurred_at']);
            $table->index(['user_id', 'type', 'occurred_at']);
            $table->index(['user_id', 'category_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('transactions');
    }
};
