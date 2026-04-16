<?php
session_start();
// Simulate admin session for testing
$_SESSION['admin_id'] = 1;
$_SESSION['admin_username'] = 'test';

// Get API response
$url = 'http://localhost/travel/admin/api/posts/get_all_commercial_posts.php?page=1&per_page=3';
$response = file_get_contents($url);

echo "<h2>API Response</h2>";
echo "<pre>";
$data = json_decode($response, true);
print_r($data);
echo "</pre>";

if (isset($data['posts']) && count($data['posts']) > 0) {
    echo "<h3>First post user_profile_image:</h3>";
    echo htmlspecialchars($data['posts'][0]['user_profile_image']);
    
    echo "<h3>First post preview:</h3>";
    echo htmlspecialchars($data['posts'][0]['preview']);
}
