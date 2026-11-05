# University Library Management System

A small PHP + MySQL web app for managing a university library: add books and students, issue and
return books (with automatic fine calculation at 50 PKR/day), see overdue books, and email overdue
notices.

**Stack:** PHP 8 (PDO), MySQL 8 / MariaDB, vanilla JavaScript, PHPMailer.

## Project structure

```
library_system/
├── database/
│   ├── schema.sql          # tables, views, triggers, stored procedures, fake sample data
│   └── sample_queries.sql  # demo / reporting queries
├── backend/                # JSON API (PHP)
│   ├── config.example.php  # copy to config.php and fill in
│   └── PHPMailer/          # bundled mail library
└── frontend/               # dashboard (HTML / CSS / JS)
```

## Setup (Laragon / XAMPP)

1. Put this folder in your web root as `www/library_system` (Laragon) or `htdocs/library_system` (XAMPP).
2. Start Apache and MySQL.
3. Import the database (**this drops and recreates the tables**):
   ```
   mysql -u root < database/schema.sql
   ```
   or import `database/schema.sql` through phpMyAdmin / HeidiSQL.
4. Copy `backend/config.example.php` to `backend/config.php` and set your MySQL user/password if they
   differ from the Laragon default (`root`, empty password).
5. Open **http://localhost/library_system/frontend/index.html**
   (opening the file straight from disk will not work, the page needs the PHP server).

## Trying it out

The sample data includes librarians `1` and `2`, five members, and ten book copies. Use a **Book ID** whose
status is *Available* (for example `2`, `4`, `6`, `9`) when issuing, and a due date after today.
Two sample books are already overdue, so the Overdue tab has data.

## Overdue emails (optional)

The **Email Overdue Students** button sends mail through Gmail SMTP.

1. Enable 2-step verification on the Google account and create an **App Password**.
2. Put the Gmail address and the app password in `backend/config.php` (never commit this file; it is in
   `.gitignore`), or set the `LIB_MAIL_USER` / `LIB_MAIL_PASS` environment variables.

The sample members use `@example.com` addresses, so no real mail goes out until you register real students.

## Limitations

This is a learning project, not production software:

- There is **no login**: anyone who can open the pages can use every action. Do not expose it to the internet.
- The default MySQL account is `root` with no password. Create a dedicated user with a password for anything beyond local use.
- Members are managed by numeric ID only (no search screens).
