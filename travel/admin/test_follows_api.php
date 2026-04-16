<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

echo "<h2>Testing Follows API</h2>";

try {
    $pdo = connectToDatabase();
    echo "✓ Database connection successful<br>";
    
    // Test query
    echo "<h3>Testing follows query:</h3>";
    $sql = "SELECT 
                f.id,
                follower.profile_image_url as followerImage,
                followed.profile_image_url as followedImage
            FROM follows f
            INNER JOIN users follower ON f.follower_id = follower.id
            INNER JOIN users followed ON f.followed_id = followed.id
            LIMIT 5";
    
    $stmt = $pdo->prepare($sql);
    $stmt->execute();
    $follows = $stmt->fetchAll(PDO::FETCH_ASSOC);
    
    echo "Found " . count($follows) . " follows<br>";
    echo "<h3>Raw data from database:</h3>";
    echo "<pre>";
    print_r($follows);
    echo "</pre>";
    
    echo "<h3>After normalizeImageUrl:</h3>";
    
    // Test with problematic URLs
    $testUrls = [
        'https://lh3.googleusercontent.com/a/ACg8ocJ5FwSt7itCLKayUB975Vx1u_hRRs1ECH4dTMN_cdT0p5R57P0',
        '/https://lh3.googleusercontent.com/a/ACg8ocJ5FwSt7itCLKayUB975Vx1u_hRRs1ECH4dTMN_cdT0p5R57P0',
        'uploads/profile_images/7_67e70a468784a_1743194694.jpg',
        '/uploads/profile_images/7_67e70a468784a_1743194694.jpg'
    ];
    
    echo "<h4>Test URLs:</h4>";
    foreach ($testUrls as $url) {
        $normalized = normalizeImageUrl($url);
        echo "Input: '$url'<br>";
        echo "Output: '$normalized'<br><br>";
    }
    
    echo "<h4>Real data:</h4>";
    foreach ($follows as &$follow) {
        $originalFollower = $follow['followerImage'];
        $originalFollowed = $follow['followedImage'];
        
        $follow['followerImage'] = $follow['followerImage'] ? normalizeImageUrl($follow['followerImage']) : null;
        $follow['followedImage'] = $follow['followedImage'] ? normalizeImageUrl($follow['followedImage']) : null;
        
        echo "Follower: '$originalFollower' => '{$follow['followerImage']}'<br>";
        echo "Followed: '$originalFollowed' => '{$follow['followedImage']}'<br><br>";
    }
    
    echo "<h3>✓ All tests passed!</h3>";
    
} catch (Exception $e) {
    echo "<h3 style='color: red;'>✗ Error: " . $e->getMessage() . "</h3>";
    echo "<pre>";
    echo $e->getTraceAsString();
    echo "</pre>";
}
