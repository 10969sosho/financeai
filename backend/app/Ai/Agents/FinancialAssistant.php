<?php

declare(strict_types=1);

namespace App\Ai\Agents;

use App\Actions\Financial\CreateTransactionAction;
use App\Actions\Financial\DeleteTransactionAction;
use App\Actions\Financial\ResolveCategoryAction;
use App\Actions\Financial\UpdateTransactionAction;
use App\Ai\Support\SystemPrompt;
use App\Ai\Tools\CreateTransactionTool;
use App\Ai\Tools\DeleteTransactionTool;
use App\Ai\Tools\GetBalanceTool;
use App\Ai\Tools\GetReportTool;
use App\Ai\Tools\ListTransactionsTool;
use App\Ai\Tools\UpdateTransactionTool;
use App\Models\User;
use App\Services\ReportService;
use Laravel\Ai\Contracts\Agent;
use Laravel\Ai\Contracts\Conversational;
use Laravel\Ai\Contracts\HasTools;
use Laravel\Ai\Contracts\Tool;
use Laravel\Ai\Messages\Message;
use Laravel\Ai\Promptable;
use Stringable;

/**
 * Agent asisten keuangan (ARCHITECTURE §3/§4).
 * Instruksi sistem server-side only (AI-9); tools delegasi ke Action layer (AI-1);
 * konteks percakapan di-inject per request dari ChatService (CS-2).
 */
final class FinancialAssistant implements Agent, Conversational, HasTools
{
    use Promptable;

    /**
     * @param  array<int, Message>  $contextMessages  riwayat pesan session (CS-2)
     */
    public function __construct(
        private readonly User $user,
        private readonly array $contextMessages = [],
    ) {}

    public function instructions(): Stringable|string
    {
        return SystemPrompt::get();
    }

    /**
     * @return iterable<Message>
     */
    public function messages(): iterable
    {
        return $this->contextMessages;
    }

    /**
     * @return iterable<Tool>
     */
    public function tools(): iterable
    {
        // Semua tool terikat ke user yang sedang bersesuaian — AI tidak bisa
        // mengakses data user lain walau prompt-nya meminta (AI-6).
        return [
            new CreateTransactionTool(
                $this->user,
                app(ResolveCategoryAction::class),
                app(CreateTransactionAction::class),
            ),
            new UpdateTransactionTool(
                $this->user,
                app(ResolveCategoryAction::class),
                app(UpdateTransactionAction::class),
            ),
            new DeleteTransactionTool(
                $this->user,
                app(DeleteTransactionAction::class),
            ),
            new ListTransactionsTool($this->user),
            new GetBalanceTool($this->user, app(ReportService::class)),
            new GetReportTool($this->user, app(ReportService::class)),
        ];
    }
}
