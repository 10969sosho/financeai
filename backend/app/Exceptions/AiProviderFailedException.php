<?php

declare(strict_types=1);

namespace App\Exceptions;

use Exception;

/**
 * Kegagalan infrastruktur AI provider (ARCHITECTURE §4 error path):
 * pesan user tetap tersimpan; endpoint merespons 503 dengan pesan standar.
 */
final class AiProviderFailedException extends Exception {}
