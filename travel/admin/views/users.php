<?php
require_once '../config/admin_config.php';
adminRequireAuth();
?>
<!DOCTYPE html>
<html lang="ru">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Управление пользователями - Admin Panel</title>
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    <link href="https://cdn.datatables.net/1.13.6/css/dataTables.bootstrap5.min.css" rel="stylesheet">
    <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/bootstrap-icons@1.11.1/font/bootstrap-icons.css">
    <link href="../assets/css/admin.css" rel="stylesheet">
</head>
<body>
    <?php include '../includes/header.php'; ?>
    
    <div class="container-fluid">
        <div class="row">
            <?php include '../includes/sidebar.php'; ?>
            
            <main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
                <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                    <h1 class="h2">Управление пользователями</h1>
                </div>
                
                <div class="card">
                    <div class="card-header">
                        <div class="row g-2">
                            <div class="col-12 col-md-6 mb-2 mb-md-0">
                                <h5 class="mb-0">Список пользователей</h5>
                            </div>
                            <div class="col-12 col-md-6">
                                <div class="input-group">
                                    <input type="text" class="form-control" id="searchInput" placeholder="Поиск...">
                                    <button class="btn btn-outline-secondary" type="button" id="searchBtn">
                                        <i class="bi bi-search"></i>
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                    <div class="card-body p-0">
                        <div class="table-responsive">
                            <table id="usersTable" class="table table-striped table-hover mb-0">
                                <thead>
                                    <tr>
                                        <th style="min-width: 50px;">ID</th>
                                        <th style="min-width: 60px;">Фото</th>
                                        <th style="min-width: 120px;">Имя</th>
                                        <th style="min-width: 150px;">Email / Apple ID</th>
                                        <th style="min-width: 80px;" class="text-center d-none d-lg-table-cell">Подписчики</th>
                                        <th style="min-width: 80px;" class="text-center d-none d-lg-table-cell">Подписки</th>
                                        <th style="min-width: 60px;" class="text-center d-none d-md-table-cell">Посты</th>
                                        <th style="min-width: 60px;" class="text-center d-none d-xl-table-cell">Лайки</th>
                                        <th style="min-width: 100px;" class="text-center d-none d-xl-table-cell">Комментарии</th>
                                        <th style="min-width: 100px;" class="d-none d-md-table-cell">Дата регистрации</th>
                                        <th style="min-width: 100px;">Действия</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <!-- Data will be loaded via AJAX -->
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </main>
        </div>
    </div>
    
    <script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>
    <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
    <script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
    <script src="../assets/js/admin.js"></script>
    <script src="../assets/js/users.js"></script>
</body>
</html>
