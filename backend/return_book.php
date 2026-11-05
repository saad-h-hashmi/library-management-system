<?php
// backend/return_book.php
require 'db.php';
require_method('POST');

$data    = read_json();
$issueId = req_id($data, 'issue_id');

try {
    $stmt = $pdo->prepare('CALL return_book(:issue_id)');
    $stmt->execute([':issue_id' => $issueId]);
    $result = $stmt->fetch();
    $stmt->closeCursor();

    if (!$result) {
        fail('No response from the database procedure.', 500);
    }
    $ok = (int)$result['success'] === 1;
    json_out(['status' => $ok ? 'success' : 'error', 'message' => $result['Transaction_Result']], $ok ? 200 : 422);
} catch (PDOException $e) {
    server_error($e, 'Could not process the return.');
}
