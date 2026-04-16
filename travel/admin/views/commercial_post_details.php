<?php
require_once '../config/admin_config.php';
adminRequireAuth();

$commercialPostId = isset($_GET['id']) ? intval($_GET['id']) : 0;

if (!$commercialPostId) {
    header('Location: posts.php');
    exit;
}

$pageTitle = 'Детали коммерческого поста';
include '../includes/header.php';
?>

<div class="container-fluid">
    <div class="d-flex justify-content-between align-items-center mb-4">
        <h2><i class="fas fa-ad me-2"></i>Детали коммерческого поста</h2>
        <button onclick="goBackToCommercial()" class="btn btn-secondary">
            <i class="fas fa-arrow-left me-2"></i>Назад
        </button>
    </div>

    <div id="commercialPostDetails">
        <div class="text-center py-5">
            <div class="spinner-border" role="status"></div>
            <p class="mt-2">Загрузка...</p>
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

<script>
document.addEventListener('DOMContentLoaded', function() {
    const commercialPostId = <?php echo $commercialPostId; ?>;
    
    fetch(`../api/posts/get_commercial_post_relations.php?commercial_post_id=${commercialPostId}`)
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                renderCommercialPostDetails(data);
            } else {
                showError(data.message || 'Неизвестная ошибка');
            }
        })
        .catch(error => {
            showError('Ошибка при загрузке данных');
            console.error(error);
        });
});

function renderCommercialPostDetails(data) {
    const cp = data.commercialPost;
    const container = document.getElementById('commercialPostDetails');
    
    let html = `
        <div class="row">
            <div class="col-md-8">
                ${cp.image_url ? `
                <div class="card mb-4">
                    <div class="card-header">
                        <h5>Изображение</h5>
                    </div>
                    <div class="card-body text-center">
                        <img src="${cp.image_url}" 
                             class="img-fluid cursor-pointer-img" 
                             style="max-height: 400px; object-fit: contain; cursor: pointer;"
                             onclick="openImagePreview('${cp.image_url.replace(/'/g, "\\'")}', '${escapeHtml(cp.title).replace(/'/g, "\\'")}', 'Основное изображение')">
                    </div>
                </div>
                ` : ''}
                
                <div class="card mb-4">
                    <div class="card-header">
                        <h5>Информация о коммерческом посте</h5>
                    </div>
                    <div class="card-body">
                        <table class="table">
                            <tr>
                                <th width="200">ID:</th>
                                <td>${cp.id}</td>
                            </tr>
                            <tr>
                                <th>Заголовок:</th>
                                <td>${escapeHtml(cp.title)}</td>
                            </tr>
                            <tr>
                                <th>Описание:</th>
                                <td>${escapeHtml(cp.description || '-')}</td>
                            </tr>
                            <tr>
                                <th>Автор:</th>
                                <td>${escapeHtml(cp.user_name)}</td>
                            </tr>
                            <tr>
                                <th>Тип:</th>
                                <td><span class="badge bg-info">${getTypeLabel(cp.type)}</span></td>
                            </tr>
                            <tr>
                                <th>Статус:</th>
                                <td><span class="badge ${cp.is_active == 1 ? 'bg-success' : 'bg-secondary'}">${cp.is_active == 1 ? 'Активен' : 'Неактивен'}</span></td>
                            </tr>
                            <tr>
                                <th>Локация:</th>
                                <td>${(cp.location_name && cp.location_name.trim() !== '') ? cp.location_name : (cp.latitude && cp.longitude ? `📍 ${cp.latitude}, ${cp.longitude}` : '-')}</td>
                            </tr>
                            <tr>
                                <th>Дата создания:</th>
                                <td>${formatDate(cp.created_at)}</td>
                            </tr>
                        </table>
                    </div>
                </div>
    `;
    
    // Related Albums
    if (data.relatedAlbums && data.relatedAlbums.length > 0) {
        html += `
            <div class="card mb-4">
                <div class="card-header">
                    <h5>Связанные альбомы</h5>
                </div>
                <div class="card-body">
                    <div class="row">
        `;
        
        data.relatedAlbums.forEach(album => {
            html += `
                <div class="col-md-6 mb-3">
                    <div class="card">
                        ${album.cover_photo ? `<img src="${album.cover_photo}" class="card-img-top cursor-pointer-img" style="height: 200px; object-fit: cover;" onclick="openImagePreview('${album.cover_photo.replace(/'/g, "\\'")}', '${escapeHtml(album.title).replace(/'/g, "\\'")}', 'Обложка альбома')">` : '<div style="height: 200px; background: #ddd;"></div>'}
                        <div class="card-body">
                            <h6>${escapeHtml(album.title)}</h6>
                            <p class="text-muted small">${escapeHtml(album.description || '')}</p>
                            <p class="mb-0"><small>Фотографий: ${album.photos_count}</small></p>
                        </div>
                    </div>
                </div>
            `;
        });
        
        html += `
                    </div>
                </div>
            </div>
        `;
    }
    
    // Related Photos
    if (data.relatedPhotos && data.relatedPhotos.length > 0) {
        html += `
            <div class="card mb-4">
                <div class="card-header">
                    <h5>Связанные фотографии</h5>
                </div>
                <div class="card-body">
                    <div class="row">
        `;
        
        data.relatedPhotos.forEach(photo => {
            html += `
                <div class="col-md-4 mb-3">
                    <div class="card">
                        <img src="${photo.preview}" class="card-img-top cursor-pointer-img" style="height: 150px; object-fit: cover;" onclick="openImagePreview('${photo.preview.replace(/'/g, "\\'")}', '${escapeHtml(photo.title || 'Без названия').replace(/'/g, "\\'")}', '${escapeHtml(photo.location_name || '').replace(/'/g, "\\'")}')">
                        <div class="card-body">
                            <h6 class="small">${escapeHtml(photo.title || 'Без названия')}</h6>
                            ${photo.location_name ? `<p class="text-muted small mb-0"><i class="fas fa-map-marker-alt me-1"></i>${escapeHtml(photo.location_name)}</p>` : ''}
                        </div>
                    </div>
                </div>
            `;
        });
        
        html += `
                    </div>
                </div>
            </div>
        `;
    }
    
    html += `</div><div class="col-md-4">`;
    
    // Displayed In Photos
    if (data.displayedInPhotos && data.displayedInPhotos.length > 0) {
        html += `
            <div class="card">
                <div class="card-header">
                    <h5>Отображается в постах (${data.displayedInPhotos.length})</h5>
                </div>
                <div class="card-body" style="max-height: 600px; overflow-y: auto;">
        `;
        
        data.displayedInPhotos.forEach(photo => {
            html += `
                <div class="card mb-2">
                    <img src="${photo.preview}" class="card-img-top cursor-pointer-img" style="height: 120px; object-fit: cover;" onclick="openImagePreview('${photo.preview.replace(/'/g, "\\'")}', '${escapeHtml(photo.title || 'Без названия').replace(/'/g, "\\'")}', '${escapeHtml(photo.location_name || '').replace(/'/g, "\\'")}')">
                    <div class="card-body p-2">
                        <p class="small mb-1"><strong>${escapeHtml(photo.title || 'Без названия')}</strong></p>
                        ${photo.location_name ? `<p class="text-muted small mb-0"><i class="fas fa-map-marker-alt me-1"></i>${escapeHtml(photo.location_name)}</p>` : ''}
                    </div>
                </div>
            `;
        });
        
        html += `
                </div>
            </div>
        `;
    }
    
    html += `</div></div>`;
    
    container.innerHTML = html;
}

function getTypeLabel(type) {
    const labels = {
        'album': 'Альбом',
        'photo': 'Фото',
        'standalone': 'Отдельный'
    };
    return labels[type] || type;
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString('ru-RU');
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function showError(message) {
    document.getElementById('commercialPostDetails').innerHTML = `
        <div class="alert alert-danger">
            <i class="fas fa-exclamation-triangle me-2"></i>${escapeHtml(message)}
        </div>
    `;
}

// Функция для открытия изображения в модальном окне
function openImagePreview(imageSrc, title, info) {
    const modal = new bootstrap.Modal(document.getElementById('imagePreviewModal'));
    const img = document.getElementById('imagePreviewImg');
    const titleElement = document.getElementById('imagePreviewTitle');
    const infoElement = document.getElementById('imagePreviewInfo');
    
    img.src = imageSrc;
    titleElement.textContent = title || 'Просмотр изображения';
    infoElement.innerHTML = info ? `<div class="text-white"><small>${escapeHtml(info)}</small></div>` : '';
    
    modal.show();
}
</script>
