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
        
        table = $('#followsTable').DataTable({
            processing: true,
            serverSide: true,
            ajax: {
                url: '../api/follows/get_all_follows.php',
                type: 'GET',
                cache: false,
                data: function(d) {
                    // Map DataTables parameters to our API
                    return {
                        page: Math.floor(d.start / d.length) + 1,
                        per_page: d.length,
                        search: d.search.value,
                        sort_by: getSortColumn(d.order[0].column),
                        sort_order: d.order[0].dir,
                        user_id: filters.user_id || '',
                        _: new Date().getTime() // Cache buster
                    };
                },
                dataSrc: function(json) {
                    console.log('API Response:', json);
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
                    
                    console.log('Follows data:', json.follows);
                    if (json.follows.length > 0) {
                        console.log('First follow sample:', json.follows[0]);
                    }
                    
                    return json.follows;
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
                        if (row.followerImage) {
                            const followerImageSrc = normalizeImageUrl(row.followerImage);
                            img = `<img src="${followerImageSrc}" class="rounded-circle me-2" style="width: 30px; height: 30px; object-fit: cover;">`;
                        } else {
                            img = `<div class="rounded-circle bg-secondary d-inline-block me-2" style="width: 30px; height: 30px;"></div>`;
                        }
                        const followerId = row.followerId || row.follower_id || 0;
                        return `<a href="user_details.php?id=${followerId}" class="text-decoration-none" onclick="console.log('Follower ID:', ${followerId})">
                                    ${img}${escapeHtml(row.followerName)}
                                </a>`;
                    },
                    orderable: true
                },
                { 
                    data: 'followerEmail',
                    render: function(data) {
                        return escapeHtml(data);
                    }
                },
                { 
                    data: null,
                    render: function(data, type, row) {
                        let img = '';
                        if (row.followedImage) {
                            const followedImageSrc = normalizeImageUrl(row.followedImage);
                            img = `<img src="${followedImageSrc}" class="rounded-circle me-2" style="width: 30px; height: 30px; object-fit: cover;">`;
                        } else {
                            img = `<div class="rounded-circle bg-secondary d-inline-block me-2" style="width: 30px; height: 30px;"></div>`;
                        }
                        const followedId = row.followedId || row.followed_id || 0;
                        return `<a href="user_details.php?id=${followedId}" class="text-decoration-none" onclick="console.log('Followed ID:', ${followedId})">
                                    ${img}${escapeHtml(row.followedName)}
                                </a>`;
                    },
                    orderable: true
                },
                { 
                    data: 'followedEmail',
                    render: function(data) {
                        return escapeHtml(data);
                    }
                },
                { 
                    data: 'createdAt',
                    render: function(data) {
                        return formatDateTime(data);
                    },
                    orderable: true
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
        const columns = ['id', 'follower_name', 'followerEmail', 'followed_name', 'followedEmail', 'created_at'];
        return columns[columnIndex] || 'created_at';
    }
    
    // Initialize table on page load
    initDataTable();
    
    // Handle filter form submission
    $('#filterForm').on('submit', function(e) {
        e.preventDefault();
        
        const filters = {
            user_id: $('#userFilter').val()
        };
        
        initDataTable(filters);
    });
    
    // Handle reset filters
    $('#resetFilters').on('click', function() {
        $('#filterForm')[0].reset();
        initDataTable();
    });
    
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
