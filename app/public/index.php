<?php

declare(strict_types=1);

require_once __DIR__ . '/../src/Database.php';
require_once __DIR__ . '/../src/Env.php';
require_once __DIR__ . '/../src/ItemRepository.php';

Env::load(__DIR__ . '/../../.env');

header('Content-Type: application/json');

function respond(int $status, array $body): void
{
    http_response_code($status);
    echo json_encode($body, JSON_UNESCAPED_SLASHES);
    exit;
}

function requestPath(): string
{
    $uri = $_SERVER['REQUEST_URI'] ?? '/';
    $path = parse_url($uri, PHP_URL_PATH);

    return is_string($path) ? $path : '/';
}

try {
    $method = $_SERVER['REQUEST_METHOD'] ?? 'GET';
    $path = requestPath();

    if ($path === '/health' && $method === 'GET') {
        respond(200, ['status' => 'ok']);
    }

    if ($path !== '/api/items') {
        respond(404, ['error' => 'Not found']);
    }

    $repository = new ItemRepository(Database::connect());

    if ($method === 'GET') {
        respond(200, ['items' => $repository->all()]);
    }

    if ($method === 'POST') {
        $rawBody = file_get_contents('php://input');
        $payload = json_decode($rawBody ?: '{}', true);

        if (!is_array($payload)) {
            respond(400, ['error' => 'JSON body is invalid']);
        }

        $name = isset($payload['name']) ? trim((string) $payload['name']) : '';

        if ($name == '') {
            respond(400, ['error' => 'Field "name" is required']);
        }

        $item = $repository->create($name);

        respond(201, ['item' => $item]);
    }

    respond(405, ['error' => 'Method not allowed']);
} catch (PDOException $exception) {
    respond(500, [
        'error' => 'Database operation failed',
        'details' => $exception->getMessage(),
    ]);
} catch (Throwable $exception) {
    respond(500, [
        'error' => 'Unexpected server error',
        'details' => $exception->getMessage(),
    ]);
}
