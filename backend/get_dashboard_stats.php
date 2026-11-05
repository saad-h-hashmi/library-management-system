<?php
// backend/get_dashboard_stats.php
require 'db.php';
require_method('GET');

try {
    $count = fn(string $sql): int => (int)$pdo->query($sql)->fetchColumn();

    json_out([
        'status'         => 'success',
        'total_books'    => $count('SELECT COUNT(*) FROM Books'),
        'active_members' => $count("SELECT COUNT(*) FROM Members WHERE account_status = 'Active'"),
        'books_issued'   => $count('SELECT COUNT(*) FROM Issue_Records WHERE return_date IS NULL'),
        'overdue_books'  => $count('SELECT COUNT(*) FROM Issue_Records WHERE return_date IS NULL AND due_date < CURRENT_DATE'),
    ]);
} catch (PDOException $e) {
    server_error($e, 'Could not load dashboard statistics.');
}
