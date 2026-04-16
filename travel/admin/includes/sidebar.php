            <!-- Offcanvas Sidebar - используется на ВСЕХ устройствах -->
            <div class="offcanvas offcanvas-start" tabindex="-1" id="sidebarMenu" aria-labelledby="sidebarMenuLabel">
                <div class="offcanvas-header bg-light">
                    <h5 class="offcanvas-title" id="sidebarMenuLabel">
                        <i class="bi bi-map"></i> Меню
                    </h5>
                    <button type="button" class="btn-close" data-bs-dismiss="offcanvas" aria-label="Close"></button>
                </div>
                <div class="offcanvas-body bg-light p-0">
                    <ul class="nav flex-column">
                        <li class="nav-item">
                            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'index.php' ? 'active' : ''; ?>" href="/travel/admin/index.php">
                                <i class="bi bi-speedometer2"></i> Dashboard
                            </a>
                        </li>
                        
                        <li class="nav-item">
                            <h6 class="sidebar-heading d-flex justify-content-between align-items-center px-3 mt-4 mb-1 text-muted">
                                <span>Контент</span>
                            </h6>
                        </li>
                        
                        <li class="nav-item">
                            <a class="nav-link <?php echo in_array(basename($_SERVER['PHP_SELF']), ['posts.php', 'commercial_post_details.php']) ? 'active' : ''; ?>" href="/travel/admin/views/posts.php">
                                <i class="bi bi-images"></i> Публикации
                            </a>
                        </li>
                        
                        <li class="nav-item">
                            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'moderation.php' ? 'active' : ''; ?>" href="/travel/admin/views/moderation.php">
                                <i class="bi bi-shield-check"></i> Модерация
                                <span id="moderationBadge" class="badge bg-danger ms-2" style="display: none;">0</span>
                            </a>
                        </li>
                        
                        <li class="nav-item">
                            <h6 class="sidebar-heading d-flex justify-content-between align-items-center px-3 mt-4 mb-1 text-muted">
                                <span>Пользователи</span>
                            </h6>
                        </li>
                        
                        <li class="nav-item">
                            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'users.php' ? 'active' : ''; ?>" href="/travel/admin/views/users.php">
                                <i class="bi bi-people"></i> Пользователи
                            </a>
                        </li>
                        
                        <li class="nav-item">
                            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'follows.php' ? 'active' : ''; ?>" href="/travel/admin/views/follows.php">
                                <i class="bi bi-person-plus"></i> Подписки
                            </a>
                        </li>
                        
                        <li class="nav-item">
                            <h6 class="sidebar-heading d-flex justify-content-between align-items-center px-3 mt-4 mb-1 text-muted">
                                <span>Активность</span>
                            </h6>
                        </li>
                        
                        <li class="nav-item">
                            <a class="nav-link <?php echo basename($_SERVER['PHP_SELF']) == 'activity.php' ? 'active' : ''; ?>" href="/travel/admin/views/activity.php">
                                <i class="bi bi-activity"></i> Лента активности
                            </a>
                        </li>
                    </ul>
                </div>
            </div>
