<?php
// Copy this file to config.php (which is git-ignored) and fill in your values.
// Environment variables with the same purpose (LIB_DB_HOST, LIB_DB_NAME, LIB_DB_USER,
// LIB_DB_PASS, LIB_MAIL_USER, LIB_MAIL_PASS, LIB_MAIL_FROM) override these.
return [
    'db' => [
        'host' => 'localhost',
        'name' => 'university_library_db',
        'user' => 'root',
        'pass' => '',            // Laragon default is an empty password
    ],
    'mail' => [
        'username'  => '',       // your Gmail address
        'password'  => '',       // Gmail APP PASSWORD (16 chars), not your normal password
        'from'      => '',       // leave empty to use the username
        'from_name' => 'University Library System',
    ],
];
