<?php
require_once __DIR__ . '/config/admin_config.php';
adminRequireAuth();

// Include header
include __DIR__ . '/includes/header.php';
?>

<?php include __DIR__ . '/includes/sidebar.php'; ?>

            <!-- Main Content -->
            <main class="col-12 px-3 px-md-4 content-wrapper">
                <div class="page-header d-flex justify-content-between flex-wrap flex-md-nowrap align-items-center pt-3 pb-2 mb-3">
                    <h1 class="h2">Dashboard</h1>
                </div>

                <!-- Date Filter -->
                <div class="card mb-4">
                    <div class="card-body">
                        <div class="row align-items-end g-3">
                            <div class="col-md-3">
                                <label for="dateFrom" class="form-label">С даты</label>
                                <input type="date" class="form-control" id="dateFrom">
                            </div>
                            <div class="col-md-3">
                                <label for="dateTo" class="form-label">По дату</label>
                                <input type="date" class="form-control" id="dateTo">
                            </div>
                            <div class="col-md-6">
                                <div class="btn-group" role="group">
                                    <button type="button" class="btn btn-outline-primary" id="btnToday">Сегодня</button>
                                    <button type="button" class="btn btn-outline-primary" id="btnYesterday">Вчера</button>
                                    <button type="button" class="btn btn-outline-primary" id="btnWeek">Неделя</button>
                                    <button type="button" class="btn btn-outline-primary" id="btnMonth">Месяц</button>
                                    <button type="button" class="btn btn-outline-primary active" id="btnAll">Все время</button>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Statistics Cards -->
                <div class="row mb-4">
                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card stat-card card-primary">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div>
                                        <div class="stat-label">Пользователи</div>
                                        <div class="stat-value" id="totalUsers">-</div>
                                    </div>
                                    <div class="stat-icon">
                                        <i class="fas fa-users"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card stat-card card-success">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div>
                                        <div class="stat-label">Публикации</div>
                                        <div class="stat-value" id="totalPosts">-</div>
                                    </div>
                                    <div class="stat-icon">
                                        <i class="fas fa-images"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card stat-card card-info">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div>
                                        <div class="stat-label">Лайки</div>
                                        <div class="stat-value" id="totalLikes">-</div>
                                    </div>
                                    <div class="stat-icon">
                                        <i class="fas fa-heart"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card stat-card card-warning">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div>
                                        <div class="stat-label">Комментарии</div>
                                        <div class="stat-value" id="totalComments">-</div>
                                    </div>
                                    <div class="stat-icon">
                                        <i class="fas fa-comments"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Additional Stats Row -->
                <div class="row mb-4">
                    <div class="col-xl-4 col-md-6 mb-4">
                        <div class="card stat-card card-danger">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div>
                                        <div class="stat-label">Подписки</div>
                                        <div class="stat-value" id="totalFollows">-</div>
                                    </div>
                                    <div class="stat-icon">
                                        <i class="fas fa-user-friends"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-xl-4 col-md-6 mb-4">
                        <div class="card stat-card card-secondary">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div>
                                        <div class="stat-label">Избранное</div>
                                        <div class="stat-value" id="totalFavorites">-</div>
                                    </div>
                                    <div class="stat-icon">
                                        <i class="fas fa-star"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card stat-card" style="background: linear-gradient(135deg, #ffecd2 0%, #fcb69f 100%);">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div>
                                        <div class="stat-label">Альбомы</div>
                                        <div class="stat-value" id="totalAlbums">-</div>
                                    </div>
                                    <div class="stat-icon">
                                        <i class="fas fa-folder"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>

                    <div class="col-xl-3 col-md-6 mb-4">
                        <div class="card stat-card" style="background: linear-gradient(135deg, #a8edea 0%, #fed6e3 100%);">
                            <div class="card-body">
                                <div class="d-flex justify-content-between align-items-center">
                                    <div>
                                        <div class="stat-label">Коммерческие посты</div>
                                        <div class="stat-value" id="totalCommercialPosts">-</div>
                                    </div>
                                    <div class="stat-icon">
                                        <i class="fas fa-bullhorn"></i>
                                    </div>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

                <!-- Activity Chart -->
                <div class="row">
                    <div class="col-12">
                        <div class="card">
                            <div class="card-header">
                                <h5 class="card-title mb-0">Активность за последние 7 дней</h5>
                            </div>
                            <div class="card-body">
                                <div class="chart-container">
                                    <canvas id="activityChart"></canvas>
                                </div>
                            </div>
                        </div>
                    </div>
                </div>

            </main>

<?php include __DIR__ . '/includes/footer.php'; ?>

<style>
/* Override stat card label colors */
.stat-card .stat-label {
    color: #ffffff !important;
}

.stat-card.card-primary .stat-label,
.stat-card.card-success .stat-label,
.stat-card.card-info .stat-label,
.stat-card.card-warning .stat-label,
.stat-card.card-danger .stat-label,
.stat-card.card-secondary .stat-label {
    color: #ffffff !important;
}
</style>

<script>
// Load dashboard statistics
let activityChart = null;

// Set date range
function setDateRange(range) {
    const today = new Date();
    const dateFrom = document.getElementById('dateFrom');
    const dateTo = document.getElementById('dateTo');
    
    // Remove active class from all buttons
    document.querySelectorAll('.btn-group .btn').forEach(btn => btn.classList.remove('active'));
    
    let fromDate, toDate;
    
    switch(range) {
        case 'today':
            fromDate = toDate = today;
            document.getElementById('btnToday').classList.add('active');
            break;
        case 'yesterday':
            fromDate = toDate = new Date(today);
            fromDate.setDate(today.getDate() - 1);
            toDate.setDate(today.getDate() - 1);
            document.getElementById('btnYesterday').classList.add('active');
            break;
        case 'week':
            fromDate = new Date(today);
            fromDate.setDate(today.getDate() - 7);
            toDate = today;
            document.getElementById('btnWeek').classList.add('active');
            break;
        case 'month':
            fromDate = new Date(today);
            fromDate.setMonth(today.getMonth() - 1);
            toDate = today;
            document.getElementById('btnMonth').classList.add('active');
            break;
        case 'all':
        default:
            dateFrom.value = '';
            dateTo.value = '';
            document.getElementById('btnAll').classList.add('active');
            loadDashboardStats();
            return;
    }
    
    // Format dates as YYYY-MM-DD
    dateFrom.value = fromDate.toISOString().split('T')[0];
    dateTo.value = toDate.toISOString().split('T')[0];
    
    // Load stats with date range
    loadDashboardStats(dateFrom.value, dateTo.value);
}

$(document).ready(function() {
    // Set today's date as default for date inputs
    const today = new Date().toISOString().split('T')[0];
    document.getElementById('dateTo').value = today;
    
    // Load initial stats
    loadDashboardStats();
    
    // Date filter buttons
    document.getElementById('btnToday').addEventListener('click', () => setDateRange('today'));
    document.getElementById('btnYesterday').addEventListener('click', () => setDateRange('yesterday'));
    document.getElementById('btnWeek').addEventListener('click', () => setDateRange('week'));
    document.getElementById('btnMonth').addEventListener('click', () => setDateRange('month'));
    document.getElementById('btnAll').addEventListener('click', () => setDateRange('all'));
    
    // Manual date selection
    document.getElementById('dateFrom').addEventListener('change', function() {
        const dateFrom = this.value;
        const dateTo = document.getElementById('dateTo').value;
        if (dateFrom && dateTo) {
            document.querySelectorAll('.btn-group .btn').forEach(btn => btn.classList.remove('active'));
            loadDashboardStats(dateFrom, dateTo);
        }
    });
    
    document.getElementById('dateTo').addEventListener('change', function() {
        const dateFrom = document.getElementById('dateFrom').value;
        const dateTo = this.value;
        if (dateFrom && dateTo) {
            document.querySelectorAll('.btn-group .btn').forEach(btn => btn.classList.remove('active'));
            loadDashboardStats(dateFrom, dateTo);
        }
    });
});

async function loadDashboardStats(dateFrom = null, dateTo = null) {
    try {
        let url = 'api/dashboard/get_stats.php';
        if (dateFrom && dateTo) {
            url += `?date_from=${dateFrom}&date_to=${dateTo}`;
        }
        
        const response = await fetch(url);
        const data = await response.json();
        
        if (data.success) {
            const stats = data.stats;
            
            // Update stat cards
            $('#totalUsers').text(stats.totalUsers.toLocaleString());
            $('#totalPosts').text(stats.totalPosts.toLocaleString());
            $('#totalLikes').text(stats.totalLikes.toLocaleString());
            $('#totalComments').text(stats.totalComments.toLocaleString());
            $('#totalFollows').text(stats.totalFollows.toLocaleString());
            $('#totalFavorites').text(stats.totalFavorites.toLocaleString());
            $('#totalAlbums').text(stats.totalAlbums.toLocaleString());
            $('#totalCommercialPosts').text(stats.totalCommercialPosts.toLocaleString());
            
            // Initialize activity chart with real data
            initActivityChart(stats.activityData);
        } else {
            console.error('Error loading stats:', data.message);
            showError('Ошибка загрузки статистики');
        }
    } catch (error) {
        console.error('Error:', error);
        showError('Ошибка при загрузке данных');
    }
}

function initActivityChart(activityData) {
    const ctx = document.getElementById('activityChart');
    if (!ctx) return;
    
    // Destroy existing chart if it exists
    if (activityChart) {
        activityChart.destroy();
    }
    
    const labels = activityData.map(item => item.date);
    const usersData = activityData.map(item => item.users);
    const postsData = activityData.map(item => item.posts);
    const commentsData = activityData.map(item => item.comments);
    
    activityChart = new Chart(ctx, {
        type: 'line',
        data: {
            labels: labels,
            datasets: [{
                label: 'Новые пользователи',
                data: usersData,
                borderColor: '#667eea',
                backgroundColor: 'rgba(102, 126, 234, 0.1)',
                tension: 0.4
            }, {
                label: 'Новые посты',
                data: postsData,
                borderColor: '#f5576c',
                backgroundColor: 'rgba(245, 87, 108, 0.1)',
                tension: 0.4
            }, {
                label: 'Новые комментарии',
                data: commentsData,
                borderColor: '#4facfe',
                backgroundColor: 'rgba(79, 172, 254, 0.1)',
                tension: 0.4
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: {
                    position: 'top',
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        stepSize: 1
                    }
                }
            }
        }
    });
}

function showError(message) {
    const alertDiv = $('<div class="alert alert-danger alert-dismissible fade show" role="alert">' +
        message +
        '<button type="button" class="btn-close" data-bs-dismiss="alert"></button>' +
        '</div>');
    $('.page-header').after(alertDiv);
}
</script>
