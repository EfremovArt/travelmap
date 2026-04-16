$(document).ready(function() {
    let currentType = 'all';
    let tables = {};
    
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
    
    // Initialize DataTable for a specific type
    function initDataTable(type, tableId, filters = {}) {
        if (tables[type]) {
            tables[type].destroy();
        }
        
        const columns = getColumnsForType(type);
        
        tables[type] = $(tableId).DataTable({
            processing: true,
            serverSide: true,
            ajax: {
                url: '../api/favorites/get_all_favorites.php',
                type: 'GET',
                data: function(d) {
                    // Map DataTables parameters to our API
                    return {
                        page: Math.floor(d.start / d.length) + 1,
                        per_page: d.length,
                        search: d.search.value,
                        sort_by: getSortColumn(d.order[0].column, type),
                        sort_order: d.order[0].dir,
                        type: type,
                        user_id: filters.user_id || '',
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
                    
                    return json.favorites;
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
            columns: columns,
            order: getDefaultOrder(type),
            pageLength: 50,
            lengthMenu: [[25, 50, 100], [25, 50, 100]],
            language: {
                url: '//cdn.datatables.net/plug-ins/1.13.7/i18n/ru.json'
            },
            dom: '<"row"<"col-sm-12 col-md-6"l><"col-sm-12 col-md-6"f>>rtip'
        });
    }
    
    // Get columns configuration based on type
    function getColumnsForType(type) {
        const baseColumns = [
            { 
                data: 'id',
                width: '50px'
            },
            { 
                data: null,
                render: function(data, type, row) {
                    let img = '';
                    if (row.userImage) {
                        const userImageSrc = normalizeImageUrl(row.userImage);
                        img = `<img src="${userImageSrc}" class="rounded-circle me-2" style="width: 30px; height: 30px; object-fit: cover;">`;
                    } else {
                        img = `<div class="rounded-circle bg-secondary d-inline-block me-2" style="width: 30px; height: 30px;"></div>`;
                    }
                    return img + escapeHtml(row.userName);
                },
                orderable: true
            }
        ];
        
        if (type === 'all') {
            return [
                ...baseColumns,
                {
                    data: 'contentType',
                    render: function(data) {
                        const typeLabels = {
                            'photo': '<span class="badge bg-primary">Фото</span>',
                            'album': '<span class="badge bg-success">Альбом</span>',
                            'commercial': '<span class="badge bg-warning text-dark">Коммерческий</span>'
                        };
                        return typeLabels[data] || data;
                    },
                    orderable: false
                },
                {
                    data: 'contentTitle',
                    render: function(data, type, row) {
                        return `<a href="#" class="text-decoration-none" onclick="viewContent('${row.contentType}', ${row.contentId}); return false;">
                                    ${escapeHtml(data || 'Без названия')}
                                </a>`;
                    },
                    orderable: true
                },
                {
                    data: 'locationName',
                    render: function(data) {
                        return escapeHtml(data || 'Не указана');
                    }
                },
                {
                    data: 'createdAt',
                    render: function(data) {
                        return formatDateTime(data);
                    },
                    orderable: true
                },
                {
                    data: 'contentPreview',
                    render: function(data, type, row) {
                        if (data) {
                            const previewSrc = normalizeImageUrl(data);
                            return `<img src="${previewSrc}" class="img-thumbnail" style="width: 60px; height: 60px; object-fit: cover; cursor: pointer;" 
                                    onclick="showImagePreview('${previewSrc}')" 
                                    title="Нажмите для увеличения">`;
                        }
                        return '<span class="text-muted">Нет изображения</span>';
                    },
                    orderable: false
                }
            ];
        } else if (type === 'photo') {
            return [
                ...baseColumns,
                {
                    data: 'contentTitle',
                    render: function(data, type, row) {
                        return `<a href="#" class="text-decoration-none" onclick="viewContent('photo', ${row.contentId}); return false;">
                                    ${escapeHtml(data || 'Без названия')}
                                </a>`;
                    },
                    orderable: true
                },
                {
                    data: 'locationName',
                    render: function(data) {
                        return escapeHtml(data || 'Не указана');
                    }
                },
                {
                    data: 'createdAt',
                    render: function(data) {
                        return formatDateTime(data);
                    },
                    orderable: true
                },
                {
                    data: 'contentPreview',
                    render: function(data) {
                        if (data) {
                            const previewSrc = normalizeImageUrl(data);
                            return `<img src="${previewSrc}" class="img-thumbnail" style="width: 60px; height: 60px; object-fit: cover; cursor: pointer;"
                                    title="Нажмите для увеличения">`;
                        }
                        return '<span class="text-muted">Нет изображения</span>';
                    },
                    orderable: false
                }
            ];
        } else if (type === 'album') {
            return [
                ...baseColumns,
                {
                    data: 'contentTitle',
                    render: function(data, type, row) {
                        return `<a href="#" class="text-decoration-none" onclick="viewContent('album', ${row.contentId}); return false;">
                                    ${escapeHtml(data || 'Без названия')}
                                </a>`;
                    },
                    orderable: true
                },
                {
                    data: 'createdAt',
                    render: function(data) {
                        return formatDateTime(data);
                    },
                    orderable: true
                },
                {
                    data: 'contentPreview',
                    render: function(data) {
                        if (data) {
                            const previewSrc = normalizeImageUrl(data);
                            return `<img src="${previewSrc}" class="img-thumbnail" style="width: 60px; height: 60px; object-fit: cover; cursor: pointer;"
                                    title="Нажмите для увеличения">`;
                        }
                        return '<span class="text-muted">Нет изображения</span>';
                    },
                    orderable: false
                }
            ];
        } else if (type === 'commercial') {
            return [
                ...baseColumns,
                {
                    data: 'contentTitle',
                    render: function(data, type, row) {
                        return `<a href="#" class="text-decoration-none" onclick="viewContent('commercial', ${row.contentId}); return false;">
                                    ${escapeHtml(data || 'Без названия')}
                                </a>`;
                    },
                    orderable: true
                },
                {
                    data: 'locationName',
                    render: function(data) {
                        return escapeHtml(data || 'Не указана');
                    }
                },
                {
                    data: 'createdAt',
                    render: function(data) {
                        return formatDateTime(data);
                    },
                    orderable: true
                },
                {
                    data: 'contentPreview',
                    render: function(data) {
                        if (data) {
                            const previewSrc = normalizeImageUrl(data);
                            return `<img src="${previewSrc}" class="img-thumbnail" style="width: 60px; height: 60px; object-fit: cover; cursor: pointer;"
                                    title="Нажмите для увеличения">`;
                        }
                        return '<span class="text-muted">Нет изображения</span>';
                    },
                    orderable: false
                }
            ];
        }
    }
    
    // Get default order based on type
    function getDefaultOrder(type) {
        if (type === 'all') {
            return [[5, 'desc']]; // Sort by created_at
        } else if (type === 'album') {
            return [[3, 'desc']]; // Sort by created_at
        } else {
            return [[4, 'desc']]; // Sort by created_at
        }
    }
    
    // Get sort column name
    function getSortColumn(columnIndex, type) {
        if (type === 'all') {
            const columns = ['id', 'user_name', 'contentType', 'content_title', 'locationName', 'created_at', 'contentPreview'];
            return columns[columnIndex] || 'created_at';
        } else if (type === 'album') {
            const columns = ['id', 'user_name', 'content_title', 'created_at', 'contentPreview'];
            return columns[columnIndex] || 'created_at';
        } else {
            const columns = ['id', 'user_name', 'content_title', 'locationName', 'created_at', 'contentPreview'];
            return columns[columnIndex] || 'created_at';
        }
    }
    
    // Initialize all tables on page load
    initDataTable('all', '#favoritesTable');
    
    // Handle tab switching
    $('button[data-bs-toggle="tab"]').on('shown.bs.tab', function (e) {
        const type = $(e.target).data('type');
        currentType = type;
        
        // Update type filter select
        $('#typeFilter').val(type);
        
        // Initialize table for this type if not already initialized
        const tableId = type === 'all' ? '#favoritesTable' : 
                       type === 'photo' ? '#photoFavoritesTable' :
                       type === 'album' ? '#albumFavoritesTable' :
                       '#commercialFavoritesTable';
        
        if (!tables[type]) {
            const filters = {
                user_id: $('#userFilter').val()
            };
            initDataTable(type, tableId, filters);
        }
    });
    
    // Handle filter form submission
    $('#filterForm').on('submit', function(e) {
        e.preventDefault();
        
        const selectedType = $('#typeFilter').val();
        const filters = {
            user_id: $('#userFilter').val()
        };
        
        // Switch to the selected tab
        if (selectedType !== currentType) {
            $(`button[data-type="${selectedType}"]`).tab('show');
        }
        
        // Reload the current table
        const tableId = selectedType === 'all' ? '#favoritesTable' : 
                       selectedType === 'photo' ? '#photoFavoritesTable' :
                       selectedType === 'album' ? '#albumFavoritesTable' :
                       '#commercialFavoritesTable';
        
        initDataTable(selectedType, tableId, filters);
    });
    
    // Handle reset filters
    $('#resetFilters').on('click', function() {
        $('#filterForm')[0].reset();
        $('#typeFilter').val('all');
        $('button[data-type="all"]').tab('show');
        initDataTable('all', '#favoritesTable');
    });
    
    // View content details
    window.viewContent = function(contentType, contentId) {
        // Show loading
        Swal.fire({
            title: 'Загрузка...',
            allowOutsideClick: false,
            didOpen: () => {
                Swal.showLoading();
            }
        });
        
        let apiUrl = '';
        
        if (contentType === 'photo') {
            apiUrl = `../api/posts/get_post_details.php?photo_id=${contentId}`;
        } else if (contentType === 'album') {
            apiUrl = `../api/posts/get_album_photos.php?album_id=${contentId}`;
        } else if (contentType === 'commercial') {
            apiUrl = `../api/posts/get_commercial_post_relations.php?commercial_post_id=${contentId}`;
        }
        
        $.ajax({
            url: apiUrl,
            method: 'GET',
            dataType: 'json',
            success: function(response) {
                if (response.success) {
                    let html = '';
                    
                    if (contentType === 'photo') {
                        const post = response.post;
                        html = `
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
                    } else if (contentType === 'album') {
                        const album = response.album;
                        const photos = response.photos || [];
                        
                        let photosHtml = '';
                        if (photos.length > 0) {
                            photosHtml = '<div class="row g-2 mt-2">';
                            photos.slice(0, 6).forEach(photo => {
                                photosHtml += `
                                    <div class="col-4">
                                        <img src="${photo.file_path}" class="img-fluid rounded" 
                                             style="width: 100%; height: 100px; object-fit: cover;"
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
                        
                        html = `
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
                    } else if (contentType === 'commercial') {
                        const cp = response.commercialPost;
                        const relatedPhotos = response.relatedPhotos || [];
                        const relatedAlbums = response.relatedAlbums || [];
                        const displayedIn = response.displayedInPhotos || [];
                        
                        let previewHtml = '';
                        if (relatedPhotos.length > 0) {
                            const photo = relatedPhotos[0];
                            previewHtml = `
                                <div class="mb-3">
                                    <img src="${normalizeImageUrl(photo.preview)}" class="img-fluid rounded" 
                                         style="max-height: 300px; width: 100%; object-fit: contain;">
                                </div>
                            `;
                        }
                        
                        let relatedHtml = '';
                        if (cp.type === 'album' && relatedAlbums.length > 0) {
                            const album = relatedAlbums[0];
                            relatedHtml = `
                                <div class="mt-2">
                                    <strong>Связанный альбом:</strong><br>
                                    ${escapeHtml(album.title || 'Без названия')} (${album.photos_count || 0} фото)
                                </div>
                            `;
                        } else if (cp.type === 'photo' && relatedPhotos.length > 0) {
                            const photo = relatedPhotos[0];
                            relatedHtml = `
                                <div class="mt-2">
                                    <strong>Связанное фото:</strong><br>
                                    ${escapeHtml(photo.title || 'Без названия')}
                                    ${photo.location_name ? `<br><small class="text-muted">${escapeHtml(photo.location_name)}</small>` : ''}
                                </div>
                            `;
                        }
                        
                        let displayedInHtml = '';
                        if (displayedIn.length > 0) {
                            displayedInHtml = `
                                <hr>
                                <h6>Отображается в фотографиях (${displayedIn.length}):</h6>
                                <div class="row g-2">
                            `;
                            displayedIn.slice(0, 4).forEach(photo => {
                                displayedInHtml += `
                                    <div class="col-3">
                                        <img src="${normalizeImageUrl(photo.preview)}" class="img-fluid rounded" 
                                             style="width: 100%; height: 60px; object-fit: cover;"
                                             title="${escapeHtml(photo.title || '')}">
                                    </div>
                                `;
                            });
                            displayedInHtml += '</div>';
                            if (displayedIn.length > 4) {
                                displayedInHtml += `<p class="text-muted mt-2">И ещё ${displayedIn.length - 4}...</p>`;
                            }
                        }
                        
                        html = `
                            <div class="text-start">
                                ${previewHtml}
                                <h5>${escapeHtml(cp.title || 'Без названия')}</h5>
                                ${cp.description ? `<p class="text-muted">${escapeHtml(cp.description)}</p>` : ''}
                                <hr>
                                <div class="row">
                                    <div class="col-6">
                                        <strong>Автор:</strong><br>
                                        ${escapeHtml(cp.user_name || 'Неизвестен')}
                                    </div>
                                    <div class="col-6">
                                        <strong>Дата создания:</strong><br>
                                        ${formatDateTime(cp.created_at)}
                                    </div>
                                </div>
                                <div class="mt-2">
                                    <strong>Тип:</strong> 
                                    <span class="badge ${cp.type === 'album' ? 'bg-success' : 'bg-primary'}">
                                        ${cp.type === 'album' ? 'Альбом' : 'Фото'}
                                    </span>
                                </div>
                                <div class="mt-2">
                                    <strong>Статус:</strong> 
                                    <span class="badge ${cp.is_active == 1 ? 'bg-success' : 'bg-danger'}">
                                        ${cp.is_active == 1 ? 'Активен' : 'Неактивен'}
                                    </span>
                                </div>
                                ${cp.latitude && cp.longitude ? `
                                <div class="mt-2">
                                    <strong>Координаты:</strong> ${cp.latitude}, ${cp.longitude}
                                </div>
                                ` : ''}
                                ${relatedHtml}
                                ${displayedInHtml}
                            </div>
                        `;
                    }
                    
                    Swal.fire({
                        title: contentType === 'photo' ? 'Детали фотографии' : 
                               contentType === 'album' ? 'Детали альбома' : 
                               'Детали коммерческого поста',
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
                console.error('Error loading content details:', error);
                Swal.fire({
                    icon: 'error',
                    title: 'Ошибка загрузки',
                    text: 'Не удалось загрузить детали контента'
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
