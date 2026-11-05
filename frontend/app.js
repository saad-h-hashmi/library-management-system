// Frontend logic for the University Library Dashboard.
// The backend folder sits next to this one: library_system/backend/
const API_BASE = '../backend/';

// ---------- helpers ----------
const $ = (id) => document.getElementById(id);

// Escape text before putting it into innerHTML (prevents XSS from book titles / emails)
function esc(value) {
    return String(value ?? '').replace(/[&<>"']/g, (c) => (
        { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]
    ));
}

async function api(endpoint, options) {
    const response = await fetch(API_BASE + endpoint, options);
    let result;
    try {
        result = await response.json();
    } catch {
        throw new Error('The server did not return valid JSON. Check the PHP error log.');
    }
    return result;
}

async function postData(endpoint, data) {
    try {
        const result = await api(endpoint, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
        });
        alert(result.message);
        return result.status === 'success';
    } catch (error) {
        alert('Network error. Is your PHP server running?');
        console.error(error);
        return false;
    }
}

// ---------- navigation ----------
const navLinks = document.querySelectorAll('.nav-links li');
const views = document.querySelectorAll('.view');

navLinks.forEach((link) => {
    link.addEventListener('click', () => {
        navLinks.forEach((n) => n.classList.remove('active'));
        views.forEach((v) => v.classList.remove('active'));

        link.classList.add('active');
        const target = link.getAttribute('data-target');
        $(target).classList.add('active');
        $('page-title').textContent = link.textContent.replace(/[^\w\s]/g, '').trim();

        if (target === 'dashboard-view') loadStats();
        if (target === 'overdue-view') fetchOverdueBooks();
    });
});

// ---------- dashboard stats ----------
async function loadStats() {
    try {
        const data = await api('get_dashboard_stats.php');
        if (data.status !== 'success') throw new Error(data.message);
        $('total-books-count').textContent = data.total_books;
        $('active-members-count').textContent = data.active_members;
        $('books-issued-count').textContent = data.books_issued;
        $('overdue-books-count').textContent = data.overdue_books;
    } catch (error) {
        console.error('Failed to load stats:', error);
    }
}

// ---------- overdue table ----------
function messageRow(text, cssClass) {
    return `<tr><td colspan="6" class="${cssClass}">${esc(text)}</td></tr>`;
}

async function fetchOverdueBooks() {
    const tbody = $('overdue-tbody');
    try {
        const result = await api('fetch_overdue.php');
        if (result.status !== 'success') {
            tbody.innerHTML = messageRow('Error: ' + result.message, 'cell-error');
            return;
        }
        if (result.data.length === 0) {
            tbody.innerHTML = messageRow('No overdue books right now! 🎉', 'cell-empty');
            return;
        }
        tbody.innerHTML = result.data.map((book) => `
            <tr>
                <td><strong>#${esc(book.issue_id)}</strong></td>
                <td>${esc(book.title)}</td>
                <td>${esc(book.email)}</td>
                <td>${esc(book.due_date)}</td>
                <td><span class="badge-red">${esc(book.days_overdue)} Days</span></td>
                <td class="badge-red">${esc(book.pending_fine)} PKR</td>
            </tr>`).join('');
    } catch (error) {
        console.error('Failed to load overdue books.', error);
        tbody.innerHTML = messageRow('Could not reach the server.', 'cell-error');
    }
}

$('refreshOverdueBtn').addEventListener('click', fetchOverdueBooks);

$('sendEmailsBtn').addEventListener('click', async () => {
    if (!confirm('Send an overdue notice email to every student with an overdue book?')) return;
    const btn = $('sendEmailsBtn');
    btn.disabled = true;
    btn.textContent = 'Sending...';
    await postData('send_overdue_emails.php', {});
    btn.disabled = false;
    btn.textContent = 'Email Overdue Students';
});

// ---------- forms ----------
$('addBookForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const ok = await postData('add_book.php', {
        isbn: $('b_isbn').value,
        title: $('b_title').value,
        author: $('b_author').value,
        category_id: $('b_category').value,
        publication_year: $('b_year').value,
    });
    if (ok) { e.target.reset(); loadStats(); }
});

$('addStudentForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const ok = await postData('add_student.php', {
        roll_number: $('s_roll').value,
        first_name: $('s_fname').value,
        last_name: $('s_lname').value,
        email: $('s_email').value,
        phone: $('s_phone').value,
    });
    if (ok) { e.target.reset(); loadStats(); }
});

$('issueBookForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const ok = await postData('issue_book.php', {
        member_id: $('i_member').value,
        book_id: $('i_book').value,
        librarian_id: $('i_librarian').value,
        due_date: $('i_due').value,
    });
    if (ok) { e.target.reset(); loadStats(); }
});

$('returnBookForm').addEventListener('submit', async (e) => {
    e.preventDefault();
    const ok = await postData('return_book.php', { issue_id: $('r_issue').value });
    if (ok) { e.target.reset(); fetchOverdueBooks(); loadStats(); }
});

// ---------- initial load ----------
document.addEventListener('DOMContentLoaded', () => {
    loadStats();
    fetchOverdueBooks();
});
