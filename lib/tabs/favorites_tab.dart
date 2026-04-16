import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import '../models/post.dart';
import '../models/location.dart';
import '../models/commercial_post.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../widgets/post_card.dart';
import '../widgets/commercial_post_card.dart';
import '../services/map_filter_service.dart';
import '../screens/main_screen.dart';
import '../utils/logger.dart';
import '../screens/upload/upload_description_screen.dart';
import '../services/album_service.dart';
import '../widgets/album_card.dart';
import 'albums_tab.dart' show AlbumDetailScreen, EditAlbumScreen; // для навигации в детали альбома и редактирования
import '../screens/comments_screen.dart';
import '../screens/image_viewer/vertical_photo_gallery_screen.dart';
import '../screens/image_viewer/commercial_post_gallery_screen.dart';
import '../screens/commercial_post_map_screen.dart';
/// Tab with user's favorite posts
class FavoritesTab extends StatefulWidget {
  const FavoritesTab({Key? key}) : super(key: key);

  @override
  _FavoritesTabState createState() => _FavoritesTabState();
}

class _FavoritesTabState extends State<FavoritesTab> with WidgetsBindingObserver {
  // Local list of favorite posts
  List<Post> _favoritePosts = [];
  // Local list of favorite commercial posts
  List<CommercialPost> _favoriteCommercialPosts = [];
  // Local list of favorite albums (raw rows as in albums list)
  List<Map<String, dynamic>> _favoriteAlbumRows = [];
  bool _isLoading = true;
  bool _isLoadingAlbums = false;
  bool _isLoadingCommercialPosts = false;
  Timer? _favoritesWatchTimer;
  List<String> _lastFavoriteIds = [];
  
  // Search functionality
  TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  
  // ScrollController for scrolling to specific posts
  final ScrollController _scrollController = ScrollController();
  
  // Map for tracking post indices for scrolling
  final Map<String, int> _postIdToIndex = {};
  
  // Cache for author info to improve search performance
  Map<String, Map<String, dynamic>> _authorCache = {};
  
  // Cache for user data
  String? _userProfileImage;
  String _userFullName = 'User';
  String _currentUserId = '';
  String _userId = '';
  
  // Service for map filtering
  final MapFilterService _mapFilterService = MapFilterService();
  
  @override
  void initState() {
    super.initState();
    
    // Register with the widget binding observer
    WidgetsBinding.instance.addObserver(this);
    
    // Load user data
    _loadUserData();
    
    // Load favorite posts
    _loadFavoritePosts();
    // Load favorite commercial posts
    _loadFavoriteCommercialPosts();
    // Load favorite albums
    _loadFavoriteAlbums();
    
    // Пока отключаем серверную синхронизацию, так как она вызывает много запросов
    // Future.microtask(() => AlbumService.syncFavoriteAlbumsFromServer());

    // Start watcher to auto-refresh when favorites change elsewhere
    _startFavoritesWatcher();
    // Быстрые обновления альбомов по стриму без ожидания 2с
    AlbumService.favoriteAlbumsChanged.stream.listen((_) {
      _loadFavoriteAlbums();
    });
    
    // Подписка на изменения обычных избранных постов
    SocialService.favoritesChanged.listen((_) {
      _loadFavoritePosts();
    });
    
    // Подписка на изменения коммерческих избранных постов
    SocialService.commercialFavoritesChanged.listen((_) {
      _loadFavoriteCommercialPosts();
    });
  }

  @override
  void dispose() {
    // Unregister from the widget binding observer
    WidgetsBinding.instance.removeObserver(this);
    
    _stopFavoritesWatcher();
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
      
      // Проверяем, нужно ли прокрутить к конкретному посту
      _checkAndScrollToPost();
    }
  }
  
  // Проверка и прокрутка к посту при возврате с карты
  Future<void> _checkAndScrollToPost() async {
    final scrollToPostId = _mapFilterService.scrollToPostId;
    AppLogger.log('🔍 FavoritesTab: Проверяем scrollToPostId: $scrollToPostId');
    
    if (scrollToPostId != null && scrollToPostId.isNotEmpty) {
      AppLogger.log('📍 FavoritesTab: Найден scrollToPostId, пробуем прокрутить к посту $scrollToPostId');
      // Очищаем сохраненный ID
      _mapFilterService.clearScrollToPostId();
      
      // Небольшая задержка для завершения анимации перехода
      await Future.delayed(Duration(milliseconds: 300));
      if (mounted) {
        await _scrollToPostById(scrollToPostId);
      }
    }
  }
  
  // Метод для прокрутки к посту по ID
  Future<void> _scrollToPostById(String postId) async {
    AppLogger.log('🎯 FavoritesTab: Начинаем прокрутку к посту $postId');
    AppLogger.log('   mounted: $mounted, hasClients: ${_scrollController.hasClients}');
    
    if (!mounted || !_scrollController.hasClients) {
      AppLogger.log('⚠️ FavoritesTab: ScrollController не готов для прокрутки');
      return;
    }
    
    final postIndex = _postIdToIndex[postId];
    AppLogger.log('   Индекс поста в _postIdToIndex: $postIndex');
    AppLogger.log('   Всего элементов в _postIdToIndex: ${_postIdToIndex.length}');
    
    if (postIndex == null) {
      AppLogger.log('⚠️ FavoritesTab: Пост $postId не найден в списке');
      AppLogger.log('   Доступные ID: ${_postIdToIndex.keys.take(5).join(", ")}...');
      return;
    }
    
    AppLogger.log('📍 FavoritesTab: Прокручиваем к посту $postId с индексом $postIndex');
    
    // Вычисляем примерный offset (высота карточки ≈ 520px + отступы)
    const double itemHeight = 536.0; // 520 + margins
    final double targetOffset = postIndex * itemHeight;
    
    // Ограничиваем offset максимальной позицией
    final double maxOffset = _scrollController.position.maxScrollExtent;
    final double safeOffset = targetOffset > maxOffset ? maxOffset : targetOffset;
    
    AppLogger.log('   Прокручиваем к offset: $safeOffset (target: $targetOffset, max: $maxOffset)');
    
    await _scrollController.animateTo(
      safeOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
    
    AppLogger.log('✅ FavoritesTab: Прокрутка завершена');
  }

  void _startFavoritesWatcher() {
    // ОТКЛЮЧАЕМ агрессивный таймер который вызывает постоянные запросы
    // Вместо этого обновления будут происходить только при ручных действиях пользователя
    _favoritesWatchTimer?.cancel();
    _favoritesWatchTimer = null;
    
    // Если нужен таймер, то с гораздо большим интервалом (например, 60 секунд)
    // _favoritesWatchTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
    //   try {
    //     if (_isLoading) return; // избегаем конкуренции с текущей загрузкой
    //     final prefsFavorites = await SocialService.getAllFavorites();
    //     final currentUser = await UserService.getEmail();
    //     final currentIds = prefsFavorites
    //         .where((f) => f.userId == currentUser)
    //         .map((f) => f.postId)
    //         .toList();
    //     if (!_areListsEqualUnordered(currentIds, _lastFavoriteIds)) {
    //       _lastFavoriteIds = List<String>.from(currentIds);
    //       await _loadFavoritePosts();
    //     }
    //     // Альбомы обновляются через стрим, убираем из таймера
    //   } catch (_) {}
    // });
  }

  void _stopFavoritesWatcher() {
    _favoritesWatchTimer?.cancel();
    _favoritesWatchTimer = null;
  }

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
  
  // Filter posts based on search query
  List<Post> _filterPosts(List<Post> posts) {
    if (_searchQuery.isEmpty) return posts;
    
    return posts.where((post) {
      final description = post.description.toLowerCase();
      final locationName = post.locationName.toLowerCase();
      
      // Check cached author info for better search
      final cachedAuthor = _authorCache[post.user];
      String authorName = '';
      if (cachedAuthor != null) {
        authorName = '${cachedAuthor['firstName']} ${cachedAuthor['lastName']}'.toLowerCase();
      }
      
      return description.contains(_searchQuery) || 
             locationName.contains(_searchQuery) ||
             authorName.contains(_searchQuery);
    }).toList();
  }

  // Filter commercial posts based on search query
  List<CommercialPost> _filterCommercialPosts(List<CommercialPost> commercialPosts) {
    if (_searchQuery.isEmpty) return commercialPosts;
    
    return commercialPosts.where((post) {
      final title = post.title.toLowerCase();
      final description = (post.description ?? '').toLowerCase();
      final userName = (post.userName ?? '').toLowerCase();
      
      return title.contains(_searchQuery) || 
             description.contains(_searchQuery) ||
             userName.contains(_searchQuery);
    }).toList();
  }
  
  // Filter albums based on search query
  List<Map<String, dynamic>> _filterAlbums(List<Map<String, dynamic>> albums) {
    if (_searchQuery.isEmpty) return albums;
    
    return albums.where((album) {
      final title = album['title']?.toString().toLowerCase() ?? '';
      final description = album['description']?.toString().toLowerCase() ?? '';
      final authorName = album['author_name']?.toString().toLowerCase() ?? '';
      
      return title.contains(_searchQuery) || 
             description.contains(_searchQuery) || 
             authorName.contains(_searchQuery);
    }).toList();
  }
  
  // Load user data
  Future<void> _loadUserData() async {
    try {
      final fullName = await UserService.getFullName();
      final profileImage = await UserService.getProfileImage();
      final userId = await UserService.getEmail();
      
      if (mounted) {
        setState(() {
          _userFullName = fullName;
          _userProfileImage = profileImage;
          _currentUserId = userId;
          _userId = userId;
        });
      }
    } catch (e) {
      AppLogger.log("Error loading user data: $e");
    }
  }
  
  // Load favorite posts
  Future<void> _loadFavoritePosts() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Clear author cache when refreshing data
      _authorCache.clear();
      
      final favoritePosts = await SocialService.getFavoritePosts();
      // Обновим кэш текущего состояния избранных ID для наблюдателя
      _lastFavoriteIds = favoritePosts.map((p) => p.id).toList();
      
      if (mounted) {
        setState(() {
          _favoritePosts = favoritePosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.log("Error loading favorite posts: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Load favorite albums
  Future<void> _loadFavoriteAlbums() async {
    // Логи закомментированы для уменьшения шума   
    
    try {
      setState(() {
        _isLoadingAlbums = true;
      });
      final rows = await AlbumService.getFavoriteAlbumsForCurrentUser();
      if (mounted) {
        setState(() {
          _favoriteAlbumRows = rows;
          _isLoadingAlbums = false;
        });
      }
    } catch (e) {
      AppLogger.log("❌ Error loading favorite albums: $e");
      if (mounted) {
        setState(() {
          _isLoadingAlbums = false;
        });
      }
    }
  }

  // Load favorite commercial posts
  Future<void> _loadFavoriteCommercialPosts() async {
    try {
      setState(() {
        _isLoadingCommercialPosts = true;
      });
      
      // Получаем коммерческие избранные из локального хранилища
      final commercialFavorites = await SocialService.getAllCommercialFavorites();
      final userId = await UserService.getEmail();
      
      // Фильтруем только избранные текущего пользователя
      final userCommercialFavoriteIds = commercialFavorites
          .where((favorite) => favorite.userId == userId)
          .map((favorite) => favorite.postId)
          .toSet();
      
      // AppLogger.log('📦 Загружено коммерческих избранных ID: ${userCommercialFavoriteIds.length}');
      
      List<CommercialPost> favoriteCommercialPosts = [];
      
      // Если есть избранные ID, пытаемся загрузить коммерческие посты с сервера
      if (userCommercialFavoriteIds.isNotEmpty) {
        try {
          final service = SocialService();
          final result = await service.getFavorites();
          
          if (result['success'] == true && 
              result['data'] != null && 
              result['data'] is Map && 
              result['data']['commercial_posts'] is List) {
            
            final List<dynamic> cp = result['data']['commercial_posts'];
            AppLogger.log('📦 Получено коммерческих постов с сервера: ${cp.length}');
            
            for (final item in cp) {
              if (item is Map) {
                try {
                  final postId = (item['id'] ?? 0).toString();
                  
                  // Проверяем, есть ли этот пост в локальных избранных
                  if (userCommercialFavoriteIds.contains(postId)) {
                    final commercialPost = CommercialPost(
                      id: (item['id'] ?? 0) is int ? item['id'] : int.tryParse(item['id']?.toString() ?? '0') ?? 0,
                      userId: (item['user_id'] ?? 0) is int ? item['user_id'] : int.tryParse(item['user_id']?.toString() ?? '0') ?? 0,
                      albumId: item['album_id'] != null ? (item['album_id'] is int ? item['album_id'] : int.tryParse(item['album_id'].toString())) : null,
                      photoId: item['photo_id'] != null ? (item['photo_id'] is int ? item['photo_id'] : int.tryParse(item['photo_id'].toString())) : null,
                      type: (item['type'] ?? 'album').toString(),
                      title: (item['title'] ?? '').toString(),
                      description: (item['description'] ?? '').toString(),
                      imageUrl: (item['image_url'] ?? '').toString(),
                      imageUrls: item['images'] is List ? List<String>.from((item['images'] as List).map((e) => e.toString())) : [],
                      price: item['price'] != null ? double.tryParse(item['price'].toString()) : null,
                      currency: (item['currency'] ?? 'USD').toString(),
                      contactInfo: (item['contact_info'] ?? '').toString(),
                      isActive: item['is_active'] == true || item['is_active'] == 1 || item['is_active'] == '1',
                      createdAt: DateTime.tryParse((item['created_at'] ?? '').toString()) ?? DateTime.now(),
                      updatedAt: DateTime.tryParse((item['updated_at'] ?? '').toString()) ?? DateTime.now(),
                      userName: (item['user_name'] ?? '').toString(),
                      userProfileImage: (item['user_profile_image'] ?? '').toString(),
                      albumTitle: (item['album_title'] ?? '').toString(),
                    );
                    favoriteCommercialPosts.add(commercialPost);
                  }
                } catch (e) {
                  AppLogger.log('❌ Ошибка при создании CommercialPost из данных сервера: $e');
                }
              }
            }
            
            AppLogger.log('✅ Загружено ${favoriteCommercialPosts.length} коммерческих избранных постов');
          }
        } catch (e) {
          AppLogger.log('❌ Ошибка при загрузке коммерческих постов с сервера: $e');
        }
      }
      
      if (mounted) {
        setState(() {
          _favoriteCommercialPosts = favoriteCommercialPosts;
          _isLoadingCommercialPosts = false;
        });
      }
    } catch (e) {
      AppLogger.log("Error loading favorite commercial posts: $e");
      if (mounted) {
        setState(() {
          _isLoadingCommercialPosts = false;
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
      _loadFavoritePosts();
    });
  }
  
  // Show favorite posts on map
  void _showFavoritesOnMap() {
    AppLogger.log("Show favorites on map button clicked");
    
    // Устанавливаем флаг для отображения только избранных постов
    _mapFilterService.setShowOnlyFavorites(true);
    // Устанавливаем заголовок для отображения на карте
    _mapFilterService.setFilterTitle('Favorites');
    _mapFilterService.setSourceView('favorites');
    
    // Пытаемся получить доступ к MainScreen через глобальный ключ
    if (mainScreenKey.currentState != null) {
      // Переключаемся на вкладку Home
      mainScreenKey.currentState?.switchToTab(0);
      
      // Показываем уведомление пользователю
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Showing only favorite posts on map'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Если не удалось получить доступ к MainScreen, используем запасной вариант
      AppLogger.log("MainScreen not found, using fallback navigation");
      
      // Используем метод Navigator.popUntil, чтобы вернуться к корневому маршруту
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      // Через небольшую задержку показываем уведомление
      Future.delayed(Duration(milliseconds: 300), () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Showing only favorite posts on map'),
            duration: Duration(seconds: 2),
          ),
        );
      });
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
        // Удаляем из избранного
        await SocialService.removeFromFavorites(post.id);
        AppLogger.log('❌ Удален из избранного пост: ${post.id}');
      } else {
        // Добавляем в избранное
        await SocialService.addToFavorites(post.id);
        AppLogger.log('⭐ Добавлен в избранное пост: ${post.id}');
      }
      
      // Принудительно обновляем список избранного
      await _loadFavoritePosts();
      
      // UI обновится автоматически через стрим, но setState нужен для текущего состояния кнопок
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
    } catch (e) {
      AppLogger.log("Error following user: $e");
    }
  }

  // Process liking a commercial post
  Future<void> _likeCommercialPost(CommercialPost post) async {
    try {
      final isLiked = await SocialService.isLiked(post.id.toString());
      
      if (isLiked) {
        await SocialService.unlikePost(post.id.toString());
      } else {
        await SocialService.likePost(post.id.toString());
      }
      
      // Update UI state
      setState(() {});
    } catch (e) {
      AppLogger.log("Error liking commercial post: $e");
    }
  }
  
  // Callback для уведомления о изменении избранного коммерческого поста
  Future<void> _favoriteCommercialPost(CommercialPost post) async {
    try {
      final isFavorite = await SocialService.isCommercialFavorite(post.id.toString());
      
      if (isFavorite) {
        // Удаляем из избранного
        await SocialService.removeFromCommercialFavorites(post.id.toString());
        AppLogger.log('❌ Удален из избранного коммерческий пост: ${post.id}');
      } else {
        // Добавляем в избранное
        await SocialService.addToCommercialFavorites(post.id.toString());
        AppLogger.log('⭐ Добавлен в избранное коммерческий пост: ${post.id}');
      }
      
      // Принудительно обновляем список избранного
      await _loadFavoriteCommercialPosts();
      
      // Update UI
      if (mounted) {
        setState(() {});
      }
    } catch (e) {
      AppLogger.log("❌ Error updating after commercial post favorite change: $e");
    }
  }

  // Показать коммерческий пост на карте
  void _showCommercialPostOnMap(CommercialPost post) {
    if (!post.hasLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No location data available for this commercial post'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    AppLogger.log("📍 Showing commercial post ${post.id} on map with coordinates ${post.latitude}, ${post.longitude}");
    
    // Открываем CommercialPostMapScreen с всеми избранными коммерческими постами
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommercialPostMapScreen(
          post: post,
          allPosts: _favoriteCommercialPosts, // Передаем все избранные коммерческие посты
          onPostTap: (tappedPost) {
            AppLogger.log("📍 User returned from map to commercial post ${tappedPost.id}");
            // Пост уже виден в списке, дополнительная прокрутка не требуется
          },
        ),
      ),
    );
  }

  // Открыть галерею фото коммерческого поста
  void _onImageTapCommercial(CommercialPost post, int index) {
    // Используем оригинальные изображения для галереи, cropped для отображения в ленте
    List<String> imageUrls = [];
    if (post.originalImageUrls.isNotEmpty) {
      imageUrls = post.originalImageUrls;
    } else if (post.hasImages) {
      // Fallback на cropped если нет оригиналов (обратная совместимость)
      imageUrls = post.imageUrls;
    } else if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
      imageUrls = [post.imageUrl!];
    }

    if (imageUrls.isNotEmpty) {
      Navigator.of(context).push(
        PageRouteBuilder(
          pageBuilder: (context, animation, secondaryAnimation) => 
            CommercialPostGalleryScreen(
              imageUrls: imageUrls,
              initialIndex: index,
              postTitle: post.title,
            ),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
          barrierColor: Colors.black,
          opaque: false,
        ),
      );
    }
  }

  // Показать обычный пост на карте с фильтрацией по избранным
  void _showFavoritePostOnMap(Post post) {
    if (post.location == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No location data available for this post'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    AppLogger.log("📍 Showing favorite post ${post.id} on map with coordinates ${post.location!.latitude}, ${post.location!.longitude}");
    
    // Устанавливаем фильтр для показа только избранных постов с выделением конкретного поста
    _mapFilterService.showFavoritesWithHighlight(post);
    
    // Получаем доступ к MainScreen через глобальный ключ
    if (mainScreenKey.currentState != null) {
      // Переключаемся на вкладку Home (карта)
      mainScreenKey.currentState?.switchToTab(0);
      
      // Показываем уведомление пользователю
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Showing favorite posts on map with highlighted post'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      // Запасной вариант навигации
      AppLogger.log("MainScreen not found, using fallback navigation");
      Navigator.of(context).popUntil((route) => route.isFirst);
      
      Future.delayed(Duration(milliseconds: 300), () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Showing favorite posts on map with highlighted post'),
            duration: Duration(seconds: 2),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Проверяем, нужно ли прокрутить к посту после возврата с карты
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndScrollToPost();
    });
    
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Favorites'),
            ],
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.black,
          bottom: TabBar(
            tabs: [
              Tab(text: 'Posts (${_favoritePosts.length + _favoriteCommercialPosts.length})'),
              Tab(text: 'Albums (${_favoriteAlbumRows.length})'),
            ],
          ),
        ),
        body: Column(
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
                  hintText: 'Search favorites...',
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
            // Tab content
            Expanded(
              child: TabBarView(
                children: [
                  // Posts tab
                  Stack(
                    children: [
                      (_isLoading || _isLoadingCommercialPosts)
                          ? Center(child: CircularProgressIndicator())
                          : _buildFavoritesList(),
                    ],
                  ),
                  // Albums tab
                  _isLoadingAlbums
                      ? Center(child: CircularProgressIndicator())
                      : _buildFavoriteAlbumsList(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFavoritesList() {
    final filteredPosts = _filterPosts(_favoritePosts);
    final filteredCommercialPosts = _filterCommercialPosts(_favoriteCommercialPosts);
    
    
    // Создаем комбинированный список с информацией о типе поста
    final List<Map<String, dynamic>> combinedItems = [];
    
    // Добавляем обычные посты
    for (final post in filteredPosts) {
      combinedItems.add({
        'type': 'regular',
        'post': post,
        'createdAt': post.createdAt,
      });
    }
    
    // Добавляем коммерческие посты
    for (final post in filteredCommercialPosts) {
      combinedItems.add({
        'type': 'commercial',
        'post': post,
        'createdAt': post.createdAt,
      });
    }
    
    // Сортируем по дате (новые сначала)
    combinedItems.sort((a, b) => (b['createdAt'] as DateTime).compareTo(a['createdAt'] as DateTime));
    
    
    return RefreshIndicator(
      onRefresh: () async {
        await Future.wait([
          _loadFavoritePosts(),
          _loadFavoriteCommercialPosts(),
        ]);
      },
      child: (_favoritePosts.isEmpty && _favoriteCommercialPosts.isEmpty)
          ? ListView(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 80),
              children: const [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.favorite_border,
                      size: 64,
                      color: Colors.grey,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'No favorite posts yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add to favorites by clicking the star icon on any post',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : combinedItems.isEmpty && _searchQuery.isNotEmpty
              ? ListView(
                  controller: _scrollController,
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
                )
              : ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.only(top: 8, bottom: 90, left: 8, right: 8),
                  itemCount: combinedItems.length,
                  separatorBuilder: (context, index) => SizedBox(height: 4),
                  itemBuilder: (context, index) {
                    final item = combinedItems[index];
                    final type = item['type'] as String;
                    
                    // Сохраняем индекс поста для возможности прокрутки
                    if (type == 'regular') {
                      final post = item['post'] as Post;
                      _postIdToIndex[post.id] = index;
                      return _buildRegularPostItem(post);
                    } else {
                      final commercialPost = item['post'] as CommercialPost;
                      _postIdToIndex[commercialPost.id.toString()] = index;
                      return _buildCommercialPostItem(commercialPost);
                    }
                  },
                ),
    );
  }

  Widget _buildRegularPostItem(Post post) {
    return FutureBuilder<bool>(
        future: SocialService.isFollowing(post.user),
        builder: (context, followingSnapshot) {
          final isFollowing = followingSnapshot.data ?? false;
          
          // Добавляем загрузку информации об авторе поста
          return FutureBuilder<Map<String, dynamic>>(
            future: _loadAuthorInfo(post.user),
            builder: (context, authorSnapshot) {
              // Создаем дефолтные значения для случая, если данные загружаются или произошла ошибка
              String authorName = 'User';
              String? authorProfileImage;
              
              // Если данные успешно загружены, используем их
              if (authorSnapshot.hasData && authorSnapshot.data != null) {
                final authorData = authorSnapshot.data!;
                final firstName = authorData['firstName'] ?? '';
                final lastName = authorData['lastName'] ?? '';
                authorName = '$firstName $lastName'.trim();
                if (authorName.isEmpty) authorName = 'User ${post.user}';
                
                authorProfileImage = authorData['profileImageUrl'];
              }
              
              return PostCard(
                post: post,
                userProfileImage: _userProfileImage,
                userFullName: _userFullName,
                authorProfileImage: authorProfileImage,
                authorName: authorName,
                isCurrentUserPost: post.user == _currentUserId,
                onShowCommentsModal: _showCommentsModal,
                onShowOnMap: _showFavoritePostOnMap,
                onEditPost: (_) {},
                onDeletePost: (_) {},
                onLikePost: _likePost,
                onFavoritePost: _favoritePost,
                onFollowUser: _followUser,
                isFollowing: isFollowing,
                onLocationPostsClick: _showFavoritePostOnMap,
                onImageTap: (post, imageIndex) {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => VerticalPhotoGalleryScreen(
                        post: post,
                        initialIndex: imageIndex,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      );
  }

  Widget _buildCommercialPostItem(CommercialPost post) {
    AppLogger.log('🏪 РЕНДЕРИНГ коммерческого поста ID: ${post.id}, title: "${post.title}"');
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
      ),
      child: CommercialPostCard(
          post: post,
          userProfileImage: _userProfileImage,
          userFullName: _userFullName,
          isCurrentUserPost: post.userId.toString() == _currentUserId,
          onEditPost: (_) {
            // Заглушка для редактирования коммерческого поста
            AppLogger.log('Edit commercial post: ${post.id}');
          },
          onDeletePost: (_) {
            // Заглушка для удаления коммерческого поста
            AppLogger.log('Delete commercial post: ${post.id}');
          },
          onFavoritePost: _favoriteCommercialPost,
          onLikePost: _likeCommercialPost,
          onFollowUser: _followUser,
          isFollowing: false, // Потребуется FutureBuilder если нужно показать реальное состояние
          onShowOnMap: _showCommercialPostOnMap,
          onImageTap: _onImageTapCommercial,
        ),
    );
  }

  Widget _buildFavoriteAlbumsList() {
    final filteredAlbums = _filterAlbums(_favoriteAlbumRows);
    
    return RefreshIndicator(
      onRefresh: _loadFavoriteAlbums,
      child: _favoriteAlbumRows.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(top: 80),
              children: const [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.photo_album_outlined, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No favorite albums yet',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add albums to favorites by clicking the star icon',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ],
            )
          : filteredAlbums.isEmpty && _searchQuery.isNotEmpty
              ? ListView(
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
                )
              : ListView.builder(
                  padding: const EdgeInsets.only(top: 8, bottom: 100),
                  itemCount: filteredAlbums.length,
                  itemBuilder: (context, index) {
                    final row = filteredAlbums[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                      child: AlbumCard(
                        albumRow: row,
                        currentUserId: _userId,
                        onChanged: () async {
                          await _loadFavoriteAlbums();
                        },
                        onTap: (albumId) async {
                          try {
                            // Открываем те же детали альбома, что и в разделе альбомов
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => AlbumDetailScreen(
                                  albumId: albumId,
                                  currentUserId: _userId,
                                ),
                              ),
                            );
                            // После возврата обновим избранные альбомы
                            await _loadFavoriteAlbums();
                          } catch (e) {
                            AppLogger.log('Error opening album from favorites: $e');
                          }
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
                          await _loadFavoriteAlbums();
                        },
                      ),
                    );
                  },
                ),
    );
  }
  
  // Метод для загрузки информации об авторе поста
  Future<Map<String, dynamic>> _loadAuthorInfo(String userId) async {
    // Check cache first
    if (_authorCache.containsKey(userId)) {
      return _authorCache[userId]!;
    }
    
    Map<String, dynamic> authorInfo;
    
    try {
      // Проверяем, является ли ID числовым (предполагаем, что это ID пользователя)
      if (int.tryParse(userId) != null) {
        // Загружаем информацию о пользователе по ID
        authorInfo = await UserService.getUserInfoById(userId);
      } else {
        // Если ID не числовой, предполагаем что это email
        final userName = await UserService.getFullNameByEmail(userId);
        final profileImage = await UserService.getProfileImageByEmail(userId);
        
        authorInfo = {
          'firstName': userName.split(' ').first,
          'lastName': userName.split(' ').length > 1 ? userName.split(' ').last : '',
          'profileImageUrl': profileImage,
        };
      }
    } catch (e) {
      AppLogger.log('Ошибка при загрузке информации об авторе $userId: $e');
      authorInfo = {
        'firstName': 'User',
        'lastName': userId,
        'profileImageUrl': null,
      };
    }
    
    // Cache the result
    _authorCache[userId] = authorInfo;
    return authorInfo;
  }
  
  // Метод для открытия экрана создания поста
  void _openUploadImageScreen() async {
    try {
      AppLogger.log("Opening upload screen from Favorites Tab");
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UploadDescriptionScreen()),
      );
      
      // При успешной загрузке обновляем данные
      if (result != null) {
        _loadFavoritePosts();
      }
    } catch (e) {
      AppLogger.log("Error opening upload screen: $e");
    }
  }
} 
