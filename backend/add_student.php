<?php
// backend/add_student.php
require 'db.php';
require_method('POST');

$data  = read_json();
$roll  = req_string($data, 'roll_number', 20);
$first = req_string($data, 'first_name', 50);
$last  = req_string($data, 'last_name', 50);
$email = req_string($data, 'email', 100);
$phone = opt_string($data, 'phone', 20);

if (!filter_var($email, FILTER_VALIDATE_EMAIL)) {
    fail('Please enter a valid email address.');
}

try {
    $stmt = $pdo->prepare(
        'INSERT INTO Members (roll_number, first_name, last_name, email, phone)
         VALUES (:roll, :first, :last, :email, :phone)'
    );
    $stmt->execute([':roll' => $roll, ':first' => $first, ':last' => $last, ':email' => $email, ':phone' => $phone]);
    json_out(['status' => 'success', 'message' => 'Student added successfully!']);
} catch (PDOException $e) {
    if ($e->getCode() === '23000') { // duplicate roll number or email
        fail('A student with that roll number or email already exists.', 409);
    }
    server_error($e, 'Could not add the student.');
}
