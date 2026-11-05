<?php
// backend/issue_book.php
require 'db.php';
require_method('POST');

$data      = read_json();
$memberId  = req_id($data, 'member_id');
$bookId    = req_id($data, 'book_id');
$librarian = req_id($data, 'librarian_id');
$dueDate   = req_string($data, 'due_date', 10);

$d = DateTime::createFromFormat('Y-m-d', $dueDate);
if (!$d || $d->format('Y-m-d') !== $dueDate) {
    fail('Due date must be a valid date (YYYY-MM-DD).');
}

try {
    $stmt = $pdo->prepare('CALL issue_book(:member_id, :book_id, :librarian_id, :due_date)');
    $stmt->execute([':member_id' => $memberId, ':book_id' => $bookId, ':librarian_id' => $librarian, ':due_date' => $dueDate]);
    $result = $stmt->fetch();
    $stmt->closeCursor();

    if (!$result) {
        fail('No response from the database procedure.', 500);
    }
    $ok = (int)$result['success'] === 1;
    json_out(['status' => $ok ? 'success' : 'error', 'message' => $result['Transaction_Result']], $ok ? 200 : 422);
} catch (PDOException $e) {
    server_error($e, 'Could not issue the book.');
}
