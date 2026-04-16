<?php
require_once __DIR__ . '/../config/admin_config.php';
adminRequireAuth();

$pageTitle = 'Модерация контента';
?>
<?php include __DIR__ . '/../includes/header.php'; ?>
<?php include __DIR__ . '/../includes/sidebar.php'; ?>

<div id="content">
    <div class="page-header">
        <h1><i class="bi bi-shield-check"></i> Модерация контента</h1>
        <nav aria-label="breadcrumb">
            <ol class="breadcrumb">
                <li class="breadcrumb-item"><a href="../index.php">Главная</a></li>
                <li class="breadcrumb-item active" aria-current="page">Модерация</li>
            </ol>
        </nav>
        <div class="page-actions">
            <button type="button" class="btn btn-danger" id="bulkDeleteBtn" disabled>
                <i class="bi bi-trash"></i> Удалить выбранные (<span id="selectedCount">0</span>)
            </button>
        </div>
    </div>
    
    <!-- Tabs -->
    <ul class="nav nav-tabs mb-4" id="moderationTabs" role="tablist">
        <li class="nav-item" role="presentation">
            <button class="nav-link active" id="photos-tab" data-bs-toggle="tab" data-bs-target="#photos" type="button" role="tab">
                <i class="bi bi-images"></i> Фотографии <span id="photosCount" class="badge bg-secondary">0</span>
            </button>
        </li>
        <li class="nav-item" role="presentation">
            <button class="nav-link" id="comments-tab" data-bs-toggle="tab" data-bs-target="#comments" type="button" role="tab">
                <i class="bi bi-chat-dots"></i> Комментарии <span id="commentsCount" class="badge bg-secondary">0</span>
            </button>
        </li>

    </ul>
    
    <div class="tab-content" id="moderationTabsContent">
        <!-- Photos Tab -->
        <div class="tab-pane fade show active" id="photos" role="tabpanel">
            <!-- Filters -->
            <div class="card mb-4">
                <div class="card-header">
                    <i class="bi bi-funnel"></i> Фильтры
                </div>
                <div class="card-body">
                    <div class="row g-3">
                        <div class="col-md-5">
                            <label for="filterUser" class="form-label">Поиск</label>
                            <input type="text" class="form-control" id="filterUser" placeholder="Имя пользователя, название или описание...">
                        </div>
                        <div class="col-md-3">
                            <label for="filterDateFrom" class="form-label">Дата от</label>
                            <input type="date" class="form-control" id="filterDateFrom">
                        </div>
                        <div class="col-md-3">
                            <label for="filterDateTo" class="form-label">Дата до</label>
                            <input type="date" class="form-control" id="filterDateTo">
                        </div>
                        <div class="col-md-1 d-flex align-items-end">
                            <button type="button" class="btn btn-secondary w-100" id="resetFilters" title="Сбросить фильтры">
                                <i class="bi bi-x-circle"></i>
                            </button>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Photo Gallery -->
            <div class="card">
                <div class="card-header">
                    <i class="bi bi-images"></i> Галерея фотографий
                </div>
                <div class="card-body">
                    <div class="mb-3">
                        <div class="form-check">
                            <input class="form-check-input" type="checkbox" id="selectAll">
                            <label class="form-check-label" for="selectAll">
                                Выбрать все на странице
                            </label>
                        </div>
                    </div>
                    
                    <div id="photoGallery" class="row g-3">
                        <!-- Photos will be loaded here -->
                    </div>
                    
                    <div id="loadingSpinner" class="text-center py-5">
                        <div class="spinner-border text-primary" role="status">
                            <span class="visually-hidden">Загрузка...</span>
                        </div>
                    </div>
                    
                    <div id="noPhotos" class="text-center py-5" style="display: none;">
                        <p class="text-muted">Фотографии не найдены</p>
                    </div>
                    
                    <!-- Pagination -->
                    <nav aria-label="Photo pagination" class="mt-4">
                        <ul class="pagination justify-content-center" id="pagination">
                        </ul>
                    </nav>
                </div>
            </div>
        </div>
        
        <!-- Comments Tab -->
        <div class="tab-pane fade" id="comments" role="tabpanel">
            <!-- Comments Filters -->
            <div class="card mb-4">
                <div class="card-header">
                    <i class="bi bi-funnel"></i> Фильтры
                </div>
                <div class="card-body">
                    <div class="row g-3">
                        <div class="col-md-6">
                            <label for="filterCommentUser" class="form-label">Поиск</label>
                            <input type="text" class="form-control" id="filterCommentUser" placeholder="Имя пользователя или текст комментария...">
                        </div>
                        <div class="col-md-2">
                            <label for="filterCommentDateFrom" class="form-label">Дата от</label>
                            <input type="date" class="form-control" id="filterCommentDateFrom">
                        </div>
                        <div class="col-md-2">
                            <label for="filterCommentDateTo" class="form-label">Дата до</label>
                            <input type="date" class="form-control" id="filterCommentDateTo">
                        </div>
                        <div class="col-md-2 d-flex align-items-end">
                            <button type="button" class="btn btn-secondary w-100" id="resetCommentFilters" title="Сбросить фильтры">
                                <i class="bi bi-x-circle"></i> Сбросить
                            </button>
                        </div>
                    </div>
                </div>
            </div>
            
            <!-- Comments List -->
            <div class="card">
                <div class="card-header">
                    <i class="bi bi-chat-dots"></i> Список комментариев
                </div>
                <div class="card-body">
                    <div id="commentsList">
                        <!-- Comments will be loaded here -->
                    </div>
                    
                    <div id="loadingCommentsSpinner" class="text-center py-5">
                        <div class="spinner-border text-primary" role="status">
                            <span class="visually-hidden">Загрузка...</span>
                        </div>
                    </div>
                    
                    <div id="noComments" class="text-center py-5" style="display: none;">
                        <p class="text-muted">Комментарии не найдены</p>
                    </div>
                    
                    <!-- Pagination -->
                    <nav aria-label="Comments pagination" class="mt-4">
                        <ul class="pagination justify-content-center" id="commentsPagination">
                        </ul>
                    </nav>
                </div>
            </div>
        </div>
    </div>
</div>

<!-- Photo Preview Modal -->
<div class="modal fade" id="photoPreviewModal" tabindex="-1" aria-labelledby="photoPreviewTitle">
    <div class="modal-dialog modal-lg modal-dialog-centered">
        <div class="modal-content">
            <div class="modal-header">
                <h5 class="modal-title" id="photoPreviewTitle">Просмотр фотографии</h5>
                <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Закрыть"></button>
            </div>
            <div class="modal-body text-center">
                <img id="photoPreviewImage" src="" alt="Photo preview" class="img-fluid" style="max-height: 70vh;">
                <div id="photoPreviewInfo" class="mt-3 text-start">
                    <!-- Photo info will be loaded here -->
                </div>
            </div>
        </div>
    </div>
</div>

<script src="../assets/js/moderation.js?v=<?php echo time(); ?>"></script>

<?php include __DIR__ . '/../includes/footer.php'; ?>
