let usersTable = null; // Глобальная переменная для доступа из обработчиков

$(document).ready(function() {
    let table = null;
    
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
    function initDataTable() {
        if (table) {
            table.destroy();
        }
        
        table = usersTable = $('#usersTable').DataTable({
            searching: false, // Отключаем встроенный поиск, используем свой
            processing: true,
            serverSide: true,
            ajax: {
                url: '../api/users/get_all_users.php',
                type: 'GET',
                data: function(d) {
                    const searchValue = $('#searchInput').val().trim();
                    return {
                        page: Math.floor(d.start / d.length) + 1,
                        per_page: d.length,
                        search: searchValue,
                        sort_by: getSortColumn(d.order[0].column),
                        sort_order: d.order[0].dir
                    };
                },
                dataSrc: function(json) {
                    if (!json.success) {
                        return [];
                    }
                    
                    json.recordsTotal = json.pagination.total;
                    json.recordsFiltered = json.pagination.total;
                    
                    return json.users;
                }
            },
            columns: [
                { 
                    data: 'id',
                    width: '50px',
                    className: 'align-middle'
                },
                {
                    data: null,
                    render: function(data) {
                        const img = normalizeImageUrl(data.profileImage) || '/travel/admin/assets/images/default-avatar.svg';
                        return `<img src="${img}" alt="${data.firstName} ${data.lastName}" style="width:40px;height:40px;border-radius:50%;object-fit:cover;flex-shrink:0;">`;
                    },
                    orderable: false,
                    width: '60px',
                    className: 'align-middle'
                },
                {
                    data: null,
                    render: function(data) {
                        const fullName = `${data.firstName} ${data.lastName}`;
                        return `<a href="user_details.php?id=${data.id}" style="word-break: break-word; min-width: 0;">${fullName}</a>`;
                    },
                    className: 'align-middle'
                },
                { 
                    data: null,
                    render: function(data) {
                        if (data.email) {
                            return `<span style="word-break: break-word; min-width: 0;">${data.email}</span>`;
                        } else if (data.appleId) {
                            return `<span class="text-muted" style="word-break: break-word; min-width: 0;"><i class="bi bi-apple"></i> ${data.appleId}</span>`;
                        }
                        return '<span class="text-muted">—</span>';
                    },
                    className: 'align-middle'
                },
                { 
                    data: 'followersCount',
                    className: 'text-center align-middle d-none d-lg-table-cell'
                },
                { 
                    data: 'followingCount',
                    className: 'text-center align-middle d-none d-lg-table-cell'
                },
                { 
                    data: 'postsCount',
                    className: 'text-center align-middle d-none d-md-table-cell'
                },
                { 
                    data: 'likesCount',
                    className: 'text-center align-middle d-none d-xl-table-cell'
                },
                { 
                    data: 'commentsCount',
                    className: 'text-center align-middle d-none d-xl-table-cell'
                },
                { 
                    data: 'createdAt',
                    render: function(data) {
                        return new Date(data).toLocaleDateString('ru-RU');
                    },
                    className: 'align-middle d-none d-md-table-cell'
                },
                {
                    data: null,
                    orderable: false,
                    render: function(data) {
                        return `
                            <div class="btn-group" role="group">
                                <a href="user_details.php?id=${data.id}" class="btn btn-sm btn-info" title="Просмотр">
                                    <i class="bi bi-eye"></i>
                                </a>
                                <button class="btn btn-sm btn-danger delete-user" data-user-id="${data.id}" data-user-name="${data.firstName} ${data.lastName}" title="Удалить">
                                    <i class="bi bi-trash"></i>
                                </button>
                            </div>
                        `;
                    },
                    width: '100px',
                    className: 'align-middle'
                }
            ],
            order: [[0, 'desc']],
            pageLength: 25,
            language: {
                url: '//cdn.datatables.net/plug-ins/1.13.4/i18n/ru.json'
            }
        });
    }
    
    function getSortColumn(columnIndex) {
        const columns = ['id', null, 'first_name', 'email', 'followers_count', 'following_count', 'posts_count', 'likes_count', 'comments_count', 'created_at', null];
        return columns[columnIndex] || 'id';
    }
    
    // Initialize table
    initDataTable();
    
    // Search function
    function performSearch() {
        if (table) {
            table.ajax.reload();
        }
    }
    
    // Search - перезагружаем данные с сервера
    $('#searchInput').on('keyup', debounce(performSearch, 500));
    
    // Search button click
    $('#searchBtn').on('click', performSearch);
    
    // Search on Enter key
    $('#searchInput').on('keypress', function(e) {
        if (e.which === 13) {
            e.preventDefault();
            performSearch();
        }
    });
    
    // Debounce helper
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
});

    // Delete user handler
    $(document).on('click', '.delete-user', function() {
        const userId = $(this).data('user-id');
        const userName = $(this).data('user-name');
        
        // Show confirmation dialog
        if (confirm(`Вы уверены, что хотите удалить пользователя "${userName}"?\n\nЭто действие удалит:\n- Все посты пользователя\n- Все альбомы\n- Все комментарии\n- Все лайки\n- Все подписки\n- Все платные посты\n\nЭто действие необратимо!`)) {
            // Show loading state
            const $btn = $(this);
            const originalHtml = $btn.html();
            $btn.prop('disabled', true).html('<i class="bi bi-hourglass-split"></i>');
            
            // Send delete request
            $.ajax({
                url: '../api/users/delete_user.php',
                type: 'POST',
                data: { user_id: userId },
                dataType: 'json',
                success: function(response) {
                    if (response.success) {
                        // Show success message
                        alert('Пользователь успешно удален');
                        
                        // Reload table
                        if (usersTable) {
                            usersTable.ajax.reload();
                        } else {
                            // Fallback: reload page if table not available
                            location.reload();
                        }
                    } else {
                        alert('Ошибка: ' + response.message);
                        $btn.prop('disabled', false).html(originalHtml);
                    }
                },
                error: function(xhr) {
                    let errorMsg = 'Ошибка при удалении пользователя';
                    try {
                        const response = JSON.parse(xhr.responseText);
                        if (response.message) {
                            errorMsg = response.message;
                        }
                    } catch (e) {
                        // Ignore parse error
                    }
                    alert(errorMsg);
                    $btn.prop('disabled', false).html(originalHtml);
                }
            });
        }
    });
