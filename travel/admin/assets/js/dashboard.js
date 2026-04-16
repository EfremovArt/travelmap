// Dashboard JavaScript
let activityChart = null;
let currentDateRange = 'all';

// Load dashboard statistics
async function loadDashboardStats(dateFrom = null, dateTo = null) {
    try {
        let url = '../api/dashboard/get_stats.php';
        if (dateFrom && dateTo) {
            url += `?date_from=${dateFrom}&date_to=${dateTo}`;
        }
        
        const response = await fetch(url);
        const data = await response.json();
        
        if (data.success) {
            const stats = data.stats;
            
            // Update stat cards
            document.getElementById('totalUsers').textContent = stats.totalUsers.toLocaleString();
            document.getElementById('totalPosts').textContent = stats.totalPosts.toLocaleString();
            document.getElementById('totalLikes').textContent = stats.totalLikes.toLocaleString();
            document.getElementById('totalComments').textContent = stats.totalComments.toLocaleString();
            document.getElementById('totalFollows').textContent = stats.totalFollows.toLocaleString();
            document.getElementById('totalFavorites').textContent = stats.totalFavorites.toLocaleString();
            document.getElementById('totalAlbums').textContent = stats.totalAlbums.toLocaleString();
            document.getElementById('totalCommercialPosts').textContent = stats.totalCommercialPosts.toLocaleString();
            
            // Update recent activity
            document.getElementById('newUsers').textContent = stats.recentActivity.newUsers.toLocaleString();
            document.getElementById('newPosts').textContent = stats.recentActivity.newPosts.toLocaleString();
            document.getElementById('newComments').textContent = stats.recentActivity.newComments.toLocaleString();
            
            // Create activity chart
            createActivityChart(stats.activityData);
        } else {
            console.error('Error loading stats:', data.message);
            showError('Ошибка загрузки статистики');
        }
    } catch (error) {
        console.error('Error:', error);
        showError('Ошибка при загрузке данных');
    }
}

// Create activity chart using Chart.js
function createActivityChart(activityData) {
    const ctx = document.getElementById('activityChart');
    
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
            datasets: [
                {
                    label: 'Новые пользователи',
                    data: usersData,
                    borderColor: 'rgb(75, 192, 192)',
                    backgroundColor: 'rgba(75, 192, 192, 0.2)',
                    tension: 0.1
                },
                {
                    label: 'Новые посты',
                    data: postsData,
                    borderColor: 'rgb(54, 162, 235)',
                    backgroundColor: 'rgba(54, 162, 235, 0.2)',
                    tension: 0.1
                },
                {
                    label: 'Новые комментарии',
                    data: commentsData,
                    borderColor: 'rgb(255, 206, 86)',
                    backgroundColor: 'rgba(255, 206, 86, 0.2)',
                    tension: 0.1
                }
            ]
        },
        options: {
            responsive: true,
            maintainAspectRatio: true,
            plugins: {
                legend: {
                    position: 'top',
                },
                title: {
                    display: false
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

// Show error message
function showError(message) {
    const statsCards = document.getElementById('statsCards');
    const alertDiv = document.createElement('div');
    alertDiv.className = 'alert alert-danger alert-dismissible fade show';
    alertDiv.innerHTML = `
        ${message}
        <button type="button" class="btn-close" data-bs-dismiss="alert"></button>
    `;
    statsCards.parentNode.insertBefore(alertDiv, statsCards);
}

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

// Initialize dashboard on page load
document.addEventListener('DOMContentLoaded', function() {
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
