let currentPage = parseInt(localStorage.getItem('moderationPage')) || 1;
let currentFilters = {};
let selectedPhotos = new Set();

// Track when user started viewing each tab (for real-time count updates)
let photosViewStartTime = null;
let commentsViewStartTime = null;

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

document.addEventListener('DOMContentLoaded', function() {
    // Check if we're on the moderation page
    if (!document.getElementById('photoGallery')) {
        return;
    }
    
    // Fix Bootstrap modal aria-hidden issue and backdrop cleanup
    const modalEl = document.getElementById('photoPreviewModal');
    if (modalEl) {
        modalEl.addEventListener('hidden.bs.modal', function() {
            // Remove aria-hidden from container-fluid that Bootstrap adds
            const containers = document.querySelectorAll('.container-fluid[aria-hidden="true"]');
            containers.forEach(container => {
                container.removeAttribute('aria-hidden');
            });
            // Remove aria-hidden from modal itself
            modalEl.removeAttribute('aria-hidden');
            
            // Clean up any leftover backdrops
            const backdrops = document.querySelectorAll('.modal-backdrop');
            backdrops.forEach(backdrop => backdrop.remove());
            
            // Remove modal-open class from body
            document.body.classList.remove('modal-open');
            document.body.style.overflow = '';
            document.body.style.paddingRight = '';
        });
        
        // Also remove aria-hidden when modal is shown
        modalEl.addEventListener('shown.bs.modal', function() {
            modalEl.removeAttribute('aria-hidden');
        });
    }
    
    loadPhotos();
    
    // Auto-search on user input
    let searchTimeout;
    const filterUser = document.getElementById('filterUser');
    if (filterUser) {
        filterUser.addEventListener('input', function() {
            clearTimeout(searchTimeout);
            searchTimeout = setTimeout(() => {
                applyFilters();
            }, 500); // Задержка 500мс после последнего ввода
        });
    }
    
    // Date filters
    const filterDateFrom = document.getElementById('filterDateFrom');
    const filterDateTo = document.getElementById('filterDateTo');
    
    if (filterDateFrom) {
        filterDateFrom.addEventListener('change', function() {
            applyFilters();
        });
    }
    
    if (filterDateTo) {
        filterDateTo.addEventListener('change', function() {
            applyFilters();
        });
    }
    
    // Reset filters
    const resetFilters = document.getElementById('resetFilters');
    if (resetFilters) {
        resetFilters.addEventListener('click', function() {
            document.getElementById('filterUser').value = '';
            document.getElementById('filterDateFrom').value = '';
            document.getElementById('filterDateTo').value = '';
            currentFilters = {};
            currentPage = 1;
            localStorage.setItem('moderationPage', 1);
            selectedPhotos.clear();
            updateSelectedCount();
            loadPhotos();
        });
    }
    
    // Select all checkbox
    const selectAll = document.getElementById('selectAll');
    if (selectAll) {
        selectAll.addEventListener('change', function() {
            const checkboxes = document.querySelectorAll('.photo-checkbox');
            checkboxes.forEach(checkbox => {
                checkbox.checked = this.checked;
                const photoId = parseInt(checkbox.dataset.photoId);
                if (this.checked) {
                    selectedPhotos.add(photoId);
                } else {
                    selectedPhotos.delete(photoId);
                }
            });
            updateSelectedCount();
        });
    }
    
    // Bulk delete button
    const bulkDeleteBtn = document.getElementById('bulkDeleteBtn');
    if (bulkDeleteBtn) {
        bulkDeleteBtn.addEventListener('click', function() {
            if (selectedPhotos.size === 0) return;
            
            Swal.fire({
                title: 'Подтверждение удаления',
                text: `Вы уверены, что хотите удалить ${selectedPhotos.size} фотографий? Это действие нельзя отменить.`,
                icon: 'warning',
                showCancelButton: true,
                confirmButtonColor: '#d33',
                cancelButtonColor: '#6c757d',
                confirmButtonText: 'Да, удалить',
                cancelButtonText: 'Отмена'
            }).then((result) => {
                if (result.isConfirmed) {
                    bulkDeletePhotos();
                }
            });
        });
    }
});

function applyFilters() {
    currentFilters = {};
    
    const userSearch = document.getElementById('filterUser').value.trim();
    const dateFrom = document.getElementById('filterDateFrom').value;
    const dateTo = document.getElementById('filterDateTo').value;
    
    if (userSearch) currentFilters.user_search = userSearch;
    if (dateFrom) currentFilters.date_from = dateFrom;
    if (dateTo) currentFilters.date_to = dateTo;
    
    currentPage = 1;
    localStorage.setItem('moderationPage', 1);
    selectedPhotos.clear();
    updateSelectedCount();
    loadPhotos();
}

function loadPhotos(preserveScroll = false) {
    const gallery = document.getElementById('photoGallery');
    const loading = document.getElementById('loadingSpinner');
    const noPhotos = document.getElementById('noPhotos');
    
    // Save current scroll position if needed
    const scrollPosition = preserveScroll ? window.pageYOffset : null;
    
    // Don't hide gallery during auto-refresh to prevent flashing
    if (!preserveScroll) {
        gallery.style.display = 'none';
        loading.style.display = 'block';
    }
    noPhotos.style.display = 'none';
    
    const params = new URLSearchParams({
        page: currentPage,
        per_page: 24,
        ...currentFilters
    });
    
    fetch(`../api/moderation/get_all_photos.php?${params}`)
        .then(response => response.json())
        .then(data => {
            if (!preserveScroll) {
                loading.style.display = 'none';
            }
            
            if (data.success && data.photos.length > 0) {
                displayPhotos(data.photos, preserveScroll);
                displayPagination(data.pagination);
                gallery.style.display = 'flex';
                
                // Restore scroll position if needed
                if (preserveScroll && scrollPosition !== null) {
                    requestAnimationFrame(() => {
                        window.scrollTo(0, scrollPosition);
                    });
                }
            } else {
                noPhotos.style.display = 'block';
            }
        })
        .catch(error => {
            console.error('Error loading photos:', error);
            loading.style.display = 'none';
            Swal.fire('Ошибка', 'Не удалось загрузить фотографии', 'error');
        });
}

function displayPhotos(photos, preserveScroll = false) {
    const gallery = document.getElementById('photoGallery');
    gallery.innerHTML = '';
    
    // Group photos by date
    const photosByDate = {};
    photos.forEach(photo => {
        const date = new Date(photo.createdAt).toLocaleDateString('ru-RU', {
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
        if (!photosByDate[date]) {
            photosByDate[date] = [];
        }
        photosByDate[date].push(photo);
    });
    
    // Display photos grouped by date
    Object.keys(photosByDate).forEach(date => {
        // Add date header
        const dateHeader = document.createElement('div');
        dateHeader.className = 'col-12 mt-4 mb-3';
        dateHeader.innerHTML = `
            <h5 class="border-bottom pb-2">
                <i class="bi bi-calendar3"></i> ${date}
                <span class="badge bg-secondary ms-2">${photosByDate[date].length}</span>
            </h5>
        `;
        gallery.appendChild(dateHeader);
        
        // Add photos for this date
        photosByDate[date].forEach(photo => {
        const col = document.createElement('div');
        col.className = 'col-md-3 col-sm-4 col-6';
        
        const isSelected = selectedPhotos.has(photo.id);
        
        let photoSrc = normalizeImageUrl(photo.filePath);
        // Filter out temp_photo.jpg and invalid paths
        if (!photoSrc || photoSrc.includes('temp_photo') || photoSrc.includes('temp_photo.jpg') || photoSrc === '') {
            photoSrc = '/travel/admin/assets/images/default-avatar.svg';
        }
        
        // Determine content type badge
        let contentTypeBadge = '';
        let contentTypeClass = '';
        if (photo.contentType === 'commercial') {
            contentTypeBadge = '<i class="bi bi-cash-coin"></i> Платный пост';
            contentTypeClass = 'bg-warning text-dark';
        } else if (photo.contentType === 'album') {
            contentTypeBadge = '<i class="bi bi-collection"></i> Альбом';
            contentTypeClass = 'bg-info';
        } else {
            contentTypeBadge = '<i class="bi bi-image"></i> Обычный пост';
            contentTypeClass = 'bg-primary';
        }
        
        col.innerHTML = `
            <div class="card photo-card h-100" data-photo-id="${photo.id}">
                <div class="position-relative">
                    <img src="${escapeHtml(photoSrc)}" 
                         class="card-img-top photo-thumbnail" 
                         alt="${escapeHtml(photo.title || 'Photo')}"
                         style="height: 200px; object-fit: cover; cursor: pointer;">
                    <div class="position-absolute bottom-0 start-0 p-2">
                        <span class="badge ${contentTypeClass}">${contentTypeBadge}</span>
                    </div>
                </div>
                <div class="card-body p-2">
                    <h6 class="card-title mb-1 text-truncate" title="${escapeHtml(photo.title || 'Без названия')}">
                        ${escapeHtml(photo.title || 'Без названия')}
                    </h6>
                    <p class="card-text small mb-1">
                        <i class="bi bi-person"></i> ${escapeHtml(photo.userName)}
                    </p>
                    ${photo.locationName ? `
                        <p class="card-text small mb-1">
                            <i class="bi bi-geo-alt"></i> ${escapeHtml(photo.locationName)}
                        </p>
                    ` : ''}
                    ${photo.commentsCount > 0 ? `
                        <p class="card-text small mb-1">
                            <i class="bi bi-chat-dots"></i> ${photo.commentsCount} комментариев
                        </p>
                    ` : ''}
                    ${photo.moderationStatus !== 'approved' ? `
                        <p class="card-text small mb-1">
                            <span class="badge ${getStatusBadgeClass(photo.moderationStatus)}">
                                ${getStatusText(photo.moderationStatus)}
                            </span>
                        </p>
                    ` : ''}
                    <div class="d-flex justify-content-between align-items-center mt-2 pt-2 border-top">
                        <div class="checkbox-container" data-photo-id="${photo.id}">
                            <input type="checkbox" 
                                   class="form-check-input photo-checkbox photo-checkbox-red" 
                                   data-photo-id="${photo.id}"
                                   ${isSelected ? 'checked' : ''}>
                            <label class="form-check-label ms-1 small">Выбрать</label>
                        </div>
                        <button class="btn btn-sm btn-danger delete-photo-btn"
                                data-photo-id="${photo.id}"
                                title="Удалить фото">
                            <i class="bi bi-trash"></i>
                        </button>
                    </div>
                </div>
            </div>
        `;
        
        gallery.appendChild(col);
        
        // Add event listeners
        const checkbox = col.querySelector('.photo-checkbox');
        checkbox.addEventListener('change', function() {
            if (this.checked) {
                selectedPhotos.add(photo.id);
            } else {
                selectedPhotos.delete(photo.id);
                document.getElementById('selectAll').checked = false;
            }
            updateSelectedCount();
        });
        
        // Delete button
        const deleteBtn = col.querySelector('.delete-photo-btn');
        if (deleteBtn) {
            deleteBtn.addEventListener('click', function(e) {
                e.stopPropagation();
                deletePhoto(photo.id);
            });
        }
        
        // Checkbox container click handler
        const checkboxContainer = col.querySelector('.checkbox-container');
        if (checkboxContainer) {
            checkboxContainer.addEventListener('click', function(e) {
                e.stopPropagation();
                // Allow checkbox and label to work naturally
                if (e.target.tagName !== 'INPUT' && e.target.tagName !== 'LABEL') {
                    const checkbox = this.querySelector('.photo-checkbox');
                    if (checkbox) {
                        checkbox.checked = !checkbox.checked;
                        checkbox.dispatchEvent(new Event('change'));
                    }
                }
            });
        }
        
        // Photo preview on card click (anywhere on the card)
        const card = col.querySelector('.photo-card');
        card.style.cursor = 'pointer';
        card.addEventListener('click', function(e) {
            // Don't open preview if clicking on checkbox area or delete button
            if (e.target.closest('.checkbox-container') || 
                e.target.closest('.photo-checkbox') || 
                e.target.closest('.delete-photo-btn')) {
                return;
            }
            showPhotoPreview(photo);
        });
        });
    });
}

function displayPagination(pagination) {
    const paginationEl = document.getElementById('pagination');
    paginationEl.innerHTML = '';
    
    if (pagination.lastPage <= 1) return;
    
    // Previous button
    const prevLi = document.createElement('li');
    prevLi.className = `page-item ${currentPage === 1 ? 'disabled' : ''}`;
    prevLi.innerHTML = `<a class="page-link" href="#" data-page="${currentPage - 1}">Назад</a>`;
    paginationEl.appendChild(prevLi);
    
    // Page numbers
    const startPage = Math.max(1, currentPage - 2);
    const endPage = Math.min(pagination.lastPage, currentPage + 2);
    
    if (startPage > 1) {
        const li = document.createElement('li');
        li.className = 'page-item';
        li.innerHTML = `<a class="page-link" href="#" data-page="1">1</a>`;
        paginationEl.appendChild(li);
        
        if (startPage > 2) {
            const li = document.createElement('li');
            li.className = 'page-item disabled';
            li.innerHTML = `<span class="page-link">...</span>`;
            paginationEl.appendChild(li);
        }
    }
    
    for (let i = startPage; i <= endPage; i++) {
        const li = document.createElement('li');
        li.className = `page-item ${i === currentPage ? 'active' : ''}`;
        li.innerHTML = `<a class="page-link" href="#" data-page="${i}">${i}</a>`;
        paginationEl.appendChild(li);
    }
    
    if (endPage < pagination.lastPage) {
        if (endPage < pagination.lastPage - 1) {
            const li = document.createElement('li');
            li.className = 'page-item disabled';
            li.innerHTML = `<span class="page-link">...</span>`;
            paginationEl.appendChild(li);
        }
        
        const li = document.createElement('li');
        li.className = 'page-item';
        li.innerHTML = `<a class="page-link" href="#" data-page="${pagination.lastPage}">${pagination.lastPage}</a>`;
        paginationEl.appendChild(li);
    }
    
    // Next button
    const nextLi = document.createElement('li');
    nextLi.className = `page-item ${currentPage === pagination.lastPage ? 'disabled' : ''}`;
    nextLi.innerHTML = `<a class="page-link" href="#" data-page="${currentPage + 1}">Вперед</a>`;
    paginationEl.appendChild(nextLi);
    
    // Add click handlers
    paginationEl.querySelectorAll('a.page-link').forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            const page = parseInt(this.dataset.page);
            if (page && page !== currentPage) {
                currentPage = page;
                localStorage.setItem('moderationPage', currentPage);
                selectedPhotos.clear();
                document.getElementById('selectAll').checked = false;
                updateSelectedCount();
                loadPhotos();
                // Smooth scroll to top only on manual page change
                window.scrollTo({ top: 0, behavior: 'smooth' });
            }
        });
    });
}

function showPhotoPreview(photo) {
    const modalEl = document.getElementById('photoPreviewModal');
    const modalBody = modalEl.querySelector('.modal-body');
    
    // Restore original modal structure if it was changed
    if (!document.getElementById('photoPreviewImage')) {
        modalBody.innerHTML = `
            <div class="text-center">
                <img id="photoPreviewImage" src="" alt="Photo preview" class="img-fluid" style="max-height: 70vh;">
            </div>
            <div id="photoPreviewInfo" class="mt-3 text-start">
                <!-- Photo info will be loaded here -->
            </div>
        `;
    }
    
    // Get or create modal instance
    let modal = bootstrap.Modal.getInstance(modalEl);
    if (!modal) {
        modal = new bootstrap.Modal(modalEl, {
            backdrop: true,
            keyboard: true,
            focus: true
        });
    }
    
    document.getElementById('photoPreviewTitle').textContent = photo.title || 'Без названия';
    
    // Filter out temp_photo.jpg and use proper image
    let photoSrc = normalizeImageUrl(photo.filePath);
    if (photoSrc && (photoSrc.includes('temp_photo') || photoSrc.includes('temp_photo.jpg'))) {
        photoSrc = '/travel/admin/assets/images/default-avatar.svg';
    }
    document.getElementById('photoPreviewImage').src = photoSrc;
    
    // Determine content type badge
    let contentTypeBadge = '';
    if (photo.contentType === 'commercial') {
        contentTypeBadge = '<span class="badge bg-warning text-dark"><i class="bi bi-cash-coin"></i> Платный пост</span>';
    } else if (photo.contentType === 'album') {
        contentTypeBadge = '<span class="badge bg-info"><i class="bi bi-collection"></i> Альбом</span>';
    } else {
        contentTypeBadge = '<span class="badge bg-primary"><i class="bi bi-image"></i> Обычный пост</span>';
    }
    
    const infoHtml = `
        <div class="row">
            <div class="col-md-6">
                <p><strong>Тип контента:</strong> ${contentTypeBadge}</p>
                <p><strong>Автор:</strong> ${escapeHtml(photo.userName)}</p>
                <p><strong>Email:</strong> ${escapeHtml(photo.userEmail)}</p>
                ${photo.locationName ? `<p><strong>Локация:</strong> ${escapeHtml(photo.locationName)}</p>` : ''}
                <p><strong>Дата загрузки:</strong> ${formatDate(photo.createdAt)}</p>
            </div>
            <div class="col-md-6">
                ${photo.description ? `<p><strong>Описание:</strong> ${escapeHtml(photo.description)}</p>` : ''}
                ${photo.inAlbums.length > 0 ? `
                    <p><strong>В альбомах:</strong></p>
                    <ul class="mb-2">
                        ${photo.inAlbums.map(album => `<li>${escapeHtml(album)}</li>`).join('')}
                    </ul>
                ` : ''}
                ${photo.inCommercialPosts.length > 0 ? `
                    <p><strong>В рекламных постах:</strong></p>
                    <ul class="mb-2">
                        ${photo.inCommercialPosts.map(post => `<li>${escapeHtml(post)}</li>`).join('')}
                    </ul>
                ` : ''}
            </div>
        </div>
        <hr>
        <div class="row">
            <div class="col-12">
                <h6><i class="bi bi-chat-dots"></i> Комментарии (${photo.commentsCount})</h6>
                <div id="photoComments">
                    <div class="text-center py-3">
                        <div class="spinner-border spinner-border-sm" role="status"></div>
                        <span class="ms-2">Загрузка комментариев...</span>
                    </div>
                </div>
            </div>
        </div>
    `;
    
    document.getElementById('photoPreviewInfo').innerHTML = infoHtml;
    modal.show();
    
    // Load comments
    if (photo.commentsCount > 0) {
        loadPhotoComments(photo.id);
    } else {
        document.getElementById('photoComments').innerHTML = '<p class="text-muted">Нет комментариев</p>';
    }
}

function loadPhotoComments(photoId) {
    fetch(`../api/comments/get_all_comments.php?photo_id=${photoId}`)
        .then(response => response.json())
        .then(data => {
            if (data.success && data.comments) {
                displayPhotoComments(data.comments);
            } else {
                document.getElementById('photoComments').innerHTML = '<p class="text-muted">Не удалось загрузить комментарии</p>';
            }
        })
        .catch(error => {
            console.error('Error loading comments:', error);
            document.getElementById('photoComments').innerHTML = '<p class="text-danger">Ошибка загрузки комментариев</p>';
        });
}

function displayPhotoComments(comments) {
    const container = document.getElementById('photoComments');
    
    if (comments.length === 0) {
        container.innerHTML = '<p class="text-muted">Нет комментариев</p>';
        return;
    }
    
    const html = comments.map(comment => {
        // Get comment text from various possible field names
        const commentText = comment.commentText || comment.comment_text || comment.text || comment.comment || '';
        const userName = comment.userName || (comment.first_name && comment.last_name ? `${comment.first_name} ${comment.last_name}` : 'Пользователь');
        const createdAt = comment.createdAt || comment.created_at;
        const commentType = comment.commentType || comment.comment_type || 'photo';
        
        return `
        <div class="border-bottom pb-2 mb-2" data-comment-id="${comment.id}">
            <div class="d-flex align-items-start justify-content-between">
                <div class="flex-grow-1">
                    <strong>${escapeHtml(userName)}</strong>
                    <small class="text-muted ms-2">${formatDate(createdAt)}</small>
                    <p class="mb-0 mt-1">${escapeHtml(commentText) || '<em class="text-muted">Нет текста</em>'}</p>
                </div>
                <button class="btn btn-sm btn-danger delete-comment-btn ms-2" 
                        data-comment-id="${comment.id}"
                        data-comment-type="${commentType}"
                        title="Удалить комментарий">
                    <i class="bi bi-trash"></i>
                </button>
            </div>
        </div>
        `;
    }).join('');
    
    container.innerHTML = html;
    
    // Add delete handlers
    container.querySelectorAll('.delete-comment-btn').forEach(btn => {
        btn.addEventListener('click', function() {
            const commentId = this.dataset.commentId;
            const commentType = this.dataset.commentType;
            deleteComment(commentId, commentType);
        });
    });
}

function deleteComment(commentId, commentType) {
    Swal.fire({
        title: 'Удалить комментарий?',
        text: 'Это действие нельзя отменить',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#6c757d',
        confirmButtonText: 'Да, удалить',
        cancelButtonText: 'Отмена'
    }).then((result) => {
        if (result.isConfirmed) {
            fetch('../api/comments/delete_comment.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': window.csrfToken
                },
                body: JSON.stringify({ 
                    commentId: parseInt(commentId),
                    commentType: commentType,
                    csrf_token: window.csrfToken
                })
            })
            .then(response => {
                if (!response.ok) {
                    return response.json().then(err => {
                        throw new Error(err.message || 'Server error');
                    });
                }
                return response.json();
            })
            .then(data => {
                if (data.success) {
                    Swal.fire('Удалено!', 'Комментарий удален', 'success');
                    // Remove comment from DOM
                    const commentEl = document.querySelector(`[data-comment-id="${commentId}"]`);
                    if (commentEl) {
                        commentEl.remove();
                    }
                    // Update count if no comments left
                    const container = document.getElementById('photoComments');
                    if (container.children.length === 0) {
                        container.innerHTML = '<p class="text-muted">Нет комментариев</p>';
                    }
                } else {
                    Swal.fire('Ошибка', data.message || 'Не удалось удалить комментарий', 'error');
                }
            })
            .catch(error => {
                console.error('Error deleting comment:', error);
                Swal.fire('Ошибка', error.message || 'Не удалось удалить комментарий', 'error');
            });
        }
    });
}

function updateSelectedCount() {
    const count = selectedPhotos.size;
    const selectedCount = document.getElementById('selectedCount');
    const bulkDeleteBtn = document.getElementById('bulkDeleteBtn');
    
    if (selectedCount) selectedCount.textContent = count;
    if (bulkDeleteBtn) bulkDeleteBtn.disabled = count === 0;
}

function getStatusBadgeClass(status) {
    switch(status) {
        case 'approved': return 'bg-success';
        case 'rejected': return 'bg-danger';
        case 'pending': return 'bg-warning text-dark';
        default: return 'bg-secondary';
    }
}

function getStatusText(status) {
    switch(status) {
        case 'approved': return '';
        case 'rejected': return 'Отклонено';
        case 'pending': return 'На проверке';
        default: return status;
    }
}

function approvePhoto(photoId) {
    Swal.fire({
        title: 'Подтверждение',
        text: 'Одобрить эту фотографию?',
        icon: 'question',
        showCancelButton: true,
        confirmButtonColor: '#28a745',
        cancelButtonColor: '#6c757d',
        confirmButtonText: 'Да, одобрить',
        cancelButtonText: 'Отмена'
    }).then((result) => {
        if (result.isConfirmed) {
            fetch('../api/moderation/approve_photo.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': window.csrfToken
                },
                body: JSON.stringify({ 
                    photoId: photoId,
                    csrf_token: window.csrfToken
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    Swal.fire('Одобрено!', data.message, 'success');
                    selectedPhotos.delete(photoId);
                    updateSelectedCount();
                    loadPhotos();
                    // Update badge count
                    if (typeof updateModerationBadge === 'function') {
                        updateModerationBadge();
                    }
                } else {
                    Swal.fire('Ошибка', data.message, 'error');
                }
            })
            .catch(error => {
                console.error('Error approving photo:', error);
                Swal.fire('Ошибка', 'Не удалось одобрить фотографию', 'error');
            });
        }
    });
}

function rejectPhoto(photoId) {
    Swal.fire({
        title: 'Подтверждение',
        text: 'Отклонить эту фотографию?',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#6c757d',
        confirmButtonText: 'Да, отклонить',
        cancelButtonText: 'Отмена'
    }).then((result) => {
        if (result.isConfirmed) {
            fetch('../api/moderation/reject_photo.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': window.csrfToken
                },
                body: JSON.stringify({ 
                    photoId: photoId,
                    csrf_token: window.csrfToken
                })
            })
            .then(response => response.json())
            .then(data => {
                if (data.success) {
                    Swal.fire('Отклонено!', data.message, 'success');
                    selectedPhotos.delete(photoId);
                    updateSelectedCount();
                    loadPhotos();
                    // Update badge count
                    if (typeof updateModerationBadge === 'function') {
                        updateModerationBadge();
                    }
                } else {
                    Swal.fire('Ошибка', data.message, 'error');
                }
            })
            .catch(error => {
                console.error('Error rejecting photo:', error);
                Swal.fire('Ошибка', 'Не удалось отклонить фотографию', 'error');
            });
        }
    });
}

function bulkApprovePhotos() {
    const photoIds = Array.from(selectedPhotos);
    
    fetch('../api/moderation/bulk_approve_photos.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': window.csrfToken
        },
        body: JSON.stringify({ 
            photoIds: photoIds,
            csrf_token: window.csrfToken
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            Swal.fire('Одобрено!', data.message, 'success');
            selectedPhotos.clear();
            document.getElementById('selectAll').checked = false;
            updateSelectedCount();
            loadPhotos();
            // Update badge count
            if (typeof updateModerationBadge === 'function') {
                updateModerationBadge();
            }
        } else {
            Swal.fire('Ошибка', data.message, 'error');
        }
    })
    .catch(error => {
        console.error('Error bulk approving photos:', error);
        Swal.fire('Ошибка', 'Не удалось одобрить фотографии', 'error');
    });
}

function bulkRejectPhotos() {
    const photoIds = Array.from(selectedPhotos);
    
    fetch('../api/moderation/bulk_reject_photos.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': window.csrfToken
        },
        body: JSON.stringify({ 
            photoIds: photoIds,
            csrf_token: window.csrfToken
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            Swal.fire('Отклонено!', data.message, 'success');
            selectedPhotos.clear();
            document.getElementById('selectAll').checked = false;
            updateSelectedCount();
            loadPhotos();
            // Update badge count
            if (typeof updateModerationBadge === 'function') {
                updateModerationBadge();
            }
        } else {
            Swal.fire('Ошибка', data.message, 'error');
        }
    })
    .catch(error => {
        console.error('Error bulk rejecting photos:', error);
        Swal.fire('Ошибка', 'Не удалось отклонить фотографии', 'error');
    });
}

function formatDate(dateString) {
    const date = new Date(dateString);
    return date.toLocaleDateString('ru-RU', {
        year: 'numeric',
        month: '2-digit',
        day: '2-digit',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function deletePhoto(photoId) {
    Swal.fire({
        title: 'Удалить фото?',
        text: 'Это действие нельзя отменить. Фото будет удалено навсегда.',
        icon: 'warning',
        showCancelButton: true,
        confirmButtonColor: '#d33',
        cancelButtonColor: '#6c757d',
        confirmButtonText: 'Да, удалить',
        cancelButtonText: 'Отмена'
    }).then((result) => {
        if (result.isConfirmed) {
            fetch('../api/moderation/delete_photo.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                    'X-CSRF-Token': window.csrfToken
                },
                body: JSON.stringify({ 
                    photoId: photoId,
                    csrf_token: window.csrfToken
                })
            })
            .then(response => {
                if (!response.ok) {
                    throw new Error(`HTTP error! status: ${response.status}`);
                }
                return response.text();
            })
            .then(text => {
                let data;
                try {
                    // Try to extract JSON from response (in case of PHP warnings before JSON)
                    const jsonMatch = text.match(/\{[\s\S]*\}$/);
                    const jsonText = jsonMatch ? jsonMatch[0] : text;
                    data = JSON.parse(jsonText);
                } catch (e) {
                    console.error('Invalid JSON response:', text);
                    throw new Error('Сервер вернул некорректный ответ');
                }
                
                if (data.success) {
                    Swal.fire('Удалено!', 'Фото успешно удалено', 'success');
                    selectedPhotos.delete(photoId);
                    updateSelectedCount();
                    loadPhotos();
                    // Update counts and notifications
                    updateCounts();
                    if (typeof loadNotifications === 'function') {
                        loadNotifications();
                    }
                } else {
                    Swal.fire('Ошибка', data.message || 'Не удалось удалить фото', 'error');
                }
            })
            .catch(error => {
                console.error('Error deleting photo:', error);
                Swal.fire('Ошибка', error.message || 'Не удалось удалить фото', 'error');
            });
        }
    });
}

function bulkDeletePhotos() {
    const photoIds = Array.from(selectedPhotos);
    
    fetch('../api/moderation/bulk_delete_photos.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': window.csrfToken
        },
        body: JSON.stringify({ 
            photoIds: photoIds,
            csrf_token: window.csrfToken
        })
    })
    .then(response => {
        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }
        return response.text();
    })
    .then(text => {
        let data;
        try {
            // Try to extract JSON from response (in case of PHP warnings before JSON)
            const jsonMatch = text.match(/\{[\s\S]*\}$/);
            const jsonText = jsonMatch ? jsonMatch[0] : text;
            data = JSON.parse(jsonText);
        } catch (e) {
            console.error('Invalid JSON response:', text);
            throw new Error('Сервер вернул некорректный ответ');
        }
        
        if (data.success) {
            Swal.fire('Удалено!', data.message || 'Фотографии успешно удалены', 'success');
            selectedPhotos.clear();
            document.getElementById('selectAll').checked = false;
            updateSelectedCount();
            loadPhotos();
            // Update counts and notifications
            updateCounts();
            if (typeof loadNotifications === 'function') {
                loadNotifications();
            }
        } else {
            Swal.fire('Ошибка', data.message || 'Не удалось удалить фотографии', 'error');
        }
    })
    .catch(error => {
        console.error('Error bulk deleting photos:', error);
        Swal.fire('Ошибка', error.message || 'Не удалось удалить фотографии', 'error');
    });
}


// Comments functionality
let currentCommentsPage = 1;
let currentCommentFilters = {};

// Load comments
function loadComments(preserveScroll = false) {
    const loadingSpinner = document.getElementById('loadingCommentsSpinner');
    const commentsList = document.getElementById('commentsList');
    const noComments = document.getElementById('noComments');
    
    // Save current scroll position if needed
    const scrollPosition = preserveScroll ? window.pageYOffset : null;
    
    if (loadingSpinner) loadingSpinner.style.display = 'block';
    if (commentsList) commentsList.style.display = 'none';
    if (noComments) noComments.style.display = 'none';
    
    const params = new URLSearchParams({
        page: currentCommentsPage,
        per_page: 20,
        ...currentCommentFilters
    });
    
    fetch(`../api/moderation/get_all_comments.php?${params}`)
        .then(response => response.json())
        .then(data => {
            if (loadingSpinner) loadingSpinner.style.display = 'none';
            
            if (data.success) {
                displayComments(data.comments);
                displayCommentsPagination(data.pagination);
                
                // Restore scroll position if needed
                if (preserveScroll && scrollPosition !== null) {
                    window.scrollTo(0, scrollPosition);
                }
            } else {
                if (noComments) {
                    noComments.style.display = 'block';
                    noComments.innerHTML = `<p class="text-danger">${data.message || 'Ошибка загрузки'}</p>`;
                }
            }
        })
        .catch(error => {
            console.error('Error loading comments:', error);
            if (loadingSpinner) loadingSpinner.style.display = 'none';
            if (noComments) {
                noComments.style.display = 'block';
                noComments.innerHTML = '<p class="text-danger">Ошибка загрузки комментариев</p>';
            }
        });
}

// Display comments
function displayComments(comments) {
    const commentsList = document.getElementById('commentsList');
    const noComments = document.getElementById('noComments');
    
    if (!commentsList) return;
    
    if (comments.length === 0) {
        commentsList.style.display = 'none';
        if (noComments) noComments.style.display = 'block';
        return;
    }
    
    commentsList.style.display = 'block';
    if (noComments) noComments.style.display = 'none';
    
    const html = comments.map(comment => {
        const userImage = normalizeImageUrl(comment.user_image) || '/travel/admin/assets/images/default-avatar.svg';
        const photoPreview = normalizeImageUrl(comment.photo_preview) || '/travel/admin/assets/images/default-avatar.svg';
        const createdAt = new Date(comment.created_at).toLocaleString('ru-RU');
        const commentType = comment.comment_type || (comment.album_id ? 'album' : 'photo');
        
        return `
            <div class="card mb-3" data-comment-id="${comment.id}" data-comment-type="${commentType}">
                <div class="card-body">
                    <div class="row">
                        <div class="col-md-2 text-center">
                            <a href="user_details.php?id=${comment.user_id}&from=moderation" class="text-decoration-none user-profile-link" data-user-id="${comment.user_id}" title="Открыть профиль пользователя">
                                <img src="${userImage}" alt="${comment.user_name}" class="rounded-circle mb-2" style="width: 60px; height: 60px; object-fit: cover; cursor: pointer; transition: opacity 0.2s;">
                                <p class="mb-0 small"><strong style="color: #3498db;">${comment.user_name}</strong></p>
                            </a>
                            <p class="mb-0 text-muted small">${createdAt}</p>
                        </div>
                        <div class="col-md-8">
                            <p class="mb-2" style="white-space: pre-wrap;">${escapeHtml(comment.text)}</p>
                            ${comment.photo_id ? `
                                <div class="d-flex align-items-center mt-2" style="cursor: pointer;" onclick="viewPostDetailsFromComment(${comment.photo_id})" title="Открыть детали поста">
                                    ${comment.photo_preview ? `
                                        <img src="${photoPreview}" alt="${comment.photo_title || 'Фото'}" class="me-2" style="width: 50px; height: 50px; object-fit: cover; border-radius: 4px; transition: opacity 0.2s;">
                                    ` : `
                                        <i class="bi bi-image me-2" style="font-size: 2rem; color: #3498db;"></i>
                                    `}
                                    <small class="text-muted" style="color: #3498db !important;">К посту: ${escapeHtml(comment.photo_title || 'Без названия')}</small>
                                </div>
                            ` : comment.album_id ? `
                                <div class="d-flex align-items-center mt-2" style="cursor: pointer;" onclick="viewAlbumDetailsFromComment(${comment.album_id})" title="Открыть детали альбома">
                                    <i class="bi bi-collection me-2" style="font-size: 2rem; color: #3498db;"></i>
                                    <small class="text-muted" style="color: #3498db !important;">К альбому: ${escapeHtml(comment.photo_title || 'Без названия')}</small>
                                </div>
                            ` : `
                                <div class="mt-2">
                                    <small class="text-muted"><i class="bi bi-exclamation-triangle"></i> Пост удалён или недоступен</small>
                                </div>
                            `}
                        </div>
                        <div class="col-md-2 text-end">
                            <button class="btn btn-sm btn-danger delete-comment" data-comment-id="${comment.id}" data-comment-type="${commentType}" title="Удалить комментарий">
                                <i class="bi bi-trash"></i> Удалить
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        `;
    }).join('');
    
    commentsList.innerHTML = html;
    
    // Add delete handlers
    document.querySelectorAll('.delete-comment').forEach(btn => {
        btn.addEventListener('click', function() {
            const commentId = this.dataset.commentId;
            const commentType = this.dataset.commentType || 'photo';
            deleteComment(commentId, commentType);
        });
    });
}

// View post details from comment (reuse the photo preview modal)
function viewPostDetailsFromComment(photoId) {
    // Fetch photo details
    fetch(`../api/posts/get_post_details.php?photo_id=${photoId}`)
        .then(response => response.json())
        .then(data => {
            if (data.success && data.post) {
                // Create a photo object compatible with showPhotoPreview
                const photo = {
                    id: data.post.id,
                    title: data.post.title || 'Без названия',
                    description: data.post.description || '',
                    filePath: data.post.filePath,
                    userName: data.post.authorName,
                    userEmail: '',
                    locationName: data.post.locationName || '',
                    createdAt: data.post.createdAt,
                    commentsCount: data.post.commentsCount || 0,
                    contentType: 'photo',
                    inAlbums: [],
                    inCommercialPosts: [],
                    moderationStatus: 'approved'
                };
                
                // Show the photo preview modal
                showPhotoPreview(photo);
            } else {
                alert('Не удалось загрузить детали поста');
            }
        })
        .catch(error => {
            console.error('Error loading post details:', error);
            alert('Ошибка при загрузке деталей поста');
        });
}

// View album details from comment
function viewAlbumDetailsFromComment(albumId) {
    // Fetch album details
    fetch(`../api/posts/get_all_albums.php?album_id=${albumId}`)
        .then(response => response.json())
        .then(data => {
            if (data.success && data.albums && data.albums.length > 0) {
                const album = data.albums[0];
                showAlbumPreview(album);
            } else {
                alert('Не удалось загрузить детали альбома');
            }
        })
        .catch(error => {
            console.error('Error loading album details:', error);
            alert('Ошибка при загрузке деталей альбома');
        });
}

// Show album preview in modal
function showAlbumPreview(album) {
    const modalEl = document.getElementById('photoPreviewModal');
    if (!modalEl) {
        alert('Модальное окно не найдено');
        return;
    }
    
    // Get or create modal instance
    let modal = bootstrap.Modal.getInstance(modalEl);
    if (!modal) {
        modal = new bootstrap.Modal(modalEl, {
            backdrop: true,
            keyboard: true,
            focus: true
        });
    }
    
    const modalTitle = document.getElementById('photoPreviewTitle');
    const modalBody = document.querySelector('#photoPreviewModal .modal-body');
    
    if (modalTitle) {
        modalTitle.textContent = album.title || 'Альбом';
    }
    
    // Fetch album photos
    fetch(`../api/posts/get_album_photos.php?album_id=${album.id}`)
        .then(response => response.json())
        .then(data => {
            if (data.success && data.photos) {
                const photosHtml = data.photos.map(photo => {
                    const photoUrl = normalizeImageUrl(photo.file_path);
                    const photoId = photo.photo_id || photo.id;
                    return `
                        <div class="col-md-4 col-sm-6 mb-3">
                            <img src="${photoUrl}" 
                                 alt="${escapeHtml(photo.title || '')}" 
                                 class="img-fluid rounded" 
                                 style="width: 100%; height: 200px; object-fit: cover; cursor: pointer;"
                                 onclick="viewPostDetailsFromComment(${photoId})">
                        </div>
                    `;
                }).join('');
                
                modalBody.innerHTML = `
                    <div class="album-details text-start">
                        ${album.description ? `<p class="text-muted mb-3">${escapeHtml(album.description)}</p>` : ''}
                        <div class="row mb-3">
                            <div class="col-md-6">
                                <p class="mb-1"><strong>Автор:</strong> ${escapeHtml(album.owner_name || album.user_name || 'Неизвестно')}</p>
                                <p class="mb-1"><strong>Создан:</strong> ${new Date(album.created_at).toLocaleString('ru-RU')}</p>
                            </div>
                            <div class="col-md-6">
                                <p class="mb-1"><strong>Фотографий:</strong> ${data.photos.length}</p>
                                <p class="mb-1"><strong>Комментариев:</strong> ${album.comments_count || 0}</p>
                            </div>
                        </div>
                        <hr>
                        <h6 class="mb-3">Фотографии в альбоме:</h6>
                        <div class="row">
                            ${photosHtml || '<div class="col-12"><p class="text-muted">Нет фотографий</p></div>'}
                        </div>
                    </div>
                `;
            } else {
                modalBody.innerHTML = `
                    <div class="album-details text-start">
                        ${album.description ? `<p class="text-muted mb-3">${escapeHtml(album.description)}</p>` : ''}
                        <p class="text-muted">Не удалось загрузить фотографии альбома</p>
                    </div>
                `;
            }
            
            modal.show();
        })
        .catch(error => {
            console.error('Error loading album photos:', error);
            modalBody.innerHTML = `
                <div class="album-details text-start">
                    <p class="text-danger">Ошибка при загрузке фотографий альбома</p>
                </div>
            `;
            modal.show();
        });
}

// Delete comment
function deleteComment(commentId, commentType = 'photo') {
    if (!confirm('Вы уверены, что хотите удалить этот комментарий?')) {
        return;
    }
    
    fetch('../api/comments/delete_comment.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/json',
            'X-CSRF-Token': window.csrfToken || ''
        },
        body: JSON.stringify({
            commentId: parseInt(commentId),
            commentType: commentType
        })
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            // Remove comment from DOM
            const commentCard = document.querySelector(`[data-comment-id="${commentId}"]`);
            if (commentCard) {
                commentCard.remove();
            }
            
            // Reload if no comments left
            const remainingComments = document.querySelectorAll('#commentsList .card');
            if (remainingComments.length === 0) {
                loadComments();
            }
            
            // Update counts
            updateCounts();
        } else {
            alert('Ошибка при удалении комментария: ' + (data.message || 'Неизвестная ошибка'));
        }
    })
    .catch(error => {
        console.error('Error deleting comment:', error);
        alert('Ошибка при удалении комментария');
    });
}

// Display comments pagination
function displayCommentsPagination(pagination) {
    const paginationEl = document.getElementById('commentsPagination');
    if (!paginationEl) return;
    
    if (pagination.lastPage <= 1) {
        paginationEl.innerHTML = '';
        return;
    }
    
    let html = '';
    
    // Previous button
    if (pagination.currentPage > 1) {
        html += `<li class="page-item"><a class="page-link" href="#" data-page="${pagination.currentPage - 1}">Назад</a></li>`;
    }
    
    // Page numbers
    for (let i = 1; i <= pagination.lastPage; i++) {
        if (i === pagination.currentPage) {
            html += `<li class="page-item active"><span class="page-link">${i}</span></li>`;
        } else if (i === 1 || i === pagination.lastPage || (i >= pagination.currentPage - 2 && i <= pagination.currentPage + 2)) {
            html += `<li class="page-item"><a class="page-link" href="#" data-page="${i}">${i}</a></li>`;
        } else if (i === pagination.currentPage - 3 || i === pagination.currentPage + 3) {
            html += `<li class="page-item disabled"><span class="page-link">...</span></li>`;
        }
    }
    
    // Next button
    if (pagination.currentPage < pagination.lastPage) {
        html += `<li class="page-item"><a class="page-link" href="#" data-page="${pagination.currentPage + 1}">Вперед</a></li>`;
    }
    
    paginationEl.innerHTML = html;
    
    // Add click handlers
    paginationEl.querySelectorAll('a.page-link').forEach(link => {
        link.addEventListener('click', function(e) {
            e.preventDefault();
            currentCommentsPage = parseInt(this.dataset.page);
            loadComments();
            // Smooth scroll to top on manual page change
            window.scrollTo({ top: 0, behavior: 'smooth' });
        });
    });
}

// Update comments count (removed - now handled by updateCounts)

// Apply comment filters
function applyCommentFilters() {
    const search = document.getElementById('filterCommentUser')?.value.trim() || '';
    const dateFrom = document.getElementById('filterCommentDateFrom')?.value || '';
    const dateTo = document.getElementById('filterCommentDateTo')?.value || '';
    
    currentCommentFilters = {};
    if (search) currentCommentFilters.search = search;
    if (dateFrom) currentCommentFilters.date_from = dateFrom;
    if (dateTo) currentCommentFilters.date_to = dateTo;
    
    currentCommentsPage = 1;
    loadComments();
}

// Escape HTML
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Auto-refresh intervals
let photosRefreshInterval = null;
let commentsRefreshInterval = null;

// Initialize comments tab
document.addEventListener('DOMContentLoaded', function() {
    // Check URL hash and switch to appropriate tab
    const hash = window.location.hash;
    if (hash === '#comments') {
        const commentsTab = document.getElementById('comments-tab');
        if (commentsTab) {
            const tab = new bootstrap.Tab(commentsTab);
            tab.show();
            // Load comments immediately when coming from hash
            setTimeout(() => loadComments(), 100);
        }
    }
    
    // Update counts on page load
    updateCounts();
    
    // Update counts every 2 minutes
    setInterval(updateCounts, 120000);
    
    // Update auto-refresh indicator text based on device
    const isMobile = window.innerWidth <= 768;
    const indicator = document.getElementById('autoRefreshIndicator');
    if (indicator && isMobile) {
        indicator.innerHTML = '<i class="bi bi-phone"></i> Автообновление отключено';
        indicator.classList.add('text-warning');
    }
    
    // Start auto-refresh for photos (active tab by default unless hash says otherwise)
    if (hash !== '#comments') {
        photosViewStartTime = new Date().toISOString();
        startPhotosAutoRefresh();
    } else {
        commentsViewStartTime = new Date().toISOString();
    }
    
    // Load comments when tab is shown
    const commentsTab = document.getElementById('comments-tab');
    if (commentsTab) {
        commentsTab.addEventListener('shown.bs.tab', function() {
            // Reset view start time for this tab
            commentsViewStartTime = new Date().toISOString();
            loadComments();
            // Start auto-refresh for comments
            startCommentsAutoRefresh();
            // Stop auto-refresh for photos
            stopPhotosAutoRefresh();
        });
    }
    
    // Switch to photos tab
    const photosTab = document.getElementById('photos-tab');
    if (photosTab) {
        photosTab.addEventListener('shown.bs.tab', function() {
            // Reset view start time for this tab
            photosViewStartTime = new Date().toISOString();
            // Start auto-refresh for photos
            startPhotosAutoRefresh();
            // Stop auto-refresh for comments
            stopCommentsAutoRefresh();
        });
    }
    
    // Comment filters
    const filterCommentUser = document.getElementById('filterCommentUser');
    if (filterCommentUser) {
        let searchTimeout;
        filterCommentUser.addEventListener('input', function() {
            clearTimeout(searchTimeout);
            searchTimeout = setTimeout(() => {
                applyCommentFilters();
            }, 500);
        });
    }
    
    const filterCommentDateFrom = document.getElementById('filterCommentDateFrom');
    if (filterCommentDateFrom) {
        filterCommentDateFrom.addEventListener('change', applyCommentFilters);
    }
    
    const filterCommentDateTo = document.getElementById('filterCommentDateTo');
    if (filterCommentDateTo) {
        filterCommentDateTo.addEventListener('change', applyCommentFilters);
    }
    
    // Reset comment filters
    const resetCommentFilters = document.getElementById('resetCommentFilters');
    if (resetCommentFilters) {
        resetCommentFilters.addEventListener('click', function() {
            document.getElementById('filterCommentUser').value = '';
            document.getElementById('filterCommentDateFrom').value = '';
            document.getElementById('filterCommentDateTo').value = '';
            currentCommentFilters = {};
            currentCommentsPage = 1;
            loadComments();
        });
    }
});

// Update counts with view tracking
function updateCounts() {
    // Build URL with session start times
    const params = new URLSearchParams();
    if (photosViewStartTime) {
        params.append('photos_session_start', photosViewStartTime);
    }
    if (commentsViewStartTime) {
        params.append('comments_session_start', commentsViewStartTime);
    }
    
    fetch(`../api/moderation/get_new_counts.php?${params}`)
        .then(response => response.json())
        .then(data => {
            if (data.success) {
                const photosBadge = document.getElementById('photosCount');
                const commentsBadge = document.getElementById('commentsCount');
                
                if (photosBadge) {
                    photosBadge.textContent = data.counts.newPhotos;
                    if (data.counts.newPhotos > 0) {
                        photosBadge.classList.remove('bg-secondary');
                        photosBadge.classList.add('bg-danger');
                    } else {
                        photosBadge.classList.remove('bg-danger');
                        photosBadge.classList.add('bg-secondary');
                    }
                }
                
                if (commentsBadge) {
                    commentsBadge.textContent = data.counts.newComments;
                    if (data.counts.newComments > 0) {
                        commentsBadge.classList.remove('bg-secondary');
                        commentsBadge.classList.add('bg-danger');
                    } else {
                        commentsBadge.classList.remove('bg-danger');
                        commentsBadge.classList.add('bg-secondary');
                    }
                }
            }
        })
        .catch(error => {
            console.error('Error loading counts:', error);
        });
}

// Mark as viewed
function markAsViewed(viewType) {
    fetch('../api/moderation/mark_as_viewed.php', {
        method: 'POST',
        headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: `view_type=${viewType}`
    })
    .then(response => response.json())
    .then(data => {
        if (data.success) {
            // Update counts after marking as viewed
            setTimeout(() => updateCounts(), 500);
            
            // Also update global notifications if function exists
            if (typeof loadNotifications === 'function') {
                setTimeout(() => loadNotifications(), 500);
            }
        }
    })
    .catch(error => {
        console.error('Error marking as viewed:', error);
    });
}


// Auto-refresh functions
function startPhotosAutoRefresh() {
    // Clear existing interval if any
    stopPhotosAutoRefresh();
    
    // Refresh photos every 15 seconds
    photosRefreshInterval = setInterval(() => {
        // Only refresh if on photos tab
        const photosTab = document.getElementById('photos-tab');
        if (photosTab && photosTab.classList.contains('active')) {
            // Show refresh indicator
            const indicator = document.getElementById('autoRefreshIndicator');
            if (indicator) {
                indicator.classList.add('text-primary');
                const icon = indicator.querySelector('i');
                if (icon) icon.classList.add('rotating');
            }
            
            // Preserve scroll position during auto-refresh
            loadPhotos(true);
            
            // Update counts to show new items
            updateCounts();
            
            // Remove indicator after 1 second
            setTimeout(() => {
                if (indicator) {
                    indicator.classList.remove('text-primary');
                    const icon = indicator.querySelector('i');
                    if (icon) icon.classList.remove('rotating');
                }
            }, 1000);
        }
    }, 15000); // 15 seconds
}

function stopPhotosAutoRefresh() {
    if (photosRefreshInterval) {
        clearInterval(photosRefreshInterval);
        photosRefreshInterval = null;
    }
}

function startCommentsAutoRefresh() {
    // Clear existing interval if any
    stopCommentsAutoRefresh();
    
    // Refresh comments every 15 seconds
    commentsRefreshInterval = setInterval(() => {
        // Only refresh if on comments tab
        const commentsTab = document.getElementById('comments-tab');
        if (commentsTab && commentsTab.classList.contains('active')) {
            // Show refresh indicator
            const indicator = document.getElementById('autoRefreshIndicator');
            if (indicator) {
                indicator.classList.add('text-primary');
                const icon = indicator.querySelector('i');
                if (icon) icon.classList.add('rotating');
            }
            
            // Preserve scroll position during auto-refresh
            loadComments(true);
            
            // Update counts to show new items
            updateCounts();
            
            // Remove indicator after 1 second
            setTimeout(() => {
                if (indicator) {
                    indicator.classList.remove('text-primary');
                    const icon = indicator.querySelector('i');
                    if (icon) icon.classList.remove('rotating');
                }
            }, 1000);
        }
    }, 15000); // 15 seconds
}

function stopCommentsAutoRefresh() {
    if (commentsRefreshInterval) {
        clearInterval(commentsRefreshInterval);
        commentsRefreshInterval = null;
    }
}

// Stop auto-refresh when page is hidden (tab switched or minimized)
document.addEventListener('visibilitychange', function() {
    if (document.hidden) {
        stopPhotosAutoRefresh();
        stopCommentsAutoRefresh();
    } else {
        // Resume auto-refresh based on active tab
        const photosTab = document.getElementById('photos-tab');
        const commentsTab = document.getElementById('comments-tab');
        
        if (photosTab && photosTab.classList.contains('active')) {
            startPhotosAutoRefresh();
        } else if (commentsTab && commentsTab.classList.contains('active')) {
            startCommentsAutoRefresh();
        }
    }
});
