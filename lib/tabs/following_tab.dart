import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../models/post.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../widgets/post_card.dart';
import '../widgets/album_card.dart';
import '../utils/logger.dart';
import '../screens/upload/upload_description_screen.dart';
import '../tabs/albums_tab.dart' show AlbumDetailScreen, EditAlbumScreen;
import '../screens/comments_screen.dart';
import '../screens/location_posts_screen.dart';
import '../screens/main_screen.dart';
import '../utils/map_helper.dart';
import '../config/mapbox_config.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
/// Tab with posts from followed users
class FollowingTab extends StatefulWidget {
  const FollowingTab({Key? key}) : super(key: key);

  @override
  _FollowingTabState createState() => _FollowingTabState();
}

class _FollowingTabState extends State<FollowingTab> with WidgetsBindingObserver {
  // Local list of following posts and albums
  List<Post> _followingPosts = [];
  List<Map<String, dynamic>> _followingAlbums = [];
  bool _isLoading = true;
  // Удаляем периодический поллинг
  // Timer? _followWatchTimer;
  List<String> _lastFollowingIds = [];
  
  // Search functionality
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // Cache for author info to improve search performance
  Map<String, Map<String, dynamic>> _authorCache = {};
  
  // Cache for user data
  String? _userProfileImage;
  String _userFullName = 'User';
  String _currentUserId = '';
  String _userId = '';
  
  // ScrollController для прокрутки к посту
  final ScrollController _scrollController = ScrollController();
  
  // Map для хранения индексов постов в списке
  final Map<String, int> _postIdToIndex = {};
  
  @override
  void initState() {
    super.initState();
    
    // Register with the widget binding observer
    WidgetsBinding.instance.addObserver(this);
    
    // Load user data
    _loadUserData();
    
    // Load posts from following
    _loadFollowingPosts();

    // Убираем автополлинг, обновление только по действиям и pull-to-refresh
    // _startFollowingWatcher();
  }
  
  @override
  void dispose() {
    // Unregister from the widget binding observer
    WidgetsBinding.instance.removeObserver(this);
    
    // _stopFollowingWatcher();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // При возобновлении приложения обновляем данные пользователя
    if (state == AppLifecycleState.resumed) {
      // Очищаем кэш данных пользователя для обновления прав доступа
      UserService.clearCache();
      // Перезагружаем данные пользователя
      _loadUserData();
    }
  }
  
  // Метод для прокрутки к посту по ID
  Future<void> _scrollToPostById(String postId) async {
    AppLogger.log('🎯 FollowingTab: Начинаем прокрутку к посту $postId');
    AppLogger.log('   mounted: $mounted, hasClients: ${_scrollController.hasClients}');
    
    if (!mounted || !_scrollController.hasClients) {
      AppLogger.log('⚠️ FollowingTab: ScrollController не готов для прокрутки');
      return;
    }
    
    final postIndex = _postIdToIndex[postId];
    AppLogger.log('   Индекс поста в _postIdToIndex: $postIndex');
    AppLogger.log('   Всего элементов в _postIdToIndex: ${_postIdToIndex.length}');
    
    if (postIndex == null) {
      AppLogger.log('⚠️ FollowingTab: Пост $postId не найден в списке');
      AppLogger.log('   Доступные ID: ${_postIdToIndex.keys.take(5).join(", ")}...');
      return;
    }
    
    AppLogger.log('📍 FollowingTab: Прокручиваем к посту $postId с индексом $postIndex');
    
    // Вычисляем примерный offset (высота PostCard + AlbumCard варьируется, используем среднее значение)
    const double itemHeight = 516.0; // Средняя высота элемента
    final double targetOffset = postIndex * itemHeight;
    
    // Ограничиваем offset максимальной позицией
    final double maxOffset = _scrollController.position.maxScrollExtent;
    final double scrollTo = targetOffset > maxOffset ? maxOffset : targetOffset;
    
    AppLogger.log('   targetOffset: $targetOffset, maxOffset: $maxOffset, scrollTo: $scrollTo');
    
    try {
      await _scrollController.animateTo(
        scrollTo,
        duration: Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      AppLogger.log('✅ FollowingTab: Прокрутка выполнена успешно к позиции $scrollTo');
    } catch (e) {
      AppLogger.log('❌ FollowingTab: Ошибка при прокрутке: $e');
    }
  }
  
  // void _startFollowingWatcher() {
  //   _followWatchTimer?.cancel();
  //   _followWatchTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
  //     try {
  //       final ids = await SocialService.getFollowingIds();
  //       if (!_areListsEqualUnordered(ids, _lastFollowingIds)) {
  //         _lastFollowingIds = List<String>.from(ids);
  //         await _loadFollowingPosts();
  //       }
  //     } catch (_) {}
  //   });
  // }
  
  // void _stopFollowingWatcher() {
  //   _followWatchTimer?.cancel();
  //   _followWatchTimer = null;
  // }
  
  bool _areListsEqualUnordered(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    final sa = Set<String>.from(a);
    final sb = Set<String>.from(b);
    return sa.length == sb.length && sa.containsAll(sb);
  }
  
  // Update search query
  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }
  
  // Filter content based on search query
  List<dynamic> _filterContent(List<dynamic> content) {
    if (_searchQuery.isEmpty) return content;
    
    return content.where((item) {
      if (item['type'] == 'album') {
        final album = item['data'] as Map<String, dynamic>;
        final authorName = album['author_name']?.toString().toLowerCase() ?? '';
        
        return authorName.contains(_searchQuery);
      } else {
        final post = item['data'] as Post;
        
        // Check cached author info for better search
        final cachedAuthor = _authorCache[post.user];
        String authorName = '';
        if (cachedAuthor != null) {
          final firstName = cachedAuthor['firstName']?.toString().trim() ?? '';
          final lastName = cachedAuthor['lastName']?.toString().trim() ?? '';
          authorName = '$firstName $lastName'.trim().toLowerCase();
        }
        
        return authorName.contains(_searchQuery);
      }
    }).toList();
  }
  
  // Load user data
  Future<void> _loadUserData() async {
    try {
      final fullName = await UserService.getFullName();
      final profileImage = await UserService.getProfileImage();
      final email = await UserService.getEmail();
      final userId = await UserService.getUserId();
      
      if (mounted) {
        setState(() {
          _userFullName = fullName;
          _userProfileImage = profileImage;
          _currentUserId = email;
          _userId = userId;
        });
      }
    } catch (e) {
      AppLogger.log("Error loading user data: $e");
    }
  }
  
  // Load posts and albums from following
  Future<void> _loadFollowingPosts() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Clear author cache when refreshing data
      _authorCache.clear();
      
      // Загружаем альбомы и отдельные посты параллельно (убираем лишний вызов getFollowingIds)
      final results = await Future.wait([
        SocialService.getFollowingAlbums(),
        SocialService.getFollowingNonAlbumPosts(),
      ]);
      
      final followingAlbums = results[0] as List<Map<String, dynamic>>;
      final followingPosts = results[1] as List<Post>;
      
      if (mounted) {
        setState(() {
          _followingAlbums = followingAlbums;
          _followingPosts = followingPosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.log("Error loading following content: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Process post comments
  void _showCommentsModal(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: CommentsScreen(
            photoId: post.id,
            photoUrl: post.imageUrls.isNotEmpty
                ? post.imageUrls.first
                : (post.images.isNotEmpty
                ? post.images.first.path
                : 'https://via.placeholder.com/300'),
          ),
        );
      },
    ).then((_) {
      // Обновляем список постов после закрытия окна комментариев
      _loadFollowingPosts();
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
  
  // Show post on map
  void _showOnMap(Post post) async {
    if (post.location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No location data available for this post'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    AppLogger.log("📍 Showing following post ${post.id} on map");
    
    // Открываем отдельный экран карты для постов followings
    final selectedId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FollowingsMapScreen(
          posts: _followingPosts,
          selectedPostId: post.id,
          title: 'Followings Map',
        ),
      ),
    );
    
    // После закрытия карты прокручиваем к выбранному посту
    if (selectedId != null && selectedId.isNotEmpty) {
      // Небольшая задержка для завершения анимации закрытия экрана карты
      await Future.delayed(Duration(milliseconds: 300));
      if (mounted) {
        await _scrollToPostById(selectedId);
      }
    }
  }
  
  // Process liking a post
  Future<void> _likePost(Post post) async {
    try {
      final isLiked = await SocialService.isLiked(post.id);
      
      if (isLiked) {
        await SocialService.unlikePost(post.id);
      } else {
        await SocialService.likePost(post.id);
      }
      
      // Update UI state
      setState(() {});
    } catch (e) {
      AppLogger.log("Error liking post: $e");
    }
  }
  
  // Process adding/removing from favorites
  Future<void> _favoritePost(Post post) async {
    try {
      final isFavorite = await SocialService.isFavorite(post.id);
      
      if (isFavorite) {
        await SocialService.removeFromFavorites(post.id);
      } else {
        await SocialService.addToFavorites(post.id);
      }
      
      // Update UI state
      setState(() {});
    } catch (e) {
      AppLogger.log("Error favoriting post: $e");
    }
  }
  
  // Process following a user
  Future<void> _followUser(String userId) async {
    try {
      // Проверяем, не пытается ли пользователь подписаться на самого себя
      if (_currentUserId == userId || userId == 'current_user') {
        AppLogger.log("Попытка подписаться на самого себя: $_currentUserId. Операция отменена.");
        return;
      }
      
      final isFollowing = await SocialService.isFollowing(userId);
      
      if (isFollowing) {
        await SocialService.unfollowUser(userId);
      } else {
        await SocialService.followUser(userId);
      }
      
      // Update UI
      setState(() {});
      
      // Reload following posts
      _loadFollowingPosts();
    } catch (e) {
      AppLogger.log("Error following user: $e");
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Following'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Search bar
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: Colors.grey.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _updateSearchQuery,
                  decoration: InputDecoration(
                    hintText: 'Search author',
                    prefixIcon: Icon(Icons.search, color: Colors.grey),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey),
                            onPressed: () {
                              _searchController.clear();
                              _updateSearchQuery('');
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.grey[100],
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              // Content
              Expanded(
                child: _isLoading
                    ? Center(child: CircularProgressIndicator())
                    : _buildFollowingList(),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFollowingList() {
    return RefreshIndicator(
      onRefresh: _loadFollowingPosts,
      child: (_followingAlbums.isEmpty && _followingPosts.isEmpty)
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 80),
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(
                      Icons.people_outline,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'You are not following anyone yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Follow users to see their albums and posts here',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : _buildContentWithSearch(),
    );
  }
  
  Widget _buildContentWithSearch() {
    final mixedContent = _getMixedContent();
    final filteredContent = _filterContent(mixedContent);
    
    if (filteredContent.isEmpty && _searchQuery.isNotEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 80),
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey,
              ),
              SizedBox(height: 16),
              Text(
                'Nothing found',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try changing your search query',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ],
      );
    }
    
    return _buildMixedContentList();
  }
  
  List<dynamic> _getMixedContent() {
    List<dynamic> mixedContent = [];
    
    // Добавляем альбомы
    for (var album in _followingAlbums) {
      mixedContent.add({
        'type': 'album',
        'data': album,
        'created_at': DateTime.tryParse(album['created_at']?.toString() ?? '') ?? DateTime.now(),
      });
    }
    
    // Добавляем посты
    for (var post in _followingPosts) {
      mixedContent.add({
        'type': 'post',
        'data': post,
        'created_at': post.createdAt,
      });
    }
    
    // Сортируем по дате создания, сначала новые
    mixedContent.sort((a, b) => (b['created_at'] as DateTime).compareTo(a['created_at'] as DateTime));
    
    return mixedContent;
  }

  Widget _buildMixedContentList() {
    // Получаем смешанный контент и применяем фильтрацию
    final mixedContent = _getMixedContent();
    final filteredContent = _filterContent(mixedContent);
    
    // Очищаем и заполняем карту индексов постов
    _postIdToIndex.clear();
    for (int i = 0; i < filteredContent.length; i++) {
      final item = filteredContent[i];
      if (item['type'] == 'post') {
        final post = item['data'] as Post;
        _postIdToIndex[post.id] = i;
      }
    }
    
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
      itemCount: filteredContent.length,
      itemBuilder: (context, index) {
        final item = filteredContent[index];
        
        if (item['type'] == 'album') {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: AlbumCard(
              albumRow: item['data'] as Map<String, dynamic>,
              currentUserId: _userId,
              onChanged: _loadFollowingPosts,
              onTap: _openAlbumDetail,
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
                _loadFollowingPosts();
              },
            ),
          );
        } else {
          final post = item['data'] as Post;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6), // Добавляем отступы между карточками постов, как у альбомов
            child: FutureBuilder<Map<String, dynamic>>(
              future: _getPostAuthorInfo(post),
              builder: (context, authorSnapshot) {
                final authorInfo = authorSnapshot.data ?? {'firstName': 'Loading...', 'lastName': '', 'profileImageUrl': ''};
                final firstName = authorInfo['firstName']?.toString().trim() ?? '';
                final lastName = authorInfo['lastName']?.toString().trim() ?? '';
                final authorName = '$firstName $lastName'.trim();
                final authorProfileImage = authorInfo['profileImageUrl'] as String?;
                
                return FutureBuilder<bool>(
                  future: SocialService.isFollowing(post.user),
                  builder: (context, snapshot) {
                    final isFollowing = snapshot.data ?? false;
                    return PostCard(
                      post: post,
                      userProfileImage: _userProfileImage,
                      userFullName: _userFullName,
                      authorProfileImage: authorProfileImage,
                      authorName: authorName,
                      isCurrentUserPost: _isCurrentUserPost(post),
                      onShowCommentsModal: _showCommentsModal,
                      onShowOnMap: _showOnMap,
                      onEditPost: (_) {},
                      onDeletePost: (_) {},
                      onLikePost: _likePost,
                      onFavoritePost: _favoritePost,
                      onFollowUser: _followUser,
                      isFollowing: isFollowing,
                      onLocationPostsClick: _openLocationPostsScreen,
                    );
                  },
                );
              },
            ),
          );
        }
      },
    );
  }

  void _openAlbumDetail(String albumId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AlbumDetailScreen(
          albumId: albumId,
          currentUserId: _currentUserId,
        ),
      ),
    );
  }
  
  // Получение информации об авторе поста
  Future<Map<String, dynamic>> _getPostAuthorInfo(Post post) async {
    // Check cache first
    if (_authorCache.containsKey(post.user)) {
      return _authorCache[post.user]!;
    }
    
    Map<String, dynamic> authorInfo;
    
    if (_isCurrentUserPost(post)) {
      // Если пост принадлежит текущему пользователю, возвращаем данные текущего пользователя
      authorInfo = {
        'firstName': _userFullName.split(' ').first,
        'lastName': _userFullName.split(' ').length > 1 ? _userFullName.split(' ').last : '',
        'profileImageUrl': _userProfileImage,
      };
    } else {
      // Иначе получаем информацию о пользователе по ID через API
      // Логи закомментированы
      authorInfo = await UserService.getUserInfoById(post.user);
    }
    
    // Cache the result
    _authorCache[post.user] = authorInfo;
    return authorInfo;
  }
  
  // Проверяем, является ли пост текущего пользователя
  bool _isCurrentUserPost(Post post) {
    // Проверяем наличие идентификаторов пользователя
    if (_currentUserId.isEmpty && _userId.isEmpty) {
      AppLogger.log("❌ FollowingTab _isCurrentUserPost: Нет доступных идентификаторов пользователя, возвращаем false");
      return false;
    }
    
    // Выводим подробную отладочную информацию
    // Логи закомментированы
    
    // Проверяем, совпадает ли пользователь поста с email текущего пользователя
    if (post.user == _currentUserId) {
      // AppLogger.log("  - Найдено совпадение: post.user совпадает с _currentUserId (email)");
      return true;
    }
    
    // Если у нас есть числовой идентификатор пользователя, проверяем, совпадает ли post.user с ним
    if (_userId.isNotEmpty && post.user == _userId) {
      // AppLogger.log("  - Найдено совпадение: post.user совпадает с _userId (numeric)");
      return true;
    }
    
    // Пытаемся проверить, является ли пользователь поста числовым ID
    try {
      final int? postUserId = int.tryParse(post.user);
      final int? currentUserId = int.tryParse(_userId);
      
      if (postUserId != null && currentUserId != null && postUserId == currentUserId) {
        // AppLogger.log("  - Найдено совпадение: числовой postUserId совпадает с числовым currentUserId");
        return true;
      }
    } catch (e) {
      AppLogger.log("  - Ошибка парсинга ID как числовых: $e");
    }
    
    // Проверяем специальные значения
    if (post.user == 'current_user' || post.user == 'null') {
      AppLogger.log("  - Найдено совпадение: post.user - это специальное значение ('current_user' или 'null')");
      return true;
    }
    
    // AppLogger.log("  - ИТОГОВЫЙ РЕЗУЛЬТАТ FollowingTab _isCurrentUserPost: false - Соответствующие критерии не найдены");
    return false;
  }

  // Метод для открытия экрана создания поста
  void _openUploadImageScreen() async {
    try {
      AppLogger.log("Opening upload screen from Following Tab");
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UploadDescriptionScreen()),
      );
      
      // При успешной загрузке обновляем данные
      if (result != null) {
        _loadFollowingPosts();
      }
    } catch (e) {
      AppLogger.log("Error opening upload screen: $e");
    }
  }
}

// ===================== Followings Map Screen =====================

class FollowingsMapScreen extends StatefulWidget {
  final List<Post> posts;
  final String selectedPostId;
  final String title;
  const FollowingsMapScreen({Key? key, required this.posts, required this.selectedPostId, required this.title}) : super(key: key);

  @override
  State<FollowingsMapScreen> createState() => _FollowingsMapScreenState();
}

class _FollowingsMapScreenState extends State<FollowingsMapScreen> {
  MapboxMap? _map;
  PointAnnotationManager? _manager;
  final Map<String, String> _annotationIdToPostId = {};
  bool _isSettingUp = false;
  String? _currentSelectedPostId;

  @override
  void initState() {
    super.initState();
    _currentSelectedPostId = widget.selectedPostId;
  }

  @override
  void dispose() {
    // Попробуем безопасно удалить менеджер аннотаций
    try {
      if (_map != null && _manager != null) {
        _map!.annotations.removeAnnotationManager(_manager!);
      }
    } catch (_) {}
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    
    // Отключаем шкалу зума
    try {
      await map.scaleBar.updateSettings(
        ScaleBarSettings(
          enabled: false,
        )
      );
    } catch (e) {
      // Игнорируем ошибки
    }
  }

  Future<void> _setupAfterStyleLoaded() async {
    if (_map == null) return;
    if (_isSettingUp) return;
    _isSettingUp = true;

    // Регистрируем базовые изображения, затем миниатюры постов
    await MapboxConfig.registerMapboxMarkerImages(_map!);
    await MapboxConfig.preloadMarkerImagesForPosts(_map!, widget.posts);

    // Удаляем прежний менеджер, если он был
    try {
      if (_manager != null) {
        await _map!.annotations.removeAnnotationManager(_manager!);
      }
    } catch (_) {}

    // Создаем новый менеджер
    _manager = await MapHelper.createAnnotationManager(_map!);
    if (_manager == null) return;

    _annotationIdToPostId.clear();

    // Обработчик кликов по маркеру
    await MapHelper.addClickListenerToAnnotation(_manager!, (annotationId) {
      final postId = _annotationIdToPostId[annotationId];
      if (postId != null) {
        // Если кликнули на уже выбранный маркер - закрываем экран
        if (_currentSelectedPostId == postId) {
          Navigator.of(context).pop(postId);
        } else {
          // Иначе выделяем этот маркер
          setState(() {
            _currentSelectedPostId = postId;
          });
          _redrawMarkers();
        }
      }
    });

    // Добавляем маркеры
    await _addMarkers();

    // Центрируем камеру на выбранном посте
    final center = widget.posts.firstWhere((p) => p.id == widget.selectedPostId, orElse: () => widget.posts.first);
    await MapHelper.moveCamera(
      mapboxMap: _map!,
      latitude: center.location.latitude,
      longitude: center.location.longitude,
      zoom: 1.5,
      animate: true,
    );
    _isSettingUp = false;
  }

  Future<void> _addMarkers() async {
    if (_map == null || _manager == null) return;

    for (final post in widget.posts) {
      final isSelected = post.id == _currentSelectedPostId;
      // Используем зарегистрированное изображение поста как иконку
      final iconId = "post-marker-${post.id}"; // совпадает с MapboxConfig.registerPostImageAsMarker
      // Если вдруг не зарегистрировано, используем стандартный
      bool hasImage = false;
      try { hasImage = await _map!.style.hasStyleImage(iconId); } catch (_) {}
      final String imageToUse = hasImage ? iconId : 'custom-marker';

      final options = PointAnnotationOptions(
        geometry: Point(coordinates: Position(post.location.longitude, post.location.latitude)),
        iconImage: imageToUse,
        iconSize: isSelected ? 0.5 : 0.25,
        iconAnchor: IconAnchor.BOTTOM,
      );
      PointAnnotation? annotation;
      try {
        // Пробуем создать маркер
        annotation = await _manager!.create(options);
      } catch (e) {
        // Если менеджер недействителен — пересоздаем и повторяем один раз
        final msg = e.toString();
        if (msg.contains('No manager found')) {
          try {
            if (_manager != null) {
              await _map!.annotations.removeAnnotationManager(_manager!);
            }
          } catch (_) {}
          _manager = await MapHelper.createAnnotationManager(_map!);
          if (_manager != null) {
            try { annotation = await _manager!.create(options); } catch (_) {}
          }
        }
      }
      if (annotation != null) {
        _annotationIdToPostId[annotation.id] = post.id;
      }
    }
  }

  Future<void> _redrawMarkers() async {
    if (_map == null || _manager == null) return;
    
    // Удаляем все существующие маркеры
    try {
      await _manager!.deleteAll();
      _annotationIdToPostId.clear();
    } catch (e) {
      // Игнорируем ошибки
    }
    
    // Создаем маркеры заново с обновленными размерами
    await _addMarkers();
  }

  void _onMapTap(MapContentGestureContext mapContext) {
    // Сбрасываем выделение при нажатии на пустое место карты
    if (_currentSelectedPostId != null) {
      setState(() {
        _currentSelectedPostId = null;
      });
      _redrawMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
      ),
      body: MapWidget(
        key: const ValueKey('followings_map_widget'),
        styleUri: MapboxConfig.DEFAULT_STYLE_URI,
        onMapCreated: _onMapCreated,
        onStyleLoadedListener: (_) => _setupAfterStyleLoaded(),
        onTapListener: _onMapTap,
      ),
    );
  }
} 