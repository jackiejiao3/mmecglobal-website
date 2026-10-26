<?php
// Contact page endpoint. Keep the visitor address in Reply-To, not From.
header('Content-Type: application/json; charset=UTF-8');

function respond($success, $message)
{
    echo json_encode(array('success' => $success, 'message' => $message));
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST' || !isset($_POST['action']) || $_POST['action'] !== 'contactform') {
    respond(false, 'Invalid request.');
}
foreach (array('username', 'email', 'message') as $field) {
    if (!isset($_POST[$field]) || !is_string($_POST[$field])) {
        respond(false, 'Please complete all fields.');
    }
}

$name = trim((string) ($_POST['username'] ?? ''));
$email = trim((string) ($_POST['email'] ?? ''));
$message = trim((string) ($_POST['message'] ?? ''));

if ($name === '' || $message === '' || strlen($name) > 200 || strlen($message) > 10000) {
    respond(false, 'Please complete all fields.');
}
if (!filter_var($email, FILTER_VALIDATE_EMAIL) || preg_match('/[\r\n]/', $email)) {
    respond(false, 'Please enter a valid email address.');
}

// Plain text ensures the email body has real line breaks in every mail client.
$body = "New inquiry from mmecglobal.com\n\n"
    . "Name / company: " . str_replace(array("\r", "\n"), ' ', $name) . "\n"
    . "Email: " . $email . "\n\n"
    . "Inquiry:\n" . str_replace("\r\n", "\n", $message) . "\n";

$headers = implode("\r\n", array(
    'From: MMEC Website <build@mmecglobal.com>',
    'Reply-To: ' . $email,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=UTF-8'
));

if (mail('jackie.jo@mdhichina.com', 'MMEC website inquiry', $body, $headers)) {
    respond(true, 'Message Sent Successfully!');
}
respond(false, 'Unable to send your message. Please try again.');
