<?php
require_once '../config/admin_config.php';
adminRequireAuth();

$pageTitle = 'Управление публикациями';
include '../includes/header.php';
?>

<div class="container-fluid">
    <div class="row">
        <?php include '../includes/sidebar.php'; ?>
        
        <main class="col-12 px-3 px-md-4">
            <div class="d-flex justify-content-between align-items-center mb-4 pt-3">
                <h2><i class="fas fa-images me-2"></i>Управление публикациями</h2>
            </div>

    <!-- Tabs -->
    <ul class="nav nav-tabs mb-4" id="postsTabs" role="tablist">
        <li class="nav-item" role="presentation">
            <button class="nav-link active" id="posts-tab" data-bs-toggle="tab" data-bs-target="#posts" type="button" role="tab">
                <i class="fas fa-image me-2"></i>Посты
            </button>
        </li>
        <li class="nav-item" role="presentation">
            <button class="nav-link" id="albums-tab" data-bs-toggle="tab" data-bs-target="#albums" type="button" role="tab">
                <i class="fas fa-folder me-2"></i>Альбомы
            </button>
        </li>
        <li class="nav-item" role="presentation">
            <button class="nav-link" id="commercial-tab" data-bs-toggle="tab" data-bs-target="#commercial" type="button" role="tab">
                <i class="fas fa-ad me-2"></i>Коммерческие посты
            </button>
        </li>
    </ul>

    <!-- Tab Content -->
    <div class="tab-content" id="postsTabContent">
        <!-- Posts Tab -->
        <div class="tab-pane fade show active" id="posts" role="tabpanel">
            <div class="card">
                <div class="card-header">
                    <div class="row">
                        <div class="col-md-6">
                            <input type="text" class="form-control" id="postsSearch" placeholder="Поиск по названию, имени пользователя...">
                        </div>
                    </div>
                </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-hover" id="postsTable" style="width: 100%;">
                            <thead>
                                <tr>
                                    <th style="width: 80px;">Превью</th>
                                    <th>Заголовок</th>
                                    <th style="width: 200px;">Автор</th>
                                    <th style="width: 150px;">Локация</th>
                                    <th style="width: 120px;">Статистика</th>
                                    <th style="width: 140px;">Дата</th>
                                    <th style="width: 80px;">Действия</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>

        <!-- Albums Tab -->
        <div class="tab-pane fade" id="albums" role="tabpanel">
            <div class="card">
                <div class="card-header">
                    <div class="row">
                        <div class="col-md-6">
                            <input type="text" class="form-control" id="albumsSearch" placeholder="Поиск по названию альбома, имени пользователя...">
                        </div>
                    </div>
                </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-hover" id="albumsTable" style="width: 100%;">
                            <thead>
                                <tr>
                                    <th style="width: 80px;">Обложка</th>
                                    <th>Название</th>
                                    <th style="width: 200px;">Владелец</th>
                                    <th style="width: 70px;">Фото</th>
                                    <th style="width: 120px;">Статистика</th>
                                    <th style="width: 140px;">Дата</th>
                                    <th style="width: 110px;">Действия</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>
        </div>

        <!-- Commercial Posts Tab -->
        <div class="tab-pane fade" id="commercial" role="tabpanel">
            <div class="card">
                <div class="card-header">
                    <div class="row">
                        <div class="col-md-6">
                            <input type="text" class="form-control" id="commercialSearch" placeholder="Поиск по названию, имени пользователя...">
                        </div>
                        <div class="col-md-3">
                            <select class="form-select" id="commercialTypeFilter">
                                <option value="">Все типы</option>
                                <option value="album">Альбом</option>
                                <option value="photo">Фото</option>
                                <option value="standalone">Отдельный</option>
                            </select>
                        </div>
                    </div>
                </div>
                <div class="card-body">
                    <div class="table-responsive">
                        <table class="table table-hover" id="commercialTable" style="width: 100%;">
                            <thead>
                                <tr>
                                    <th style="width: 80px;">Превью</th>
                                    <th>Заголовок</th>
                                    <th style="width: 200px;">Автор</th>
                                    <th style="width: 120px;">Тип</th>
                                    <th style="width: 100px;">Статус</th>
                                    <th style="width: 140px;">Дата</th>
                                    <th style="width: 110px;">Действия</th>
                                </tr>
                            </thead>
                            <tbody></tbody>
                        </table>
                    </div>
                </div>
            </div>
            </div>
        </div>
        </main>
    </div>
</div>

<!-- Album Photos Modal -->
<div class="modal fade" id="albumPhotosModal" tabindex="-1">
    <div class="modal-dialog modal-xl">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title">Фотографии альбома</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body">
                <div id="albumPhotosContent">
                    <div class="text-center">
                        <div class="spinner-border" role="status"></div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Post Details Modal -->
<div class="modal fade" id="postDetailsModal" tabindex="-1" aria-labelledby="postDetailsTitle">
    <div class="modal-dialog modal-xl modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="postDetailsTitle">Детали публикации</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
            </div>
            <div class="modal-body">
                <div id="postDetailsContent">
                    <div class="text-center py-5">
                        <div class="spinner-border" role="status">
                            <span class="visually-hidden">Загрузка...</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Image Preview Modal -->
<div class="modal fade" id="imagePreviewModal" tabindex="-1">
    <div class="modal-dialog modal-xl modal-dialog-centered">
        <div class="modal-content bg-dark">
            <div class="modal-header border-0">
                <h5 class="modal-title text-white" id="imagePreviewTitle">Просмотр изображения</h5>
                <button type="button" class="btn-close btn-close-white" data-bs-dismiss="modal"></button>
            </div>
            <div class="modal-body text-center p-0">
                <img id="imagePreviewImg" src="" alt="Preview" style="max-width: 100%; max-height: 80vh; object-fit: contain;">
            </div>
            <div class="modal-footer border-0 justify-content-center" id="imagePreviewInfo">
                <!-- Информация об изображении будет добавлена динамически -->
            </div>
        </div>
    </div>
</div>

<?php include '../includes/footer.php'; ?>

<script src="../assets/js/posts.js?v=<?php echo time(); ?>"></script>
