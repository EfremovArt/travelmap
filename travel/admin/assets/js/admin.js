/**
 * Admin Panel - Common JavaScript Functions
 */

// Initialize when DOM is ready
$(document).ready(function() {
    // Initialize tooltips
    initTooltips();
    
    // Initialize popovers
    initPopovers();
    
    // Initialize dropdowns explicitly for better mobile support with a small delay
    setTimeout(initDropdowns, 100);
    
    // Add active class to current page in sidebar
    highlightCurrentPage();
    
    // Initialize sidebar toggle
    initSidebarToggle();
    
    // Load moderation badge count
    updateModerationBadge();
    
    // Update badge every 2 minutes (120000ms) to reduce load
    setInterval(updateModerationBadge, 120000);
    
    // Load notifications immediately
    loadNotifications();
    
    // Reload notifications every 10 seconds for real-time updates
    setInterval(loadNotifications, 10000);
    
    // Reload notifications when dropdown is shown
    $('#notificationsDropdown').on('shown.bs.dropdown', function() {
        loadNotifications();
    });
});

/**
 * Initialize Bootstrap dropdowns explicitly
 */
function initDropdowns() {
    // Explicitly initialize all dropdowns for better mobile support
    const dropdownElementList = document.querySelectorAll('[data-bs-toggle="dropdown"]');
    const dropdownList = [...dropdownElementList].map(dropdownToggleEl => {
        return new bootstrap.Dropdown(dropdownToggleEl, {
            autoClose: true,
            boundary: 'viewport'
        });
    });
}



/**
 * Initialize Bootstrap tooltips
 */
function initTooltips() {
    const tooltipTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="tooltip"]'));
    tooltipTriggerList.map(function (tooltipTriggerEl) {
        return new bootstrap.Tooltip(tooltipTriggerEl);
    });
}

/**
 * Initialize Bootstrap popovers
 */
function initPopovers() {
    const popoverTriggerList = [].slice.call(document.querySelectorAll('[data-bs-toggle="popover"]'));
    popoverTriggerList.map(function (popoverTriggerEl) {
        return new bootstrap.Popover(popoverTriggerEl);
    });
}

/**
 * Highlight current page in sidebar
 */
function highlightCurrentPage() {
    const currentPath = window.location.pathname;
    $('.sidebar .nav-link').each(function() {
        const linkPath = $(this).attr('href');
        if (linkPath && currentPath.includes(linkPath)) {
            $(this).addClass('active');
        }
    });
}

/**
 * Show loading spinner
 */
function showLoading(containerId) {
    const container = document.getElementById(containerId);
    if (container) {
        container.innerHTML = `
            <div class="loading-spinner">
                <div class="spinner-border text-primary" role="status">
                    <span class="visually-hidden">Загрузка...</span>
                </div>
            </div>
        `;
    }
}

/**
 * Show error message
 */
function showError(message, title = 'Ошибка') {
    Swal.fire({
        icon: 'error',
        title: title,
        text: message,
        confirmButtonColor: '#3498db'
    });
}

/**
 * Show success message
 */
function showSuccess(message, title = 'Успешно') {
    Swal.fire({
        icon: 'success',
        title: title,
        text: message,
        confirmButtonColor: '#3498db',
        timer: 2000
    });
}

/**
 * Show confirmation dialog
 */
function showConfirmation(message, title = 'Подтверждение') {
    return Swal.fire({
        icon: 'warning',
        title: title,
        text: message,
        showCancelButton: true,
        confirmButtonColor: '#3498db',
        cancelButtonColor: '#d33',
        confirmButtonText: 'Да',
        cancelButtonText: 'Отмена'
    });
}

/**
 * Format date to readable format
 */
function formatDate(dateString) {
    const date = new Date(dateString);
    const options = { 
        year: 'numeric', 
        month: 'long', 
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    };
    return date.toLocaleDateString('ru-RU', options);
}

/**
 * Format number with thousands separator
 */
function formatNumber(number) {
    return number.toString().replace(/\B(?=(\d{3})+(?!\d))/g, " ");
}

/**
 * Truncate text to specified length
 */
function truncateText(text, maxLength) {
    if (text.length <= maxLength) return text;
    return text.substr(0, maxLength) + '...';
}

/**
 * Get user avatar or default
 */
function getUserAvatar(imagePath) {
    if (imagePath && imagePath !== '') {
        return imagePath;
    }
    return '/travel/uploads/default_avatar.png';
}

/**
 * Get photo thumbnail or default
 */
function getPhotoThumbnail(imagePath) {
    if (imagePath && imagePath !== '') {
        return imagePath;
    }
    return '/travel/uploads/default_photo.png';
}

/**
 * Initialize DataTable with common settings
 */
function initDataTable(tableId, options = {}) {
    const defaultOptions = {
        language: {
            url: '//cdn.datatables.net/plug-ins/1.13.6/i18n/ru.json'
        },
        pageLength: 25,
        lengthMenu: [[10, 25, 50, 100], [10, 25, 50, 100]],
        order: [[0, 'desc']],
        responsive: true,
        processing: true
    };
    
    const mergedOptions = { ...defaultOptions, ...options };
    return $(tableId).DataTable(mergedOptions);
}

/**
 * Reload DataTable
 */
function reloadDataTable(table) {
    if (table) {
        table.ajax.reload(null, false);
    }
}

/**
 * Make AJAX request
 */
function makeAjaxRequest(url, method = 'GET', data = null) {
    return new Promise((resolve, reject) => {
        $.ajax({
            url: url,
            method: method,
            data: data,
            dataType: 'json',
            success: function(response) {
                resolve(response);
            },
            error: function(xhr, status, error) {
                reject({
                    status: xhr.status,
                    message: error,
                    response: xhr.responseJSON
                });
            }
        });
    });
}

/**
 * Handle AJAX error
 */
function handleAjaxError(error) {
    console.error('AJAX Error:', error);
    
    let message = 'Произошла ошибка при выполнении запроса';
    
    if (error.response && error.response.message) {
        message = error.response.message;
    } else if (error.message) {
        message = error.message;
    }
    
    showError(message);
}

/**
 * Debounce function for search inputs
 */
function debounce(func, wait) {
    let timeout;
    return function executedFunction(...args) {
        const later = () => {
            clearTimeout(timeout);
            func(...args);
        };
        clearTimeout(timeout);
        timeout = setTimeout(later, wait);
    };
}

/**
 * Export table to CSV
 */
function exportTableToCSV(tableId, filename) {
    const table = document.getElementById(tableId);
    let csv = [];
    const rows = table.querySelectorAll('tr');
    
    for (let i = 0; i < rows.length; i++) {
        const row = [];
        const cols = rows[i].querySelectorAll('td, th');
        
        for (let j = 0; j < cols.length; j++) {
            row.push(cols[j].innerText);
        }
        
        csv.push(row.join(','));
    }
    
    downloadCSV(csv.join('\n'), filename);
}

/**
 * Download CSV file
 */
function downloadCSV(csv, filename) {
    const csvFile = new Blob([csv], { type: 'text/csv' });
    const downloadLink = document.createElement('a');
    downloadLink.download = filename;
    downloadLink.href = window.URL.createObjectURL(csvFile);
    downloadLink.style.display = 'none';
    document.body.appendChild(downloadLink);
    downloadLink.click();
    document.body.removeChild(downloadLink);
}


/**
 * Initialize sidebar toggle for mobile
 */
function initSidebarToggle() {
    // Обработчик для кнопки меню
    $('#sidebarToggle').on('click', function(e) {
        e.preventDefault();
        $('#sidebarMenu').toggleClass('show');
        
        if ($('#sidebarMenu').hasClass('show')) {
            $('body').append('<div class="offcanvas-backdrop fade show"></div>');
            $('body').addClass('offcanvas-open');
        }
    });
    
    // Закрытие сайдбара при клике на backdrop
    $(document).on('click', '.offcanvas-backdrop', function() {
        $('#sidebarMenu').removeClass('show');
        $('.offcanvas-backdrop').remove();
        $('body').removeClass('offcanvas-open');
    });
    
    // Закрытие сайдбара при клике на ссылку
    $('#sidebarMenu a').on('click', function() {
        if (window.innerWidth < 992) { // Только на мобильных
            $('#sidebarMenu').removeClass('show');
            $('.offcanvas-backdrop').remove();
            $('body').removeClass('offcanvas-open');
        }
    });
}

/**
 * Update moderation badge with pending photos count
 */
function updateModerationBadge() {
    $.ajax({
        url: '/travel/admin/api/moderation/get_pending_count.php',
        type: 'GET',
        dataType: 'json',
        success: function(response) {
            if (response.success && response.count > 0) {
                $('#moderationBadge').text(response.count).show();
            } else {
                $('#moderationBadge').hide();
            }
        },
        error: function() {
            // Тихо игнорируем ошибки, чтобы не мешать работе
            console.log('Failed to load moderation count');
        }
    });
}

/**
 * Load and display notifications with view tracking
 */
function loadNotifications() {
    $.ajax({
        url: '/travel/admin/api/moderation/get_new_counts.php',
        type: 'GET',
        dataType: 'json',
        success: function(response) {
            console.log('Notifications API response:', response);
            if (response.success) {
                console.log('New photos:', response.counts.newPhotos);
                console.log('New comments:', response.counts.newComments);
                updateNotificationUI(response.counts);
            } else {
                console.error('API returned success=false:', response);
            }
        },
        error: function(xhr, status, error) {
            console.error('Failed to load notifications:', error);
            console.error('Status:', status);
            console.error('Response:', xhr.responseText);
        }
    });
}

// Store previous notification count
let previousNotificationCount = 0;

/**
 * Update notification UI with counts (using view tracking)
 */
function updateNotificationUI(counts) {
    const newPhotos = counts.newPhotos || 0;
    const newComments = counts.newComments || 0;
    const total = newPhotos + newComments;
    
    // Check if there are new notifications
    if (total > previousNotificationCount && previousNotificationCount > 0) {
        showNotificationToast(newPhotos, newComments);
    }
    previousNotificationCount = total;
    
    // Update badge with animation
    const badge = $('#notificationBadge');
    if (total > 0) {
        const oldValue = badge.text();
        badge.text(total > 99 ? '99+' : total).show();
        
        // Add pulse animation if count increased
        if (oldValue !== badge.text()) {
            badge.addClass('pulse-animation');
            setTimeout(() => badge.removeClass('pulse-animation'), 1000);
        }
        
        $('#totalNotifications').text(total);
    } else {
        badge.hide();
        $('#totalNotifications').text('0');
    }
    
    // Build notifications list
    let html = '';
    
    if (total === 0) {
        html = `
            <div class="text-center py-3 text-muted">
                <i class="bi bi-check-circle fs-3"></i>
                <p class="mb-0 small">Нет новых уведомлений</p>
            </div>
        `;
    } else {
        if (newPhotos > 0) {
            html += `
                <a class="dropdown-item d-flex justify-content-between align-items-center notification-link" href="/travel/admin/views/moderation.php" data-view-type="photos">
                    <span>
                        <i class="bi bi-image text-warning"></i>
                        Новые фото на модерации
                    </span>
                    <span class="badge bg-warning text-dark">${newPhotos}</span>
                </a>
            `;
        }
        
        if (newComments > 0) {
            html += `
                <a class="dropdown-item d-flex justify-content-between align-items-center notification-link" href="/travel/admin/views/moderation.php#comments" data-view-type="comments">
                    <span>
                        <i class="bi bi-chat-dots text-danger"></i>
                        Новые комментарии
                    </span>
                    <span class="badge bg-danger">${newComments}</span>
                </a>
            `;
        }
    }
    
    $('#notificationsList').html(html);
    
    // Add click handlers to mark as viewed
    $('.notification-link').on('click', function() {
        const viewType = $(this).data('view-type');
        if (viewType) {
            markNotificationAsViewed(viewType);
        }
    });
}

/**
 * Show toast notification for new items
 */
function showNotificationToast(newPhotos, newComments) {
    let message = '';
    if (newPhotos > 0 && newComments > 0) {
        message = `Новые фото (${newPhotos}) и комментарии (${newComments})`;
    } else if (newPhotos > 0) {
        message = `Новые фото на модерации (${newPhotos})`;
    } else if (newComments > 0) {
        message = `Новые комментарии (${newComments})`;
    }
    
    if (message) {
        // Create toast element if it doesn't exist
        if (!document.getElementById('notificationToast')) {
            const toastHtml = `
                <div class="position-fixed bottom-0 end-0 p-3" style="z-index: 11">
                    <div id="notificationToast" class="toast" role="alert" aria-live="assertive" aria-atomic="true">
                        <div class="toast-header bg-primary text-white">
                            <i class="bi bi-bell-fill me-2"></i>
                            <strong class="me-auto">Новое уведомление</strong>
                            <button type="button" class="btn-close btn-close-white" data-bs-dismiss="toast" aria-label="Close"></button>
                        </div>
                        <div class="toast-body" id="notificationToastBody">
                        </div>
                    </div>
                </div>
            `;
            $('body').append(toastHtml);
        }
        
        // Update toast message and show
        $('#notificationToastBody').html(`
            <p class="mb-2">${message}</p>
            <a href="/travel/admin/views/moderation.php" class="btn btn-sm btn-primary">
                <i class="bi bi-eye"></i> Перейти к модерации
            </a>
        `);
        
        const toastEl = document.getElementById('notificationToast');
        const toast = new bootstrap.Toast(toastEl, {
            autohide: true,
            delay: 5000
        });
        toast.show();
    }
}

/**
 * Mark notification as viewed
 */
function markNotificationAsViewed(viewType) {
    $.ajax({
        url: '/travel/admin/api/moderation/mark_as_viewed.php',
        type: 'POST',
        data: { view_type: viewType },
        dataType: 'json',
        success: function(response) {
            if (response.success) {
                // Reload notifications after marking as viewed
                setTimeout(loadNotifications, 500);
            }
        },
        error: function() {
            console.log('Failed to mark as viewed');
        }
    });
}


