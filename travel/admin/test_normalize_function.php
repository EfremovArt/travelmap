<?php
require_once 'config/admin_config.php';

echo "<h2>Testing normalizeImageUrl function</h2>";

$testUrls = [
    'uploads/profile_images/7_67e70a468784a_1743194694.jpg',
    '/uploads/profile_images/7_67e70a468784a_1743194694.jpg',
    '/travel/uploads/profile_images/7_67e70a468784a_1743194694.jpg',
    'https://lh3.googleusercontent.com/a/ACg8ocJ5FwSt7itCLKayUB975Vx1u_hRRs1ECH4dTMN_cdT0p5R57P0',
    '/https://lh3.googleusercontent.com/a/ACg8ocJ5FwSt7itCLKayUB975Vx1u_hRRs1ECH4dTMN_cdT0p5R57P0'
];

echo "<table border='1' cellpadding='5'>";
echo "<tr><th>Input</th><th>Output</th></tr>";

foreach ($testUrls as $url) {
    $result = normalizeImageUrl($url);
    echo "<tr>";
    echo "<td>" . htmlspecialchars($url) . "</td>";
    echo "<td>" . htmlspecialchars($result) . "</td>";
    echo "</tr>";
}

echo "</table>";
