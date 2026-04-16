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
        
        table = $('#likesTable').DataTable({
            processing: true,
            serverSide: true,
            ajax: {
                url: '../api/likes/get_all_likes.php',
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
                        photo_id: filters.photo_id || ''
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
                    
                    return json.likes;
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
                    data: 'photoTitle',
                    render: function(data, type, row) {
                        return `<a href="#" class="text-decoration-none" onclick="viewPhoto(${row.photoId}); return false;">
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
                    data: 'photoPreview',
                    render: function(data, type, row) {
                        if (data) {
                            const photoSrc = normalizeImageUrl(data);
                            const imgSrc = photoSrc.startsWith('http') ? photoSrc : `../../../${photoSrc}`;
                            return `<img src="${imgSrc}" class="img-thumbnail" style="width: 60px; height: 60px; object-fit: cover; cursor: pointer;" 
                                    onclick="showImagePreview('${imgSrc}')" 
                                    title="Нажмите для увеличения">`;
                        }
                        return '<span class="text-muted">Нет изображения</span>';
                    },
                    orderable: false
                }
            ],
            order: [[5, 'desc']], // Sort by created_at descending by default
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
        const columns = ['id', 'user_name', 'userEmail', 'photo_title', 'locationName', 'created_at', 'photoPreview'];
        return columns[columnIndex] || 'created_at';
    }
    
    // Initialize table on page load
    initDataTable();
    
    // Handle filter form submission
    $('#filterForm').on('submit', function(e) {
        e.preventDefault();
        
        const filters = {
            user_id: $('#userFilter').val(),
            photo_id: $('#photoFilter').val()
        };
        
        initDataTable(filters);
    });
    
    // Handle reset filters
    $('#resetFilters').on('click', function() {
        $('#filterForm')[0].reset();
        initDataTable();
    });
    
    // View photo details
    window.viewPhoto = function(photoId) {
        // Показываем загрузку
        Swal.fire({
            title: 'Загрузка...',
            allowOutsideClick: false,
            didOpen: () => {
                Swal.showLoading();
            }
        });
        
        // Загружаем данные поста
        $.ajax({
            url: `../api/posts/get_post_details.php?photo_id=${photoId}`,
            type: 'GET',
            success: function(response) {
                if (response.success) {
                    const post = response.post;
                    const imageUrl = post.filePath ? (post.filePath.startsWith('http') ? post.filePath : `../../../${post.filePath}`) : '';
                    
                    Swal.fire({
                        title: post.title || 'Без названия',
                        html: `
                            <div style="text-align: left;">
                                ${imageUrl ? `<img src="${imageUrl}" style="width: 100%; max-height: 400px; object-fit: contain; margin-bottom: 15px;">` : ''}
                                <p><strong>Описание:</strong> ${post.description || 'Нет описания'}</p>
                                <p><strong>Автор:</strong> ${post.authorName}</p>
                                <p><strong>Локация:</strong> ${post.locationName || 'Не указана'}</p>
                                <p><strong>Дата создания:</strong> ${new Date(post.createdAt).toLocaleString('ru-RU')}</p>
                                <hr>
                                <p><strong>Статистика:</strong></p>
                                <ul>
                                    <li>Лайков: ${post.likesCount}</li>
                                    <li>Комментариев: ${post.commentsCount}</li>
                                    <li>В избранном: ${post.favoritesCount}</li>
                                </ul>
                            </div>
                        `,
                        width: '600px',
                        showCloseButton: true,
                        confirmButtonText: 'Закрыть'
                    });
                } else {
                    Swal.fire({
                        icon: 'error',
                        title: 'Ошибка',
                        text: response.message || 'Не удалось загрузить данные поста'
                    });
                }
            },
            error: function() {
                Swal.fire({
                    icon: 'error',
                    title: 'Ошибка',
                    text: 'Не удалось загрузить данные поста'
                });
            }
        });
    };
    
    // Show image preview
    window.showImagePreview = function(imagePath) {
        Swal.fire({
            imageUrl: imagePath,
            imageAlt: 'Превью фотографии',
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
