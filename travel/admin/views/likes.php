<?php
require_once '../config/admin_config.php';
adminRequireAuth();

$pageTitle = 'Управление лайками';
include '../includes/header.php';
?>

<div class="container-fluid">
    <div class="row">
        <?php include '../includes/sidebar.php'; ?>
        
        <main class="col-12 px-3 px-md-4">
            <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                <h1 class="h2">Управление лайками</h1>
            </div>
            
            <!-- Filters -->
            <div class="card mb-4">
                <div class="card-body">
                    <form id="filterForm" class="row g-3">
                        <div class="col-md-4">
                            <label for="userFilter" class="form-label">Фильтр по пользователю</label>
                            <input type="number" class="form-control" id="userFilter" name="user_id" placeholder="ID пользователя">
                        </div>
                        <div class="col-md-4">
                            <label for="photoFilter" class="form-label">Фильтр по посту</label>
                            <input type="number" class="form-control" id="photoFilter" name="photo_id" placeholder="ID поста">
                        </div>
                        <div class="col-md-4">
                            <label for="searchInput" class="form-label">Поиск по имени</label>
                            <input type="text" class="form-control" id="searchInput" name="search" placeholder="Введите имя пользователя">
                        </div>
                        <div class="col-12">
                            <button type="submit" class="btn btn-primary">Применить фильтры</button>
                            <button type="button" class="btn btn-secondary" id="resetFilters">Сбросить</button>
                        </div>
                    </form>
                </div>
            </div>
            
            <!-- Likes Table -->
            <div class="card">
                <div class="card-body">
                    <div class="table-responsive">
                        <table id="likesTable" class="table table-striped table-hover">
                            <thead>
                                <tr>
                                    <th>ID</th>
                                    <th>Пользователь</th>
                                    <th>Email</th>
                                    <th>Пост</th>
                                    <th>Локация</th>
                                    <th>Дата создания</th>
                                    <th>Превью</th>
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

<script src="https://code.jquery.com/jquery-3.7.0.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/js/bootstrap.bundle.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/jquery.dataTables.min.js"></script>
<script src="https://cdn.datatables.net/1.13.6/js/dataTables.bootstrap5.min.js"></script>
<script src="https://cdn.jsdelivr.net/npm/sweetalert2@11"></script>
<script src="../assets/js/likes.js"></script>
</body>
</html>
