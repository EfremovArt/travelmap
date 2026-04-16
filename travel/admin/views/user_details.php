<?php
$pageTitle = 'Детали пользователя';
require_once '../config/admin_config.php';
adminRequireAuth();

$userId = isset($_GET['id']) ? intval($_GET['id']) : 0;
if ($userId <= 0) {
    header('Location: users.php');
    exit;
}

// Определяем откуда пришли для правильного возврата
$from = isset($_GET['from']) ? $_GET['from'] : '';
$backUrl = 'users.php';
$backText = 'Назад к списку';

if ($from === 'moderation') {
    $backUrl = 'moderation.php#comments';
    $backText = 'Назад к модерации';
}

include '../includes/header.php';
include '../includes/sidebar.php';
?>
<style>
        .preview-image {
            transition: transform 0.2s, box-shadow 0.2s;
        }
        .preview-image:hover {
            transform: scale(1.05);
            box-shadow: 0 4px 8px rgba(0,0,0,0.2);
        }
        #modalImage {
            max-width: 100%;
            height: auto;
        }
        
        /* Общие правила для предотвращения горизонтального скролла */
        body {
            overflow-x: hidden;
        }
        
        .container-fluid {
            overflow-x: hidden;
        }
        
        /* Перенос длинных слов и текста */
        .card-body,
        .table td,
        .table th,
        small,
        p,
        h6 {
            word-wrap: break-word;
            word-break: break-word;
            overflow-wrap: break-word;
            hyphens: auto;
        }
        
        /* Адаптивность для мобильных устройств */
        @media (max-width: 768px) {
            /* Уменьшаем отступы на мобильных */
            main.col-12 {
                padding-left: 0.5rem !important;
                padding-right: 0.5rem !important;
            }
            
            /* Карточки без лишних отступов */
            .card {
                margin-bottom: 0.5rem;
            }
            
            .card-body {
                padding: 0.75rem;
            }
            
            /* Аватар пользователя */
            #userAvatar {
                max-width: 100px !important;
            }
            
            /* Таблица с информацией */
            .table th {
                width: 120px !important;
                font-size: 0.875rem;
            }
            
            .table td {
                font-size: 0.875rem;
            }
            
            /* Карточки статистики */
            .row.mb-4 .col-md-3 {
                margin-bottom: 0.5rem;
            }
            
            .card-body h3 {
                font-size: 1.5rem;
            }
            
            .card-body p {
                font-size: 0.875rem;
            }
            
            /* Вкладки */
            .nav-tabs {
                flex-wrap: nowrap;
                overflow-x: auto;
                overflow-y: hidden;
                -webkit-overflow-scrolling: touch;
                scrollbar-width: thin;
            }
            
            .nav-tabs .nav-link {
                white-space: nowrap;
                font-size: 0.875rem;
                padding: 0.5rem 0.75rem;
            }
            
            .nav-tabs .badge {
                font-size: 0.7rem;
            }
            
            /* Подвкладки (pills) */
            .nav-pills .nav-link {
                font-size: 0.875rem;
                padding: 0.4rem 0.6rem;
            }
            
            /* Посты и альбомы */
            .border.rounded {
                margin-bottom: 0.5rem;
                padding: 0.5rem !important;
            }
            
            .border.rounded img {
                width: 80px !important;
                height: 80px !important;
                flex-shrink: 0;
            }
            
            .border.rounded h6 {
                font-size: 0.85rem;
                margin-bottom: 0.25rem;
                line-height: 1.2;
            }
            
            .border.rounded small {
                font-size: 0.7rem;
                line-height: 1.3;
                display: block;
            }
            
            .border.rounded .flex-grow-1 {
                min-width: 0;
                overflow: hidden;
            }
            
            /* Кнопки */
            .btn-sm {
                font-size: 0.75rem;
                padding: 0.25rem 0.5rem;
            }
            
            /* Списки пользователей */
            .d-flex.align-items-center {
                flex-wrap: wrap;
            }
            
            .d-flex.align-items-center img.rounded-circle {
                width: 40px !important;
                height: 40px !important;
                flex-shrink: 0;
            }
            
            .d-flex.align-items-center .flex-grow-1 {
                min-width: 0;
                flex: 1;
            }
            
            .d-flex.align-items-center h6,
            .d-flex.align-items-center small {
                overflow: hidden;
                text-overflow: ellipsis;
            }
            
            /* Комментарии и лайки */
            .border-bottom {
                padding: 0.5rem !important;
            }
            
            .border-bottom img {
                width: 50px !important;
                height: 50px !important;
                flex-shrink: 0;
            }
            
            .border-bottom .flex-grow-1 {
                min-width: 0;
                overflow: hidden;
            }
            
            /* Модальное окно */
            .modal-dialog {
                margin: 0.5rem;
            }
            
            #modalImage {
                max-height: 70vh !important;
            }
        }
        
        @media (max-width: 576px) {
            /* Еще меньше для очень маленьких экранов */
            .card-body h3 {
                font-size: 1.1rem;
            }
            
            .card-body p {
                font-size: 0.75rem;
            }
            
            .nav-tabs .nav-link {
                font-size: 0.7rem;
                padding: 0.35rem 0.4rem;
            }
            
            .nav-tabs .badge {
                font-size: 0.65rem;
                padding: 0.15rem 0.3rem;
            }
            
            .border.rounded {
                padding: 0.5rem !important;
                margin-bottom: 0.5rem;
            }
            
            .border.rounded img {
                width: 60px !important;
                height: 60px !important;
            }
            
            .border.rounded h6 {
                font-size: 0.8rem;
            }
            
            .border.rounded small {
                font-size: 0.65rem;
            }
            
            /* Кнопки компактнее */
            .border.rounded .d-flex > div {
                display: flex;
                flex-direction: column;
                gap: 0.25rem;
            }
            
            .border.rounded .d-flex button,
            .border.rounded .d-flex a {
                font-size: 0.7rem;
                padding: 0.25rem 0.4rem;
                white-space: nowrap;
            }
            
            /* Списки пользователей */
            .d-flex.align-items-center {
                padding: 0.5rem 0 !important;
            }
            
            .d-flex.align-items-center h6 {
                font-size: 0.85rem;
                margin-bottom: 0.1rem;
            }
            
            .d-flex.align-items-center small {
                font-size: 0.7rem;
            }
            
            /* Комментарии */
            .border-bottom p {
                font-size: 0.8rem;
                margin-bottom: 0.25rem;
            }
            
            .border-bottom small {
                font-size: 0.65rem;
            }
        }
        
        /* Горизонтальная прокрутка для вкладок */
        .nav-tabs::-webkit-scrollbar {
            height: 4px;
        }
        
        .nav-tabs::-webkit-scrollbar-track {
            background: #f1f1f1;
        }
        
        .nav-tabs::-webkit-scrollbar-thumb {
            background: #888;
            border-radius: 4px;
        }
        
        .nav-tabs::-webkit-scrollbar-thumb:hover {
            background: #555;
        }
        
        /* Дополнительные правила для мобильных */
        @media (max-width: 768px) {
            /* Заголовок страницы */
            .h2 {
                font-size: 1.25rem;
            }
            
            /* Кнопка "Назад" */
            .btn-secondary {
                font-size: 0.8rem;
                padding: 0.375rem 0.75rem;
            }
            
            /* Карточка с информацией */
            .card-header h5 {
                font-size: 1rem;
            }
            
            /* Таблица */
            .table-borderless {
                font-size: 0.85rem;
            }
            
            .table-borderless th {
                padding: 0.25rem 0.5rem;
            }
            
            .table-borderless td {
                padding: 0.25rem 0.5rem;
            }
            
            /* Бейджи на вкладках */
            .badge {
                font-size: 0.7rem;
            }
            
            /* Контент вкладок */
            .tab-content {
                font-size: 0.875rem;
            }
            
            /* Подвкладки (pills) */
            .nav-pills {
                flex-wrap: nowrap;
                overflow-x: auto;
            }
        }
    </style>

<main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
<div class="container-fluid">
                <div class="d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3 border-bottom">
                    <h1 class="h2">Детали пользователя</h1>
                    <a href="<?php echo htmlspecialchars($backUrl); ?>" class="btn btn-secondary">
                        <i class="bi bi-arrow-left"></i> <?php echo htmlspecialchars($backText); ?>
                    </a>
                </div>
                
                <div id="loadingSpinner" class="text-center my-5">
                    <div class="spinner-border" role="status">
                        <span class="visually-hidden">Загрузка...</span>
                    </div>
                </div>
                
                <div id="userContent" style="display: none;">
                    <!-- User Info Card -->
                    <div class="card mb-4">
                        <div class="card-header">
                            <h5 class="mb-0">Информация о пользователе</h5>
                        </div>
                        <div class="card-body">
                            <div class="row">
                                <div class="col-md-3 col-12 text-center mb-3 mb-md-0">
                                    <img id="userAvatar" src="" alt="Avatar" class="img-fluid rounded-circle" style="max-width: 150px;">
                                </div>
                                <div class="col-md-9 col-12">
                                    <table class="table table-borderless">
                                        <tr>
                                            <th width="200">ID:</th>
                                            <td id="userId"></td>
                                        </tr>
                                        <tr>
                                            <th>Имя:</th>
                                            <td id="userName"></td>
                                        </tr>
                                        <tr>
                                            <th>Метод авторизации:</th>
                                            <td id="authMethod"></td>
                                        </tr>
                                        <tr id="emailRow" style="display: none;">
                                            <th>Email:</th>
                                            <td id="userEmail"></td>
                                        </tr>
                                        <tr id="appleIdRow" style="display: none;">
                                            <th>Apple ID:</th>
                                            <td id="userAppleId"></td>
                                        </tr>
                                        <tr id="phoneRow" style="display: none;">
                                            <th>Телефон:</th>
                                            <td id="userPhone"></td>
                                        </tr>
                                        <tr id="birthDateRow" style="display: none;">
                                            <th>Дата рождения:</th>
                                            <td id="userBirthDate"></td>
                                        </tr>
                                        <tr>
                                            <th>Дата регистрации:</th>
                                            <td id="userCreatedAt"></td>
                                        </tr>
                                    </table>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <!-- Statistics Cards -->
                    <div class="row mb-4 g-2">
                        <div class="col-md-3 col-6">
                            <div class="card text-center">
                                <div class="card-body py-2">
                                    <h3 id="followersCount" class="text-primary mb-1">0</h3>
                                    <p class="mb-0 small">Подписчики</p>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3 col-6">
                            <div class="card text-center">
                                <div class="card-body py-2">
                                    <h3 id="followingCount" class="text-info mb-1">0</h3>
                                    <p class="mb-0 small">Подписки</p>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3 col-6">
                            <div class="card text-center">
                                <div class="card-body py-2">
                                    <h3 id="postsCount" class="text-success mb-1">0</h3>
                                    <p class="mb-0 small">Посты</p>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3 col-6">
                            <div class="card text-center">
                                <div class="card-body py-2">
                                    <h3 id="likesGiven" class="text-danger mb-1">0</h3>
                                    <p class="mb-0 small">Лайки</p>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3 col-6">
                            <div class="card text-center">
                                <div class="card-body py-2">
                                    <h3 id="commentsGiven" class="text-warning mb-1">0</h3>
                                    <p class="mb-0 small">Комментарии</p>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3 col-6">
                            <div class="card text-center">
                                <div class="card-body py-2">
                                    <h3 id="favoritesCount" class="text-secondary mb-1">0</h3>
                                    <p class="mb-0 small">Избранное</p>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3 col-6">
                            <div class="card text-center">
                                <div class="card-body py-2">
                                    <h3 id="albumsCount" class="text-primary mb-1">0</h3>
                                    <p class="mb-0 small">Альбомы</p>
                                </div>
                            </div>
                        </div>
                        <div class="col-md-3 col-6">
                            <div class="card text-center">
                                <div class="card-body py-2">
                                    <h3 id="commercialPostsCount" class="text-info mb-1">0</h3>
                                    <p class="mb-0 small">Коммерч. посты</p>
                                </div>
                            </div>
                        </div>
                    </div>
                    
                    <!-- Tabs -->
                    <ul class="nav nav-tabs" id="userTabs" role="tablist">
                        <li class="nav-item" role="presentation">
                            <button class="nav-link active" id="posts-tab" data-bs-toggle="tab" data-bs-target="#posts" type="button">
                                Посты <span id="postsTabCount" class="badge bg-secondary">0</span>
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link" id="albums-tab" data-bs-toggle="tab" data-bs-target="#albums" type="button">
                                Альбомы <span id="albumsTabCount" class="badge bg-secondary">0</span>
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link" id="commercial-tab" data-bs-toggle="tab" data-bs-target="#commercial" type="button">
                                Платные посты <span id="commercialTabCount" class="badge bg-warning text-dark">0</span>
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link" id="followers-tab" data-bs-toggle="tab" data-bs-target="#followers" type="button">
                                Подписчики <span id="followersTabCount" class="badge bg-secondary">0</span>
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link" id="following-tab" data-bs-toggle="tab" data-bs-target="#following" type="button">
                                Подписки <span id="followingTabCount" class="badge bg-secondary">0</span>
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link" id="likes-tab" data-bs-toggle="tab" data-bs-target="#likes" type="button">
                                Лайки <span id="likesTabCount" class="badge bg-secondary">0</span>
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link" id="comments-tab" data-bs-toggle="tab" data-bs-target="#comments" type="button">
                                Комментарии <span id="commentsTabCount" class="badge bg-secondary">0</span>
                            </button>
                        </li>
                        <li class="nav-item" role="presentation">
                            <button class="nav-link" id="favorites-tab" data-bs-toggle="tab" data-bs-target="#favorites" type="button">
                                Избранное <span id="favoritesTabCount" class="badge bg-secondary">0</span>
                            </button>
                        </li>
                    </ul>
                    
                    <div class="tab-content" id="userTabsContent">
                        <div class="tab-pane fade show active" id="posts" role="tabpanel">
                            <div class="card">
                                <div class="card-body">
                                    <div id="postsList"></div>
                                </div>
                            </div>
                        </div>
                        <div class="tab-pane fade" id="albums" role="tabpanel">
                            <div class="card">
                                <div class="card-body">
                                    <div id="albumsList"></div>
                                </div>
                            </div>
                        </div>
                        <div class="tab-pane fade" id="commercial" role="tabpanel">
                            <div class="card">
                                <div class="card-body">
                                    <div id="commercialPostsList"></div>
                                </div>
                            </div>
                        </div>
                        <div class="tab-pane fade" id="followers" role="tabpanel">
                            <div class="card">
                                <div class="card-body">
                                    <div id="followersList"></div>
                                </div>
                            </div>
                        </div>
                        <div class="tab-pane fade" id="following" role="tabpanel">
                            <div class="card">
                                <div class="card-body">
                                    <div id="followingList"></div>
                                </div>
                            </div>
                        </div>
                        <div class="tab-pane fade" id="likes" role="tabpanel">
                            <div class="card">
                                <div class="card-body">
                                    <ul class="nav nav-pills mb-3">
                                        <li class="nav-item">
                                            <button class="nav-link active" data-bs-toggle="pill" data-bs-target="#likes-given">
                                                Поставленные
                                            </button>
                                        </li>
                                        <li class="nav-item">
                                            <button class="nav-link" data-bs-toggle="pill" data-bs-target="#likes-received">
                                                Полученные
                                            </button>
                                        </li>
                                    </ul>
                                    <div class="tab-content">
                                        <div class="tab-pane fade show active" id="likes-given">
                                            <div id="likedPostsList"></div>
                                        </div>
                                        <div class="tab-pane fade" id="likes-received">
                                            <div id="postsLikedByOthersList"></div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="tab-pane fade" id="comments" role="tabpanel">
                            <div class="card">
                                <div class="card-body">
                                    <ul class="nav nav-pills mb-3">
                                        <li class="nav-item">
                                            <button class="nav-link active" data-bs-toggle="pill" data-bs-target="#comments-given">
                                                Написанные
                                            </button>
                                        </li>
                                        <li class="nav-item">
                                            <button class="nav-link" data-bs-toggle="pill" data-bs-target="#comments-received">
                                                Полученные
                                            </button>
                                        </li>
                                    </ul>
                                    <div class="tab-content">
                                        <div class="tab-pane fade show active" id="comments-given">
                                            <div id="userCommentsList"></div>
                                        </div>
                                        <div class="tab-pane fade" id="comments-received">
                                            <div id="commentsOnUserPostsList"></div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                        </div>
                        <div class="tab-pane fade" id="favorites" role="tabpanel">
                            <div class="card">
                                <div class="card-body">
                                    <div id="favoritesList"></div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>
                
                <div id="errorMessage" class="alert alert-danger" style="display: none;"></div>
            </main>
        </div>
    </div>
    
    <!-- Image Preview Modal -->
    <div class="modal fade" id="imageModal" tabindex="-1" aria-labelledby="imageModalLabel" aria-hidden="true">
        <div class="modal-dialog modal-dialog-centered modal-xl">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title" id="imageModalLabel">Просмотр изображения</h5>
                    <button type="button" class="btn-close" data-bs-dismiss="modal" aria-label="Close"></button>
                </div>
                <div class="modal-body text-center">
                    <img id="modalImage" src="" alt="Preview" class="img-fluid" style="max-height: 80vh;">
                </div>
            </div>
        </div>
    </div>
    
    <script>
        // Define userId globally
        const userId = <?php echo $userId; ?>;
        
        // Save and restore active tab
        document.addEventListener('DOMContentLoaded', function() {
            // Restore active tab
            const savedTab = localStorage.getItem('userDetailsActiveTab_' + userId);
            if (savedTab) {
                const tabButton = document.querySelector(`#${savedTab}-tab`);
                if (tabButton) {
                    const tab = new bootstrap.Tab(tabButton);
                    tab.show();
                }
            }
            
            // Save active tab on change
            document.querySelectorAll('#userTabs button[data-bs-toggle="tab"]').forEach(button => {
                button.addEventListener('shown.bs.tab', function(e) {
                    const tabId = e.target.id.replace('-tab', '');
                    localStorage.setItem('userDetailsActiveTab_' + userId, tabId);
                });
            });
        });
        
        // Function to show image in modal
        function showImageModal(imageSrc, title) {
            title = title || 'Просмотр изображения';
            if (typeof jQuery !== 'undefined') {
                jQuery('#modalImage').attr('src', imageSrc);
                jQuery('#imageModalLabel').text(title);
                const modal = new bootstrap.Modal(document.getElementById('imageModal'));
                modal.show();
            }
        }
        
        function loadUserDetails() {
            if (typeof jQuery === 'undefined') {
                setTimeout(loadUserDetails, 50);
                return;
            }
            
            jQuery.ajax({
                url: '../api/users/get_user_details.php',
                type: 'GET',
                data: { user_id: userId },
                dataType: 'json',
                success: function(response) {
                    if (response.success) {
                        displayUserDetails(response);
                    } else {
                        showError(response.message || 'Ошибка загрузки данных');
                    }
                },
                error: function(xhr) {
                    showError('Ошибка при загрузке данных пользователя');
                    console.error(xhr);
                }
            });
        }
        
        // Wait for jQuery to load from footer.php
        document.addEventListener('DOMContentLoaded', function() {
            function initUserDetails() {
                if (typeof jQuery === 'undefined') {
                    setTimeout(initUserDetails, 50);
                    return;
                }
                
                // Add click handler for images (delegated event)
                jQuery(document).on('click', '.preview-image', function(e) {
                    e.preventDefault();
                    const src = jQuery(this).attr('src') || jQuery(this).data('src');
                    const title = jQuery(this).attr('alt') || 'Просмотр изображения';
                    showImageModal(src, title);
                });
                
                // Handle image load errors - replace with placeholder
                jQuery(document).on('error', 'img', function() {
                    if (jQuery(this).attr('src') !== '/travel/admin/assets/images/default-avatar.svg') {
                        jQuery(this).attr('src', '/travel/admin/assets/images/default-avatar.svg');
                    }
                });
                
                // Load user details
                loadUserDetails();
            }
            
            initUserDetails();
        });
        
        function displayUserDetails(data) {
            const $ = jQuery;
            const user = data.user;
            const stats = data.stats;
            
            // User info
            $('#userAvatar').attr('src', user.profileImage || '/travel/admin/assets/images/default-avatar.svg');
            $('#userId').text(user.id);
            $('#userName').text(user.firstName + ' ' + user.lastName);
            
            // Определяем метод авторизации
            let authMethod = '';
            let authIcon = '';
            
            if (user.appleId) {
                authMethod = 'Apple ID';
                authIcon = '<i class="bi bi-apple"></i> ';
                $('#userAppleId').text(user.appleId);
                $('#appleIdRow').show();
            } else if (user.email && user.email.includes('@')) {
                authMethod = 'Email';
                authIcon = '<i class="bi bi-envelope"></i> ';
                $('#userEmail').text(user.email);
                $('#emailRow').show();
            } else if (user.phoneNumber) {
                authMethod = 'Телефон';
                authIcon = '<i class="bi bi-telephone"></i> ';
                $('#userPhone').text(user.phoneNumber);
                $('#phoneRow').show();
            } else if (user.email) {
                authMethod = 'Google';
                authIcon = '<i class="bi bi-google"></i> ';
                $('#userEmail').text(user.email);
                $('#emailRow').show();
            } else {
                authMethod = 'Неизвестно';
                authIcon = '<i class="bi bi-question-circle"></i> ';
            }
            
            $('#authMethod').html(authIcon + authMethod);
            
            // Дата рождения
            if (user.dateOfBirth && user.dateOfBirth !== 'null' && user.dateOfBirth !== null) {
                try {
                    const birthDate = new Date(user.dateOfBirth);
                    // Проверяем что дата валидна
                    if (!isNaN(birthDate.getTime())) {
                        const today = new Date();
                        let age = today.getFullYear() - birthDate.getFullYear();
                        const monthDiff = today.getMonth() - birthDate.getMonth();
                        if (monthDiff < 0 || (monthDiff === 0 && today.getDate() < birthDate.getDate())) {
                            age--;
                        }
                        $('#userBirthDate').html(birthDate.toLocaleDateString('ru-RU') + ' <span class="text-muted">(' + age + ' лет)</span>');
                        $('#birthDateRow').show();
                    }
                } catch (e) {
                    // Ignore invalid dates
                }
            }
            
            $('#userCreatedAt').text(new Date(user.createdAt).toLocaleString('ru-RU'));
            
            // Statistics
            $('#followersCount').text(stats.followersCount);
            $('#followingCount').text(stats.followingCount);
            $('#postsCount').text(stats.postsCount);
            $('#likesGiven').text(stats.likesGiven);
            $('#commentsGiven').text(stats.commentsGiven);
            $('#favoritesCount').text(stats.favoritesCount);
            $('#albumsCount').text(stats.albumsCount);
            $('#commercialPostsCount').text(stats.commercialPostsCount);
            
            // Tab counts
            $('#postsTabCount').text(stats.postsCount);
            $('#albumsTabCount').text(stats.albumsCount);
            $('#commercialTabCount').text(stats.commercialPostsCount);
            $('#followersTabCount').text(data.followers.length);
            $('#followingTabCount').text(data.following.length);
            $('#likesTabCount').text(data.likedPosts.length + data.postsLikedByOthers.length);
            $('#commentsTabCount').text(data.userComments.length + data.commentsOnUserPosts.length);
            $('#favoritesTabCount').text(data.userFavorites ? data.userFavorites.length : 0);
            
            // Load posts, albums and commercial posts
            loadUserPosts();
            loadUserAlbums();
            loadCommercialPosts();
            
            // Followers list
            displayUserList(data.followers, '#followersList');
            
            // Following list
            displayUserList(data.following, '#followingList');
            
            // Liked posts
            displayLikedPosts(data.likedPosts);
            
            // User comments
            displayUserComments(data.userComments);
            
            // Posts liked by others
            displayPostsLikedByOthers(data.postsLikedByOthers);
            
            // Comments on user posts
            displayCommentsOnUserPosts(data.commentsOnUserPosts);
            
            // User favorites
            displayUserFavorites(data.userFavorites);
            
            $('#loadingSpinner').hide();
            $('#userContent').show();
        }
        
        function loadUserPosts() {
            const $ = jQuery;
            $.ajax({
                url: '../api/posts/get_all_posts.php',
                type: 'GET',
                data: { user_id: userId, per_page: 100 },
                success: function(response) {
                    if (response.success) {
                        displayUserPosts(response.posts);
                    }
                },
                error: function() {
                    $('#postsList').html('<p class="text-danger">Ошибка загрузки постов</p>');
                }
            });
        }
        
        function loadUserAlbums() {
            const $ = jQuery;
            $.ajax({
                url: '../api/posts/get_all_albums.php',
                type: 'GET',
                data: { user_id: userId, per_page: 100 },
                success: function(response) {
                    if (response.success) {
                        displayUserAlbums(response.albums);
                    }
                },
                error: function() {
                    $('#albumsList').html('<p class="text-danger">Ошибка загрузки альбомов</p>');
                }
            });
        }
        
        function loadCommercialPosts() {
            const $ = jQuery;
            $.ajax({
                url: '../api/posts/get_all_commercial_posts.php',
                type: 'GET',
                data: { user_id: userId, per_page: 100 },
                success: function(response) {
                    if (response.success) {
                        displayCommercialPosts(response.commercialPosts);
                    }
                },
                error: function() {
                    $('#commercialPostsList').html('<p class="text-danger">Ошибка загрузки платных постов</p>');
                }
            });
        }
        
        function displayUserPosts(posts) {
            const $ = jQuery;
            const container = $('#postsList');
            container.empty();
            
            if (posts.length === 0) {
                container.html('<p class="text-muted">Нет постов</p>');
                return;
            }
            
            const html = posts.map(p => {
                // Filter out temp_photo paths
                let imageSrc = p.preview;
                if (!imageSrc || imageSrc.includes('temp_photo')) {
                    imageSrc = '/travel/admin/assets/images/default-avatar.svg';
                }
                
                return `
                <div class="mb-3 p-3 border rounded" data-post-id="${p.id}">
                    <div class="d-flex align-items-start">
                        <img src="${imageSrc}" 
                             alt="${p.title}" 
                             class="me-3 preview-image" 
                             style="width: 120px; height: 120px; object-fit: cover; border-radius: 8px; cursor: pointer;"
                             title="Нажмите для просмотра">
                        <div class="flex-grow-1">
                            <h6 class="mb-1">
                                <a href="#" class="text-decoration-none view-post-details" data-post-id="${p.id}" title="Просмотр деталей">
                                    ${p.title || 'Без названия'}
                                </a>
                            </h6>
                            <p class="mb-1 text-muted small">${p.description || ''}</p>
                            <small class="text-muted">
                                Локация: ${(p.location_name && p.location_name.trim() !== '') ? p.location_name : (p.latitude && p.longitude ? `📍 ${parseFloat(p.latitude).toFixed(4)}, ${parseFloat(p.longitude).toFixed(4)}` : 'Не указана')} | 
                                Лайки: ${p.likes_count} | 
                                Комментарии: ${p.comments_count} | 
                                ${new Date(p.created_at).toLocaleString('ru-RU')}
                            </small>
                        </div>
                        <div class="d-flex flex-column gap-1">
                            <button class="btn btn-sm btn-info view-post-btn" data-post-id="${p.id}" title="Просмотр">
                                <i class="bi bi-eye"></i>
                            </button>
                            <button class="btn btn-sm btn-danger delete-post" data-post-id="${p.id}" title="Удалить">
                                <i class="bi bi-trash"></i>
                            </button>
                        </div>
                    </div>
                </div>
                `;
            }).join('');
            
            container.html(html);
            
            // Add view post handlers
            $('.view-post-btn, .view-post-details').on('click', function(e) {
                e.preventDefault();
                const postId = $(this).data('post-id');
                viewPostDetails(postId);
            });
            
            // Add delete handlers
            $('.delete-post').on('click', function() {
                const postId = $(this).data('post-id');
                if (confirm('Вы уверены, что хотите удалить этот пост?')) {
                    deletePost(postId);
                }
            });
        }
        
        function displayUserAlbums(albums) {
            const $ = jQuery;
            const container = $('#albumsList');
            container.empty();
            
            if (albums.length === 0) {
                container.html('<p class="text-muted">Нет альбомов</p>');
                return;
            }
            
            const html = albums.map(a => `
                <div class="mb-3 p-3 border rounded" data-album-id="${a.id}">
                    <div class="d-flex align-items-start mb-2">
                        <img src="${a.cover_photo || '/travel/admin/assets/images/default-avatar.svg'}" 
                             alt="${a.title}" 
                             class="me-3 preview-image" 
                             style="width: 120px; height: 120px; object-fit: cover; border-radius: 8px; cursor: pointer;"
                             title="Нажмите для просмотра">
                        <div class="flex-grow-1">
                            <h6 class="mb-1">
                                <a href="#" class="text-decoration-none view-album-details" data-album-id="${a.id}" title="Просмотр альбома">
                                    ${a.title || 'Без названия'}
                                </a>
                            </h6>
                            <p class="mb-1 text-muted small">${a.description || ''}</p>
                            <small class="text-muted">
                                Фото: ${a.photos_count} | 
                                Лайки: ${a.likes_count} | 
                                Комментарии: ${a.comments_count} | 
                                ${new Date(a.created_at).toLocaleString('ru-RU')}
                            </small>
                        </div>
                        <div class="d-flex flex-column gap-1">
                            <button class="btn btn-sm btn-info view-album-btn" data-album-id="${a.id}" title="Просмотр">
                                <i class="bi bi-eye"></i>
                            </button>
                            <button class="btn btn-sm btn-primary view-album-photos" data-album-id="${a.id}" title="Фото">
                                <i class="bi bi-images"></i>
                            </button>
                            <button class="btn btn-sm btn-danger delete-album" data-album-id="${a.id}" title="Удалить">
                                <i class="bi bi-trash"></i>
                            </button>
                        </div>
                    </div>
                    <div class="album-photos-${a.id}" style="display: none;"></div>
                </div>
            `).join('');
            
            container.html(html);
            
            // Add view album handlers
            $('.view-album-btn, .view-album-details').on('click', function(e) {
                e.preventDefault();
                const albumId = $(this).data('album-id');
                viewAlbumDetails(albumId);
            });
            
            // Add handlers
            $('.view-album-photos').on('click', function() {
                const albumId = $(this).data('album-id');
                const photosContainer = $(`.album-photos-${albumId}`);
                
                if (photosContainer.is(':visible')) {
                    photosContainer.slideUp();
                    $(this).html('<i class="bi bi-images"></i>');
                } else {
                    loadAlbumPhotos(albumId);
                    $(this).html('<i class="bi bi-eye-slash"></i>');
                }
            });
            
            $('.delete-album').on('click', function() {
                const albumId = $(this).data('album-id');
                if (confirm('Вы уверены, что хотите удалить этот альбом?')) {
                    deleteAlbum(albumId);
                }
            });
        }
        
        function displayCommercialPosts(posts) {
            const $ = jQuery;
            const container = $('#commercialPostsList');
            container.empty();
            
            if (posts.length === 0) {
                container.html('<p class="text-muted">Нет платных постов</p>');
                return;
            }
            
            const typeLabels = {
                'photo': 'Фото',
                'album': 'Альбом',
                'standalone': 'Отдельный'
            };
            
            const html = posts.map(p => {
                // Filter out temp_photo paths
                let imageSrc = p.preview;
                if (!imageSrc || imageSrc.includes('temp_photo')) {
                    imageSrc = '/travel/admin/assets/images/default-avatar.svg';
                }
                
                // Format location
                let locationText = '';
                if (p.location_name && p.location_name.trim() !== '') {
                    locationText = `📍 ${p.location_name}`;
                } else if (p.latitude && p.longitude) {
                    locationText = `📍 ${parseFloat(p.latitude).toFixed(4)}, ${parseFloat(p.longitude).toFixed(4)}`;
                }
                
                return `
                <div class="mb-3 p-3 border rounded ${p.is_active == 1 ? 'border-success' : 'border-secondary'}" data-commercial-id="${p.id}">
                    <div class="d-flex align-items-start">
                        <img src="${imageSrc}" 
                             alt="${p.title}" 
                             class="me-3 preview-image" 
                             style="width: 120px; height: 120px; object-fit: cover; border-radius: 8px; cursor: pointer;"
                             title="Нажмите для просмотра">
                        <div class="flex-grow-1">
                            <div class="d-flex align-items-center mb-1">
                                <h6 class="mb-0 me-2">
                                    <a href="commercial_post_details.php?id=${p.id}" class="text-decoration-none" title="Открыть детали">
                                        ${p.title || 'Без названия'}
                                    </a>
                                </h6>
                                <span class="badge ${p.is_active == 1 ? 'bg-success' : 'bg-secondary'} me-2">
                                    ${p.is_active == 1 ? 'Активен' : 'Неактивен'}
                                </span>
                                <span class="badge bg-warning text-dark">
                                    ${typeLabels[p.type] || p.type}
                                </span>
                            </div>
                            <p class="mb-1 text-muted small">${p.description || ''}</p>
                            ${p.related_title ? `<p class="mb-1 text-info small">Связан с: "${p.related_title}"</p>` : ''}
                            <small class="text-muted">
                                ${locationText ? locationText + ' | ' : ''}
                                📅 ${new Date(p.created_at).toLocaleString('ru-RU')}
                            </small>
                        </div>
                        <div class="d-flex flex-column gap-1">
                            <a href="commercial_post_details.php?id=${p.id}" class="btn btn-sm btn-info" title="Детали">
                                <i class="bi bi-eye"></i>
                            </a>
                            <button class="btn btn-sm btn-${p.is_active == 1 ? 'warning' : 'success'} toggle-commercial-status" 
                                    data-commercial-id="${p.id}" 
                                    data-current-status="${p.is_active}"
                                    title="${p.is_active == 1 ? 'Деактивировать' : 'Активировать'}">
                                <i class="bi bi-toggle-${p.is_active == 1 ? 'on' : 'off'}"></i>
                            </button>
                            <button class="btn btn-sm btn-danger delete-commercial" data-commercial-id="${p.id}" title="Удалить">
                                <i class="bi bi-trash"></i>
                            </button>
                        </div>
                    </div>
                </div>
                `;
            }).join('');
            
            container.html(html);
            
            // Add handlers
            $('.toggle-commercial-status').on('click', function() {
                const commercialId = $(this).data('commercial-id');
                const currentStatus = $(this).data('current-status');
                const newStatus = currentStatus == 1 ? 0 : 1;
                toggleCommercialStatus(commercialId, newStatus);
            });
            
            $('.delete-commercial').on('click', function() {
                const commercialId = $(this).data('commercial-id');
                if (confirm('Вы уверены, что хотите удалить этот платный пост?')) {
                    deleteCommercialPost(commercialId);
                }
            });
        }
        
        function loadAlbumPhotos(albumId) {
            const $ = jQuery;
            const container = $(`.album-photos-${albumId}`);
            container.html('<p class="text-muted">Загрузка...</p>').slideDown();
            
            $.ajax({
                url: '../api/posts/get_album_photos.php',
                type: 'GET',
                data: { album_id: albumId },
                success: function(response) {
                    if (response.success) {
                        displayAlbumPhotos(albumId, response.photos);
                    }
                },
                error: function() {
                    container.html('<p class="text-danger">Ошибка загрузки фото</p>');
                }
            });
        }
        
        function displayAlbumPhotos(albumId, photos) {
            const $ = jQuery;
            const container = $(`.album-photos-${albumId}`);
            
            if (photos.length === 0) {
                container.html('<p class="text-muted">Нет фото в альбоме</p>');
                return;
            }
            
            const html = `
                <div class="row g-2 mt-2">
                    ${photos.map(p => `
                        <div class="col-md-3" data-album-photo-id="${p.album_photo_id}">
                            <div class="card">
                                <img src="${p.file_path || '/travel/admin/assets/images/default-avatar.svg'}" 
                                     class="card-img-top preview-image" 
                                     style="height: 150px; object-fit: cover; cursor: pointer;"
                                     alt="${p.title || 'Фото'}"
                                     title="Нажмите для просмотра">
                                <div class="card-body p-2">
                                    <small class="text-muted d-block">${p.title || 'Без названия'}</small>
                                    <button class="btn btn-sm btn-danger w-100 mt-1 delete-album-photo" 
                                            data-album-photo-id="${p.album_photo_id}">
                                        <i class="bi bi-trash"></i> Удалить
                                    </button>
                                </div>
                            </div>
                        </div>
                    `).join('')}
                </div>
            `;
            
            container.html(html);
            
            // Add delete handlers
            $('.delete-album-photo').on('click', function() {
                const albumPhotoId = $(this).data('album-photo-id');
                if (confirm('Вы уверены, что хотите удалить это фото из альбома?')) {
                    deleteAlbumPhoto(albumPhotoId, albumId);
                }
            });
        }
        
        function viewPostDetails(postId) {
            const $ = jQuery;
            $.ajax({
                url: '../api/posts/get_post_details.php',
                type: 'GET',
                data: { photo_id: postId },
                success: function(response) {
                    if (response.success) {
                        showPostDetailsModal(response.post, response.likes, response.comments);
                    } else {
                        alert('Ошибка: ' + response.message);
                    }
                },
                error: function() {
                    alert('Ошибка при загрузке деталей поста');
                }
            });
        }
        
        function viewAlbumDetails(albumId) {
            const $ = jQuery;
            $.ajax({
                url: '../api/posts/get_album_photos.php',
                type: 'GET',
                data: { album_id: albumId },
                success: function(response) {
                    if (response.success) {
                        showAlbumDetailsModal(response.album, response.photos, response.likes, response.comments);
                    } else {
                        alert('Ошибка: ' + response.message);
                    }
                },
                error: function() {
                    alert('Ошибка при загрузке деталей альбома');
                }
            });
        }
        
        function showAlbumDetailsModal(album, photos, likes, comments) {
            const $ = jQuery;
            // Подсчитываем общее количество лайков и комментариев
            const totalLikes = Object.values(likes || {}).reduce((sum, arr) => sum + arr.length, 0);
            const totalComments = Object.values(comments || {}).reduce((sum, arr) => sum + arr.length, 0);
            
            // Формируем HTML для фотографий
            const photosHtml = photos.map(p => {
                const imgSrc = p.file_path || '/travel/admin/assets/images/default-avatar.svg';
                const photoLikes = likes[p.photo_id] || [];
                const photoComments = comments[p.photo_id] || [];
                
                return `
                <div class="col-md-4 col-sm-6 mb-3">
                    <img src="${imgSrc}" 
                         class="img-fluid rounded preview-image" 
                         style="cursor: pointer; height: 200px; width: 100%; object-fit: cover;"
                         alt="${p.title || 'Фото'}"
                         title="Нажмите для просмотра">
                    <small class="d-block mt-1 text-muted">${p.title || 'Без названия'}</small>
                    <small class="d-block text-muted">
                        <i class="bi bi-heart-fill"></i> ${photoLikes.length} 
                        <i class="bi bi-chat-fill ms-2"></i> ${photoComments.length}
                    </small>
                </div>
                `;
            }).join('');
            
            // Формируем HTML для всех лайков
            const allLikes = [];
            Object.entries(likes || {}).forEach(([photoId, photoLikes]) => {
                photoLikes.forEach(like => {
                    allLikes.push({...like, photoId});
                });
            });
            allLikes.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
            
            const likesHtml = allLikes.length > 0 ? allLikes.slice(0, 50).map(like => `
                <div class="d-flex align-items-center mb-2">
                    <img src="${like.image || '/travel/admin/assets/images/default-avatar.svg'}" 
                         class="rounded-circle me-2" 
                         style="width: 32px; height: 32px; object-fit: cover;"
                         alt="${like.name}">
                    <div class="flex-grow-1">
                        <a href="user_details.php?id=${like.id}" class="text-decoration-none">
                            ${like.name}
                        </a>
                        <small class="text-muted d-block">${new Date(like.created_at).toLocaleString('ru-RU')}</small>
                    </div>
                </div>
            `).join('') : '<p class="text-muted">Нет лайков</p>';
            
            // Формируем HTML для всех комментариев
            const allComments = [];
            Object.entries(comments || {}).forEach(([photoId, photoComments]) => {
                photoComments.forEach(comment => {
                    allComments.push({...comment, photoId});
                });
            });
            allComments.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
            
            const commentsHtml = allComments.length > 0 ? allComments.slice(0, 50).map(comment => `
                <div class="d-flex align-items-start mb-3 pb-2 border-bottom">
                    <img src="${comment.user_image || '/travel/admin/assets/images/default-avatar.svg'}" 
                         class="rounded-circle me-2" 
                         style="width: 32px; height: 32px; object-fit: cover;"
                         alt="${comment.user_name}">
                    <div class="flex-grow-1">
                        <a href="user_details.php?id=${comment.user_id}" class="text-decoration-none fw-bold">
                            ${comment.user_name}
                        </a>
                        <small class="text-muted ms-2">${new Date(comment.created_at).toLocaleString('ru-RU')}</small>
                        <p class="mb-0 mt-1">${comment.text}</p>
                    </div>
                </div>
            `).join('') : '<p class="text-muted">Нет комментариев</p>';
            
            const modalHtml = `
                <div class="modal fade" id="albumDetailsModal" tabindex="-1">
                    <div class="modal-dialog modal-xl">
                        <div class="modal-content">
                            <div class="modal-header">
                                <h5 class="modal-title">${album.title || 'Без названия'}</h5>
                                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                            </div>
                            <div class="modal-body">
                                <div class="row">
                                    <div class="col-md-8">
                                        <p><strong>Описание:</strong> ${album.description || 'Нет описания'}</p>
                                        <p><strong>Владелец:</strong> ${album.owner_name || 'Неизвестно'}</p>
                                        <p><strong>Дата создания:</strong> ${new Date(album.created_at).toLocaleString('ru-RU')}</p>
                                        <p><strong>Фотографий:</strong> ${photos.length}</p>
                                        <hr>
                                        <h6>Фотографии:</h6>
                                        <div class="row">
                                            ${photosHtml || '<p class="text-muted col-12">Нет фотографий</p>'}
                                        </div>
                                    </div>
                                    <div class="col-md-4">
                                        <ul class="nav nav-tabs mb-3" role="tablist">
                                            <li class="nav-item">
                                                <a class="nav-link active" data-bs-toggle="tab" href="#albumLikesTab">
                                                    <i class="bi bi-heart-fill me-1"></i>Лайки (${totalLikes})
                                                </a>
                                            </li>
                                            <li class="nav-item">
                                                <a class="nav-link" data-bs-toggle="tab" href="#albumCommentsTab">
                                                    <i class="bi bi-chat-fill me-1"></i>Комментарии (${totalComments})
                                                </a>
                                            </li>
                                        </ul>
                                        <div class="tab-content" style="max-height: 500px; overflow-y: auto;">
                                            <div class="tab-pane fade show active" id="albumLikesTab">
                                                ${likesHtml}
                                            </div>
                                            <div class="tab-pane fade" id="albumCommentsTab">
                                                ${commentsHtml}
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <div class="modal-footer">
                                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Закрыть</button>
                            </div>
                        </div>
                    </div>
                </div>
            `;
            
            // Remove existing modal and backdrop if any
            $('#albumDetailsModal').modal('hide').remove();
            $('.modal-backdrop').remove();
            
            // Add new modal
            $('body').append(modalHtml);
            
            // Show modal after a small delay to ensure DOM is ready
            setTimeout(() => {
                $('#albumDetailsModal').modal('show');
            }, 100);
            
            // Clean up on close
            $('#albumDetailsModal').on('hidden.bs.modal', function() {
                $(this).remove();
            });
        }
        
        function showPostDetailsModal(post, likes, comments) {
            const $ = jQuery;
            // Формируем HTML для лайков
            const likesHtml = likes && likes.length > 0 ? likes.map(like => `
                <div class="d-flex align-items-center mb-2">
                    <img src="${like.image || '/travel/admin/assets/images/default-avatar.svg'}" 
                         class="rounded-circle me-2" 
                         style="width: 32px; height: 32px; object-fit: cover;"
                         alt="${like.name}">
                    <div class="flex-grow-1">
                        <a href="user_details.php?id=${like.id}" class="text-decoration-none">
                            ${like.name}
                        </a>
                        <small class="text-muted d-block">${new Date(like.created_at).toLocaleString('ru-RU')}</small>
                    </div>
                </div>
            `).join('') : '<p class="text-muted">Нет лайков</p>';
            
            // Формируем HTML для комментариев
            const commentsHtml = comments && comments.length > 0 ? comments.map(comment => `
                <div class="d-flex align-items-start mb-3 pb-2 border-bottom">
                    <img src="${comment.user_image || '/travel/admin/assets/images/default-avatar.svg'}" 
                         class="rounded-circle me-2" 
                         style="width: 32px; height: 32px; object-fit: cover;"
                         alt="${comment.user_name}">
                    <div class="flex-grow-1">
                        <a href="user_details.php?id=${comment.user_id}" class="text-decoration-none fw-bold">
                            ${comment.user_name}
                        </a>
                        <small class="text-muted ms-2">${new Date(comment.created_at).toLocaleString('ru-RU')}</small>
                        <p class="mb-0 mt-1">${comment.text}</p>
                    </div>
                </div>
            `).join('') : '<p class="text-muted">Нет комментариев</p>';
            
            const modalHtml = `
                <div class="modal fade" id="postDetailsModal" tabindex="-1">
                    <div class="modal-dialog modal-xl">
                        <div class="modal-content">
                            <div class="modal-header">
                                <h5 class="modal-title">${post.title || 'Без названия'}</h5>
                                <button type="button" class="btn-close" data-bs-dismiss="modal"></button>
                            </div>
                            <div class="modal-body">
                                <div class="row">
                                    <div class="col-md-6">
                                        <img src="${post.filePath || '/travel/admin/assets/images/default-avatar.svg'}" 
                                             class="img-fluid rounded mb-3" 
                                             alt="${post.title}">
                                        <p><strong>Описание:</strong> ${post.description || 'Нет описания'}</p>
                                        <p><strong>Локация:</strong> ${post.locationName || 'Не указана'}</p>
                                        <p><strong>Автор:</strong> ${post.authorName}</p>
                                        <p><strong>Дата создания:</strong> ${new Date(post.createdAt).toLocaleString('ru-RU')}</p>
                                    </div>
                                    <div class="col-md-6">
                                        <ul class="nav nav-tabs mb-3" role="tablist">
                                            <li class="nav-item">
                                                <a class="nav-link active" data-bs-toggle="tab" href="#likesTab">
                                                    <i class="bi bi-heart-fill me-1"></i>Лайки (${post.likesCount || 0})
                                                </a>
                                            </li>
                                            <li class="nav-item">
                                                <a class="nav-link" data-bs-toggle="tab" href="#commentsTab">
                                                    <i class="bi bi-chat-fill me-1"></i>Комментарии (${post.commentsCount || 0})
                                                </a>
                                            </li>
                                        </ul>
                                        <div class="tab-content" style="max-height: 400px; overflow-y: auto;">
                                            <div class="tab-pane fade show active" id="likesTab">
                                                ${likesHtml}
                                            </div>
                                            <div class="tab-pane fade" id="commentsTab">
                                                ${commentsHtml}
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            </div>
                            <div class="modal-footer">
                                <button type="button" class="btn btn-secondary" data-bs-dismiss="modal">Закрыть</button>
                            </div>
                        </div>
                    </div>
                </div>
            `;
            
            // Remove existing modal and backdrop if any
            $('#postDetailsModal').modal('hide').remove();
            $('.modal-backdrop').remove();
            
            // Add new modal
            $('body').append(modalHtml);
            
            // Show modal after a small delay to ensure DOM is ready
            setTimeout(() => {
                $('#postDetailsModal').modal('show');
            }, 100);
            
            // Clean up on close
            $('#postDetailsModal').on('hidden.bs.modal', function() {
                $(this).remove();
            });
        }
        
        function deletePost(postId) {
            const $ = jQuery;
            $.ajax({
                url: '../api/posts/delete_post.php',
                type: 'POST',
                data: { post_id: postId },
                success: function(response) {
                    if (response.success) {
                        $(`[data-post-id="${postId}"]`).fadeOut(300, function() {
                            $(this).remove();
                        });
                        alert('Пост успешно удален');
                        loadUserDetails(); // Reload stats
                    } else {
                        alert('Ошибка: ' + response.message);
                    }
                },
                error: function() {
                    alert('Ошибка при удалении поста');
                }
            });
        }
        
        function deleteAlbum(albumId) {
            const $ = jQuery;
            $.ajax({
                url: '../api/posts/delete_album.php',
                type: 'POST',
                data: { album_id: albumId },
                success: function(response) {
                    if (response.success) {
                        $(`[data-album-id="${albumId}"]`).fadeOut(300, function() {
                            $(this).remove();
                        });
                        alert('Альбом успешно удален');
                        loadUserDetails(); // Reload stats
                    } else {
                        alert('Ошибка: ' + response.message);
                    }
                },
                error: function() {
                    alert('Ошибка при удалении альбома');
                }
            });
        }
        
        function deleteAlbumPhoto(albumPhotoId, albumId) {
            const $ = jQuery;
            $.ajax({
                url: '../api/posts/delete_album_photo.php',
                type: 'POST',
                data: { album_photo_id: albumPhotoId },
                success: function(response) {
                    if (response.success) {
                        $(`[data-album-photo-id="${albumPhotoId}"]`).fadeOut(300, function() {
                            $(this).remove();
                        });
                        alert('Фото успешно удалено из альбома');
                        loadUserDetails(); // Reload stats
                    } else {
                        alert('Ошибка: ' + response.message);
                    }
                },
                error: function() {
                    alert('Ошибка при удалении фото');
                }
            });
        }
        
        function toggleCommercialStatus(commercialId, newStatus) {
            const $ = jQuery;
            $.ajax({
                url: '../api/posts/toggle_commercial_status.php',
                type: 'POST',
                data: { 
                    commercial_id: commercialId,
                    is_active: newStatus
                },
                success: function(response) {
                    if (response.success) {
                        alert(response.message);
                        loadCommercialPosts(); // Reload commercial posts
                        loadUserDetails(); // Reload stats
                    } else {
                        alert('Ошибка: ' + response.message);
                    }
                },
                error: function() {
                    alert('Ошибка при изменении статуса');
                }
            });
        }
        
        function deleteCommercialPost(commercialId) {
            const $ = jQuery;
            $.ajax({
                url: '../api/posts/delete_commercial_post.php',
                type: 'POST',
                data: { commercial_id: commercialId },
                success: function(response) {
                    if (response.success) {
                        $(`[data-commercial-id="${commercialId}"]`).fadeOut(300, function() {
                            $(this).remove();
                        });
                        alert('Платный пост успешно удален');
                        loadUserDetails(); // Reload stats
                    } else {
                        alert('Ошибка: ' + response.message);
                    }
                },
                error: function() {
                    alert('Ошибка при удалении платного поста');
                }
            });
        }
        
        function displayUserList(users, containerId) {
            const $ = jQuery;
            const container = $(containerId);
            container.empty();
            
            if (users.length === 0) {
                container.html('<p class="text-muted">Нет данных</p>');
                return;
            }
            
            const html = users.map(u => `
                <div class="d-flex align-items-center mb-3 p-2 border-bottom">
                    <img src="${u.profileImage || '/travel/admin/assets/images/default-avatar.svg'}" 
                         alt="${u.firstName}" 
                         class="rounded-circle me-3" 
                         style="width: 50px; height: 50px; object-fit: cover;">
                    <div class="flex-grow-1">
                        <h6 class="mb-0">
                            <a href="user_details.php?id=${u.id}">${u.firstName} ${u.lastName}</a>
                        </h6>
                        <small class="text-muted">${u.email}</small>
                    </div>
                    <small class="text-muted">${new Date(u.followedAt).toLocaleDateString('ru-RU')}</small>
                </div>
            `).join('');
            
            container.html(html);
        }

        function displayLikedPosts(posts) {
            const $ = jQuery;
            const container = $('#likedPostsList');
            container.empty();
            
            if (posts.length === 0) {
                container.html('<p class="text-muted">Нет лайкнутых постов</p>');
                return;
            }
            
            const html = posts.map(p => `
                <div class="mb-3 p-3 border-bottom">
                    <div class="d-flex align-items-start">
                        <img src="${p.filePath || '/travel/admin/assets/images/default-avatar.svg'}" 
                             alt="${p.title}" 
                             class="me-3 preview-image" 
                             style="width: 80px; height: 80px; object-fit: cover; border-radius: 8px; cursor: pointer;"
                             title="Нажмите для просмотра">
                        <div class="flex-grow-1">
                            <h6 class="mb-1">${p.title || 'Без названия'}</h6>
                            <p class="mb-1 text-muted small">${p.description || ''}</p>
                            <small class="text-muted">
                                Автор: ${p.authorName} | 
                                Локация: ${(p.locationName && p.locationName.trim() !== '') ? p.locationName : (p.latitude && p.longitude ? `📍 ${parseFloat(p.latitude).toFixed(4)}, ${parseFloat(p.longitude).toFixed(4)}` : 'Не указана')} | 
                                Лайкнуто: ${new Date(p.likedAt).toLocaleString('ru-RU')}
                            </small>
                        </div>
                    </div>
                </div>
            `).join('');
            
            container.html(html);
        }
        
        function displayUserFavorites(favorites) {
            const $ = jQuery;
            const container = $('#favoritesList');
            container.empty();
            
            if (!favorites || favorites.length === 0) {
                container.html('<p class="text-muted">Нет избранных постов</p>');
                return;
            }
            
            const html = favorites.map(f => `
                <div class="mb-3 p-3 border-bottom" data-favorite-photo-id="${f.id}">
                    <div class="d-flex align-items-start">
                        <img src="${f.filePath || '/travel/admin/assets/images/default-avatar.svg'}" 
                             alt="${f.title}" 
                             class="me-3 preview-image" 
                             style="width: 80px; height: 80px; object-fit: cover; border-radius: 8px; cursor: pointer;"
                             title="Нажмите для просмотра">
                        <div class="flex-grow-1">
                            <h6 class="mb-1">
                                <a href="#" class="text-decoration-none view-post-details" data-post-id="${f.id}" title="Просмотр деталей">
                                    ${f.title || 'Без названия'}
                                </a>
                            </h6>
                            <p class="mb-1 text-muted small">${f.description || ''}</p>
                            <small class="text-muted">
                                Автор: ${f.authorName} | 
                                Добавлено в избранное: ${new Date(f.favoritedAt).toLocaleString('ru-RU')}
                            </small>
                        </div>
                        <div class="d-flex flex-column gap-1">
                            <button class="btn btn-sm btn-info view-post-btn" data-post-id="${f.id}" title="Просмотр">
                                <i class="bi bi-eye"></i>
                            </button>
                            <button class="btn btn-sm btn-danger delete-favorite" data-photo-id="${f.id}" title="Удалить из избранного">
                                <i class="bi bi-trash"></i>
                            </button>
                        </div>
                    </div>
                </div>
            `).join('');
            
            container.html(html);
            
            // Add view post handlers
            container.find('.view-post-btn, .view-post-details').on('click', function(e) {
                e.preventDefault();
                const postId = $(this).data('post-id');
                viewPostDetails(postId);
            });
            
            // Add delete favorite handlers
            container.find('.delete-favorite').on('click', function() {
                const photoId = $(this).data('photo-id');
                if (confirm('Вы уверены, что хотите удалить этот пост из избранного?')) {
                    deleteFavorite(photoId);
                }
            });
        }
        
        function deleteFavorite(photoId) {
            const $ = jQuery;
            $.ajax({
                url: '../api/favorites/delete_favorite.php',
                type: 'POST',
                data: { 
                    user_id: userId,
                    photo_id: photoId 
                },
                success: function(response) {
                    if (response.success) {
                        $(`[data-favorite-photo-id="${photoId}"]`).fadeOut(300, function() {
                            $(this).remove();
                            // Update counter
                            const currentCount = parseInt($('#favoritesTabCount').text()) || 0;
                            $('#favoritesTabCount').text(Math.max(0, currentCount - 1));
                        });
                        alert('Пост удален из избранного');
                    } else {
                        alert('Ошибка: ' + response.message);
                    }
                },
                error: function() {
                    alert('Ошибка при удалении из избранного');
                }
            });
        }
        
        function displayUserComments(comments) {
            const $ = jQuery;
            const container = $('#userCommentsList');
            container.empty();
            
            if (comments.length === 0) {
                container.html('<p class="text-muted">Нет комментариев</p>');
                return;
            }
            
            const html = comments.map(c => {
                // Проверяем и фильтруем неправильные пути изображений
                let imageSrc = c.postImage;
                if (!imageSrc || imageSrc === 'null' || imageSrc === '/travel/temp_photo.jpg' || imageSrc.includes('temp_photo')) {
                    imageSrc = '/travel/admin/assets/images/default-avatar.svg';
                }
                
                return `
                    <div class="mb-3 p-3 border-bottom" data-comment-id="${c.id}">
                        <div class="d-flex align-items-start">
                            <img src="${imageSrc}" 
                                 alt="${c.postTitle || 'Пост'}" 
                                 class="me-3 preview-image" 
                                 style="width: 60px; height: 60px; object-fit: cover; border-radius: 8px; cursor: pointer;"
                                 title="Нажмите для просмотра"
                                 onerror="this.src='/travel/admin/assets/images/default-avatar.svg'">
                            <div class="flex-grow-1">
                                <p class="mb-1"><strong>${c.text || ''}</strong></p>
                                <small class="text-muted">
                                    К посту: "${c.postTitle || 'Без названия'}" (автор: ${c.postAuthorName || 'Неизвестен'}) | 
                                    ${new Date(c.createdAt).toLocaleString('ru-RU')}
                                </small>
                            </div>
                            <div class="d-flex flex-column gap-1">
                                <button class="btn btn-sm btn-info view-comment-post" data-post-id="${c.postId}" title="Просмотр поста">
                                    <i class="bi bi-eye"></i>
                                </button>
                                <button class="btn btn-sm btn-danger delete-comment" data-comment-id="${c.id}" title="Удалить">
                                    <i class="bi bi-trash"></i>
                                </button>
                            </div>
                        </div>
                    </div>
                `;
            }).join('');
            
            container.html(html);
            
            // Add handlers
            container.find('.view-comment-post').on('click', function() {
                const postId = $(this).data('post-id');
                viewPostDetails(postId);
            });
            
            container.find('.delete-comment').on('click', function() {
                const commentId = $(this).data('comment-id');
                if (confirm('Вы уверены, что хотите удалить этот комментарий?')) {
                    deleteComment(commentId);
                }
            });
        }
        
        function deleteComment(commentId) {
            const $ = jQuery;
            $.ajax({
                url: '../api/comments/delete_comment.php',
                type: 'POST',
                data: { comment_id: commentId },
                success: function(response) {
                    if (response.success) {
                        $(`[data-comment-id="${commentId}"]`).fadeOut(300, function() {
                            $(this).remove();
                        });
                        alert('Комментарий успешно удален');
                        loadUserDetails(); // Reload stats
                    } else {
                        alert('Ошибка: ' + response.message);
                    }
                },
                error: function() {
                    alert('Ошибка при удалении комментария');
                }
            });
        }
        
        function displayPostsLikedByOthers(posts) {
            const $ = jQuery;
            const container = $('#postsLikedByOthersList');
            container.empty();
            
            if (posts.length === 0) {
                container.html('<p class="text-muted">Никто не лайкал посты</p>');
                return;
            }
            
            const html = posts.map(p => `
                <div class="mb-3 p-3 border-bottom">
                    <div class="d-flex align-items-start">
                        <img src="${p.likerImage || '/travel/admin/assets/images/default-avatar.svg'}" 
                             alt="${p.likerName}" 
                             class="rounded-circle me-3" 
                             style="width: 50px; height: 50px; object-fit: cover;">
                        <div class="flex-grow-1">
                            <h6 class="mb-1">
                                <a href="user_details.php?id=${p.likerId}">${p.likerName}</a>
                            </h6>
                            <p class="mb-1 text-muted small">Лайкнул пост: "${p.postTitle}"</p>
                            <small class="text-muted">${new Date(p.likedAt).toLocaleString('ru-RU')}</small>
                        </div>
                        <img src="${p.postImage || '/travel/admin/assets/images/default-avatar.svg'}" 
                             alt="${p.postTitle}" 
                             class="ms-2 preview-image" 
                             style="width: 60px; height: 60px; object-fit: cover; border-radius: 8px; cursor: pointer;"
                             title="Нажмите для просмотра">
                    </div>
                </div>
            `).join('');
            
            container.html(html);
        }

        function displayCommentsOnUserPosts(comments) {
            const $ = jQuery;
            const container = $('#commentsOnUserPostsList');
            container.empty();
            
            if (comments.length === 0) {
                container.html('<p class="text-muted">Нет комментариев к постам</p>');
                return;
            }
            
            const html = comments.map(c => {
                // Проверяем и фильтруем неправильные пути изображений
                let postImageSrc = c.postImage;
                if (!postImageSrc || postImageSrc === 'null' || postImageSrc === '/travel/temp_photo.jpg' || postImageSrc.includes('temp_photo')) {
                    postImageSrc = '/travel/admin/assets/images/default-avatar.svg';
                }
                
                let commenterImageSrc = c.commenterImage;
                if (!commenterImageSrc || commenterImageSrc === 'null') {
                    commenterImageSrc = '/travel/admin/assets/images/default-avatar.svg';
                }
                
                return `
                    <div class="mb-3 p-3 border-bottom" data-comment-id="${c.id}">
                        <div class="d-flex align-items-start">
                            <img src="${commenterImageSrc}" 
                                 alt="${c.commenterName || 'Пользователь'}" 
                                 class="rounded-circle me-3" 
                                 style="width: 50px; height: 50px; object-fit: cover;"
                                 onerror="this.src='/travel/admin/assets/images/default-avatar.svg'">
                            <div class="flex-grow-1">
                                <h6 class="mb-1">
                                    <a href="user_details.php?id=${c.commenterId}">${c.commenterName || 'Неизвестен'}</a>
                                </h6>
                                <p class="mb-1"><strong>${c.text || ''}</strong></p>
                                <p class="mb-1 text-muted small">К посту: "${c.postTitle || 'Без названия'}"</p>
                                <small class="text-muted">${new Date(c.createdAt).toLocaleString('ru-RU')}</small>
                            </div>
                            <div class="d-flex align-items-center gap-2">
                                <img src="${postImageSrc}" 
                                     alt="${c.postTitle || 'Пост'}" 
                                     class="preview-image" 
                                     style="width: 60px; height: 60px; object-fit: cover; border-radius: 8px; cursor: pointer;"
                                     title="Нажмите для просмотра"
                                     onerror="this.src='/travel/admin/assets/images/default-avatar.svg'">
                                <div class="d-flex flex-column gap-1">
                                    <button class="btn btn-sm btn-info view-comment-post" data-post-id="${c.postId}" title="Просмотр поста">
                                        <i class="bi bi-eye"></i>
                                    </button>
                                    <button class="btn btn-sm btn-danger delete-comment" data-comment-id="${c.id}" title="Удалить">
                                        <i class="bi bi-trash"></i>
                                    </button>
                                </div>
                            </div>
                        </div>
                    </div>
                `;
            }).join('');
            
            container.html(html);
            
            // Add handlers
            container.find('.view-comment-post').on('click', function() {
                const postId = $(this).data('post-id');
                viewPostDetails(postId);
            });
            
            container.find('.delete-comment').on('click', function() {
                const commentId = $(this).data('comment-id');
                if (confirm('Вы уверены, что хотите удалить этот комментарий?')) {
                    deleteComment(commentId);
                }
            });
        }
        
        function showError(message) {
            if (typeof jQuery !== 'undefined') {
                $('#loadingSpinner').hide();
                $('#errorMessage').text(message).show();
            } else {
                document.getElementById('loadingSpinner').style.display = 'none';
                document.getElementById('errorMessage').textContent = message;
                document.getElementById('errorMessage').style.display = 'block';
            }
        }
    </script>
</div>
</main>

<?php include '../includes/footer.php'; ?>
