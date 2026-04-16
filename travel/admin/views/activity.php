<?php
$pageTitle = 'Лента активности';
require_once '../config/admin_config.php';
adminRequireAuth();
include '../includes/header.php';
include '../includes/sidebar.php';
?>

<main class="col-md-9 ms-sm-auto col-lg-10 px-md-4">
<div class="container-fluid">
    <div class="d-flex flex-column flex-md-row justify-content-between align-items-start align-items-md-center mb-4 gap-3">
        <h2 class="mb-0"><i class="fas fa-stream me-2"></i>Лента активности</h2>
        <div class="btn-group w-100 w-md-auto" role="group">
            <button type="button" class="btn btn-outline-primary active" data-filter="all">
                <i class="fas fa-list me-1 d-none d-sm-inline"></i><span class="d-none d-sm-inline">Все</span><span class="d-sm-none">📋</span>
            </button>
            <button type="button" class="btn btn-outline-danger" data-filter="like">
                <i class="fas fa-heart me-1 d-none d-sm-inline"></i><span class="d-none d-sm-inline">Лайки</span><span class="d-sm-none">❤️</span>
            </button>
            <button type="button" class="btn btn-outline-info" data-filter="comment">
                <i class="fas fa-comment me-1 d-none d-sm-inline"></i><span class="d-none d-sm-inline">Комментарии</span><span class="d-sm-none">💬</span>
            </button>
            <button type="button" class="btn btn-outline-warning" data-filter="favorite">
                <i class="fas fa-star me-1 d-none d-sm-inline"></i><span class="d-none d-sm-inline">Избранное</span><span class="d-sm-none">⭐</span>
            </button>
        </div>
    </div>

    <div class="card">
        <div class="card-body">
            <div id="activityFeed">
                <div class="text-center py-5">
                    <div class="spinner-border" role="status"></div>
                    <p class="mt-2">Загрузка активности...</p>
                </div>
            </div>
            
            <div id="pagination" class="mt-4"></div>
        </div>
    </div>
</div>
</main>

<?php include '../includes/footer.php'; ?>

<script>
let currentPage = 1;
let currentFilter = 'all';

$(document).ready(function() {
    loadActivityFeed();
    
    // Фильтры
    $('[data-filter]').on('click', function() {
        $('[data-filter]').removeClass('active');
        $(this).addClass('active');
        currentFilter = $(this).data('filter');
        currentPage = 1;
        loadActivityFeed();
    });
    
    // Автообновление каждые 30 секунд
    setInterval(function() {
        if (currentPage === 1) {
            loadActivityFeed(true); // silent reload
        }
    }, 30000);
    
    // Sidebar toggle инициализируется в admin.js
});

function loadActivityFeed(silent = false) {
    if (!silent) {
        $('#activityFeed').html(`
            <div class="text-center py-5">
                <div class="spinner-border" role="status"></div>
                <p class="mt-2">Загрузка...</p>
            </div>
        `);
    }
    
    $.ajax({
        url: '../api/activity/get_activity_feed.php',
        type: 'GET',
        data: {
            page: currentPage,
            per_page: 50,
            type: currentFilter
        },
        success: function(response) {
            if (response.success) {
                displayActivityFeed(response.activities);
                displayPagination(response.pagination);
            } else {
                showError(response.message);
            }
        },
        error: function() {
            showError('Ошибка при загрузке ленты активности');
        }
    });
}

function displayActivityFeed(activities) {
    const container = $('#activityFeed');
    
    if (activities.length === 0) {
        container.html('<p class="text-muted text-center py-5">Нет активности</p>');
        return;
    }
    
    const html = activities.map(activity => {
        const timeAgo = getTimeAgo(activity.created_at);
        
        // Фильтруем temp_photo.jpg
        let actorImage = activity.actor_image || '/travel/admin/assets/images/default-avatar.svg';
        if (actorImage.includes('temp_photo')) {
            actorImage = '/travel/admin/assets/images/default-avatar.svg';
        }
        
        let targetImage = activity.target_image || '/travel/admin/assets/images/default-avatar.svg';
        if (targetImage.includes('temp_photo')) {
            targetImage = '/travel/admin/assets/images/default-avatar.svg';
        }
        
        let icon, iconColor, actionText;
        
        switch(activity.activity_type) {
            case 'like':
                icon = 'fa-heart';
                iconColor = 'text-danger';
                actionText = 'поставил(а) лайк на публикацию';
                break;
            case 'comment':
                icon = 'fa-comment';
                iconColor = 'text-info';
                actionText = 'прокомментировал(а) публикацию';
                break;
            case 'favorite':
                icon = 'fa-star';
                iconColor = 'text-warning';
                actionText = 'добавил(а) в избранное публикацию';
                break;
        }
        
        return `
            <div class="activity-item border-bottom py-3">
                <div class="d-flex align-items-start">
                    <div class="position-relative me-2 me-sm-3 flex-shrink-0">
                        <img src="${actorImage}" 
                             class="rounded-circle" 
                             style="width: 40px; height: 40px; object-fit: cover;"
                             alt="${activity.actor_name}">
                        <i class="fas ${icon} ${iconColor} position-absolute" 
                           style="bottom: -2px; right: -2px; background: white; border-radius: 50%; padding: 3px; font-size: 12px;"></i>
                    </div>
                    <div class="flex-grow-1 min-width-0">
                        <div class="mb-2">
                            <a href="user_details.php?id=${activity.actor_id}" class="fw-bold text-decoration-none text-break">
                                ${activity.actor_name}
                            </a>
                            <span class="text-muted d-block d-sm-inline"> ${actionText} </span>
                            <a href="user_details.php?id=${activity.target_owner_id}" class="text-decoration-none text-break d-block d-sm-inline">
                                ${activity.target_owner_name}
                            </a>
                        </div>
                        ${activity.comment_text ? `
                            <div class="bg-light p-2 rounded mb-2">
                                <small class="text-break">${escapeHtml(activity.comment_text)}</small>
                            </div>
                        ` : ''}
                        <small class="text-muted">
                            <i class="far fa-clock me-1"></i>${timeAgo}
                        </small>
                    </div>
                    <div class="ms-2 ms-sm-3 flex-shrink-0">
                        <img src="${targetImage}" 
                             class="rounded" 
                             style="width: 60px; height: 60px; object-fit: cover; cursor: pointer;"
                             onclick="viewPostDetails(${activity.target_id})"
                             title="${activity.target_title || 'Без названия'}">
                    </div>
                </div>
            </div>
        `;
    }).join('');
    
    container.html(html);
}

function displayPagination(pagination) {
    const container = $('#pagination');
    
    if (pagination.lastPage <= 1) {
        container.html('');
        return;
    }
    
    let html = '<nav><ul class="pagination justify-content-center">';
    
    // Previous
    html += `<li class="page-item ${pagination.currentPage === 1 ? 'disabled' : ''}">
                <a class="page-link" href="#" onclick="changePage(${pagination.currentPage - 1}); return false;">Назад</a>
             </li>`;
    
    // Pages
    for (let i = 1; i <= pagination.lastPage; i++) {
        if (i === 1 || i === pagination.lastPage || (i >= pagination.currentPage - 2 && i <= pagination.currentPage + 2)) {
            html += `<li class="page-item ${i === pagination.currentPage ? 'active' : ''}">
                        <a class="page-link" href="#" onclick="changePage(${i}); return false;">${i}</a>
                     </li>`;
        } else if (i === pagination.currentPage - 3 || i === pagination.currentPage + 3) {
            html += '<li class="page-item disabled"><span class="page-link">...</span></li>';
        }
    }
    
    // Next
    html += `<li class="page-item ${pagination.currentPage === pagination.lastPage ? 'disabled' : ''}">
                <a class="page-link" href="#" onclick="changePage(${pagination.currentPage + 1}); return false;">Вперед</a>
             </li>`;
    
    html += '</ul></nav>';
    container.html(html);
}

function changePage(page) {
    currentPage = page;
    loadActivityFeed();
    $('html, body').animate({ scrollTop: 0 }, 300);
}

function getTimeAgo(dateString) {
    const date = new Date(dateString);
    const now = new Date();
    const seconds = Math.floor((now - date) / 1000);
    
    if (seconds < 60) return 'только что';
    if (seconds < 3600) return Math.floor(seconds / 60) + ' мин назад';
    if (seconds < 86400) return Math.floor(seconds / 3600) + ' ч назад';
    if (seconds < 604800) return Math.floor(seconds / 86400) + ' дн назад';
    
    return date.toLocaleDateString('ru-RU');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function showError(message) {
    $('#activityFeed').html(`
        <div class="alert alert-danger">
            <i class="fas fa-exclamation-triangle me-2"></i>${escapeHtml(message)}
        </div>
    `);
}

function viewPostDetails(postId) {
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

function showPostDetailsModal(post, likes, comments) {
    // Фильтруем temp_photo.jpg для всех изображений
    let postImage = post.filePath || '/travel/admin/assets/images/default-avatar.svg';
    if (postImage.includes('temp_photo')) {
        postImage = '/travel/admin/assets/images/default-avatar.svg';
    }
    
    // Формируем HTML для лайков
    const likesHtml = likes && likes.length > 0 ? likes.map(like => {
        let likeImage = like.image || '/travel/admin/assets/images/default-avatar.svg';
        if (likeImage.includes('temp_photo')) {
            likeImage = '/travel/admin/assets/images/default-avatar.svg';
        }
        return `
            <div class="d-flex align-items-center mb-2">
                <img src="${likeImage}" 
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
        `;
    }).join('') : '<p class="text-muted">Нет лайков</p>';
    
    // Формируем HTML для комментариев
    const commentsHtml = comments && comments.length > 0 ? comments.map(comment => {
        let commentImage = comment.user_image || '/travel/admin/assets/images/default-avatar.svg';
        if (commentImage.includes('temp_photo')) {
            commentImage = '/travel/admin/assets/images/default-avatar.svg';
        }
        return `
            <div class="d-flex align-items-start mb-3 pb-2 border-bottom">
                <img src="${commentImage}" 
                     class="rounded-circle me-2" 
                     style="width: 32px; height: 32px; object-fit: cover;"
                     alt="${comment.user_name}">
                <div class="flex-grow-1">
                    <a href="user_details.php?id=${comment.user_id}" class="text-decoration-none fw-bold">
                        ${comment.user_name}
                    </a>
                    <small class="text-muted ms-2">${new Date(comment.created_at).toLocaleString('ru-RU')}</small>
                    <p class="mb-0 mt-1">${escapeHtml(comment.text)}</p>
                </div>
            </div>
        `;
    }).join('') : '<p class="text-muted">Нет комментариев</p>';
    
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
                                <img src="${postImage}" 
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
    
    // Remove existing modal if any
    const existingModal = document.getElementById('postDetailsModal');
    if (existingModal) {
        const modalInstance = bootstrap.Modal.getInstance(existingModal);
        if (modalInstance) {
            modalInstance.dispose();
        }
        existingModal.remove();
    }
    
    // Remove any leftover backdrops
    document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
    
    // Reset body classes
    document.body.classList.remove('modal-open');
    document.body.style.removeProperty('overflow');
    document.body.style.removeProperty('padding-right');
    
    // Add new modal
    $('body').append(modalHtml);
    
    // Show modal
    const modalElement = document.getElementById('postDetailsModal');
    const modal = new bootstrap.Modal(modalElement);
    modal.show();
    
    // Clean up on close
    modalElement.addEventListener('hidden.bs.modal', function() {
        modal.dispose();
        this.remove();
        document.querySelectorAll('.modal-backdrop').forEach(el => el.remove());
        document.body.classList.remove('modal-open');
        document.body.style.removeProperty('overflow');
        document.body.style.removeProperty('padding-right');
    }, { once: true });
}
</script>

<style>
.activity-item:hover {
    background-color: #f8f9fa;
}

.activity-item:last-child {
    border-bottom: none !important;
}

.min-width-0 {
    min-width: 0;
}

.text-break {
    word-wrap: break-word;
    word-break: break-word;
}

/* Мобильные устройства */
@media (max-width: 575.98px) {
    .activity-item {
        padding: 0.75rem 0 !important;
    }
    
    .activity-item img.rounded-circle {
        width: 36px !important;
        height: 36px !important;
    }
    
    .activity-item img.rounded {
        width: 50px !important;
        height: 50px !important;
    }
    
    .activity-item .position-absolute i {
        font-size: 10px !important;
        padding: 2px !important;
    }
    
    .btn-group {
        flex-wrap: nowrap;
    }
    
    .btn-group .btn {
        font-size: 0.875rem;
        padding: 0.375rem 0.5rem;
    }
    
    h2 {
        font-size: 1.5rem;
    }
}

/* Планшеты */
@media (min-width: 576px) and (max-width: 767.98px) {
    .activity-item img.rounded-circle {
        width: 44px !important;
        height: 44px !important;
    }
    
    .activity-item img.rounded {
        width: 70px !important;
        height: 70px !important;
    }
}

/* Десктоп */
@media (min-width: 768px) {
    .activity-item img.rounded-circle {
        width: 48px !important;
        height: 48px !important;
    }
    
    .activity-item img.rounded {
        width: 80px !important;
        height: 80px !important;
    }
}

/* Пагинация на мобильных */
@media (max-width: 575.98px) {
    .pagination {
        font-size: 0.875rem;
    }
    
    .pagination .page-link {
        padding: 0.375rem 0.5rem;
    }
}

/* Offcanvas backdrop стили в admin.css */
</style>
