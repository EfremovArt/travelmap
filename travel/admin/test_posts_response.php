<?php
require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

header('Content-Type: text/html; charset=UTF-8');

echo "<h2>Testing get_all_posts.php API</h2>";

// Simulate API call
$_GET['page'] = 1;
$_GET['per_page'] = 5;
$_GET['search'] = '';
$_GET['sort_by'] = 'created_at';
$_GET['sort_order'] = 'desc';

// Capture output
ob_start();
include 'api/posts/get_all_posts.php';
$output = ob_get_clean();

echo "<h3>Raw Output:</h3>";
echo "<pre>" . htmlspecialchars($output) . "</pre>";

echo "<h3>JSON Validation:</h3>";
$json = json_decode($output, true);
if ($json === null) {
    echo "<p style='color: red;'>❌ Invalid JSON! Error: " . json_last_error_msg() . "</p>";
    
    // Try to find the issue
    echo "<h4>Looking for non-JSON content:</h4>";
    $lines = explode("\n", $output);
    foreach ($lines as $i => $line) {
        if (trim($line) && $line[0] !== '{' && $line[0] !== '[' && $line[0] !== '"') {
            echo "<p>Line " . ($i + 1) . ": <code>" . htmlspecialchars($line) . "</code></p>";
        }
    }
} else {
    echo "<p style='color: green;'>✅ Valid JSON</p>";
    echo "<h4>Parsed Data:</h4>";
    echo "<pre>" . print_r($json, true) . "</pre>";
}
