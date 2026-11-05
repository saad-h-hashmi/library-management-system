-- ==============================================================================
-- DEMO / REPORTING QUERIES (run after importing schema.sql)
-- ==============================================================================
USE university_library_db;

-- Q1. All available books in the 'Computer Science' category
SELECT b.book_id, b.title, b.author, c.category_name
FROM Books b
JOIN Categories c ON b.category_id = c.category_id
WHERE b.availability_status = 'Available' AND c.category_name = 'Computer Science';

-- Q2. Top 3 most borrowed books
SELECT b.title, COUNT(ir.issue_id) AS total_borrows
FROM Books b
JOIN Issue_Records ir ON b.book_id = ir.book_id
GROUP BY b.title
ORDER BY total_borrows DESC
LIMIT 3;

-- Q3. Borrowing history of one student (roll number BCS-05-012)
SELECT b.title, ir.issue_date, ir.due_date, ir.return_date, ir.fine_paid
FROM Issue_Records ir
JOIN Books b   ON ir.book_id = b.book_id
JOIN Members m ON ir.member_id = m.member_id
WHERE m.roll_number = 'BCS-05-012'
ORDER BY ir.issue_date DESC;

-- Q4. Who owes late fees right now
SELECT * FROM overdue_books_view;

-- Q5. Books currently issued
SELECT * FROM active_issues_view;

-- Q6. Try the procedures
-- CALL issue_book(3, 2, 1, CURRENT_DATE + INTERVAL 14 DAY);
-- CALL return_book(3);
