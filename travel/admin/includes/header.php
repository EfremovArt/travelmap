<?php
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Check if user is authenticated
if (!isset($_SESSION['admin_id'])) {
    header('Location: /travel/admin/login.php');
    exit;
}

$adminName = $_SESSION['admin_username'] ?? 'Admin';
$adminEmail = $_SESSION['admin_email'] ?? '';
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TravelMap - Административная панель</title>
    
    <!-- Bootstrap 5 CSS -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    
    <!-- DataTables CSS -->
    <link href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css" rel="stylesheet">
    
    <!-- Font Awesome - removed to avoid QUIC protocol errors -->
    
    <!-- Bootstrap Icons -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css" rel="stylesheet">
    
    <!-- Custom Admin CSS -->
    <link href="/travel/admin/assets/css/admin.css" rel="stylesheet">
    
    <script>
        // Expose CSRF token to JavaScript
        window.csrfToken = '<?php 
            require_once __DIR__ . '/../config/admin_config.php';
            echo generateCsrfToken(); 
        ?>';
    </script>
</head>
<body>
    <!-- Top Navigation Bar -->
    <nav class="navbar navbar-dark bg-dark fixed-top">
        <div class="container-fluid">
            <!-- Кнопка меню - ВИДНА НА ВСЕХ ЭКРАНАХ -->
            <button class="btn btn-dark me-2" type="button" id="sidebarToggle" aria-controls="sidebarMenu">
                <i class="bi bi-list"></i>
            </button>
            
            <a class="navbar-brand" href="/travel/admin/index.php">
                <i class="bi bi-map"></i> TravelMap Admin
            </a>
            
            <div class="ms-auto d-flex align-items-center">
                <ul class="navbar-nav flex-row align-items-center">
                    <!-- Notifications Bell -->
                    <li class="nav-item dropdown me-3">
                        <a class="nav-link position-relative" 
                           href="#" 
                           id="notificationsDropdown" 
                           role="button" 
                           data-bs-toggle="dropdown" 
                           data-bs-auto-close="outside"
                           aria-expanded="false"
                           style="padding: 0.5rem;"
                           title="Уведомления (обновляются каждые 10 сек)">
                            <i class="bi bi-bell fs-5"></i>
                            <span id="notificationBadge" class="badge rounded-pill bg-danger position-absolute" style="display: none; top: 0; right: 0; pointer-events: none;">
                                0
                            </span>
                        </a>
                        <div class="dropdown-menu dropdown-menu-end" style="min-width: 320px; max-width: 400px;">
                            <h6 class="dropdown-header d-flex justify-content-between align-items-center">
                                <span>Уведомления</span>
                                <span id="totalNotifications" class="badge bg-primary">0</span>
                            </h6>
                            <div class="dropdown-divider"></div>
                            <div id="notificationsList" style="max-height: 400px; overflow-y: auto;">
                                <div class="text-center py-3 text-muted">
                                    <i class="bi bi-inbox fs-3"></i>
                                    <p class="mb-0 small">Загрузка...</p>
                                </div>
                            </div>
                        </div>
                    </li>
                    
                    <!-- Admin User Dropdown -->
                    <li class="nav-item dropdown">
                        <a class="nav-link dropdown-toggle" href="#" id="adminDropdown" role="button" data-bs-toggle="dropdown">
                            <i class="bi bi-person-circle"></i> 
                            <span class="d-none d-md-inline"><?php echo htmlspecialchars($adminName); ?></span>
                        </a>
                        <ul class="dropdown-menu dropdown-menu-end">
                            <li><span class="dropdown-item-text text-muted small"><?php echo htmlspecialchars($adminEmail); ?></span></li>
                            <li><hr class="dropdown-divider"></li>
                            <li><a class="dropdown-item" href="/travel/admin/logout.php"><i class="bi bi-box-arrow-right"></i> Выход</a></li>
                        </ul>
                    </li>
                </ul>
            </div>
        </div>
    </nav>

    <div class="container-fluid">
        <div class="row">
