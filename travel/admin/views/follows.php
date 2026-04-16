<?php
require_once '../config/admin_config.php';
adminRequireAuth();

$pageTitle = 'Управление подписками';
include '../includes/header.php';
?>

<div class="container-fluid">
    <div class="row">
        <?php include '../includes/sidebar.php'; ?>
        
        <main class="col-12 px-3 px-md-4">
            <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                <h1 class="h2">Управление подписками</h1>
            </div>
            
            <!-- Filters -->
            <div class="card mb-4">
                <div class="card-body">
                    <form id="filterForm" class="row g-3">
                        <div class="col-md-6">
                            <label for="userFilter" class="form-label">Фильтр по пользователю</label>
                            <input type="number" class="form-control" id="userFilter" name="user_id" placeholder="ID пользователя (подписчик или подписан)">
                            <small class="form-text text-muted">Показать все подписки, где пользователь является подписчиком или на него подписаны</small>
                        </div>
                        <div class="col-md-6">
                            <label for="searchInput" class="form-label">Поиск по имени</label>
                            <input type="text" class="form-control" id="searchInput" name="search" placeholder="Введите имя пользователя">
                            <small class="form-text text-muted">Поиск по имени подписчика или пользователя</small>
                        </div>
                        <div class="col-12">
                            <button type="submit" class="btn btn-primary">Применить фильтры</button>
                            <button type="button" class="btn btn-secondary" id="resetFilters">Сбросить</button>
                        </div>
                    </form>
                </div>
            </div>
            
            <!-- Follows Table -->
            <div class="card">
                <div class="card-body">
                    <div class="table-responsive">
                        <table id="followsTable" class="table table-striped table-hover">
                            <thead>
                                <tr>
                                    <th>ID</th>
                                    <th>Подписчик</th>
                                    <th>Email подписчика</th>
                                    <th>Подписан на</th>
                                    <th>Email пользователя</th>
                                    <th>Дата подписки</th>
                                </tr>
                            </thead>
                            <tbody>
                                <!-- Data will be loaded via DataTables -->
                            </tbody>
                        </table>
                    </div>
                </div>
            </div>
        </main>
    </div>
</div>

<?php include '../includes/footer.php'; ?>

<script src="../assets/js/follows.js"></script>
