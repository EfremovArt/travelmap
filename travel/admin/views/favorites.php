<?php
require_once '../config/admin_config.php';
adminRequireAuth();

$pageTitle = 'Управление избранным';
include '../includes/header.php';
?>

<div class="container-fluid">
    <div class="row">
        <?php include '../includes/sidebar.php'; ?>
        
        <main class="col-12 px-3 px-md-4">
            <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                <h1 class="h2">Управление избранным</h1>
            </div>
            
            <!-- Filters -->
            <div class="card mb-4">
                <div class="card-body">
                    <form id="filterForm" class="row g-3">
                        <div class="col-md-4">
                            <label for="typeFilter" class="form-label">Тип контента</label>
                            <select class="form-select" id="typeFilter" name="type">
                                <option value="all">Все типы</option>
                                <option value="photo">Фотографии</option>
                                <option value="album">Альбомы</option>
                                <option value="commercial">Коммерческие посты</option>
                            </select>
                        </div>
                        <div class="col-md-4">
                            <label for="userFilter" class="form-label">Фильтр по пользователю</label>
                            <input type="number" class="form-control" id="userFilter" name="user_id" placeholder="ID пользователя">
                        </div>
                        <div class="col-md-4">
                            <label for="searchInput" class="form-label">Поиск</label>
                            <input type="text" class="form-control" id="searchInput" name="search" placeholder="Имя пользователя или название">
                        </div>
                        <div class="col-12">
                            <button type="submit" class="btn btn-primary">Применить фильтры</button>
                            <button type="button" class="btn btn-secondary" id="resetFilters">Сбросить</button>
                        </div>
                    </form>
                </div>
            </div>
            
            <!-- Tabs -->
            <ul class="nav nav-tabs mb-3" id="favoriteTabs" role="tablist">
                <li class="nav-item" role="presentation">
                    <button class="nav-link active" id="all-tab" data-bs-toggle="tab" data-bs-target="#all" 
                            type="button" role="tab" aria-controls="all" aria-selected="true" data-type="all">
                        Все
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link" id="photo-tab" data-bs-toggle="tab" data-bs-target="#photo" 
                            type="button" role="tab" aria-controls="photo" aria-selected="false" data-type="photo">
                        Фотографии
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link" id="album-tab" data-bs-toggle="tab" data-bs-target="#album" 
                            type="button" role="tab" aria-controls="album" aria-selected="false" data-type="album">
                        Альбомы
                    </button>
                </li>
                <li class="nav-item" role="presentation">
                    <button class="nav-link" id="commercial-tab" data-bs-toggle="tab" data-bs-target="#commercial" 
                            type="button" role="tab" aria-controls="commercial" aria-selected="false" data-type="commercial">
                        Коммерческие посты
                    </button>
                </li>
            </ul>
            
            <!-- Tab Content -->
            <div class="tab-content" id="favoriteTabContent">
                <div class="tab-pane fade show active" id="all" role="tabpanel" aria-labelledby="all-tab">
                    <div class="card">
                        <div class="card-body">
                            <div class="table-responsive">
                                <table id="favoritesTable" class="table table-striped table-hover">
                                    <thead>
                                        <tr>
                                            <th>ID</th>
                                            <th>Пользователь</th>
                                            <th>Тип</th>
                                            <th>Контент</th>
                                            <th>Локация</th>
                                            <th>Дата добавления</th>
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
                </div>
                
                <div class="tab-pane fade" id="photo" role="tabpanel" aria-labelledby="photo-tab">
                    <div class="card">
                        <div class="card-body">
                            <div class="table-responsive">
                                <table id="photoFavoritesTable" class="table table-striped table-hover">
                                    <thead>
                                        <tr>
                                            <th>ID</th>
                                            <th>Пользователь</th>
                                            <th>Фотография</th>
                                            <th>Локация</th>
                                            <th>Дата добавления</th>
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
                </div>
                
                <div class="tab-pane fade" id="album" role="tabpanel" aria-labelledby="album-tab">
                    <div class="card">
                        <div class="card-body">
                            <div class="table-responsive">
                                <table id="albumFavoritesTable" class="table table-striped table-hover">
                                    <thead>
                                        <tr>
                                            <th>ID</th>
                                            <th>Пользователь</th>
                                            <th>Альбом</th>
                                            <th>Дата добавления</th>
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
                </div>
                
                <div class="tab-pane fade" id="commercial" role="tabpanel" aria-labelledby="commercial-tab">
                    <div class="card">
                        <div class="card-body">
                            <div class="table-responsive">
                                <table id="commercialFavoritesTable" class="table table-striped table-hover">
                                    <thead>
                                        <tr>
                                            <th>ID</th>
                                            <th>Пользователь</th>
                                            <th>Коммерческий пост</th>
                                            <th>Локация</th>
                                            <th>Дата добавления</th>
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
                </div>
            </div>
        </main>
    </div>
</div>

<?php include '../includes/footer.php'; ?>

<script src="../assets/js/favorites.js"></script>
