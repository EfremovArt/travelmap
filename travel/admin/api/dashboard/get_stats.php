<?php
require_once '../../config/admin_config.php';
require_once '../../config/cache_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    // Get date range from parameters
    $dateFrom = isset($_GET['date_from']) ? $_GET['date_from'] : null;
    $dateTo = isset($_GET['date_to']) ? $_GET['date_to'] : null;
    
    // Build date filter
    $dateFilter = '';
    $dateParams = [];
    if ($dateFrom && $dateTo) {
        $dateFilter = " WHERE DATE(created_at) BETWEEN ? AND ?";
        $dateParams = [$dateFrom, $dateTo];
    }
    
    // Check cache first (5 minute TTL) - only if no date filter
    $cacheKey = 'dashboard_stats';
    if (!$dateFrom && !$dateTo) {
        $cachedData = $adminCache->get($cacheKey);
        
        if ($cachedData !== null) {
            echo json_encode([
                'success' => true,
                'stats' => $cachedData,
                'cached' => true
            ]);
            exit;
        }
    }
    
    $conn = connectToDatabase();
    
    // Get total users count
    $sql = "SELECT COUNT(*) as count FROM users" . $dateFilter;
    $stmt = $conn->prepare($sql);
    if (!empty($dateParams)) {
        $stmt->execute($dateParams);
    } else {
        $stmt->execute();
    }
    $totalUsers = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    // Get total posts count
    $sql = "SELECT COUNT(*) as count FROM photos" . $dateFilter;
    $stmt = $conn->prepare($sql);
    if (!empty($dateParams)) {
        $stmt->execute($dateParams);
    } else {
        $stmt->execute();
    }
    $totalPosts = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    // Get total likes count
    $sql = "SELECT COUNT(*) as count FROM likes" . $dateFilter;
    $stmt = $conn->prepare($sql);
    if (!empty($dateParams)) {
        $stmt->execute($dateParams);
    } else {
        $stmt->execute();
    }
    $totalLikes = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    // Get total comments count (photos + albums)
    $sql = "SELECT COUNT(*) as count FROM comments" . $dateFilter;
    $stmt = $conn->prepare($sql);
    if (!empty($dateParams)) {
        $stmt->execute($dateParams);
    } else {
        $stmt->execute();
    }
    $photoComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $sql = "SELECT COUNT(*) as count FROM album_comments" . $dateFilter;
    $stmt = $conn->prepare($sql);
    if (!empty($dateParams)) {
        $stmt->execute($dateParams);
    } else {
        $stmt->execute();
    }
    $albumComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $totalComments = $photoComments + $albumComments;
    
    // Get total follows count
    $sql = "SELECT COUNT(*) as count FROM follows" . $dateFilter;
    $stmt = $conn->prepare($sql);
    if (!empty($dateParams)) {
        $stmt->execute($dateParams);
    } else {
        $stmt->execute();
    }
    $totalFollows = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    // Get total favorites count (photos + albums + commercial)
    $sql = "SELECT COUNT(*) as count FROM favorites" . $dateFilter;
    $stmt = $conn->prepare($sql);
    if (!empty($dateParams)) {
        $stmt->execute($dateParams);
    } else {
        $stmt->execute();
    }
    $photoFavorites = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $sql = "SELECT COUNT(*) as count FROM album_favorites" . $dateFilter;
    $stmt = $conn->prepare($sql);
    if (!empty($dateParams)) {
        $stmt->execute($dateParams);
    } else {
        $stmt->execute();
    }
    $albumFavorites = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $sql = "SELECT COUNT(*) as count FROM commercial_favorites" . $dateFilter;
    $stmt = $conn->prepare($sql);
    if (!empty($dateParams)) {
        $stmt->execute($dateParams);
    } else {
        $stmt->execute();
    }
    $commercialFavorites = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $totalFavorites = $photoFavorites + $albumFavorites + $commercialFavorites;
    
    // Get total albums count
    $sql = "SELECT COUNT(*) as count FROM albums" . $dateFilter;
    $stmt = $conn->prepare($sql);
    if (!empty($dateParams)) {
        $stmt->execute($dateParams);
    } else {
        $stmt->execute();
    }
    $totalAlbums = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    // Get total commercial posts count
    $sql = "SELECT COUNT(*) as count FROM commercial_posts" . $dateFilter;
    $stmt = $conn->prepare($sql);
    if (!empty($dateParams)) {
        $stmt->execute($dateParams);
    } else {
        $stmt->execute();
    }
    $totalCommercialPosts = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    // Get recent activity (last 7 days)
    $stmt = $conn->prepare("
        SELECT COUNT(*) as count 
        FROM users 
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ");
    $stmt->execute();
    $newUsers = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $stmt = $conn->prepare("
        SELECT COUNT(*) as count 
        FROM photos 
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ");
    $stmt->execute();
    $newPosts = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $stmt = $conn->prepare("
        SELECT COUNT(*) as count 
        FROM comments 
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ");
    $stmt->execute();
    $newPhotoComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $stmt = $conn->prepare("
        SELECT COUNT(*) as count 
        FROM album_comments 
        WHERE created_at >= DATE_SUB(NOW(), INTERVAL 7 DAY)
    ");
    $stmt->execute();
    $newAlbumComments = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
    
    $newComments = $newPhotoComments + $newAlbumComments;
    
    // Get activity data for last 7 days (for chart)
    $activityData = [];
    for ($i = 6; $i >= 0; $i--) {
        $date = date('Y-m-d', strtotime("-$i days"));
        $dateLabel = date('M d', strtotime("-$i days"));
        
        // Users registered on this day
        $stmt = $conn->prepare("
            SELECT COUNT(*) as count 
            FROM users 
            WHERE DATE(created_at) = ?
        ");
        $stmt->execute([$date]);
        $usersCount = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        
        // Posts created on this day
        $stmt = $conn->prepare("
            SELECT COUNT(*) as count 
            FROM photos 
            WHERE DATE(created_at) = ?
        ");
        $stmt->execute([$date]);
        $postsCount = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        
        // Comments created on this day
        $stmt = $conn->prepare("
            SELECT COUNT(*) as count 
            FROM comments 
            WHERE DATE(created_at) = ?
        ");
        $stmt->execute([$date]);
        $photoCommentsCount = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        
        $stmt = $conn->prepare("
            SELECT COUNT(*) as count 
            FROM album_comments 
            WHERE DATE(created_at) = ?
        ");
        $stmt->execute([$date]);
        $albumCommentsCount = $stmt->fetch(PDO::FETCH_ASSOC)['count'];
        
        $commentsCount = $photoCommentsCount + $albumCommentsCount;
        
        $activityData[] = [
            'date' => $dateLabel,
            'users' => (int)$usersCount,
            'posts' => (int)$postsCount,
            'comments' => (int)$commentsCount
        ];
    }
    
    $statsData = [
        'totalUsers' => (int)$totalUsers,
        'totalPosts' => (int)$totalPosts,
        'totalLikes' => (int)$totalLikes,
        'totalComments' => (int)$totalComments,
        'totalFollows' => (int)$totalFollows,
        'totalFavorites' => (int)$totalFavorites,
        'totalAlbums' => (int)$totalAlbums,
        'totalCommercialPosts' => (int)$totalCommercialPosts,
        'recentActivity' => [
            'newUsers' => (int)$newUsers,
            'newPosts' => (int)$newPosts,
            'newComments' => (int)$newComments
        ],
        'activityData' => $activityData
    ];
    
    // Cache the stats for 5 minutes (300 seconds) - only if no date filter
    if (!$dateFrom && !$dateTo) {
        $adminCache->set($cacheKey, $statsData, 300);
    }
    
    echo json_encode([
        'success' => true,
        'stats' => $statsData,
        'cached' => false,
        'dateRange' => $dateFrom && $dateTo ? ['from' => $dateFrom, 'to' => $dateTo] : null
    ]);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при получении статистики: ' . $e->getMessage()
    ]);
}
