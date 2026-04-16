<?php
require_once 'config/admin_config.php';
require_once '../config.php';

adminRequireAuth();

$pdo = connectToDatabase();

echo "<h2>Тест API уведомлений</h2>";

// Тестируем API
$ch = curl_init();
curl_setopt($ch, CURLOPT_URL, 'http://' . $_SERVER['HTTP_HOST'] . '/travel/admin/api/notifications/get_counts.php');
curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
curl_setopt($ch, CURLOPT_COOKIE, session_name() . '=' . session_id());
$response = curl_exec($ch);
curl_close($ch);

echo "<h3>Ответ API:</h3>";
echo "<pre>" . htmlspecialchars($response) . "</pre>";

$data = json_decode($response, true);

if ($data && $data['success']) {
    echo "<h3>Расшифровка:</h3>";
    echo "<ul>";
    echo "<li>Фото на модерации: " . $data['counts']['pendingPhotos'] . "</li>";
    echo "<li>Новые посты (24ч): " . $data['counts']['newPosts'] . "</li>";
    echo "<li>Новые альбомы (24ч): " . $data['counts']['newAlbums'] . "</li>";
    echo "<li>Новые платные посты (24ч): " . $data['counts']['newCommercial'] . "</li>";
    echo "<li>Новые пользователи (24ч): " . $data['counts']['newUsers'] . "</li>";
    echo "<li>Новые комментарии (24ч): " . $data['counts']['newComments'] . "</li>";
    echo "<li><strong>ВСЕГО: " . $data['counts']['total'] . "</strong></li>";
    echo "</ul>";
}

// Проверяем данные напрямую из БД
echo "<h3>Проверка данных из БД:</h3>";

$pendingPhotos = $pdo->query("SELECT COUNT(*) as count FROM photos WHERE moderation_status IS NULL OR moderation_status = 'pending'")->fetch()['count'];
echo "<p>Фото на модерации: $pendingPhotos</p>";

$newPosts = $pdo->query("SELECT COUNT(*) as count FROM photos WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)")->fetch()['count'];
echo "<p>Новые посты за 24ч: $newPosts</p>";

$newAlbums = $pdo->query("SELECT COUNT(*) as count FROM albums WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)")->fetch()['count'];
echo "<p>Новые альбомы за 24ч: $newAlbums</p>";

$newCommercial = $pdo->query("SELECT COUNT(*) as count FROM commercial_posts WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)")->fetch()['count'];
echo "<p>Новые платные посты за 24ч: $newCommercial</p>";

$newUsers = $pdo->query("SELECT COUNT(*) as count FROM users WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)")->fetch()['count'];
echo "<p>Новые пользователи за 24ч: $newUsers</p>";

$newComments = $pdo->query("SELECT COUNT(*) as count FROM comments WHERE created_at >= DATE_SUB(NOW(), INTERVAL 24 HOUR)")->fetch()['count'];
echo "<p>Новые комментарии за 24ч: $newComments</p>";

echo "<hr>";
echo "<a href='index.php'>Вернуться на главную</a>";
