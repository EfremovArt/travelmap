let postsTable, albumsTable, commercialTable;
let postsSearchTimeout, albumsSearchTimeout, commercialSearchTimeout;

// Helper function to normalize image URLs
function normalizeImageUrl(url) {
    if (!url) return '';
    // Filter out temp_photo.jpg
    if (url.includes('temp_photo')) {
        return '';
    }
    // If it's already an external URL (starts with http:// or https://), return as is
    if (url.startsWith('http://') || url.startsWith('https://')) {
        return url;
    }
    // Otherwise, it's a relative path, return as is
    return url;
}

document.addEventListener('DOMContentLoaded', function() {
    // Restore active tab from localStorage
    const savedTab = localStorage.getItem('postsActiveTab') || 'posts';
    const tabButton = document.querySelector(`#${savedTab}-tab`);
    if (tabButton) {
        const tab = new bootstrap.Tab(tabButton);
        tab.show();
    }
    
    // Save active tab on change
    document.querySelectorAll('#postsTabs button[data-bs-toggle="tab"]').forEach(button => {
        button.addEventListener('shown.bs.tab', function(e) {
            const tabId = e.target.id.replace('-tab', '');
            localStorage.setItem('postsActiveTab', tabId);
        });
    });
    
    // Initialize Posts Table
    initPostsTable();
    
    // Initialize Albums Table
    initAlbumsTable();
    
    // Initialize Commercial Posts Table
    initCommercialTable();
    
    // Search handlers
    document.getElementById('postsSearch').addEventListener('input', function() {
        clearTimeout(postsSearchTimeout);
        postsSearchTimeout = setTimeout(() => {
            postsTable.ajax.reload();
        }, 500);
    });
    
    document.getElementById('albumsSearch').addEventListener('input', function() {
        clearTimeout(albumsSearchTimeout);
        albumsSearchTimeout = setTimeout(() => {
            albumsTable.ajax.reload();
        }, 500);
    });
    
    document.getElementById('commercialSearch').addEventListener('input', function() {
        clearTimeout(commercialSearchTimeout);
        commercialSearchTimeout = setTimeout(() => {
            commercialTable.ajax.reload();
        }, 500);
    });
    
    // Filter handlers
    document.getElementById('commercialTypeFilter').addEventListener('change', function() {
        commercialTable.ajax.reload();
    });
});

function initPostsTable() {
    const savedPage = parseInt(localStorage.getItem('postsTablePage')) || 0;
    
    postsTable = $('#postsTable').DataTable({
        processing: true,
        serverSide: true,
        displayStart: savedPage * 25,
        ajax: {
            url: '../api/posts/get_all_posts.php',
            type: 'GET',
            data: function(d) {
                const searchValue = document.getElementById('postsSearch').value.trim();
                return {
                    page: Math.floor(d.start / d.length) + 1,
                    per_page: d.length,
                    user_search: searchValue,
                    sort_by: 'created_at',
                    sort_order: 'desc'
                };
            },
            dataSrc: function(json) {
                if (json && json.success) {
                    json.recordsTotal = json.pagination.total;
                    json.recordsFiltered = json.pagination.total;
                    return json.posts;
                }
                console.error('Posts API error:', json);
                return [];
            },
            error: function(xhr, error, thrown) {
                console.error('Posts API request failed:', error, thrown);
                console.error('Response:', xhr.responseText);
            }
        },
        columns: [
            {
                data: 'preview',
                orderable: false,
                render: function(data, type, row) {
                    const previewSrc = normalizeImageUrl(data);
                    if (previewSrc) {
                        return `<img src="${previewSrc}" 
                                     style="width: 60px; height: 60px; object-fit: cover; border-radius: 4px; cursor: pointer;" 
                                     onclick="openImagePreview('${previewSrc.replace(/'/g, "\\'")}', '${escapeHtml(row.title || 'Пост').replace(/'/g, "\\'")}', '${escapeHtml(row.user_name).replace(/'/g, "\\'")}')">`;
                    }
                    return `<div style="width: 60px; height: 60px; background: #e9ecef; border-radius: 4px; display: flex; align-items: center; justify-content: center;">
                                <i class="bi bi-image" style="font-size: 24px; color: #adb5bd;"></i>
                            </div>`;
                }
            },
            {
                data: 'title',
                render: function(data, type, row) {
                    return `<div>
                        <strong>${escapeHtml(data || 'Без названия')}</strong>
                        ${row.description ? `<br><small class="text-muted">${escapeHtml(row.description.substring(0, 50))}${row.description.length > 50 ? '...' : ''}</small>` : ''}
                    </div>`;
                }
            },
            {
                data: 'user_name',
                render: function(data, type, row) {
                    const profileImageSrc = normalizeImageUrl(row.user_profile_image);
                    return `<div class="d-flex align-items-center">
                        ${profileImageSrc ? `<img src="${profileImageSrc}" class="rounded-circle me-2" style="width: 30px; height: 30px; object-fit: cover;">` : '<div class="rounded-circle bg-secondary me-2" style="width: 30px; height: 30px;"></div>'}
                        <div>
                            <div>${escapeHtml(data)}</div>
                            <small class="text-muted">${escapeHtml(row.user_email)}</small>
                        </div>
                    </div>`;
                }
            },
            {
                data: 'location_name',
                render: function(data) {
                    return data ? `<i class="fas fa-map-marker-alt me-1"></i>${escapeHtml(data)}` : '-';
                }
            },
            {
                data: null,
                orderable: false,
                render: function(data, type, row) {
                    return `<div style="font-size: 0.85rem; text-align: center;">
                        <div><i class="bi bi-heart-fill text-danger me-1"></i>${row.likes_count} лайков</div>
                        <div><i class="bi bi-chat-fill text-primary me-1"></i>${row.comments_count} комм.</div>
                    </div>`;
                }
            },
            {
                data: 'created_at',
                render: function(data) {
                    return formatDate(data);
                }
            },
            {
                data: null,
                orderable: false,
                render: function(data, type, row) {
                    return `<button class="btn btn-sm btn-primary" onclick="viewPostDetails(${row.id})" title="Просмотр деталей">
                        <i class="bi bi-eye"></i>
                    </button>`;
                }
            }
        ],
        order: [[5, 'desc']],
        pageLength: 25,
        autoWidth: false,
        language: {
            url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/ru.json'
        }
    });
}

function initAlbumsTable() {
    const savedPage = parseInt(localStorage.getItem('albumsTablePage')) || 0;
    
    albumsTable = $('#albumsTable').DataTable({
        processing: true,
        serverSide: true,
        displayStart: savedPage * 25,
        ajax: {
            url: '../api/posts/get_all_albums.php',
            type: 'GET',
            data: function(d) {
                const searchValue = document.getElementById('albumsSearch').value.trim();
                return {
                    page: Math.floor(d.start / d.length) + 1,
                    per_page: d.length,
                    user_search: searchValue,
                    sort_by: 'created_at',
                    sort_order: 'desc'
                };
            },
            dataSrc: function(json) {
                if (json && json.success) {
                    json.recordsTotal = json.pagination.total;
                    json.recordsFiltered = json.pagination.total;
                    return json.albums;
                }
                console.error('Albums API error:', json);
                return [];
            },
            error: function(xhr, error, thrown) {
                console.error('Albums API request failed:', error, thrown);
                console.error('Response:', xhr.responseText);
            }
        },
        columns: [
            {
                data: 'cover_photo',
                orderable: false,
                render: function(data, type, row) {
                    const coverPhotoSrc = normalizeImageUrl(data);
                    if (coverPhotoSrc) {
                        return `<img src="${coverPhotoSrc}" 
                                     style="width: 60px; height: 60px; object-fit: cover; border-radius: 4px; cursor: pointer;" 
                                     onclick="openImagePreview('${coverPhotoSrc.replace(/'/g, "\\'")}', '${escapeHtml(row.title).replace(/'/g, "\\'")}', '${escapeHtml(row.owner_name).replace(/'/g, "\\'")}')">`;
                    }
                    return `<div style="width: 60px; height: 60px; background: #e9ecef; border-radius: 4px; display: flex; align-items: center; justify-content: center;">
                                <i class="bi bi-images" style="font-size: 24px; color: #adb5bd;"></i>
                            </div>`;
                }
            },
            {
                data: 'title',
                render: function(data, type, row) {
                    return `<div>
                        <strong>${escapeHtml(data)}</strong>
                        ${row.description ? `<br><small class="text-muted">${escapeHtml(row.description.substring(0, 50))}${row.description.length > 50 ? '...' : ''}</small>` : ''}
                    </div>`;
                }
            },
            {
                data: 'owner_name',
                render: function(data, type, row) {
                    const ownerProfileImageSrc = normalizeImageUrl(row.owner_profile_image);
                    return `<div class="d-flex align-items-center">
                        ${ownerProfileImageSrc ? `<img src="${ownerProfileImageSrc}" class="rounded-circle me-2" style="width: 30px; height: 30px; object-fit: cover;">` : '<div class="rounded-circle bg-secondary me-2" style="width: 30px; height: 30px;"></div>'}
                        <div>
                            <div>${escapeHtml(data)}</div>
                            <small class="text-muted">${escapeHtml(row.owner_email)}</small>
                        </div>
                    </div>`;
                }
            },
            {
                data: 'photos_count',
                render: function(data) {
                    return `<span class="badge bg-primary">${data}</span>`;
                }
            },
            {
                data: null,
                orderable: false,
                render: function(data, type, row) {
                    return `<div style="font-size: 0.85rem; text-align: center;">
                        <div><i class="bi bi-heart-fill text-danger me-1"></i>${row.likes_count} лайков</div>
                        <div><i class="bi bi-chat-fill text-primary me-1"></i>${row.comments_count} комм.</div>
                        <div><i class="bi bi-star-fill text-warning me-1"></i>${row.favorites_count} избр.</div>
                    </div>`;
                }
            },
            {
                data: 'created_at',
                render: function(data) {
                    return formatDate(data);
                }
            },
            {
                data: null,
                orderable: false,
                render: function(data, type, row) {
                    return `<button class="btn btn-sm btn-primary" onclick="viewAlbumPhotos(${row.id})">
                        <i class="fas fa-images"></i> Фото
                    </button>`;
                }
            }
        ],
        order: [[5, 'desc']],
        pageLength: 25,
        autoWidth: false,
        language: {
            url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/ru.json'
        }
    });
}

function initCommercialTable() {
    const savedPage = parseInt(localStorage.getItem('commercialTablePage')) || 0;
    
    commercialTable = $('#commercialTable').DataTable({
        processing: true,
        serverSide: true,
        displayStart: savedPage * 25,
        ajax: {
            url: '../api/posts/get_all_commercial_posts.php',
            type: 'GET',
            data: function(d) {
                const searchValue = document.getElementById('commercialSearch').value.trim();
                return {
                    page: Math.floor(d.start / d.length) + 1,
                    per_page: d.length,
                    user_search: searchValue,
                    type: document.getElementById('commercialTypeFilter').value,
                    sort_by: 'created_at',
                    sort_order: 'desc'
                };
            },
            dataSrc: function(json) {
                if (json && json.success) {
                    json.recordsTotal = json.pagination.total;
                    json.recordsFiltered = json.pagination.total;
                    return json.commercialPosts;
                }
                console.error('Commercial posts API error:', json);
                return [];
            },
            error: function(xhr, error, thrown) {
                console.error('Commercial posts API request failed:', error, thrown);
                console.error('Response:', xhr.responseText);
            }
        },
        columns: [
            {
                data: 'preview',
                orderable: false,
                render: function(data, type, row) {
                    const previewSrc = normalizeImageUrl(data);
                    if (previewSrc) {
                        return `<img src="${previewSrc}" 
                                     style="width: 60px; height: 60px; object-fit: cover; border-radius: 4px; cursor: pointer;" 
                                     onclick="openImagePreview('${previewSrc.replace(/'/g, "\\'")}', '${escapeHtml(row.title).replace(/'/g, "\\'")}', '${escapeHtml(row.user_name).replace(/'/g, "\\'")}')">`;
                    }
                    return `<div style="width: 60px; height: 60px; background: #e9ecef; border-radius: 4px; display: flex; align-items: center; justify-content: center;">
                                <i class="bi bi-cash-coin" style="font-size: 24px; color: #adb5bd;"></i>
                            </div>`;
                }
            },
            {
                data: 'title',
                render: function(data, type, row) {
                    return `<div>
                        <strong>${escapeHtml(data)}</strong>
                        ${row.description ? `<br><small class="text-muted">${escapeHtml(row.description.substring(0, 50))}${row.description.length > 50 ? '...' : ''}</small>` : ''}
                    </div>`;
                }
            },
            {
                data: 'user_name',
                render: function(data, type, row) {
                    const profileImageSrc = normalizeImageUrl(row.user_profile_image);
                    return `<div class="d-flex align-items-center">
                        ${profileImageSrc ? `<img src="${profileImageSrc}" class="rounded-circle me-2" style="width: 30px; height: 30px; object-fit: cover;">` : '<div class="rounded-circle bg-secondary me-2" style="width: 30px; height: 30px;"></div>'}
                        <div>
                            <div>${escapeHtml(data)}</div>
                            <small class="text-muted">${escapeHtml(row.user_email)}</small>
                        </div>
                    </div>`;
                }
            },
            {
                data: 'type',
                render: function(data, type, row) {
                    const types = {
                        'album': '<span class="badge bg-primary">Альбом</span>',
                        'photo': '<span class="badge bg-success">Фото</span>',
                        'standalone': '<span class="badge bg-info">Отдельный</span>'
                    };
                    let html = types[data] || data;
                    if (row.related_title) {
                        html += `<br><small class="text-muted">${escapeHtml(row.related_title.substring(0, 20))}${row.related_title.length > 20 ? '...' : ''}</small>`;
                    }
                    return html;
                }
            },
            {
                data: 'is_active',
                render: function(data) {
                    return data == 1 ? '<span class="badge bg-success">Активен</span>' : '<span class="badge bg-secondary">Неактивен</span>';
                }
            },
            {
                data: 'created_at',
                render: function(data) {
                    return formatDate(data);
                }
            },
            {
                data: null,
                orderable: false,
                render: function(data, type, row) {
                    return `<button class="btn btn-sm btn-primary" onclick="viewCommercialPostDetails(${row.id})">
                        <i class="fas fa-eye"></i> Детали
                    </button>`;
                }
            }
        ],
        order: [[5, 'desc']],
        pageLength: 25,
        autoWidth: false,
        language: {
            url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/ru.json'
        }
    });
}

function loadUsersForFilters() {
    fetch('../api/users/get_all_users.php?per_page=1000')
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                const users = data.users;
                const postsFilter = document.getElementById('postsUserFilter');
                const albumsFilter = document.getElementById('albumsUserFilter');
                const commercialFilter = document.getElementById('commercialUserFilter');
                
                users.forEach(user => {
                    const option = `<option value="${user.id}">${escapeHtml(user.first_name + ' ' + user.last_name)}</option>`;
                    postsFilter.innerHTML += option;
                    albumsFilter.innerHTML += option;
                    commercialFilter.innerHTML += option;
                });
            }
        })
        .catch(error => console.error('Error loading users:', error));
}

function viewAlbumPhotos(albumId) {
    const modal = new bootstrap.Modal(document.getElementById('albumPhotosModal'));
    const content = document.getElementById('albumPhotosContent');
    
    content.innerHTML = '<div class="text-center"><div class="spinner-border" role="status"></div></div>';
    modal.show();
    
    fetch(`../api/posts/get_album_photos.php?album_id=${albumId}`)
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                renderAlbumPhotos(data);
            } else {
                content.innerHTML = `<div class="alert alert-danger">${escapeHtml(data.message)}</div>`;
            }
        })
        .catch(error => {
            content.innerHTML = '<div class="alert alert-danger">Ошибка при загрузке фотографий</div>';
            console.error(error);
        });
}

function renderAlbumPhotos(data) {
    const content = document.getElementById('albumPhotosContent');
    const album = data.album;
    const photos = data.photos;
    
    let html = `
        <div class="mb-4">
            <h5>${escapeHtml(album.title)}</h5>
            ${album.description ? `<p class="text-muted">${escapeHtml(album.description)}</p>` : ''}
            <p><strong>Владелец:</strong> ${escapeHtml(album.owner_name)}</p>
            <p><strong>Публичный:</strong> ${album.is_public == 1 ? 'Да' : 'Нет'}</p>
        </div>
        <div class="row">
    `;
    
    if (photos.length === 0) {
        html += '<div class="col-12"><p class="text-muted text-center">В альбоме нет фотографий</p></div>';
    } else {
        photos.forEach(photo => {
            const photoSrc = normalizeImageUrl(photo.file_path);
            html += `
                <div class="col-md-3 mb-3">
                    <div class="card">
                        <img src="${photoSrc}" 
                             class="card-img-top cursor-pointer-img" 
                             style="height: 150px; object-fit: cover;" 
                             onclick="openImagePreview('${photoSrc.replace(/'/g, "\\'")}', '${escapeHtml(photo.title || 'Без названия').replace(/'/g, "\\'")}', '${escapeHtml(album.owner_name).replace(/'/g, "\\'")}')">
                        <div class="card-body p-2">
                            <p class="small mb-1"><strong>${escapeHtml(photo.title || 'Без названия')}</strong></p>
                            ${photo.location_name ? `<p class="text-muted small mb-0"><i class="fas fa-map-marker-alt me-1"></i>${escapeHtml(photo.location_name)}</p>` : ''}
                        </div>
                    </div>
                </div>
            `;
        });
    }
    
    html += '</div>';
    content.innerHTML = html;
}

function viewCommercialPostDetails(commercialPostId) {
    window.location.href = `commercial_post_details.php?id=${commercialPostId}`;
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleString('ru-RU', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Функция для открытия изображения в модальном окне
function openImagePreview(imageSrc, title, author) {
    const modal = new bootstrap.Modal(document.getElementById('imagePreviewModal'));
    const img = document.getElementById('imagePreviewImg');
    const titleElement = document.getElementById('imagePreviewTitle');
    const infoElement = document.getElementById('imagePreviewInfo');
    
    // Устанавливаем изображение
    img.src = imageSrc;
    
    // Устанавливаем заголовок
    titleElement.textContent = title || 'Просмотр изображения';
    
    // Устанавливаем информацию
    infoElement.innerHTML = `
        <div class="text-white">
            <small><i class="fas fa-user me-2"></i>${escapeHtml(author)}</small>
        </div>
    `;
    
    // Показываем модальное окно
    modal.show();
}


// Функция для просмотра деталей поста с лайками и комментариями
function viewPostDetails(postId) {
    const modal = new bootstrap.Modal(document.getElementById('postDetailsModal'));
    const content = document.getElementById('postDetailsContent');
    
    // Показываем спиннер
    content.innerHTML = `
        <div class="text-center py-5">
            <div class="spinner-border" role="status">
                <span class="visually-hidden">Загрузка...</span>
            </div>
        </div>
    `;
    
    modal.show();
    
    // Загружаем детали поста
    fetch(`../api/posts/get_post_details.php?photo_id=${postId}`)
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                displayPostDetails(data.post, data.likes, data.comments);
            } else {
                content.innerHTML = `<div class="alert alert-danger">Ошибка: ${data.message}</div>`;
            }
        })
        .catch(error => {
            console.error('Error loading post details:', error);
            content.innerHTML = `<div class="alert alert-danger">Ошибка при загрузке деталей поста</div>`;
        });
}

function displayPostDetails(post, likes, comments) {
    const content = document.getElementById('postDetailsContent');
    
    // Формируем HTML для лайков
    const likesHtml = likes && likes.length > 0 ? likes.map(like => `
        <div class="d-flex align-items-center mb-2 pb-2 border-bottom">
            <img src="${normalizeImageUrl(like.image) || '/travel/admin/assets/images/default-avatar.svg'}" 
                 class="rounded-circle me-2" 
                 style="width: 32px; height: 32px; object-fit: cover;"
                 alt="${escapeHtml(like.name)}">
            <div class="flex-grow-1">
                <a href="user_details.php?id=${like.id}" class="text-decoration-none">
                    ${escapeHtml(like.name)}
                </a>
                <small class="text-muted d-block">${formatDate(like.created_at)}</small>
            </div>
        </div>
    `).join('') : '<p class="text-muted">Нет лайков</p>';
    
    // Формируем HTML для комментариев
    const commentsHtml = comments && comments.length > 0 ? comments.map(comment => `
        <div class="d-flex align-items-start mb-3 pb-3 border-bottom">
            <img src="${normalizeImageUrl(comment.user_image) || '/travel/admin/assets/images/default-avatar.svg'}" 
                 class="rounded-circle me-2" 
                 style="width: 32px; height: 32px; object-fit: cover;"
                 alt="${escapeHtml(comment.user_name)}">
            <div class="flex-grow-1">
                <a href="user_details.php?id=${comment.user_id}" class="text-decoration-none fw-bold">
                    ${escapeHtml(comment.user_name)}
                </a>
                <small class="text-muted ms-2">${formatDate(comment.created_at)}</small>
                <p class="mb-0 mt-1">${escapeHtml(comment.text)}</p>
            </div>
        </div>
    `).join('') : '<p class="text-muted">Нет комментариев</p>';
    
    let photoSrc = normalizeImageUrl(post.filePath);
    if (!photoSrc || photoSrc.includes('temp_photo')) {
        photoSrc = '/travel/admin/assets/images/default-avatar.svg';
    }
    
    content.innerHTML = `
        <div class="row">
            <div class="col-md-6">
                <img src="${photoSrc}" 
                     class="img-fluid rounded mb-3" 
                     alt="${escapeHtml(post.title)}"
                     style="max-height: 400px; width: 100%; object-fit: cover;">
                <h5>${escapeHtml(post.title || 'Без названия')}</h5>
                <p><strong>Описание:</strong> ${escapeHtml(post.description || 'Нет описания')}</p>
                <p><strong>Локация:</strong> ${escapeHtml(post.locationName || 'Не указана')}</p>
                <p><strong>Автор:</strong> <a href="user_details.php?id=${post.userId}">${escapeHtml(post.authorName)}</a></p>
                <p><strong>Дата создания:</strong> ${formatDate(post.createdAt)}</p>
            </div>
            <div class="col-md-6">
                <ul class="nav nav-tabs mb-3" role="tablist">
                    <li class="nav-item">
                        <a class="nav-link active" data-bs-toggle="tab" href="#postLikesTab">
                            <i class="bi bi-heart-fill me-1"></i>Лайки (${post.likesCount || 0})
                        </a>
                    </li>
                    <li class="nav-item">
                        <a class="nav-link" data-bs-toggle="tab" href="#postCommentsTab">
                            <i class="bi bi-chat-fill me-1"></i>Комментарии (${post.commentsCount || 0})
                        </a>
                    </li>
                </ul>
                <div class="tab-content" style="max-height: 500px; overflow-y: auto;">
                    <div class="tab-pane fade show active" id="postLikesTab">
                        ${likesHtml}
                    </div>
                    <div class="tab-pane fade" id="postCommentsTab">
                        ${commentsHtml}
                    </div>
                </div>
            </div>
        </div>
    `;
}


// Save and restore table pages
$(document).ready(function() {
    // Wait for tables to initialize
    setTimeout(function() {
        if (typeof postsTable !== 'undefined' && postsTable) {
            postsTable.on('page.dt', function() {
                const info = postsTable.page.info();
                localStorage.setItem('postsTablePage', info.page);
            });
        }
        
        if (typeof albumsTable !== 'undefined' && albumsTable) {
            albumsTable.on('page.dt', function() {
                const info = albumsTable.page.info();
                localStorage.setItem('albumsTablePage', info.page);
            });
        }
        
        if (typeof commercialTable !== 'undefined' && commercialTable) {
            commercialTable.on('page.dt', function() {
                const info = commercialTable.page.info();
                localStorage.setItem('commercialTablePage', info.page);
            });
        }
    }, 1000);
});
