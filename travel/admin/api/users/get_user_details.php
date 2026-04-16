<?php
require_once '../../config/admin_config.php';
require_once '../../../config.php';

adminRequireAuth();

header('Content-Type: application/json; charset=UTF-8');

try {
    $pdo = connectToDatabase();
    
    // Валидация параметра user_id
    $userId = validateInt(getParam('user_id'), 1);
    
    if ($userId === false) {
        adminHandleError('Неверный ID пользователя', 400, 'INVALID_PARAMETERS');
    }
    
    // Get user basic info - безопасный запрос с проверкой существования колонок
    try {
        $userSql = "SELECT id, first_name, last_name, email, apple_id, phone_number, date_of_birth, profile_image_url, created_at FROM users WHERE id = :user_id";
        $userStmt = $pdo->prepare($userSql);
        $userStmt->execute([':user_id' => $userId]);
        $user = $userStmt->fetch(PDO::FETCH_ASSOC);
    } catch (Exception $e) {
        // Если колонки не существуют, пробуем без них
        $userSql = "SELECT id, first_name, last_name, email, apple_id, profile_image_url, created_at FROM users WHERE id = :user_id";
        $userStmt = $pdo->prepare($userSql);
        $userStmt->execute([':user_id' => $userId]);
        $user = $userStmt->fetch(PDO::FETCH_ASSOC);
        
        // Добавляем пустые значения для отсутствующих колонок
        if ($user) {
            $user['phone_number'] = null;
            $user['date_of_birth'] = null;
        }
    }
    
    if (!$user) {
        throw new Exception('User not found');
    }
    
    // Get user statistics - безопасно, с проверкой существования таблиц
    $stats = [
        'followers_count' => 0,
        'following_count' => 0,
        'posts_count' => 0,
        'albums_count' => 0,
        'commercial_posts_count' => 0,
        'likes_given' => 0,
        'likes_received' => 0,
        'comments_given' => 0,
        'comments_received' => 0,
        'favorites_count' => 0
    ];
    
    // Подсчитываем статистику по каждой таблице отдельно
    try {
        $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM follows WHERE followed_id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $stats['followers_count'] = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    } catch (Exception $e) {}
    
    try {
        $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM follows WHERE follower_id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $stats['following_count'] = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    } catch (Exception $e) {}
    
    try {
        $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM photos WHERE user_id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $stats['posts_count'] = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    } catch (Exception $e) {}
    
    try {
        $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM albums WHERE owner_id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $stats['albums_count'] = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    } catch (Exception $e) {}
    
    try {
        $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM commercial_posts WHERE user_id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $stats['commercial_posts_count'] = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    } catch (Exception $e) {}
    
    try {
        $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM likes WHERE user_id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $stats['likes_given'] = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    } catch (Exception $e) {}
    
    try {
        $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM likes l JOIN photos p ON l.photo_id = p.id WHERE p.user_id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $stats['likes_received'] = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
    } catch (Exception $e) {}
    
    try {
        $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM comments WHERE user_id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $commentsCount = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
        
        $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM album_comments WHERE user_id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $albumCommentsCount = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
        
        $stats['comments_given'] = $commentsCount + $albumCommentsCount;
    } catch (Exception $e) {}
    
    try {
        $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM favorites WHERE user_id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $favoritesCount = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
        
        $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM album_favorites WHERE user_id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $albumFavoritesCount = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
        
        $stmt = $pdo->prepare("SELECT COUNT(*) as cnt FROM commercial_favorites WHERE user_id = :user_id");
        $stmt->execute([':user_id' => $userId]);
        $commercialFavoritesCount = $stmt->fetch(PDO::FETCH_ASSOC)['cnt'];
        
        $stats['favorites_count'] = $favoritesCount + $albumFavoritesCount + $commercialFavoritesCount;
    } catch (Exception $e) {}
    
    // Get followers
    $followers = [];
    try {
        $followersSql = "
            SELECT u.id, u.first_name, u.last_name, u.email, u.profile_image_url as profile_image, f.created_at
            FROM follows f
            JOIN users u ON f.follower_id = u.id
            WHERE f.followed_id = :user_id
            ORDER BY f.created_at DESC
            LIMIT 50
        ";
        $followersStmt = $pdo->prepare($followersSql);
        $followersStmt->execute([':user_id' => $userId]);
        $followers = $followersStmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {}
    
    // Get following
    $following = [];
    try {
        $followingSql = "
            SELECT u.id, u.first_name, u.last_name, u.email, u.profile_image_url as profile_image, f.created_at
            FROM follows f
            JOIN users u ON f.followed_id = u.id
            WHERE f.follower_id = :user_id
            ORDER BY f.created_at DESC
            LIMIT 50
        ";
        $followingStmt = $pdo->prepare($followingSql);
        $followingStmt->execute([':user_id' => $userId]);
        $following = $followingStmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {}
    
    // Get favorite posts
    $favoritePosts = [];
    try {
        $favoritePostsSql = "
            SELECT p.id, p.title, p.description, p.file_path, p.created_at, l.name as location_name, f.created_at as favorited_at
            FROM favorites f
            JOIN photos p ON f.photo_id = p.id
            LEFT JOIN locations l ON p.location_id = l.id
            WHERE f.user_id = :user_id
            ORDER BY f.created_at DESC
            LIMIT 50
        ";
        $favoritePostsStmt = $pdo->prepare($favoritePostsSql);
        $favoritePostsStmt->execute([':user_id' => $userId]);
        $favoritePosts = $favoritePostsStmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {}
    
    // Get favorite albums
    $favoriteAlbums = [];
    try {
        $favoriteAlbumsSql = "
            SELECT a.id, a.title, a.description, a.cover_photo_id, p.file_path as cover_photo, af.created_at as favorited_at
            FROM album_favorites af
            JOIN albums a ON af.album_id = a.id
            LEFT JOIN album_photos p ON a.cover_photo_id = p.id
            WHERE af.user_id = :user_id
            ORDER BY af.created_at DESC
            LIMIT 50
        ";
        $favoriteAlbumsStmt = $pdo->prepare($favoriteAlbumsSql);
        $favoriteAlbumsStmt->execute([':user_id' => $userId]);
        $favoriteAlbums = $favoriteAlbumsStmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {}
    
    // Get commented posts
    $commentedPosts = [];
    try {
        $commentedPostsSql = "
            SELECT DISTINCT p.id, p.title, p.description, p.file_path, p.created_at, l.name as location_name,
                   (SELECT COUNT(*) FROM comments WHERE photo_id = p.id AND user_id = :user_id) as comment_count
            FROM comments c
            JOIN photos p ON c.photo_id = p.id
            LEFT JOIN locations l ON p.location_id = l.id
            WHERE c.user_id = :user_id
            ORDER BY c.created_at DESC
            LIMIT 50
        ";
        $commentedPostsStmt = $pdo->prepare($commentedPostsSql);
        $commentedPostsStmt->execute([':user_id' => $userId]);
        $commentedPosts = $commentedPostsStmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {}
    
    // Get posts with comments (posts owned by user that have comments)
    $postsWithComments = [];
    try {
        $postsWithCommentsSql = "
            SELECT DISTINCT p.id, p.title, p.description, p.file_path, p.created_at, l.name as location_name,
                   (SELECT COUNT(*) FROM comments WHERE photo_id = p.id) as comment_count
            FROM photos p
            LEFT JOIN locations l ON p.location_id = l.id
            WHERE p.user_id = :user_id AND EXISTS (SELECT 1 FROM comments WHERE photo_id = p.id)
            ORDER BY p.created_at DESC
            LIMIT 50
        ";
        $postsWithCommentsStmt = $pdo->prepare($postsWithCommentsSql);
        $postsWithCommentsStmt->execute([':user_id' => $userId]);
        $postsWithComments = $postsWithCommentsStmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {}
    
    // Get liked posts (посты которые пользователь лайкал)
    $likedPosts = [];
    try {
        $likedPostsSql = "
            SELECT p.id, p.title, p.description, p.file_path, p.created_at, l.name as location_name, 
                   u.first_name as author_first_name, u.last_name as author_last_name,
                   lk.created_at as liked_at
            FROM likes lk
            JOIN photos p ON lk.photo_id = p.id
            LEFT JOIN locations l ON p.location_id = l.id
            LEFT JOIN users u ON p.user_id = u.id
            WHERE lk.user_id = :user_id
            ORDER BY lk.created_at DESC
            LIMIT 50
        ";
        $likedPostsStmt = $pdo->prepare($likedPostsSql);
        $likedPostsStmt->execute([':user_id' => $userId]);
        $likedPosts = $likedPostsStmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {}
    
    // Get posts liked by others (кто лайкнул посты пользователя)
    $postsLikedByOthers = [];
    try {
        $postsLikedByOthersSql = "
            SELECT p.id, p.title, p.description, p.file_path, p.created_at,
                   u.id as liker_id, u.first_name as liker_first_name, u.last_name as liker_last_name,
                   u.profile_image_url as liker_profile_image,
                   lk.created_at as liked_at
            FROM likes lk
            JOIN photos p ON lk.photo_id = p.id
            JOIN users u ON lk.user_id = u.id
            WHERE p.user_id = :user_id
            ORDER BY lk.created_at DESC
            LIMIT 50
        ";
        $postsLikedByOthersStmt = $pdo->prepare($postsLikedByOthersSql);
        $postsLikedByOthersStmt->execute([':user_id' => $userId]);
        $postsLikedByOthers = $postsLikedByOthersStmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {}
    
    // Get user's favorite posts (избранные посты пользователя)
    $userFavorites = [];
    try {
        $userFavoritesSql = "
            SELECT p.id, p.title, p.description, p.file_path, p.created_at,
                   u.first_name as author_first_name, u.last_name as author_last_name,
                   u.profile_image_url as author_profile_image,
                   f.created_at as favorited_at
            FROM favorites f
            JOIN photos p ON f.photo_id = p.id
            JOIN users u ON p.user_id = u.id
            WHERE f.user_id = :user_id
            ORDER BY f.created_at DESC
            LIMIT 50
        ";
        $userFavoritesStmt = $pdo->prepare($userFavoritesSql);
        $userFavoritesStmt->execute([':user_id' => $userId]);
        $userFavorites = $userFavoritesStmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {}
    
    // Get who favorited user's posts (кто добавил посты пользователя в избранное)
    $postsFavoritedByOthers = [];
    try {
        $postsFavoritedByOthersSql = "
            SELECT p.id, p.title, p.description, p.file_path, p.created_at,
                   u.id as favoriter_id, u.first_name as favoriter_first_name, u.last_name as favoriter_last_name,
                   u.profile_image_url as favoriter_profile_image,
                   f.created_at as favorited_at
            FROM favorites f
            JOIN photos p ON f.photo_id = p.id
            JOIN users u ON f.user_id = u.id
            WHERE p.user_id = :user_id
            ORDER BY f.created_at DESC
            LIMIT 50
        ";
        $postsFavoritedByOthersStmt = $pdo->prepare($postsFavoritedByOthersSql);
        $postsFavoritedByOthersStmt->execute([':user_id' => $userId]);
        $postsFavoritedByOthers = $postsFavoritedByOthersStmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {}
    
    // Get comments made by user with details (комментарии пользователя с деталями)
    $userComments = [];
    try {
        $userCommentsSql = "
            SELECT c.id, c.comment as comment_text, c.created_at,
                   p.id as post_id, p.title as post_title, p.file_path as post_image,
                   u.id as post_author_id, u.first_name as post_author_first_name, u.last_name as post_author_last_name
            FROM comments c
            JOIN photos p ON c.photo_id = p.id
            JOIN users u ON p.user_id = u.id
            WHERE c.user_id = :user_id
            ORDER BY c.created_at DESC
            LIMIT 50
        ";
        $userCommentsStmt = $pdo->prepare($userCommentsSql);
        $userCommentsStmt->execute([':user_id' => $userId]);
        $userComments = $userCommentsStmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {}
    
    // Get comments on user's posts (комментарии к постам пользователя от других пользователей)
    $commentsOnUserPosts = [];
    try {
        $commentsOnUserPostsSql = "
            SELECT c.id, c.comment as comment_text, c.created_at,
                   p.id as post_id, p.title as post_title, p.file_path as post_image,
                   u.id as commenter_id, u.first_name as commenter_first_name, u.last_name as commenter_last_name,
                   u.profile_image_url as commenter_profile_image
            FROM comments c
            JOIN photos p ON c.photo_id = p.id
            JOIN users u ON c.user_id = u.id
            WHERE p.user_id = :user_id AND c.user_id != :user_id
            ORDER BY c.created_at DESC
            LIMIT 50
        ";
        $commentsOnUserPostsStmt = $pdo->prepare($commentsOnUserPostsSql);
        $commentsOnUserPostsStmt->execute([':user_id' => $userId]);
        $commentsOnUserPosts = $commentsOnUserPostsStmt->fetchAll(PDO::FETCH_ASSOC);
    } catch (Exception $e) {}
    
    // Format response
    $response = [
        'success' => true,
        'user' => [
            'id' => intval($user['id']),
            'firstName' => $user['first_name'],
            'lastName' => $user['last_name'],
            'email' => $user['email'],
            'appleId' => $user['apple_id'],
            'phoneNumber' => $user['phone_number'],
            'dateOfBirth' => $user['date_of_birth'],
            'profileImage' => normalizeImageUrl($user['profile_image_url']),
            'createdAt' => $user['created_at']
        ],
        'stats' => [
            'followersCount' => intval($stats['followers_count']),
            'followingCount' => intval($stats['following_count']),
            'postsCount' => intval($stats['posts_count']),
            'albumsCount' => intval($stats['albums_count']),
            'commercialPostsCount' => intval($stats['commercial_posts_count']),
            'likesGiven' => intval($stats['likes_given']),
            'likesReceived' => intval($stats['likes_received']),
            'commentsGiven' => intval($stats['comments_given']),
            'commentsReceived' => intval($stats['comments_received']),
            'favoritesCount' => intval($stats['favorites_count'])
        ],
        'followers' => array_map(function($f) {
            return [
                'id' => intval($f['id']),
                'firstName' => $f['first_name'],
                'lastName' => $f['last_name'],
                'email' => $f['email'],
                'profileImage' => normalizeImageUrl($f['profile_image']),
                'followedAt' => $f['created_at']
            ];
        }, $followers),
        'following' => array_map(function($f) {
            return [
                'id' => intval($f['id']),
                'firstName' => $f['first_name'],
                'lastName' => $f['last_name'],
                'email' => $f['email'],
                'profileImage' => normalizeImageUrl($f['profile_image']),
                'followedAt' => $f['created_at']
            ];
        }, $following),
        'favoritePosts' => array_map(function($p) {
            return [
                'id' => intval($p['id']),
                'title' => $p['title'],
                'description' => $p['description'],
                'filePath' => normalizeImageUrl($p['file_path']),
                'locationName' => $p['location_name'],
                'createdAt' => $p['created_at'],
                'favoritedAt' => $p['favorited_at']
            ];
        }, $favoritePosts),
        'favoriteAlbums' => array_map(function($a) {
            return [
                'id' => intval($a['id']),
                'title' => $a['title'],
                'description' => $a['description'],
                'coverPhoto' => normalizeImageUrl($a['cover_photo']),
                'favoritedAt' => $a['favorited_at']
            ];
        }, $favoriteAlbums),
        'commentedPosts' => array_map(function($p) {
            return [
                'id' => intval($p['id']),
                'title' => $p['title'],
                'description' => $p['description'],
                'filePath' => normalizeImageUrl($p['file_path']),
                'locationName' => $p['location_name'],
                'createdAt' => $p['created_at'],
                'commentCount' => intval($p['comment_count'])
            ];
        }, $commentedPosts),
        'postsWithComments' => array_map(function($p) {
            return [
                'id' => intval($p['id']),
                'title' => $p['title'],
                'description' => $p['description'],
                'filePath' => normalizeImageUrl($p['file_path']),
                'locationName' => $p['location_name'],
                'createdAt' => $p['created_at'],
                'commentCount' => intval($p['comment_count'])
            ];
        }, $postsWithComments),
        'likedPosts' => array_map(function($p) {
            return [
                'id' => intval($p['id']),
                'title' => $p['title'],
                'description' => $p['description'],
                'filePath' => normalizeImageUrl($p['file_path']),
                'locationName' => $p['location_name'],
                'authorName' => $p['author_first_name'] . ' ' . $p['author_last_name'],
                'createdAt' => $p['created_at'],
                'likedAt' => $p['liked_at']
            ];
        }, $likedPosts),
        'userFavorites' => array_map(function($p) {
            return [
                'id' => intval($p['id']),
                'title' => $p['title'],
                'description' => $p['description'],
                'filePath' => normalizeImageUrl($p['file_path']),
                'authorName' => $p['author_first_name'] . ' ' . $p['author_last_name'],
                'authorImage' => normalizeImageUrl($p['author_profile_image']),
                'createdAt' => $p['created_at'],
                'favoritedAt' => $p['favorited_at']
            ];
        }, $userFavorites),
        'postsLikedByOthers' => array_map(function($p) {
            return [
                'postId' => intval($p['id']),
                'postTitle' => $p['title'],
                'postImage' => normalizeImageUrl($p['file_path']),
                'likerId' => intval($p['liker_id']),
                'likerName' => $p['liker_first_name'] . ' ' . $p['liker_last_name'],
                'likerImage' => normalizeImageUrl($p['liker_profile_image']),
                'likedAt' => $p['liked_at']
            ];
        }, $postsLikedByOthers),
        'postsFavoritedByOthers' => array_map(function($p) {
            return [
                'postId' => intval($p['id']),
                'postTitle' => $p['title'],
                'postImage' => normalizeImageUrl($p['file_path']),
                'favoriterId' => intval($p['favoriter_id']),
                'favoriterName' => $p['favoriter_first_name'] . ' ' . $p['favoriter_last_name'],
                'favoriterImage' => normalizeImageUrl($p['favoriter_profile_image']),
                'favoritedAt' => $p['favorited_at']
            ];
        }, $postsFavoritedByOthers),
        'userComments' => array_map(function($c) {
            return [
                'id' => intval($c['id']),
                'text' => $c['comment_text'],
                'createdAt' => $c['created_at'],
                'postId' => intval($c['post_id']),
                'postTitle' => $c['post_title'],
                'postImage' => normalizeImageUrl($c['post_image']),
                'postAuthorId' => intval($c['post_author_id']),
                'postAuthorName' => $c['post_author_first_name'] . ' ' . $c['post_author_last_name']
            ];
        }, $userComments),
        'commentsOnUserPosts' => array_map(function($c) {
            return [
                'id' => intval($c['id']),
                'text' => $c['comment_text'],
                'createdAt' => $c['created_at'],
                'postId' => intval($c['post_id']),
                'postTitle' => $c['post_title'],
                'postImage' => normalizeImageUrl($c['post_image']),
                'commenterId' => intval($c['commenter_id']),
                'commenterName' => $c['commenter_first_name'] . ' ' . $c['commenter_last_name'],
                'commenterImage' => normalizeImageUrl($c['commenter_profile_image'])
            ];
        }, $commentsOnUserPosts)
    ];
    
    echo json_encode($response, JSON_UNESCAPED_UNICODE);
    
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode([
        'success' => false,
        'message' => 'Ошибка при получении данных пользователя: ' . $e->getMessage()
    ], JSON_UNESCAPED_UNICODE);
}
