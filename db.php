<?php
// ============================================================
//  DATABASE CONFIGURATION
//  Edit host/user/pass to match your phpMyAdmin / XAMPP setup
// ============================================================

// ── Force JSON output — suppress any stray HTML errors ──────
ini_set('display_errors', 0);
error_reporting(0);

// ── Custom error handler: convert PHP errors → JSON ─────────
set_error_handler(function(int $errno, string $errstr) {
    header('Content-Type: application/json; charset=utf-8');
    http_response_code(500);
    echo json_encode(['error' => "PHP Error [$errno]: $errstr"]);
    exit;
});

set_exception_handler(function(Throwable $e) {
    header('Content-Type: application/json; charset=utf-8');
    http_response_code(500);
    echo json_encode(['error' => get_class($e) . ': ' . $e->getMessage()]);
    exit;
});

// ── DB settings ──────────────────────────────────────────────
define('DB_HOST',    'localhost');
define('DB_USER',    'root');       // default XAMPP user
define('DB_PASS',    '');           // default XAMPP: empty
define('DB_NAME',    'malacca_db');
define('DB_CHARSET', 'utf8mb4');

// ── CORS ─────────────────────────────────────────────────────
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');
header('Content-Type: application/json; charset=utf-8');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

// ── PDO CONNECTION ────────────────────────────────────────────
function getDB(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $dsn = sprintf('mysql:host=%s;dbname=%s;charset=%s', DB_HOST, DB_NAME, DB_CHARSET);
        try {
            $pdo = new PDO($dsn, DB_USER, DB_PASS, [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ]);
        } catch (PDOException $e) {
            $msg = $e->getMessage();

            // Friendly hints in the JSON error
            if (strpos($msg, 'Unknown database') !== false) {
                $hint = "Database 'hormuz_db' not found. Import hormuz_db.sql via phpMyAdmin first.";
            } elseif (strpos($msg, 'Access denied') !== false) {
                $hint = "Access denied. Check DB_USER / DB_PASS in db.php.";
            } elseif (strpos($msg, 'Connection refused') !== false || strpos($msg, "Can't connect") !== false) {
                $hint = "MySQL is not running. Start it in the XAMPP Control Panel.";
            } else {
                $hint = $msg;
            }

            http_response_code(500);
            echo json_encode(['error' => $hint]);
            exit;
        }
    }
    return $pdo;
}

// ── HELPER: send JSON response ────────────────────────────────
function jsonResponse(array $data, int $code = 200): void {
    http_response_code($code);
    echo json_encode($data, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    exit;
}
