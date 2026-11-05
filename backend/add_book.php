<?php
// backend/add_book.php
require 'db.php';
require_method('POST');

$data     = read_json();
$isbn     = req_string($data, 'isbn', 20);
$title    = req_string($data, 'title', 200);
$author   = req_string($data, 'author', 150);
$category = req_id($data, 'category_id');
$yearRaw  = opt_string($data, 'publication_year', 4);

$year = null;
if ($yearRaw !== null) {
    $year = filter_var($yearRaw, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1901, 'max_range' => 2155]]);
    if ($year === false) {
        fail('Publication year must be between 1901 and 2155.');
    }
}

try {
    $stmt = $pdo->prepare(
        'INSERT INTO Books (isbn, title, author, category_id, publication_year)
         VALUES (:isbn, :title, :author, :category_id, :year)'
    );
    $stmt->execute([':isbn' => $isbn, ':title' => $title, ':author' => $author, ':category_id' => $category, ':year' => $year]);
    json_out(['status' => 'success', 'message' => 'Book added successfully!']);
} catch (PDOException $e) {
    if ($e->getCode() === '23000') { // most likely an unknown category_id
        fail('Could not add the book. Check that the category ID exists.', 409);
    }
    server_error($e, 'Could not add the book.');
}
