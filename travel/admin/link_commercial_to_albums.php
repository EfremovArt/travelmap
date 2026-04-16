<?php
error_reporting(E_ALL);
ini_set('display_errors', 1);

require_once 'config/admin_config.php';
require_once '../config.php';

$pdo = connectToDatabase();

// Handle form submission
if ($_SERVER['REQUEST_METHOD'] === 'POST' && isset($_POST['commercial_id'], $_POST['album_id'])) {
    $commercialId = intval($_POST['commercial_id']);
    $albumId = intval($_POST['album_id']);
    
    $stmt = $pdo->prepare("UPDATE commercial_posts SET album_id = ? WHERE id = ?");
    $stmt->execute([$albumId, $commercialId]);
    
    echo "<div style='background: #d4edda; padding: 10px; margin: 10px 0; border: 1px solid #c3e6cb;'>";
    echo "✓ Commercial post #{$commercialId} linked to album #{$albumId}";
    echo "</div>";
}

// Get commercial posts of type 'album' without album_id
$commercialPosts = $pdo->query("
    SELECT * FROM commercial_posts 
    WHERE type = 'album' AND (album_id IS NULL OR album_id = 0)
    ORDER BY id
")->fetchAll(PDO::FETCH_ASSOC);

// Get all albums
$albums = $pdo->query("
    SELECT a.*, u.first_name, u.last_name,
           (SELECT COUNT(*) FROM album_photos WHERE album_id = a.id) as photos_count
    FROM albums a
    LEFT JOIN users u ON a.owner_id = u.id
    ORDER BY a.created_at DESC
")->fetchAll(PDO::FETCH_ASSOC);

?>
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>Link Commercial Posts to Albums</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .commercial-post { border: 2px solid #007bff; padding: 15px; margin: 20px 0; background: #f8f9fa; }
        .album-option { border: 1px solid #ddd; padding: 10px; margin: 5px 0; background: white; }
        .album-option:hover { background: #e9ecef; }
        button { background: #28a745; color: white; border: none; padding: 10px 20px; cursor: pointer; }
        button:hover { background: #218838; }
    </style>
</head>
<body>
    <h1>Link Commercial Posts to Albums</h1>
    <p>Found <?php echo count($commercialPosts); ?> commercial posts without album links</p>
    
    <?php foreach ($commercialPosts as $post): ?>
        <div class="commercial-post">
            <h3>Commercial Post #<?php echo $post['id']; ?>: <?php echo htmlspecialchars($post['title']); ?></h3>
            <p><strong>Type:</strong> <?php echo $post['type']; ?></p>
            <p><strong>Description:</strong> <?php echo htmlspecialchars($post['description'] ?? 'N/A'); ?></p>
            
            <h4>Select Album to Link:</h4>
            <?php foreach ($albums as $album): ?>
                <div class="album-option">
                    <form method="POST" style="display: inline;">
                        <input type="hidden" name="commercial_id" value="<?php echo $post['id']; ?>">
                        <input type="hidden" name="album_id" value="<?php echo $album['id']; ?>">
                        <strong>Album #<?php echo $album['id']; ?>:</strong> 
                        <?php echo htmlspecialchars($album['title']); ?>
                        (<?php echo $album['photos_count']; ?> photos, 
                        by <?php echo htmlspecialchars($album['first_name'] . ' ' . $album['last_name']); ?>)
                        <button type="submit">Link This Album</button>
                    </form>
                </div>
            <?php endforeach; ?>
        </div>
    <?php endforeach; ?>
    
    <?php if (empty($commercialPosts)): ?>
        <p style="color: green;">✓ All commercial posts are already linked!</p>
    <?php endif; ?>
    
    <p><a href="test_commercial_photos.php">Check Results</a> | <a href="views/moderation.php">Go to Moderation</a></p>
</body>
</html>
