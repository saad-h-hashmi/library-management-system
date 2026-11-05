<?php
// backend/db.php - PDO connection (settings come from config.php or environment variables)
require_once __DIR__ . '/helpers.php';

$cfg = load_config()['db'];

try {
    $pdo = new PDO(
        "mysql:host={$cfg['host']};dbname={$cfg['name']};charset=utf8mb4",
        $cfg['user'],
        $cfg['pass'],
        [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
        ]
    );
} catch (PDOException $e) {
    server_error($e, 'Database connection failed. Check backend/config.php.');
}
