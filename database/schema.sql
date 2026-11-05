-- ==============================================================================
-- UNIVERSITY LIBRARY MANAGEMENT SYSTEM
-- Schema, views, triggers, stored procedures and sample (fake) data.
-- Import with:  mysql -u root < database/schema.sql
-- WARNING: this script DROPS and recreates all tables (clean reset).
-- ==============================================================================

CREATE DATABASE IF NOT EXISTS university_library_db;
USE university_library_db;

-- ------------------------------------------------------------------------------
-- DROP EXISTING OBJECTS (reverse dependency order)
-- ------------------------------------------------------------------------------
DROP VIEW  IF EXISTS view_active_fines;
DROP VIEW  IF EXISTS active_issues_view;
DROP VIEW  IF EXISTS overdue_books_view;
DROP TABLE IF EXISTS Issue_Records;
DROP TABLE IF EXISTS Books;
DROP TABLE IF EXISTS Categories;
DROP TABLE IF EXISTS Members;
DROP TABLE IF EXISTS Librarians;

-- ------------------------------------------------------------------------------
-- 1. CATEGORIES (lookup table for book classifications)
-- ------------------------------------------------------------------------------
CREATE TABLE Categories (
    category_id   INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE,
    description   VARCHAR(255)
);

-- ------------------------------------------------------------------------------
-- 2. LIBRARIANS (staff who issue books)
-- ------------------------------------------------------------------------------
CREATE TABLE Librarians (
    librarian_id     INT AUTO_INCREMENT PRIMARY KEY,
    employee_code    VARCHAR(20)  NOT NULL UNIQUE,
    first_name       VARCHAR(50)  NOT NULL,
    last_name        VARCHAR(50)  NOT NULL,
    email            VARCHAR(100) NOT NULL UNIQUE,
    shift_preference ENUM('Morning', 'Evening', 'Night') DEFAULT 'Morning'
);

-- ------------------------------------------------------------------------------
-- 3. MEMBERS (students / faculty borrowing books)
-- ------------------------------------------------------------------------------
CREATE TABLE Members (
    member_id         INT AUTO_INCREMENT PRIMARY KEY,
    roll_number       VARCHAR(20)  NOT NULL UNIQUE,
    first_name        VARCHAR(50)  NOT NULL,
    last_name         VARCHAR(50)  NOT NULL,
    email             VARCHAR(100) NOT NULL UNIQUE,
    phone             VARCHAR(20),
    registration_date DATE NOT NULL DEFAULT (CURRENT_DATE),
    account_status    ENUM('Active', 'Suspended', 'Graduated') DEFAULT 'Active'
);

-- ------------------------------------------------------------------------------
-- 4. BOOKS (each row is one physical copy)
-- ------------------------------------------------------------------------------
CREATE TABLE Books (
    book_id             INT AUTO_INCREMENT PRIMARY KEY, -- acts as the accession number
    isbn                VARCHAR(20)  NOT NULL,          -- may repeat: library can own several copies
    title               VARCHAR(200) NOT NULL,
    author              VARCHAR(150) NOT NULL,
    category_id         INT NOT NULL,
    publication_year    YEAR,
    availability_status ENUM('Available', 'Issued', 'Lost', 'Maintenance') DEFAULT 'Available',

    FOREIGN KEY (category_id) REFERENCES Categories(category_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- ------------------------------------------------------------------------------
-- 5. ISSUE_RECORDS (core transaction table)
-- "Overdue" is NOT stored: it is derived (return_date IS NULL AND due_date < today)
-- so it can never go stale. See overdue_books_view.
-- ------------------------------------------------------------------------------
CREATE TABLE Issue_Records (
    issue_id    INT AUTO_INCREMENT PRIMARY KEY,
    book_id     INT NOT NULL,
    member_id   INT NOT NULL,
    issued_by   INT NOT NULL,

    issue_date  DATE NOT NULL DEFAULT (CURRENT_DATE),
    due_date    DATE NOT NULL,
    return_date DATE DEFAULT NULL,

    status      ENUM('Active', 'Returned') DEFAULT 'Active',
    fine_paid   DECIMAL(10, 2) DEFAULT 0.00,  -- fine actually collected on return

    FOREIGN KEY (book_id)   REFERENCES Books(book_id)         ON DELETE RESTRICT,
    FOREIGN KEY (member_id) REFERENCES Members(member_id)     ON DELETE RESTRICT,
    FOREIGN KEY (issued_by) REFERENCES Librarians(librarian_id) ON DELETE RESTRICT,

    INDEX idx_issue_member (member_id),
    INDEX idx_issue_open   (return_date, due_date)
);

-- ==============================================================================
-- VIEWS
-- ==============================================================================

-- Fine calculation for books that are overdue right now (50 PKR / day)
CREATE OR REPLACE VIEW view_active_fines AS
SELECT
    i.issue_id,
    m.first_name,
    m.roll_number,
    b.title,
    i.due_date,
    CURRENT_DATE AS today_date,
    DATEDIFF(CURRENT_DATE, i.due_date) AS days_overdue,
    (DATEDIFF(CURRENT_DATE, i.due_date) * 50.00) AS calculated_fine_amount
FROM Issue_Records i
JOIN Members m ON i.member_id = m.member_id
JOIN Books b   ON i.book_id = b.book_id
WHERE i.return_date IS NULL
  AND CURRENT_DATE > i.due_date;

-- All books currently out
CREATE OR REPLACE VIEW active_issues_view AS
SELECT
    ir.issue_id,
    b.book_id,
    b.title,
    m.roll_number,
    CONCAT(m.first_name, ' ', m.last_name) AS student_name,
    ir.issue_date,
    ir.due_date
FROM Issue_Records ir
JOIN Books b   ON ir.book_id = b.book_id
JOIN Members m ON ir.member_id = m.member_id
WHERE ir.return_date IS NULL;

-- Overdue books (used by the dashboard)
CREATE OR REPLACE VIEW overdue_books_view AS
SELECT
    ir.issue_id,
    b.title,
    m.email,
    ir.due_date,
    DATEDIFF(CURRENT_DATE, ir.due_date) AS days_overdue,
    (DATEDIFF(CURRENT_DATE, ir.due_date) * 50.00) AS pending_fine -- 50 PKR/day
FROM Issue_Records ir
JOIN Books b   ON ir.book_id = b.book_id
JOIN Members m ON ir.member_id = m.member_id
WHERE ir.return_date IS NULL AND ir.due_date < CURRENT_DATE;

-- ==============================================================================
-- TRIGGERS
-- ==============================================================================
DELIMITER $$

-- A new open issue record marks the book as Issued
DROP TRIGGER IF EXISTS after_book_issue $$
CREATE TRIGGER after_book_issue
AFTER INSERT ON Issue_Records
FOR EACH ROW
BEGIN
    IF NEW.return_date IS NULL THEN
        UPDATE Books
        SET availability_status = 'Issued'
        WHERE book_id = NEW.book_id;
    END IF;
END $$

-- Returning a book (return_date NULL -> date) marks it Available again
DROP TRIGGER IF EXISTS after_book_return $$
CREATE TRIGGER after_book_return
AFTER UPDATE ON Issue_Records
FOR EACH ROW
BEGIN
    IF NEW.return_date IS NOT NULL AND OLD.return_date IS NULL THEN
        UPDATE Books
        SET availability_status = 'Available'
        WHERE book_id = NEW.book_id;
    END IF;
END $$

-- ==============================================================================
-- STORED PROCEDURES
-- Both return ONE row: success (1/0) and Transaction_Result (message).
-- ==============================================================================

-- Issue a book. Validates everything and locks the book row so two
-- simultaneous requests cannot issue the same copy.
DROP PROCEDURE IF EXISTS issue_book $$
CREATE PROCEDURE issue_book(
    IN p_member_id    INT,
    IN p_book_id      INT,
    IN p_librarian_id INT,
    IN p_due_date     DATE
)
BEGIN
    DECLARE v_book_status   VARCHAR(20) DEFAULT NULL;
    DECLARE v_member_status VARCHAR(20) DEFAULT NULL;
    DECLARE v_librarian_id  INT         DEFAULT NULL;

    IF p_due_date IS NULL OR p_due_date <= CURRENT_DATE THEN
        SELECT 0 AS success, 'Error: Due date must be after today.' AS Transaction_Result;
    ELSE
        START TRANSACTION;

        SELECT account_status INTO v_member_status
        FROM Members WHERE member_id = p_member_id;

        SELECT librarian_id INTO v_librarian_id
        FROM Librarians WHERE librarian_id = p_librarian_id;

        SELECT availability_status INTO v_book_status
        FROM Books WHERE book_id = p_book_id FOR UPDATE;

        IF v_member_status IS NULL THEN
            ROLLBACK;
            SELECT 0 AS success, 'Error: Member not found.' AS Transaction_Result;
        ELSEIF v_member_status <> 'Active' THEN
            ROLLBACK;
            SELECT 0 AS success,
                   CONCAT('Error: Member account is ', v_member_status, '.') AS Transaction_Result;
        ELSEIF v_librarian_id IS NULL THEN
            ROLLBACK;
            SELECT 0 AS success, 'Error: Librarian not found.' AS Transaction_Result;
        ELSEIF v_book_status IS NULL THEN
            ROLLBACK;
            SELECT 0 AS success, 'Error: Book not found.' AS Transaction_Result;
        ELSEIF v_book_status <> 'Available' THEN
            ROLLBACK;
            SELECT 0 AS success,
                   CONCAT('Error: Book is currently ', v_book_status, ' and cannot be issued.') AS Transaction_Result;
        ELSE
            -- trigger after_book_issue marks the book as Issued
            INSERT INTO Issue_Records (book_id, member_id, issued_by, issue_date, due_date, status)
            VALUES (p_book_id, p_member_id, p_librarian_id, CURRENT_DATE, p_due_date, 'Active');
            COMMIT;
            SELECT 1 AS success, 'Success: Book has been issued.' AS Transaction_Result;
        END IF;
    END IF;
END $$

-- Return a book and calculate the fine (50 PKR per late day)
DROP PROCEDURE IF EXISTS return_book $$
CREATE PROCEDURE return_book(
    IN p_issue_id INT
)
BEGIN
    DECLARE v_due_date    DATE DEFAULT NULL;
    DECLARE v_days_late   INT;
    DECLARE v_fine_amount DECIMAL(10,2) DEFAULT 0.00;

    START TRANSACTION;

    SELECT due_date INTO v_due_date
    FROM Issue_Records
    WHERE issue_id = p_issue_id AND return_date IS NULL
    FOR UPDATE;

    IF v_due_date IS NOT NULL THEN
        SET v_days_late = DATEDIFF(CURRENT_DATE, v_due_date);
        IF v_days_late > 0 THEN
            SET v_fine_amount = v_days_late * 50.00;
        END IF;

        -- trigger after_book_return marks the book as Available
        UPDATE Issue_Records
        SET return_date = CURRENT_DATE,
            status      = 'Returned',
            fine_paid   = v_fine_amount
        WHERE issue_id = p_issue_id;

        COMMIT;
        SELECT 1 AS success,
               CONCAT('Success: Book returned. Total Fine Collected: ', v_fine_amount, ' PKR') AS Transaction_Result;
    ELSE
        ROLLBACK;
        SELECT 0 AS success, 'Error: Invalid Issue ID or book already returned.' AS Transaction_Result;
    END IF;
END $$

DELIMITER ;

-- ==============================================================================
-- SAMPLE DATA (all names / emails are fictional)
-- Triggers above automatically set Books.availability_status for open issues.
-- ==============================================================================

INSERT INTO Categories (category_name, description) VALUES
('Computer Science',     'Programming, Architecture, and Theory'),
('Software Engineering', 'SDLC, Agile, and Project Management'),
('Mathematics',          'Calculus, Algebra, and Discrete Math'),
('Literature',           'Classic and Modern Fiction');

INSERT INTO Librarians (employee_code, first_name, last_name, email, shift_preference) VALUES
('EMP-101', 'Zainab', 'Tariq',  'zainab.t@library.example.com', 'Morning'),
('EMP-102', 'Usman',  'Sheikh', 'usman.s@library.example.com',  'Evening');

INSERT INTO Members (roll_number, first_name, last_name, email, phone) VALUES
('BCS-05-012', 'Ali',    'Hassan',  'ali.hassan@student.example.com', '0300-1234567'),
('BCS-05-045', 'Fatima', 'Noor',    'fatima.n@student.example.com',   '0300-7654321'),
('BCS-05-088', 'Bilal',  'Ahmed',   'bilal.a@student.example.com',    '0333-9998887'),
('BSE-04-011', 'Ayesha', 'Khan',    'ayesha.k@student.example.com',   '0321-4445556'),
('BCS-05-102', 'Saad',   'Mahmood', 'saad.m@student.example.com',     '0345-1112223');

-- Book copies 1,3,5,7 become 'Issued' via the trigger when their issue records are inserted.
INSERT INTO Books (isbn, title, author, category_id, publication_year, availability_status) VALUES
('978-0133970777', 'Software Engineering (10th Edition)',      'Ian Sommerville',      2, 2015, 'Available'),
('978-0133970777', 'Software Engineering (10th Edition)',      'Ian Sommerville',      2, 2015, 'Available'), -- 2nd copy
('978-1491954249', 'Flutter & Dart: Mobile App Development',   'Raphael Collins',      1, 2021, 'Available'),
('978-1449331818', 'Learning React',                           'Alex Banks',           1, 2017, 'Available'),
('978-0073523323', 'Database System Concepts',                 'Abraham Silberschatz', 1, 2010, 'Available'),
('978-0073523323', 'Database System Concepts',                 'Abraham Silberschatz', 1, 2010, 'Available'), -- 2nd copy
('978-1119056553', 'Advanced SQL Techniques',                  'Ben Forta',            1, 2016, 'Available'),
('978-0262033848', 'Introduction to Algorithms',               'Thomas H. Cormen',     1, 2009, 'Maintenance'),
('978-0134092669', 'Discrete Mathematics',                     'Kenneth Rosen',        3, 2018, 'Available'),
('978-0441219716', 'Dune',                                     'Frank Herbert',        4, 1965, 'Available');

-- Dates are relative to today so the demo always shows overdue books.
INSERT INTO Issue_Records (book_id, member_id, issued_by, issue_date, due_date, return_date, status, fine_paid) VALUES
-- 1: returned on time, no fine
(2, 1, 1, CURRENT_DATE - INTERVAL 60 DAY, CURRENT_DATE - INTERVAL 46 DAY, CURRENT_DATE - INTERVAL 51 DAY, 'Returned', 0.00),
-- 2: active, not yet due
(1, 3, 1, CURRENT_DATE - INTERVAL 2 DAY,  CURRENT_DATE + INTERVAL 12 DAY, NULL, 'Active', 0.00),
-- 3: overdue (40 days late)
(5, 2, 2, CURRENT_DATE - INTERVAL 54 DAY, CURRENT_DATE - INTERVAL 40 DAY, NULL, 'Active', 0.00),
-- 4: returned 4 days late, fine of 200 PKR collected
(4, 4, 1, CURRENT_DATE - INTERVAL 80 DAY, CURRENT_DATE - INTERVAL 66 DAY, CURRENT_DATE - INTERVAL 62 DAY, 'Returned', 200.00),
-- 5: active, not yet due
(3, 5, 2, CURRENT_DATE - INTERVAL 5 DAY,  CURRENT_DATE + INTERVAL 9 DAY,  NULL, 'Active', 0.00),
-- 6: overdue (20 days late)
(7, 1, 1, CURRENT_DATE - INTERVAL 34 DAY, CURRENT_DATE - INTERVAL 20 DAY, NULL, 'Active', 0.00);
