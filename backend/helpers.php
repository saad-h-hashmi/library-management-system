<?php
// backend/helpers.php - shared helpers for all endpoints

function load_config(): array
{
    static $config = null;
    if ($config !== null) {
        return $config;
    }

    $defaults = [
        'db'   => ['host' => 'localhost', 'name' => 'university_library_db', 'user' => 'root', 'pass' => ''],
        'mail' => ['username' => '', 'password' => '', 'from' => '', 'from_name' => 'University Library System'],
    ];

    $file = __DIR__ . '/config.php';
    $local = is_file($file) ? (require $file) : [];
    $config = array_replace_recursive($defaults, is_array($local) ? $local : []);

    // Environment variables win over the file
    $env = [
        ['db', 'host', 'LIB_DB_HOST'], ['db', 'name', 'LIB_DB_NAME'],
        ['db', 'user', 'LIB_DB_USER'], ['db', 'pass', 'LIB_DB_PASS'],
        ['mail', 'username', 'LIB_MAIL_USER'], ['mail', 'password', 'LIB_MAIL_PASS'],
        ['mail', 'from', 'LIB_MAIL_FROM'],
    ];
    foreach ($env as [$section, $key, $var]) {
        $value = getenv($var);
        if ($value !== false && $value !== '') {
            $config[$section][$key] = $value;
        }
    }
    return $config;
}

function json_out(array $payload, int $httpCode = 200): void
{
    http_response_code($httpCode);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload);
    exit;
}

function fail(string $message, int $httpCode = 400): void
{
    json_out(['status' => 'error', 'message' => $message], $httpCode);
}

function require_method(string $method): void
{
    if ($_SERVER['REQUEST_METHOD'] !== $method) {
        header('Allow: ' . $method);
        fail("Method not allowed. Use $method.", 405);
    }
}

function read_json(): array
{
    $data = json_decode(file_get_contents('php://input'), true);
    if (!is_array($data)) {
        fail('Invalid JSON body.');
    }
    return $data;
}

// Required, non-empty, trimmed string with a max length
function req_string(array $data, string $key, int $max = 255): string
{
    $value = isset($data[$key]) && is_scalar($data[$key]) ? trim((string)$data[$key]) : '';
    if ($value === '') {
        fail("Missing required field: $key.");
    }
    if (mb_strlen($value) > $max) {
        fail("Field $key is too long (max $max characters).");
    }
    return $value;
}

// Optional string; empty -> null
function opt_string(array $data, string $key, int $max = 255): ?string
{
    $value = isset($data[$key]) && is_scalar($data[$key]) ? trim((string)$data[$key]) : '';
    if ($value === '') {
        return null;
    }
    if (mb_strlen($value) > $max) {
        fail("Field $key is too long (max $max characters).");
    }
    return $value;
}

// Required positive integer
function req_id(array $data, string $key): int
{
    $value = $data[$key] ?? null;
    if (!is_scalar($value) || filter_var($value, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]) === false) {
        fail("Field $key must be a positive whole number.");
    }
    return (int)$value;
}

// Server-side error: log details, show a generic message
function server_error(Throwable $e, string $publicMessage = 'Something went wrong on the server.'): void
{
    error_log('[library_system] ' . $e->getMessage());
    fail($publicMessage, 500);
}
