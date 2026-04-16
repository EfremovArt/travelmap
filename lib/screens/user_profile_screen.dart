import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../models/post.dart';
import '../models/location.dart';
import '../services/post_service.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../widgets/post_card.dart';
import '../widgets/comments_modal.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';
import '../screens/edit/edit_post_screen.dart';
import '../screens/location_posts_screen.dart';
import '../screens/image_viewer/vertical_photo_gallery_screen.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/album_service.dart';
import '../widgets/album_card.dart';
import '../services/commercial_post_service.dart';
import '../models/commercial_post.dart';
import '../widgets/commercial_post_card.dart';
import 'image_viewer/commercial_post_gallery_screen.dart';
import 'edit_commercial_post_screen.dart';
import 'create_commercial_post_screen.dart';
import 'upload/upload_description_screen.dart';
import '../tabs/albums_tab.dart' show CreateAlbumScreen, AlbumDetailScreen, EditAlbumScreen;
import '../services/map_filter_service.dart';
import 'main_screen.dart';
import 'dart:async';
import 'commercial_post_map_screen.dart';

class UserProfileScreen extends StatefulWidget {
  final String userId;
  final String? initialProfileImage;
  final String initialName;
  final int sourceTabIndex;
  // Опционально: заранее загруженные посты для мгновенной прокрутки без ожидания сети
  final List<Post>? initialPosts;

  const UserProfileScreen({
    Key? key,
    required this.userId,
    this.initialProfileImage,
    required this.initialName,
    this.sourceTabIndex = 0,
    this.initialPosts,
  }) : super(key: key);

  @override
  _UserProfileScreenState createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  late Future<Map<String, dynamic>> _userDataFuture;
  late Future<List<Post>> _userPostsFuture;
  bool _isCurrentUser = false;
  bool _isFollowing = false;
  String _currentUserId = '';
  int _followersCount = 0;
  int _followingCount = 0;
  
  // Информация об авторе (имя и аватарка) для использования в постах
  String _authorName = '';
  String _authorProfileImage = '';

  // Новое: будущее для альбомов пользователя
  Future<List<Map<String, dynamic>>>? _userAlbumsFuture;

  // Новое: агрегированные счётчики
  bool _statsLoading = false;
  int _totalLikes = 0;
  int _totalFavorites = 0;
  int _totalComments = 0;

  // Переменная для отслеживания, показывать ли bottomNavigationBar
  bool _showBottomNav = false;
  
  // ScrollController для прокрутки к нужному посту
  final ScrollController _postsScrollController = ScrollController();
  
  // Сервис фильтрации карты
  final MapFilterService _mapFilterService = MapFilterService();
  
  // Флаг, чтобы прокрутка выполнялась только один раз
  bool _hasScrolledToPost = false;
  
  // Таймер для агрессивных ретраев прокрутки
  Timer? _scrollRetryTimer;
  
  // Кэшированный список постов для быстрого доступа
  List<Post>? _cachedPosts;

  @override
  void initState() {
    super.initState();
    // Если есть заранее загруженные посты, используем их как кэш
    if (widget.initialPosts != null && widget.initialPosts!.isNotEmpty) {
      _cachedPosts = List<Post>.from(widget.initialPosts!);
      AppLogger.log('⚡ initialPosts переданы: используем ${_cachedPosts!.length} постов для мгновенной прокрутки');
    }
    _loadData();
  }
  
  @override
  void dispose() {
    _postsScrollController.dispose();
    // Отменяем таймер ретраев, если он активен
    _scrollRetryTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Проверяем только один раз при инициализации зависимостей
    if (!mounted) return;
    final canPop = Navigator.of(context).canPop();
    if (_showBottomNav != canPop) {
      setState(() {
        _showBottomNav = canPop;
      });
    }
    
    // Проверяем ID для прокрутки сразу после построения фрейма
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _checkScrollToPost();
    });
  }
  
  // Проверяем, есть ли ID для прокрутки
  void _checkScrollToPost() async {
    final scrollToPostId = _mapFilterService.scrollToPostId;
    if (scrollToPostId != null && !_hasScrolledToPost) {
      AppLogger.log('🔍 Найден ID для прокрутки в didChangeDependencies: $scrollToPostId');
      
      try {
        // Сначала пробуем использовать кэшированные посты (если доступны)
        if (_cachedPosts != null && _cachedPosts!.isNotEmpty) {
          AppLogger.log('⚡ Используем кэшированные посты (${_cachedPosts!.length}), прокрутка будет мгновенной');
          _scrollToPostIfNeeded(_cachedPosts!);
        } else {
          // Если кэша нет, ждем загрузки постов
          AppLogger.log('⏳ Кэш пуст, ждем загрузки постов...');
          final posts = await _userPostsFuture;
          if (posts.isNotEmpty) {
            AppLogger.log('✅ Посты загружены (${posts.length}), вызываем прокрутку');
            _scrollToPostIfNeeded(posts);
          }
        }
      } catch (e) {
        AppLogger.log('❌ Ошибка при загрузке постов для прокрутки: $e');
      }
    }
  }
  
  // Метод для прокрутки к нужному посту
  void _scrollToPostIfNeeded(List<Post> posts) {
    AppLogger.log('🔍 _scrollToPostIfNeeded вызван. hasScrolled=$_hasScrolledToPost');
    
    if (_hasScrolledToPost) {
      AppLogger.log('⏭️ Прокрутка уже выполнена, пропускаем');
      return;
    }
    
    final scrollToPostId = _mapFilterService.scrollToPostId;
    AppLogger.log('🔍 scrollToPostId из MapFilterService: $scrollToPostId');
    
    if (scrollToPostId == null) {
      AppLogger.log('⏭️ ID поста для прокрутки не задан');
      return;
    }
    
    // Очищаем ID
    _mapFilterService.clearScrollToPostId();
    
    final postIndex = posts.indexWhere((post) => post.id == scrollToPostId);
    
    if (postIndex == -1) {
      AppLogger.log('❌ Пост с ID $scrollToPostId не найден в списке из ${posts.length} постов');
      // Выведем ID всех постов для отладки
      for (var i = 0; i < posts.length; i++) {
        AppLogger.log('  Пост $i: ID=${posts[i].id}');
      }
      return;
    }
    
    AppLogger.log('✅ Найден пост для прокрутки: ID=$scrollToPostId, индекс=$postIndex из ${posts.length} постов');
    
    // Функция для выполнения прокрутки
    void performScroll() {
      if (!mounted || !_postsScrollController.hasClients) {
        AppLogger.log('❌ ScrollController не готов для прокрутки');
        return;
      }
      
      if (_hasScrolledToPost) {
        AppLogger.log('⏭️ Прокрутка уже выполнена, пропускаем повтор');
        return;
      }
      
      // Устанавливаем флаг
      _hasScrolledToPost = true;
      
      // Вычисляем примерную позицию поста
      // Высота PostCard примерно 400-600px, используем среднее значение 520px
      final itemHeight = 520.0;
      final separatorHeight = 4.0;
      final offset = postIndex * (itemHeight + separatorHeight);
      
      // Ограничиваем максимальный offset
      final maxScroll = _postsScrollController.position.maxScrollExtent;
      final targetOffset = offset > maxScroll ? maxScroll : offset;
      
      AppLogger.log('🔄 Вычислен offset: $offset, ограничен до: $targetOffset (max: $maxScroll)');
      
      // Если пост далеко (больше 2 позиций), используем jumpTo для мгновенной прокрутки
      if (postIndex > 2) {
        _postsScrollController.jumpTo(targetOffset);
        AppLogger.log('⚡ Мгновенная прокрутка выполнена к посту: $scrollToPostId (индекс: $postIndex)');
      } else {
        // Для близких постов используем быструю анимацию
        _postsScrollController.animateTo(
          targetOffset,
          duration: Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ).then((_) {
          AppLogger.log('✅ Анимация прокрутки завершена к посту: $scrollToPostId (индекс: $postIndex)');
        });
      }
    }
    
    // Множественные попытки прокрутки для максимальной скорости
    // Попытка 1: сразу после построения фрейма
    SchedulerBinding.instance.addPostFrameCallback((_) {
      AppLogger.log('📋 Попытка прокрутки #1 (PostFrameCallback)');
      performScroll();
    });
    
    // Попытка 2: через минимальную задержку (на случай, если ScrollController еще не готов)
    Future.delayed(Duration(milliseconds: 50), () {
      if (mounted && !_hasScrolledToPost) {
        AppLogger.log('📋 Попытка прокрутки #2 (через 50ms)');
        performScroll();
      }
    });
    
    // Дополнительно: агрессивные ретраи каждые 50мс до 2 секунд или до успеха
    int attempts = 0;
    _scrollRetryTimer?.cancel();
    _scrollRetryTimer = Timer.periodic(const Duration(milliseconds: 50), (t) {
      attempts++;
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_hasScrolledToPost) {
        t.cancel();
        return;
      }
      if (_postsScrollController.hasClients) {
        AppLogger.log('📋 Попытка прокрутки (ретрай) #${attempts}');
        performScroll();
        if (_hasScrolledToPost) {
          t.cancel();
          return;
        }
      }
      if (attempts >= 40) { // ~2 секунды
        AppLogger.log('⏱️ Прокрутка не выполнена за отведённое время ретраев');
        t.cancel();
      }
    });
  }

  /// Открыть страницу с постами локации
  void _openLocationPostsScreen(Post post) {
    AppLogger.log('🔄 Открытие экрана постов локации: ${post.locationName}');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LocationPostsScreen(
          initialPost: post,
          locationName: post.locationName,
          latitude: post.location.latitude,
          longitude: post.location.longitude,
        ),
      ),
    );
  }

  Future<void> _loadData() async {
    _userDataFuture = _loadUserData();
    _userPostsFuture = _loadUserPosts();
    
    // Новое: загрузка альбомов пользователя (для таба Albums/Commercial)
    _userAlbumsFuture = AlbumService.getUserAlbumsFromServer(widget.userId, page: 1, perPage: 50).then((res) {
      try {
        if (res is Map && res['albums'] is List) {
          return List<Map<String, dynamic>>.from(res['albums']);
        }
      } catch (_) {}
      return <Map<String, dynamic>>[];
    }).catchError((_) => <Map<String, dynamic>>[]);
    
    // Очищаем старые подписки с email и удаляем дубликаты
    await SocialService.cleanupFollowsByEmail();
    await SocialService.removeDuplicateFollows();
    
    // Проверка и исправление профильного изображения
    if (_isCurrentUser) {
      AppLogger.log('🔄 Проверка и исправление профильного изображения для текущего пользователя');
      final profileImage = await UserService.checkAndFixProfileImage();
      if (profileImage.isNotEmpty) {
        _authorProfileImage = profileImage;
        AppLogger.log('✅ Профильное изображение установлено: $_authorProfileImage');
      }
    }
    
    // Загружаем данные автора сразу
    try {
      final userData = await _loadUserData();
      _authorName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
      if (_authorProfileImage.isEmpty) {
        _authorProfileImage = userData['profileImageUrl'] ?? '';
      }
      if (_authorName.isEmpty) _authorName = 'User ${widget.userId}';
      
      // Логи закомментированы
      // AppLogger.log('📊 _loadData: загружены данные автора:');
    } catch (e) {
      AppLogger.log('❌ Error loading author data: $e');
      _authorName = 'User ${widget.userId}';
      if (_authorProfileImage.isEmpty) {
        _authorProfileImage = '';
      }
    }
    
    // Проверяем, текущий ли пользователь
    _currentUserId = await UserService.getUserId();
    if (mounted) {
      setState(() {
        _isCurrentUser = _currentUserId == widget.userId;
      });
    }
    
    // Проверяем, подписан ли на пользователя
    if (!_isCurrentUser) {
      _isFollowing = await SocialService.isFollowing(widget.userId);
    }
    
    // Загружаем количество подписчиков и подписок
    await _loadFollowCounts();

    // Новое: загрузка агрегированных счётчиков
    await _loadEngagementStats();
  }
  
  Future<void> _loadFollowCounts() async {
    try {
      // Получаем всех подписчиков
      final follows = await SocialService.getAllFollows();
      
      // Получаем ID текущего пользователя для сравнения
      final currentUserEmail = await UserService.getEmail();
      final currentUserId = await UserService.getUserId();
      
      // Логи закомментированы
      
      // Подсчитываем количество подписчиков для просматриваемого профиля
      final followers = follows.where((follow) => follow.followedId == widget.userId).length;
      
      // Определяем, какой ID использовать для подсчета подписок
      String idForFollowing = _isCurrentUser ? currentUserId : widget.userId;
      
      // Подсчитываем количество подписок (на которых подписан пользователь)
      final following = follows.where((follow) => follow.followerId == idForFollowing).length;
      
      // Логи закомментированы
      
      if (mounted) {
        setState(() {
          _followersCount = followers;
          _followingCount = following;
        });
      }
    } catch (e) {
      AppLogger.log('❌ Error loading follow counts: $e');
    }
  }

  Future<void> _loadEngagementStats() async {
    // Загружаем статистику только для своего профиля
    if (!_isCurrentUser) {
      if (mounted) setState(() => _statsLoading = false);
      return;
    }
    
    try {
      if (mounted) setState(() => _statsLoading = true);
      final posts = await _userPostsFuture;
      if (posts.isEmpty) {
        if (mounted) setState(() {
          _totalLikes = 0;
          _totalFavorites = 0;
          _totalComments = 0;
          _statsLoading = false;
        });
        return;
      }

      // Лайки: суммируем по постам (сервер/локально внутри сервиса)
      final likesCounts = await Future.wait(
        posts.map((p) => SocialService.getPostLikesCount(p.id))
      );
      final likesTotal = likesCounts.fold<int>(0, (sum, c) => sum + (c ?? 0));

      // Комментарии: быстро получаем total через пагинацию (perPage=1)
      final commentsTotals = await Future.wait(posts.map((p) async {
        try {
          final res = await SocialService().getComments(p.id, page: 1, perPage: 1);
          if (res['success'] == true && res['pagination'] is Map) {
            return int.tryParse(res['pagination']['total']?.toString() ?? '0') ?? 0;
          }
        } catch (_) {}
        return 0;
      }));
      final commentsTotal = commentsTotals.fold<int>(0, (sum, c) => sum + c);

      // Избранное: считаем локально по известным избранным (best-effort)
      int favoritesTotal = 0;
      try {
        final favorites = await SocialService.getAllFavorites();
        final postIds = posts.map((p) => p.id).toSet();
        favoritesTotal = favorites.where((f) => postIds.contains(f.postId)).length;
      } catch (_) {
        favoritesTotal = 0;
      }

      if (mounted) {
        setState(() {
          _totalLikes = likesTotal;
          _totalFavorites = favoritesTotal;
          _totalComments = commentsTotal;
          _statsLoading = false;
        });
      }
    } catch (e) {
      AppLogger.log('❌ Error loading engagement stats: $e');
      if (mounted) setState(() => _statsLoading = false);
    }
  }

  Future<Map<String, dynamic>> _loadUserData() async {
    try {
      return await UserService.getUserInfoById(widget.userId);
    } catch (e) {
      AppLogger.log('❌ Error loading user data: $e');
      // Возвращаем базовые данные из параметров виджета
      return {
        'id': widget.userId,
        'firstName': widget.initialName.split(' ').first,
        'lastName': widget.initialName.split(' ').length > 1 
            ? widget.initialName.split(' ').last 
            : '',
        'profileImageUrl': widget.initialProfileImage ?? '',
      };
    }
  }

  Future<List<Post>> _loadUserPosts() async {
    try {
      // Загружаем посты пользователя
      List<Post> posts = await PostService.getUserPosts(userId: widget.userId);
      
      // Сохраняем в кэш для быстрого доступа
      _cachedPosts = posts;
      
      // Если это не текущий пользователь и у нас есть его данные профиля,
      // загружаем информацию об авторе для отображения в постах
      if (!_isCurrentUser && posts.isNotEmpty) {
        try {
          // Загружаем данные профиля автора через _loadUserData
          // Информация уже загружается в _loadData, поэтому дополнительная загрузка не требуется
          // _authorName и _authorProfileImage используются в методе build
        } catch (e) {
          AppLogger.log('❌ Error loading author data for posts: $e');
        }
      }
      
      return posts;
    } catch (e) {
      AppLogger.log('❌ Error loading user posts: $e');
      return [];
    }
  }

  Future<void> _toggleFollow() async {
    if (_isCurrentUser) return;
    
    if (mounted) {
      setState(() {
        _isFollowing = !_isFollowing;
        // Изменяем только количество подписчиков у просматриваемого профиля
        if (_isFollowing) {
          _followersCount++;
        } else {
          _followersCount = _followersCount > 0 ? _followersCount - 1 : 0;
        }
      });
    }
    
    try {
      await SocialService.toggleFollow(widget.userId);
      // Обновляем счетчики
      await _loadFollowCounts();
    } catch (e) {
      AppLogger.log('❌ Error toggling follow status: $e');
      // В случае ошибки возвращаем предыдущее состояние
      if (mounted) {
        setState(() {
          _isFollowing = !_isFollowing;
          // Откатываем изменение количества подписчиков
          if (_isFollowing) {
            _followersCount++;
          } else {
            _followersCount = _followersCount > 0 ? _followersCount - 1 : 0;
          }
        });
      }
    }
  }

  void _showFollowersList() {
    _showUsersList(isFollowers: true);
  }

  void _showFollowingList() {
    _showUsersList(isFollowers: false);
  }

  void _showUsersList({required bool isFollowers}) async {
    try {
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );
      
      final follows = await SocialService.getAllFollows();
      final List<String> userIds = [];
      
      if (isFollowers) {
        // Получаем ID пользователей, которые подписаны на текущего
        userIds.addAll(follows
            .where((follow) => follow.followedId == widget.userId)
            .map((follow) => follow.followerId));
      } else {
        // Получаем ID пользователей, на которых подписан текущий
        userIds.addAll(follows
            .where((follow) => follow.followerId == widget.userId)
            .map((follow) => follow.followedId));
      }
      
      // Получаем информацию о пользователях
      List<Map<String, dynamic>> usersData = [];
      for (var userId in userIds) {
        try {
          final userData = await UserService.getUserInfoById(userId);
          final userPosts = await PostService.getUserPosts(userId: userId);
          
          usersData.add({
            'id': userId,
            'name': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
            'profileImageUrl': userData['profileImageUrl'] ?? '',
            'postsCount': userPosts.length,
          });
        } catch (e) {
          AppLogger.log('❌ Error loading user info for $userId: $e');
        }
      }
      
      // Закрываем диалог загрузки
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (usersData.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(isFollowers ? 'No followers yet' : 'Not following anyone yet'))
          );
        }
        return;
      }
      
      if (context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (context) => Container(
            padding: EdgeInsets.symmetric(vertical: 20),
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.7,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Text(
                        isFollowers ? 'Followers' : 'Following',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Spacer(),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Divider(),
                Expanded(
                  child: ListView.builder(
                    itemCount: usersData.length,
                    itemBuilder: (context, index) {
                      final user = usersData[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.grey.shade200,
                          backgroundImage: user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty
                              ? CachedNetworkImageProvider(ApiConfig.formatImageUrl(user['profileImageUrl']))
                              : null,
                          child: (user['profileImageUrl'] == null || user['profileImageUrl'].isEmpty)
                              ? Icon(Icons.person, color: Colors.grey.shade600)
                              : null,
                        ),
                        title: GestureDetector(
                          onTap: () {
                            // Переход к профилю пользователя
                            Navigator.pop(context);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UserProfileScreen(
                                  userId: user['id'],
                                  initialName: user['name'],
                                  initialProfileImage: user['profileImageUrl'],
                                  sourceTabIndex: widget.sourceTabIndex,
                                ),
                              ),
                            );
                          },
                          child: Text(
                            user['name'] != null && user['name'].isNotEmpty
                                ? user['name']
                                : 'User ${user['id']}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        trailing: Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.photo_camera, size: 12, color: Colors.blue),
                              SizedBox(width: 4),
                              Text(
                                '${user['postsCount']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.log('❌ Error showing users list: $e');
      // Закрываем диалог загрузки если он открыт
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load users list'))
        );
      }
    }
  }

  // Show dialog to choose between post, album and commercial post
  void _showCreateOptionsDialog() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'What would you like to create?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 20),
            ListTile(
              leading: Icon(Icons.photo_camera, color: Colors.blue),
              title: Text('Create Post'),
              subtitle: Text('Add new photos with geolocation'),
              onTap: () {
                Navigator.pop(context);
                _openUploadImageScreen();
              },
            ),
            ListTile(
              leading: Icon(Icons.photo_album, color: Colors.green),
              title: Text('Create Album'),
              subtitle: Text('Organize your posts into an album'),
              onTap: () {
                Navigator.pop(context);
                _openCreateAlbum();
              },
            ),
            ListTile(
              leading: Icon(Icons.business, color: Colors.orange),
              title: Text('Create Commercial Post'),
              subtitle: Text('Create a post for business or selling'),
              onTap: () {
                Navigator.pop(context);
                _openCreateCommercialPost();
              },
            ),
          ],
        ),
      ),
    );
  }

  // Open post creation screen
  void _openUploadImageScreen() async {
    try {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const UploadDescriptionScreen(),
        ),
      );
      
      // If post was created, update data
      if (result != null && mounted) {
        setState(() {
          _userPostsFuture = _loadUserPosts();
        });
        // Also update statistics
        await _loadEngagementStats();
      }
    } catch (e) {
      AppLogger.log('❌ Error opening upload screen: $e');
    }
  }

  // Open album creation screen
  void _openCreateAlbum() async {
    try {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const CreateAlbumScreen(),
        ),
      );
      
      // If album was created, update data
      if (result != null && mounted) {
        setState(() {
          // Update albums list
          _userAlbumsFuture = AlbumService.getUserAlbumsFromServer(widget.userId, page: 1, perPage: 50).then((res) {
            try {
              if (res is Map && res['albums'] is List) {
                return List<Map<String, dynamic>>.from(res['albums']);
              }
            } catch (_) {}
            return <Map<String, dynamic>>[];
          }).catchError((_) => <Map<String, dynamic>>[]);
        });
      }
    } catch (e) {
      AppLogger.log('❌ Error opening create album screen: $e');
    }
  }

  // Open commercial post creation screen
  void _openCreateCommercialPost() async {
    try {
      final userId = int.tryParse(widget.userId);
      if (userId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: Invalid user ID'))
          );
        }
        return;
      }

      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CreateCommercialPostScreen(
            userId: userId,
          ),
        ),
      );
      
      // If commercial post was created, update data
      if (result == true && mounted) {
        setState(() {
          // Update commercial posts data
          _userAlbumsFuture = AlbumService.getUserAlbumsFromServer(widget.userId, page: 1, perPage: 50).then((res) {
            try {
              if (res is Map && res['albums'] is List) {
                return List<Map<String, dynamic>>.from(res['albums']);
              }
            } catch (_) {}
            return <Map<String, dynamic>>[];
          }).catchError((_) => <Map<String, dynamic>>[]);
        });
        // Also update engagement stats
        await _loadEngagementStats();
      }
    } catch (e) {
      AppLogger.log('❌ Error opening create commercial post screen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        body: Stack(
          children: [
            NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  // Убираем стрелку назад, если возвращаться некуда
                  if (_showBottomNav)
                    SliverAppBar(
                      expandedHeight: 0,
                      floating: false,
                      pinned: true,
                      elevation: 0,
                      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                      leading: IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.black),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ),
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _UserProfileHeaderDelegate(
                      userData: _userDataFuture,
                      postsFuture: _userPostsFuture,
                      isCurrentUser: _isCurrentUser,
                      isFollowing: _isFollowing,
                      onToggleFollow: _toggleFollow,
                      followersCount: _followersCount,
                      followingCount: _followingCount,
                      onFollowersTap: _showFollowersList,
                      onFollowingTap: _showFollowingList,
                      statsLoading: _statsLoading,
                      totalLikes: _totalLikes,
                      totalFavorites: _totalFavorites,
                      totalComments: _totalComments,
                    ),
                  ),
                ];
              },
              body: TabBarView(
                children: [
                  // Posts
                  _buildPostsTab(),
                  // Albums
                  _buildAlbumsTab(),
                  // Commercial
                  _buildCommercialTab(),
                ],
              ),
            ),
            
            // Add post/album button - only for current user
            if (_isCurrentUser)
              Positioned(
                bottom: _showBottomNav ? 80 : 25,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                    child: InkWell(
                      onTap: _showCreateOptionsDialog,
                      borderRadius: BorderRadius.circular(25),
                      child: Image.asset(
                        'assets/Images/plus.png',
                        width: 24,
                        height: 24,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        // Показываем меню только для чужих профилей (когда есть кнопка назад)
        bottomNavigationBar: _showBottomNav
            ? BottomNavigationBar(
                type: BottomNavigationBarType.fixed,
                backgroundColor: Colors.white,
                selectedItemColor: Colors.blue.shade900,
                unselectedItemColor: Colors.grey.shade600,
                currentIndex: widget.sourceTabIndex,
                iconSize: 24.0,
                onTap: (index) {
                  // Навигация через главный экран
                  if (mainScreenKey.currentState != null) {
                    mainScreenKey.currentState!.switchToTab(index);
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  } else {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  }
                },
                showSelectedLabels: false,
                showUnselectedLabels: false,
                items: [
                  BottomNavigationBarItem(
                    icon: SvgPicture.asset(
                      'assets/Images/home.svg',
                      color: Colors.grey.shade700,
                      width: 24,
                      height: 24,
                    ),
                    activeIcon: SvgPicture.asset(
                      'assets/Images/home.svg',
                      color: Color.fromRGBO(0, 122, 255, 1),
                      width: 24,
                      height: 24,
                    ),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: SvgPicture.asset(
                      'assets/Images/following.svg',
                      color: Colors.grey.shade700,
                      width: 24,
                      height: 24,
                    ),
                    activeIcon: SvgPicture.asset(
                      'assets/Images/following.svg',
                      color: Color.fromRGBO(0, 122, 255, 1),
                      width: 24,
                      height: 24,
                    ),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: SvgPicture.asset(
                      'assets/Images/favorites.svg',
                      color: Colors.grey.shade700,
                      width: 24,
                      height: 24,
                    ),
                    activeIcon: SvgPicture.asset(
                      'assets/Images/favorites.svg',
                      color: Color.fromRGBO(0, 122, 255, 1),
                      width: 24,
                      height: 24,
                    ),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: SvgPicture.asset(
                      'assets/Images/mymap.svg',
                      color: Colors.grey.shade700,
                      width: 24,
                      height: 24,
                    ),
                    activeIcon: SvgPicture.asset(
                      'assets/Images/mymap.svg',
                      color: Color.fromRGBO(0, 122, 255, 1),
                      width: 24,
                      height: 24,
                    ),
                    label: '',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(
                      Icons.photo_album_outlined,
                      color: Colors.grey.shade700,
                      size: 24,
                    ),
                    activeIcon: Icon(
                      Icons.photo_album,
                      color: Color.fromRGBO(0, 122, 255, 1),
                      size: 24,
                    ),
                    label: '',
                  ),
                ],
              )
            : null,
      ),
    );
  }

  Widget _buildPostsTab() {
    return FutureBuilder<List<Post>>(
      future: _userPostsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading posts: ${snapshot.error}'));
        }
        final posts = snapshot.data ?? [];
        if (posts.isEmpty) {
          return Center(child: Text('No posts yet'));
        }
        
        // Обновляем кэш постов
        _cachedPosts = posts;
        
        // Вызываем прокрутку к нужному посту после загрузки данных
        _scrollToPostIfNeeded(posts);
        
        return FutureBuilder<Map<String, dynamic>>(
          future: _userDataFuture,
          builder: (context, userSnapshot) {
            final userData = userSnapshot.data ?? {};
            final userFullName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
            final profileImageUrl = userData['profileImageUrl'] ?? '';
            final formattedProfileImageUrl = ApiConfig.formatImageUrl(profileImageUrl);
            return ListView.separated(
              controller: _postsScrollController,
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              itemCount: posts.length,
              separatorBuilder: (context, index) => SizedBox(height: 4),
              itemBuilder: (context, index) {
                final post = posts[index];
                return PostCard(
                  post: post,
                  userProfileImage: formattedProfileImageUrl,
                  userFullName: userFullName,
                  authorProfileImage: post.user == widget.userId ? formattedProfileImageUrl : _authorProfileImage,
                  authorName: post.user == widget.userId ? userFullName : _authorName,
                  isCurrentUserPost: _isCurrentUser,
                  onShowCommentsModal: (post) {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => CommentsModal(post: post),
                    );
                  },
                  onLocationPostsClick: _openLocationPostsScreen,
                  onShowOnMap: (post) {
                    if (post.latitude != null && post.longitude != null) {
                      AppLogger.log('Show post on map: ${post.latitude}, ${post.longitude}');
                      
                      // Сбрасываем флаг прокрутки, чтобы при возврате она работала снова
                      _hasScrolledToPost = false;
                      
                      final mapFilterService = MapFilterService();
                      // Источник — профиль (для корректного возврата из карты)
                      mapFilterService.setSourceView('profile');
                      // Устанавливаем заголовок для отображения на карте
                      mapFilterService.setFilterTitle('My Map');
                      // Снимаем режим избранного и подсвечиваем нужный пост
                      mapFilterService.setShowOnlyFavorites(false);
                      mapFilterService.setHighlightedPost(post);

                      // Переключаемся на вкладку с картой
                      if (mainScreenKey.currentState != null) {
                        mainScreenKey.currentState!.switchToTab(0);
                      } else {
                        Navigator.of(context).popUntil((route) => route.isFirst);
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('No location data available for this post'))
                      );
                    }
                  },
                  onEditPost: (post) {
                    if (_isCurrentUser) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EditPostScreen(post: post)
                        )
                      ).then((result) {
                        if (result != null) {
                          if (mounted) {
                            setState(() {
                              _userPostsFuture = _loadUserPosts();
                            });
                          }
                        }
                      });
                    }
                  },
                  onDeletePost: (post) {
                    if (_isCurrentUser) {
                      _confirmDeletePost(post);
                    }
                  },
                  onLikePost: (post) {
                    SocialService.likePost(post.id).then((_) => _loadEngagementStats());
                  },
                  onFavoritePost: (post) {
                    SocialService.addToFavorites(post.id).then((_) => _loadEngagementStats());
                  },
                  onFollowUser: (userId) {
                    SocialService.toggleFollow(userId).then((_) {
                      if (mounted) {
                        setState(() {
                          _loadFollowCounts();
                        });
                      }
                    });
                  },
                  onImageTap: (post, index) {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => VerticalPhotoGalleryScreen(
                          post: post,
                          initialIndex: index,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildAlbumsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _userAlbumsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        final albums = snapshot.data ?? [];
        if (albums.isEmpty) {
          return Center(child: Text('No albums yet'));
        }
        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _userAlbumsFuture = AlbumService.getUserAlbumsFromServer(widget.userId, page: 1, perPage: 50).then((res) {
                if (res is Map && res['albums'] is List) {
                  return List<Map<String, dynamic>>.from(res['albums']);
                }
                return <Map<String, dynamic>>[];
              }).catchError((_) => <Map<String, dynamic>>[]);
            });
          },
          child: ListView.separated(
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            itemCount: albums.length,
            separatorBuilder: (context, index) => SizedBox(height: 8),
            itemBuilder: (context, index) {
              final albumRow = albums[index];
              return AlbumCard(
                albumRow: albumRow,
                currentUserId: _currentUserId,
                onTap: (albumId) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AlbumDetailScreen(
                        albumId: albumId,
                        currentUserId: _currentUserId,
                      ),
                    ),
                  );
                },
                onChanged: () async {
                  setState(() {
                    _userAlbumsFuture = AlbumService.getUserAlbumsFromServer(widget.userId, page: 1, perPage: 50).then((res) {
                      if (res is Map && res['albums'] is List) {
                        return List<Map<String, dynamic>>.from(res['albums']);
                      }
                      return <Map<String, dynamic>>[];
                    }).catchError((_) => <Map<String, dynamic>>[]);
                  });
                },
                onEditAlbum: (albumId, album, photos) async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditAlbumScreen(
                        albumId: albumId,
                        initialTitle: album['title']?.toString() ?? '',
                        initialDescription: album['description']?.toString() ?? '',
                        initialPhotos: photos,
                      ),
                    ),
                  );
                  setState(() {
                    _userAlbumsFuture = AlbumService.getUserAlbumsFromServer(widget.userId, page: 1, perPage: 50).then((res) {
                      if (res is Map && res['albums'] is List) {
                        return List<Map<String, dynamic>>.from(res['albums']);
                      }
                      return <Map<String, dynamic>>[];
                    }).catchError((_) => <Map<String, dynamic>>[]);
                  });
                },
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCommercialTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _userAlbumsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }
        final albums = snapshot.data ?? [];

        Future<List<CommercialPost>> _loadAllCommercialPosts() async {
          final List<CommercialPost> all = [];
          final profileUserIdInt = int.tryParse(widget.userId);
          
          // Загружаем коммерческие посты из альбомов
          for (final row in albums) {
            final idStr = row['id']?.toString() ?? '';
            final albumId = int.tryParse(idStr);
            if (albumId == null) continue;
            try {
              final posts = await CommercialPostService.getCommercialPostsForAlbum(albumId);
              if (posts.isNotEmpty) {
                // Filter only profile user's posts
                final userPosts = profileUserIdInt != null 
                    ? posts.where((post) => post.userId == profileUserIdInt).toList()
                    : posts;
                all.addAll(userPosts);
              }
            } catch (_) {}
          }
          
          // Загружаем standalone коммерческие посты (без альбома)
          if (profileUserIdInt != null) {
            try {
              final standalonePosts = await CommercialPostService.getStandaloneCommercialPosts(profileUserIdInt);
              all.addAll(standalonePosts);
            } catch (e) {
              AppLogger.log('❌ Error loading standalone commercial posts: $e');
            }
          }
          
          all.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
          return all;
        }

        return FutureBuilder<List<CommercialPost>>(
          future: _loadAllCommercialPosts(),
          builder: (context, postsSnap) {
            if (postsSnap.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            }
            final items = postsSnap.data ?? [];
            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.business_center_outlined,
                      size: 64,
                      color: Colors.grey.shade400,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No commercial posts yet',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Create your first commercial post to promote your business',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }

            int? currentUserIdInt = int.tryParse(_currentUserId);

            return RefreshIndicator(
              onRefresh: () async {
                if (mounted) {
                  SchedulerBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {});
                    }
                  });
                }
              },
              child: ListView.separated(
                padding: EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 90),
                itemCount: items.length,
                separatorBuilder: (context, index) => SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final post = items[index];
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: CommercialPostCard(
                      post: post,
                      userProfileImage: post.userProfileImage?.isNotEmpty == true ? post.userProfileImage : (_authorProfileImage.isNotEmpty ? _authorProfileImage : null),
                      userFullName: post.userName?.isNotEmpty == true ? post.userName! : (_authorName.isNotEmpty ? _authorName : 'User'),
                      onEditPost: (p) async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EditCommercialPostScreen(post: p),
                          ),
                        );
                        setState(() {});
                      },
                      onDeletePost: (p) async {
                        if (currentUserIdInt == null) return;
                        try {
                          final ok = await CommercialPostService.deleteCommercialPost(p.id, currentUserIdInt);
                          if (ok && mounted) setState(() {});
                        } catch (_) {}
                      },
                      isCurrentUserPost: _isCurrentUser,
                      onLikePost: null,
                      onFavoritePost: (p) async {
                        if (mounted) setState(() {});
                      },
                      onImageTap: (p, i) {
                        // Используем оригинальные изображения для галереи, cropped для отображения в ленте
                        final imageUrls = p.originalImageUrls.isNotEmpty
                            ? p.originalImageUrls
                            : p.imageUrls.isNotEmpty
                                ? p.imageUrls
                                : (p.imageUrl != null && p.imageUrl!.isNotEmpty) ? [p.imageUrl!] : <String>[];
                        if (imageUrls.isEmpty) return;
                        Navigator.of(context).push(
                          PageRouteBuilder(
                            pageBuilder: (context, animation, secondaryAnimation) => 
                              CommercialPostGalleryScreen(
                                imageUrls: imageUrls,
                                initialIndex: i,
                                postTitle: p.title,
                              ),
                            transitionsBuilder: (context, animation, secondaryAnimation, child) {
                              return FadeTransition(opacity: animation, child: child);
                            },
                            transitionDuration: const Duration(milliseconds: 300),
                            barrierColor: Colors.black,
                            opaque: false,
                          ),
                        );
                      },
                      onShowOnMap: (p) {
                        if (p.hasLocation) {
                          AppLogger.log('📍 Opening map for commercial post: ${p.title}');
                          
                          // Открываем CommercialPostMapScreen с всеми коммерческими постами пользователя
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CommercialPostMapScreen(
                                post: p,
                                allPosts: items, // Передаем все коммерческие посты пользователя
                                onPostTap: (tappedPost) {
                                  AppLogger.log("📍 User returned from map to commercial post ${tappedPost.id}");
                                  // Пост уже виден в списке, дополнительная прокрутка не требуется
                                },
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('No location data available for this commercial post'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                      isFollowing: false,
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _confirmDeletePost(Post post) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Post'),
        content: Text('Are you sure you want to delete this post?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              PostService.deletePost(post.id).then((_) {
                if (mounted) {
                  setState(() {
                    _userPostsFuture = _loadUserPosts();
                  });
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Post deleted successfully'))
                  );
                }
              }).catchError((error) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete post: $error'))
                  );
                }
              });
            },
            child: Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _UserProfileHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Future<Map<String, dynamic>> userData;
  final Future<List<Post>> postsFuture;
  final bool isCurrentUser;
  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final int followersCount;
  final int followingCount;
  final VoidCallback onFollowersTap;
  final VoidCallback onFollowingTap;

  // Новое: агрегированные счётчики
  final bool statsLoading;
  final int totalLikes;
  final int totalFavorites;
  final int totalComments;

  _UserProfileHeaderDelegate({
    required this.userData,
    required this.postsFuture,
    required this.isCurrentUser,
    required this.isFollowing,
    required this.onToggleFollow,
    required this.followersCount,
    required this.followingCount,
    required this.onFollowersTap,
    required this.onFollowingTap,
    required this.statsLoading,
    required this.totalLikes,
    required this.totalFavorites,
    required this.totalComments,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: FutureBuilder<Map<String, dynamic>>(
        future: userData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          
          final userData = snapshot.data ?? {};
          final firstName = userData['firstName'] ?? '';
          final lastName = userData['lastName'] ?? '';
          final fullName = '$firstName $lastName'.trim();
          final profileImageUrl = userData['profileImageUrl'] ?? '';
          
          // AppLogger.log('📊 UserProfileHeaderDelegate: Используемый URL фото профиля: $profileImageUrl');
          
          return FutureBuilder<List<Post>>(
            future: postsFuture,
            builder: (context, postsSnapshot) {
              final postsCount = postsSnapshot.data?.length ?? 0;
              
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Аватарка пользователя
                            CircleAvatar(
                              radius: 32,
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: profileImageUrl.isNotEmpty
                                  ? CachedNetworkImageProvider(ApiConfig.formatImageUrl(profileImageUrl))
                                  : null,
                              child: profileImageUrl.isEmpty
                                  ? Icon(Icons.person, color: Colors.grey.shade600, size: 32)
                                  : null,
                            ),
                            SizedBox(width: 16),
                            
                            // Информация о пользователе (имя, посты, подписки)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Имя пользователя и кнопка подписки в одной строке
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      // Имя пользователя и счетчик постов
                                      Flexible(
                                        child: Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                fullName.isNotEmpty ? fullName : 'User',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 18,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            // Иконка с количеством постов
                                            Container(
                                              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: Colors.blue.withOpacity(0.1),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.photo_camera, size: 12, color: Colors.blue),
                                                  SizedBox(width: 2),
                                                  Text(
                                                    '$postsCount',
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.blue,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Кнопка подписки (если не текущий пользователь)
                                      if (!isCurrentUser)
                                        ElevatedButton(
                                          onPressed: onToggleFollow,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: isFollowing ? Colors.grey[300] : Colors.blue,
                                            foregroundColor: isFollowing ? Colors.black : Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            minimumSize: Size(0, 30),
                                          ),
                                          child: Text(
                                            isFollowing ? 'Following' : 'Follow',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  
                                  SizedBox(height: 2),
                                  
                                  // Счетчики подписчиков и подписок
                                  Row(
                                    children: [
                                      GestureDetector(
                                        onTap: onFollowersTap,
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: '$followersCount ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              TextSpan(
                                                text: 'followers',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      GestureDetector(
                                        onTap: onFollowingTap,
                                        child: RichText(
                                          text: TextSpan(
                                            children: [
                                              TextSpan(
                                                text: '$followingCount ',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black,
                                                  fontSize: 12,
                                                ),
                                              ),
                                              TextSpan(
                                                text: 'following',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),

                                  // Агрегированные счётчики - только для своего профиля
                                  if (isCurrentUser) ...[
                                    SizedBox(height: 4),
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 4,
                                      children: [
                                        _StatChip(icon: Icons.favorite, color: Colors.red, loading: statsLoading, value: totalLikes),
                                        _StatChip(icon: Icons.star, color: Colors.orange, loading: statsLoading, value: totalFavorites),
                                        _StatChip(icon: Icons.mode_comment, color: Colors.blueGrey, loading: statsLoading, value: totalComments),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // TabBar на всю ширину, без горизонтального паддинга
                  const TabBar(
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Colors.blue,
                    tabs: [
                      Tab(text: 'Posts'),
                      Tab(text: 'Albums'),
                      Tab(text: 'Commercial'),
                    ],
                  ),
                  const Divider(height: 1),
                ],
              );
            },
          );
        },
      ),
    );
  }

  @override
  double get maxExtent => 150.0;

  @override
  double get minExtent => 150.0;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final bool loading;
  final int value;
  const _StatChip({required this.icon, required this.color, required this.loading, required this.value});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          loading
              ? SizedBox(width: 10, height: 10, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(
                  '$value',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
        ],
      ),
    );
  }
} 