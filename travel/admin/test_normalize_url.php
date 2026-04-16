<?php
require_once 'config/admin_config.php';

header('Content-Type: text/html; charset=UTF-8');

$testUrls = [
    'https://lh3.googleusercontent.com/a/ACg8ocJ5FwSt7itCLKayUB975Vx1u_hRRs1ECH4dTMN_cdT0p5R57P0',
    '/travel/uploads/profile_images/25_69002ea8bcaf4_1761619624.png',
    'travel/uploads/profile_images/25_69002ea8bcaf4_1761619624.png',
    '/travel/travel/uploads/profile_images/25_69002ea8bcaf4_1761619624.png',
    'travel/travel/uploads/profile_images/25_69002ea8bcaf4_1761619624.png',
    'uploads/profile_images/25_69002ea8bcaf4_1761619624.png',
    '/uploads/profile_images/25_69002ea8bcaf4_1761619624.png',
];

echo "<h2>Test normalizeImageUrl() function</h2>";
echo "<table border='1' cellpadding='10'>";
echo "<tr><th>Input</th><th>Output</th></tr>";

foreach ($testUrls as $url) {
    $normalized = normalizeImageUrl($url);
    echo "<tr>";
    echo "<td>" . htmlspecialchars($url) . "</td>";
    echo "<td>" . htmlspecialchars($normalized) . "</td>";
    echo "</tr>";
}

echo "</table>";
