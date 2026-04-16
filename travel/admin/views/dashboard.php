<?php
require_once '../config/admin_config.php';
adminRequireAuth();
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dashboard - Admin Panel</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.0/font/bootstrap-icons.css">
    <link rel="stylesheet" href="../assets/css/admin.css">
</head>
<body>
    <?php include '../includes/header.php'; ?>
    
    <div class="container-fluid">
        <div class="row">
            <?php include '../includes/sidebar.php'; ?>
            
            <main class="col-12 px-3 px-md-4">
                <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                    <h1 class="h2">Dashboard</h1>
                </div>

                <!-- Date Filter -->
                <div class="card mb-4">
                    <div class="card-body">
                        <div class="row align-items-end">
                            <div class="col-md-3">
                                <label for="dateFrom" class="form-label">С даты</label>
                                <input type="date" class="form-control" id="dateFrom">
                            </div>
                            <div class="col-md-3">
                                <label for="dateTo" class="form-label">По дату</label>
                                <input type="date" class="form-control" id="dateTo">
                            </div>
                            <div class="col-md-6">
                                <div class="btn-group" role="group">
                                    <button type="button" class="btn btn-outline-primary" id="btnToday">Сегодня</button>
                                    <button type="button" class="btn btn-outline-primary" id="btnYesterday">Вчера</button>
                                    <button type="button" class="btn btn-outline-primary" id="btnWeek">Неделя</button>
                                    <button type="button" class="btn btn-outline-primary" id="btnMonth">Месяц</button>
                                    <button type="button" class="btn btn-outline-primary active" id="btnAll">Все время</button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Statistics Cards -->
                <div class="row mb-4" id="statsCards">
                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card border-left-primary shadow h-100 py-2">
                            <div class="card-body">
                                <div class="row no-gutters align-items-center">
                                    <div class="col mr-2">
                                        <div class="text-xs font-weight-bold text-primary text-uppercase mb-1">
                                            Пользователи
                                        </div>
                                        <div class="h5 mb-0 font-weight-bold text-gray-800" id="totalUsers">
                                            <span class="spinner-border spinner-border-sm" role="status"></span>
                                        </div>
                                        <div class="text-xs text-muted mt-1">
                                            <span id="newUsers">0</span> новых за неделю
                                        </div>
                                    </div>
                                    <div class="col-auto">
                                        <i class="bi bi-people fs-2 text-gray-300"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card border-left-success shadow h-100 py-2">
                            <div class="card-body">
                                <div class="row no-gutters align-items-center">
                                    <div class="col mr-2">
                                        <div class="text-xs font-weight-bold text-success text-uppercase mb-1">
                                            Посты
                                        </div>
                                        <div class="h5 mb-0 font-weight-bold text-gray-800" id="totalPosts">
                                            <span class="spinner-border spinner-border-sm" role="status"></span>
                                        </div>
                                        <div class="text-xs text-muted mt-1">
                                            <span id="newPosts">0</span> новых за неделю
                                        </div>
                                    </div>
                                    <div class="col-auto">
                                        <i class="bi bi-image fs-2 text-gray-300"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card border-left-info shadow h-100 py-2">
                            <div class="card-body">
                                <div class="row no-gutters align-items-center">
                                    <div class="col mr-2">
                                        <div class="text-xs font-weight-bold text-info text-uppercase mb-1">
                                            Лайки
                                        </div>
                                        <div class="h5 mb-0 font-weight-bold text-gray-800" id="totalLikes">
                                            <span class="spinner-border spinner-border-sm" role="status"></span>
                                        </div>
                                    </div>
                                    <div class="col-auto">
                                        <i class="bi bi-heart-fill fs-2 text-gray-300"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card border-left-warning shadow h-100 py-2">
                            <div class="card-body">
                                <div class="row no-gutters align-items-center">
                                    <div class="col mr-2">
                                        <div class="text-xs font-weight-bold text-warning text-uppercase mb-1">
                                            Комментарии
                                        </div>
                                        <div class="h5 mb-0 font-weight-bold text-gray-800" id="totalComments">
                                            <span class="spinner-border spinner-border-sm" role="status"></span>
                                        </div>
                                        <div class="text-xs text-muted mt-1">
                                            <span id="newComments">0</span> новых за неделю
                                        </div>
                                    </div>
                                    <div class="col-auto">
                                        <i class="bi bi-chat-dots fs-2 text-gray-300"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Second Row of Stats -->
                <div class="row mb-4">
                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card border-left-secondary shadow h-100 py-2">
                            <div class="card-body">
                                <div class="row no-gutters align-items-center">
                                    <div class="col mr-2">
                                        <div class="text-xs font-weight-bold text-secondary text-uppercase mb-1">
                                            Подписки
                                        </div>
                                        <div class="h5 mb-0 font-weight-bold text-gray-800" id="totalFollows">
                                            <span class="spinner-border spinner-border-sm" role="status"></span>
                                        </div>
                                    </div>
                                    <div class="col-auto">
                                        <i class="bi bi-person-plus fs-2 text-gray-300"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card border-left-danger shadow h-100 py-2">
                            <div class="card-body">
                                <div class="row no-gutters align-items-center">
                                    <div class="col mr-2">
                                        <div class="text-xs font-weight-bold text-danger text-uppercase mb-1">
                                            Избранное
                                        </div>
                                        <div class="h5 mb-0 font-weight-bold text-gray-800" id="totalFavorites">
                                            <span class="spinner-border spinner-border-sm" role="status"></span>
                                        </div>
                                    </div>
                                    <div class="col-auto">
                                        <i class="bi bi-star-fill fs-2 text-gray-300"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card border-left-dark shadow h-100 py-2">
                            <div class="card-body">
                                <div class="row no-gutters align-items-center">
                                    <div class="col mr-2">
                                        <div class="text-xs font-weight-bold text-dark text-uppercase mb-1">
                                            Альбомы
                                        </div>
                                        <div class="h5 mb-0 font-weight-bold text-gray-800" id="totalAlbums">
                                            <span class="spinner-border spinner-border-sm" role="status"></span>
                                        </div>
                                    </div>
                                    <div class="col-auto">
                                        <i class="bi bi-collection fs-2 text-gray-300"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card border-left-primary shadow h-100 py-2">
                            <div class="card-body">
                                <div class="row no-gutters align-items-center">
                                    <div class="col mr-2">
                                        <div class="text-xs font-weight-bold text-primary text-uppercase mb-1">
                                            Коммерческие посты
                                        </div>
                                        <div class="h5 mb-0 font-weight-bold text-gray-800" id="totalCommercialPosts">
                                            <span class="spinner-border spinner-border-sm" role="status"></span>
                                        </div>
                                    </div>
                                    <div class="col-auto">
                                        <i class="bi bi-megaphone fs-2 text-gray-300"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Activity Chart -->
                <div class="row">
                    <div class="col-12">
                        <div class="card shadow mb-4">
                            <div class="card-header py-3">
                                <h6 class="m-0 font-weight-bold text-primary">Активность за последние 7 дней</h6>
                            </div>
                            <div class="card-body">
                                <canvas id="activityChart" style="max-height: 400px;"></canvas>
                            </div>
                        </div>
                    </div>
                </div>
            </main>
        </div>
    </div>

    <?php include '../includes/footer.php'; ?>

    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js"></script>
    <script src="../assets/js/dashboard.js?v=<?php echo time(); ?>"></script>
</body>
</html>
