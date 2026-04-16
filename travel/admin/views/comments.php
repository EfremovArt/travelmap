<?php
require_once '../config/admin_config.php';
adminRequireAuth();

$pageTitle = 'Управление комментариями';
include '../includes/header.php';
?>

<div class="container-fluid">
    <div class="row">
        <?php include '../includes/sidebar.php'; ?>
        
        <main class="col-12 px-3 px-md-4">
            <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                <h1 class="h2">Управление комментариями</h1>
            </div>
            
            <!-- Filters -->
            <div class="card mb-4">
                <div class="card-body">
                    <form id="filterForm" class="row g-3">
                        <div class="col-md-3">
                            <label for="userFilter" class="form-label">Фильтр по пользователю</label>
                            <input type="number" class="form-control" id="userFilter" name="user_id" placeholder="ID пользователя">
                        </div>
                        <div class="col-md-3">
                            <label for="photoFilter" class="form-label">Фильтр по посту</label>
                            <input type="number" class="form-control" id="photoFilter" name="photo_id" placeholder="ID поста">
                        </div>
                        <div class="col-md-3">
                            <label for="albumFilter" class="form-label">Фильтр по альбому</label>
                            <input type="number" class="form-control" id="albumFilter" name="album_id" placeholder="ID альбома">
                        </div>
                        <div class="col-md-3">
                            <label for="searchInput" class="form-label">Поиск по тексту</label>
                            <input type="text" class="form-control" id="searchInput" name="search" placeholder="Текст комментария">
                        </div>
                        <div class="col-12">
                            <button type="submit" class="btn btn-primary">Применить фильтры</button>
                            <button type="button" class="btn btn-secondary" id="resetFilters">Сбросить</button>
                        </div>
                    </form>
                </div>
            </div>
            
            <!-- Comments Table -->
            <div class="card">
                <div class="card-body">
                    <div class="table-responsive">
                        <table id="commentsTable" class="table table-striped table-hover">
                            <thead>
                                <tr>
                                    <th>ID</th>
                                    <th>Тип</th>
                                    <th>Пользователь</th>
                                    <th>Email</th>
                                    <th>Пост/Альбом</th>
                                    <th>Комментарий</th>
                                    <th>Дата создания</th>
                                    <th>Действия</th>
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

<script src="../assets/js/comments.js"></script>
