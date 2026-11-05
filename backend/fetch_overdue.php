<?php
// backend/fetch_overdue.php
require 'db.php';
require_method('GET');

try {
    $rows = $pdo->query('SELECT * FROM overdue_books_view ORDER BY days_overdue DESC')->fetchAll();
    json_out(['status' => 'success', 'total_overdue' => count($rows), 'data' => $rows]);
} catch (PDOException $e) {
    server_error($e, 'Could not load overdue books.');
}
