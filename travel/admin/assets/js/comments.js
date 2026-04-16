$(document).ready(function() {
    let table;
    
    // Helper function to normalize image URLs
    function normalizeImageUrl(url) {
        if (!url) return '';
        // If it's already an external URL (starts with http:// or https://), return as is
        if (url.startsWith('http://') || url.startsWith('https://')) {
            return url;
        }
        // Otherwise, it's a relative path, return as is
        return url;
    }
    
    // Initialize DataTables
    function initDataTable(filters = {}) {
        if (table) {
            table.destroy();
        }
        
        table = $('#commentsTable').DataTable({
            processing: true,
            serverSide: true,
            ajax: {
                url: '../api/comments/get_all_comments.php',
                type: 'GET',
                data: function(d) {
                    // Map DataTables parameters to our API
                    return {
                        page: Math.floor(d.start / d.length) + 1,
                        per_page: d.length,
                        search: d.search.value,
                        sort_by: getSortColumn(d.order[0].column),
                        sort_order: d.order[0].dir,
                        user_id: filters.user_id || '',
                        photo_id: filters.photo_id || '',
                        album_id: filters.album_id || ''
                    };
                },
                dataSrc: function(json) {
                    if (!json.success) {
                        Swal.fire({
                            icon: 'error',
                            title: 'Ошибка',
                            text: json.message || 'Не удалось загрузить данные'
                        });
                        return [];
                    }
                    
                    // Set total records for pagination
                    json.recordsTotal = json.pagination.total;
                    json.recordsFiltered = json.pagination.total;
                    
                    return json.comments;
                },
                error: function(xhr, error, thrown) {
                    console.error('DataTables error:', error, thrown);
                    Swal.fire({
                        icon: 'error',
                        title: 'Ошибка загрузки',
                        text: 'Не удалось загрузить данные. Проверьте консоль для деталей.'
                    });
                }
            },
            columns: [
                { 
                    data: 'id',
                    width: '50px'
                },
                { 
                    data: 'commentType',
                    render: function(data) {
                        if (data === 'photo') {
                            return '<span class="badge bg-primary">Пост</span>';
                        } else if (data === 'album') {
                            return '<span class="badge bg-info">Альбом</span>';
                        }
                        return '<span class="badge bg-secondary">Неизвестно</span>';
                    },
                    width: '80px',
                    orderable: false
                },
                { 
                    data: null,
                    render: function(data, type, row) {
                        let img = '';
                        if (row.userProfileImage) {
                            const profileImageSrc = normalizeImageUrl(row.userProfileImage);
                            // If it's external URL, use as is, otherwise add relative path
                            const imgSrc = profileImageSrc.startsWith('http') ? profileImageSrc : `../../../${profileImageSrc}`;
                            img = `<img src="${imgSrc}" class="rounded-circle me-2" style="width: 30px; height: 30px; object-fit: cover;">`;
                        } else {
                            img = `<div class="rounded-circle bg-secondary d-inline-block me-2" style="width: 30px; height: 30px;"></div>`;
                        }
                        return img + escapeHtml(row.userName);
                    },
                    orderable: true
                },
                { 
                    data: 'userEmail',
                    render: function(data) {
                        return escapeHtml(data);
                    }
                },
                { 
                    data: null,
                    render: function(data, type, row) {
                        if (row.commentType === 'photo' && row.photoTitle) {
                            return `<a href="#" class="text-decoration-none" onclick="viewPhoto(${row.photoId}); return false;">
                                        ${escapeHtml(row.photoTitle)}
                                    </a>`;
                        } else if (row.commentType === 'album' && row.albumTitle) {
                            return `<a href="#" class="text-decoration-none" onclick="viewAlbum(${row.albumId}); return false;">
                                        ${escapeHtml(row.albumTitle)}
                                    </a>`;
                        }
                        return '<span class="text-muted">Не указано</span>';
                    },
                    orderable: false
                },
                { 
                    data: 'commentText',
                    render: function(data) {
                        const maxLength = 100;
                        const text = escapeHtml(data || '');
                        if (text.length > maxLength) {
                            return `<span title="${text}">${text.substring(0, maxLength)}...</span>`;
                        }
                        return text;
                    },
                    orderable: false
                },
                { 
                    data: 'createdAt',
                    render: function(data) {
                        return formatDateTime(data);
                    },
                    orderable: true
                },
                { 
                    data: null,
                    render: function(data, type, row) {
                        return `<button class="btn btn-sm btn-danger" onclick="deleteComment(${row.id}, '${row.commentType}'); return false;">
                                    <i class="bi bi-trash"></i> Удалить
                                </button>`;
                    },
                    orderable: false,
                    width: '100px'
                }
            ],
            order: [[6, 'desc']], // Sort by created_at descending by default
            pageLength: 50,
            lengthMenu: [[25, 50, 100], [25, 50, 100]],
            language: {
                url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/ru.json'
            },
            dom: '<"row"<"col-sm-12 col-md-6"l><"col-sm-12 col-md-6"f>>rtip'
        });
    }
    
    // Get sort column name
    function getSortColumn(columnIndex) {
        const columns = ['id', 'comment_type', 'user_name', 'userEmail', 'content', 'commentText', 'created_at', 'actions'];
        return columns[columnIndex] || 'created_at';
    }
    
    // Initialize table on page load
    initDataTable();
    
    // Handle filter form submission
    $('#filterForm').on('submit', function(e) {
        e.preventDefault();
        
        const filters = {
            user_id: $('#userFilter').val(),
            photo_id: $('#photoFilter').val(),
            album_id: $('#albumFilter').val()
        };
        
        initDataTable(filters);
    });
    
    // Handle reset filters
    $('#resetFilters').on('click', function() {
        $('#filterForm')[0].reset();
        initDataTable();
    });
    
    // Delete comment with confirmation
    window.deleteComment = function(commentId, commentType) {
        Swal.fire({
            title: 'Удалить комментарий?',
            text: 'Это действие нельзя отменить!',
            icon: 'warning',
            showCancelButton: true,
            confirmButtonColor: '#d33',
            cancelButtonColor: '#3085d6',
            confirmButtonText: 'Да, удалить',
            cancelButtonText: 'Отмена'
        }).then((result) => {
            if (result.isConfirmed) {
                performDelete(commentId, commentType);
            }
        });
    };
    
    // Perform delete operation
    function performDelete(commentId, commentType) {
        $.ajax({
            url: '../api/comments/delete_comment.php',
            type: 'POST',
            contentType: 'application/json',
            headers: {
                'X-CSRF-Token': window.csrfToken
            },
            data: JSON.stringify({
                commentId: commentId,
                commentType: commentType,
                csrf_token: window.csrfToken
            }),
            success: function(response) {
                if (response.success) {
                    Swal.fire({
                        icon: 'success',
                        title: 'Успешно',
                        text: response.message || 'Комментарий удален',
                        timer: 2000,
                        showConfirmButton: false
                    });
                    table.ajax.reload(null, false); // Reload table without resetting pagination
                } else {
                    Swal.fire({
                        icon: 'error',
                        title: 'Ошибка',
                        text: response.message || 'Не удалось удалить комментарий'
                    });
                }
            },
            error: function(xhr, status, error) {
                console.error('Delete error:', error);
                Swal.fire({
                    icon: 'error',
                    title: 'Ошибка',
                    text: 'Не удалось удалить комментарий. Проверьте консоль для деталей.'
                });
            }
        });
    }
    
    // View photo details
    window.viewPhoto = function(photoId) {
        // Show loading
        Swal.fire({
            title: 'Загрузка...',
            allowOutsideClick: false,
            didOpen: () => {
                Swal.showLoading();
            }
        });
        
        $.ajax({
            url: `../api/posts/get_post_details.php?photo_id=${photoId}`,
            method: 'GET',
            dataType: 'json',
            success: function(response) {
                if (response.success) {
                    const post = response.post;
                    const html = `
                        <div class="text-start">
                            <div class="mb-3">
                                <img src="${post.filePath}" class="img-fluid rounded" style="max-height: 400px; width: 100%; object-fit: contain;">
                            </div>
                            <h5>${escapeHtml(post.title || 'Без названия')}</h5>
                            ${post.description ? `<p class="text-muted">${escapeHtml(post.description)}</p>` : ''}
                            <hr>
                            <div class="row">
                                <div class="col-6">
                                    <strong>Автор:</strong><br>
                                    <a href="users.php?user_id=${post.authorId}" class="text-decoration-none">
                                        ${escapeHtml(post.authorName)}
                                    </a>
                                </div>
                                <div class="col-6">
                                    <strong>Дата создания:</strong><br>
                                    ${formatDateTime(post.createdAt)}
                                </div>
                            </div>
                            ${post.locationName ? `
                            <div class="mt-2">
                                <strong>Локация:</strong> ${escapeHtml(post.locationName)}
                            </div>
                            ` : ''}
                            <hr>
                            <div class="row text-center">
                                <div class="col-4">
                                    <i class="bi bi-heart-fill text-danger"></i> ${post.likesCount}<br>
                                    <small class="text-muted">Лайков</small>
                                </div>
                                <div class="col-4">
                                    <i class="bi bi-chat-fill text-primary"></i> ${post.commentsCount}<br>
                                    <small class="text-muted">Комментариев</small>
                                </div>
                                <div class="col-4">
                                    <i class="bi bi-star-fill text-warning"></i> ${post.favoritesCount}<br>
                                    <small class="text-muted">В избранном</small>
                                </div>
                            </div>
                        </div>
                    `;
                    
                    Swal.fire({
                        title: 'Детали фотографии',
                        html: html,
                        width: '800px',
                        showCloseButton: true,
                        showConfirmButton: false,
                        customClass: {
                            popup: 'text-start'
                        }
                    });
                } else {
                    Swal.fire({
                        icon: 'error',
                        title: 'Ошибка',
                        text: response.message || 'Не удалось загрузить данные'
                    });
                }
            },
            error: function(xhr, status, error) {
                console.error('Error loading photo details:', error);
                Swal.fire({
                    icon: 'error',
                    title: 'Ошибка загрузки',
                    text: 'Не удалось загрузить детали фотографии'
                });
            }
        });
    };
    
    // View album details
    window.viewAlbum = function(albumId) {
        // Show loading
        Swal.fire({
            title: 'Загрузка...',
            allowOutsideClick: false,
            didOpen: () => {
                Swal.showLoading();
            }
        });
        
        $.ajax({
            url: `../api/posts/get_album_photos.php?album_id=${albumId}`,
            method: 'GET',
            dataType: 'json',
            success: function(response) {
                if (response.success) {
                    const album = response.album;
                    const photos = response.photos || [];
                    
                    let photosHtml = '';
                    if (photos.length > 0) {
                        photosHtml = '<div class="row g-2 mt-2">';
                        photos.slice(0, 6).forEach(photo => {
                            photosHtml += `
                                <div class="col-4">
                                    <img src="${photo.file_path}" class="img-fluid rounded" 
                                         style="width: 100%; height: 100px; object-fit: cover; cursor: pointer;"
                                         onclick="showImagePreview('${photo.file_path}')"
                                         title="${escapeHtml(photo.title || '')}">
                                </div>
                            `;
                        });
                        photosHtml += '</div>';
                        if (photos.length > 6) {
                            photosHtml += `<p class="text-muted mt-2">И ещё ${photos.length - 6} фото...</p>`;
                        }
                    } else {
                        photosHtml = '<p class="text-muted">Альбом пуст</p>';
                    }
                    
                    const html = `
                        <div class="text-start">
                            <h5>${escapeHtml(album.title || 'Без названия')}</h5>
                            ${album.description ? `<p class="text-muted">${escapeHtml(album.description)}</p>` : ''}
                            <hr>
                            <div class="row">
                                <div class="col-6">
                                    <strong>Владелец:</strong><br>
                                    ${escapeHtml(album.owner_name || 'Неизвестен')}
                                </div>
                                <div class="col-6">
                                    <strong>Дата создания:</strong><br>
                                    ${formatDateTime(album.created_at)}
                                </div>
                            </div>
                            <div class="mt-2">
                                <strong>Статус:</strong> 
                                <span class="badge ${album.is_public == 1 ? 'bg-success' : 'bg-secondary'}">
                                    ${album.is_public == 1 ? 'Публичный' : 'Приватный'}
                                </span>
                            </div>
                            <div class="mt-2">
                                <strong>Фотографий:</strong> ${photos.length}
                            </div>
                            <hr>
                            <h6>Фотографии в альбоме:</h6>
                            ${photosHtml}
                        </div>
                    `;
                    
                    Swal.fire({
                        title: 'Детали альбома',
                        html: html,
                        width: '800px',
                        showCloseButton: true,
                        showConfirmButton: false,
                        customClass: {
                            popup: 'text-start'
                        }
                    });
                } else {
                    Swal.fire({
                        icon: 'error',
                        title: 'Ошибка',
                        text: response.message || 'Не удалось загрузить данные'
                    });
                }
            },
            error: function(xhr, status, error) {
                console.error('Error loading album details:', error);
                Swal.fire({
                    icon: 'error',
                    title: 'Ошибка загрузки',
                    text: 'Не удалось загрузить детали альбома'
                });
            }
        });
    };
    
    // Show image preview
    window.showImagePreview = function(imagePath) {
        Swal.fire({
            imageUrl: imagePath,
            imageAlt: 'Превью изображения',
            showCloseButton: true,
            showConfirmButton: false,
            width: 'auto',
            customClass: {
                image: 'img-fluid'
            }
        });
    };
    
    // Escape HTML to prevent XSS
    function escapeHtml(text) {
        if (!text) return '';
        const map = {
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#039;'
        };
        return text.toString().replace(/[&<>"']/g, function(m) { return map[m]; });
    }
    
    // Format datetime
    function formatDateTime(datetime) {
        if (!datetime) return '';
        const date = new Date(datetime);
        return date.toLocaleString('ru-RU', {
            year: 'numeric',
            month: '2-digit',
            day: '2-digit',
            hour: '2-digit',
            minute: '2-digit'
        });
    }
});
