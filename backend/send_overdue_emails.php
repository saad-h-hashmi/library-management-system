<?php
// backend/send_overdue_emails.php
// Sends one email per overdue book. POST only (triggered by the button in the UI).
use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\Exception;

require 'PHPMailer/Exception.php';
require 'PHPMailer/PHPMailer.php';
require 'PHPMailer/SMTP.php';
require 'db.php';

require_method('POST');

$mailCfg = load_config()['mail'];
if ($mailCfg['username'] === '' || $mailCfg['password'] === '') {
    fail('Email is not configured. Set the Gmail address and app password in backend/config.php.', 503);
}

$h = fn($v) => htmlspecialchars((string)$v, ENT_QUOTES, 'UTF-8');

try {
    $rows = $pdo->query(
        "SELECT m.first_name, m.last_name, m.email, b.title, ir.due_date,
                DATEDIFF(CURRENT_DATE, ir.due_date) AS days_late
         FROM Issue_Records ir
         JOIN Members m ON ir.member_id = m.member_id
         JOIN Books b   ON ir.book_id = b.book_id
         WHERE ir.return_date IS NULL AND ir.due_date < CURRENT_DATE"
    )->fetchAll();
} catch (PDOException $e) {
    server_error($e, 'Could not load overdue records.');
}

if (count($rows) === 0) {
    json_out(['status' => 'success', 'message' => 'No overdue books found today.', 'emails_sent' => 0, 'errors' => []]);
}

$sent = 0;
$errors = [];

try {
    $mail = new PHPMailer(true);
    $mail->isSMTP();
    $mail->Host       = 'smtp.gmail.com';
    $mail->SMTPAuth   = true;
    $mail->Username   = $mailCfg['username'];
    $mail->Password   = $mailCfg['password'];
    $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
    $mail->Port       = 587;
    $mail->CharSet    = 'UTF-8';
    $mail->setFrom($mailCfg['from'] !== '' ? $mailCfg['from'] : $mailCfg['username'], $mailCfg['from_name']);
    $mail->isHTML(true);
    $mail->Subject = 'Overdue Library Book Notice';
    $mail->SMTPKeepAlive = true;
} catch (Exception $e) {
    server_error($e, 'Could not set up the mail server.');
}

foreach ($rows as $r) {
    try {
        $mail->clearAddresses();
        $mail->addAddress($r['email'], $r['first_name'] . ' ' . $r['last_name']);

        $body = '<h3>Library Overdue Notice</h3>'
              . '<p>Dear ' . $h($r['first_name'] . ' ' . $r['last_name']) . ',</p>'
              . '<p>Our records show you have an overdue book:</p><ul>'
              . '<li><strong>Book Title:</strong> ' . $h($r['title']) . '</li>'
              . '<li><strong>Due Date:</strong> ' . $h($r['due_date']) . '</li>'
              . '<li><strong>Days Late:</strong> ' . $h($r['days_late']) . ' days</li></ul>'
              . "<p style='color:red;font-weight:bold;'>Please return this book as soon as possible. "
              . 'A late fine of 50 PKR per day is accumulating on your account.</p>'
              . '<p>Thank you,<br>University Library Administration</p>';

        $mail->Body    = $body;
        $mail->AltBody = strip_tags($body);
        $mail->send();
        $sent++;
    } catch (Exception $e) {
        error_log('[library_system] mail failed for ' . $r['email'] . ': ' . $e->getMessage());
        $errors[] = 'Could not send to ' . $r['email'];
    }
}

json_out([
    'status'      => $sent > 0 || count($errors) === 0 ? 'success' : 'error',
    'message'     => "$sent email(s) sent" . (count($errors) ? ', ' . count($errors) . ' failed.' : '.'),
    'emails_sent' => $sent,
    'errors'      => $errors,
]);
