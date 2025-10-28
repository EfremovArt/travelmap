import 'package:flutter/material.dart';
import '../models/post.dart';
import '../models/location.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import 'post_card.dart';
import '../utils/logger.dart';
import 'photo_grid.dart';
import 'dart:async';

/// Виджет для отображения группы постов из одной локации с возможностью свайпа
class LocationPostsViewerController {
  _LocationPostsViewerState? _state;

  void _attach(_LocationPostsViewerState state) {
    _state = state;
  }

  void _detach(_LocationPostsViewerState state) {
    if (identical(_state, state)) {
      _state = null;
    }
  }

  void selectPostById(String postId) {
    _state?.selectPostById(postId);
  }
}

class LocationPostsViewer extends StatefulWidget {
  final Post initialPost;
  final String? userProfileImage;
  final String userFullName;
  final Function(Post) onShowCommentsModal;
  final Function(Post) onShowOnMap;
  final Function(Post) onEditPost;
  final Function(Post) onDeletePost;
  final Function(Post)? onLikePost;
  final Function(Post)? onFavoritePost;
  final Function(String)? onFollowUser;
  final Map<String, bool> followingUsers;
  final Function(Post, int)? onImageTap;
  final LocationPostsViewerController? controller;

  const LocationPostsViewer({
    Key? key,
    required this.initialPost,
    required this.userProfileImage,
    required this.userFullName,
    required this.onShowCommentsModal,
    required this.onShowOnMap,
    required this.onEditPost,
    required this.onDeletePost,
    this.onLikePost,
    this.onFavoritePost,
    this.onFollowUser,
    required this.followingUsers,
    this.onImageTap,
    this.controller,
  }) : super(key: key);

  @override
  _LocationPostsViewerState createState() => _LocationPostsViewerState();
}

class _LocationPostsViewerState extends State<LocationPostsViewer> {
  int _currentIndex = 0;
  List<Post> _locationPosts = [];
  bool _isLoading = true;
  Map<String, String> _authorNames = {};
  Map<String, String?> _authorAvatars = {};
  String _userId = '';
  String _userEmail = '';
  String? _error;

  // PageView контроллер (объявление)
  late PageController _pageController;
  bool _pageControllerInitialized = false;

  @override
  void initState() {
    super.initState();
    // Привязываем контроллер, если он передан
    if (widget.controller != null) {
      widget.controller!._attach(this);
    }
    AppLogger.log('⭐⭐⭐ LocationPostsViewer.initState ВЫЗВАН для поста ${widget.initialPost.id} ⭐⭐⭐');
    AppLogger.log('🔍🔍🔍 ЛОКАЦИЯ: ${widget.initialPost.locationName}, КООРДИНАТЫ: ${widget.initialPost.location.latitude},${widget.initialPost.location.longitude} 🔍🔍🔍');

    _loadUserInfo();
    _loadPostsFromSameLocation();
  }
  
  @override
  void didUpdateWidget(LocationPostsViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем данные пользователя при изменении виджета
    _loadUserInfo(forceRefresh: true);
  }

  @override
  void dispose() {
    if (widget.controller != null) {
      widget.controller!._detach(this);
    }
    // Освобождаем ресурсы PageController только если он был инициализирован
    if (_pageControllerInitialized) {
      _pageController.dispose();
    }

    super.dispose();
  }

  // Загружаем информацию о текущем пользователе
  Future<void> _loadUserInfo({bool forceRefresh = false}) async {
    try {
      // Очищаем кэш при принудительном обновлении
      if (forceRefresh) {
        UserService.clearCache();
      }
      _userEmail = await UserService.getEmail();
      _userId = await UserService.getUserId();
      AppLogger.log('📱📱📱 LocationPostsViewer: Текущий пользователь - EMAIL: $_userEmail, ID: $_userId 📱📱📱');
      
      // Обновляем UI если данные изменились
      if (mounted && forceRefresh) {
        setState(() {});
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при загрузке информации о пользователе: $e');
    }
  }

  // Загрузка всех постов из той же локации
  Future<void> _loadPostsFromSameLocation() async {
    AppLogger.log('⭐⭐⭐ LocationPostsViewer._loadPostsFromSameLocation ВЫЗВАН ⭐⭐⭐');
    AppLogger.log('🚀🚀🚀 Начинаем загрузку постов для локации: ${widget.initialPost.locationName} 🚀🚀🚀');

    setState(() {
      _isLoading = true;
    });

    try {
      AppLogger.log("🔄 LocationPostsViewer: Loading posts from same location");
      AppLogger.log("🔄 Initial post ID: ${widget.initialPost.id}");

      final posts = await PostService.getPostsInSameLocation(widget.initialPost);

      if (!mounted) {
        AppLogger.log("❌ Widget not mounted, skipping setState");
        return;
      }

      // Находим индекс начального поста в списке
      int initialIndex = posts.indexWhere((post) => post.id == widget.initialPost.id);
      if (initialIndex == -1) {
        AppLogger.log('⚠️⚠️⚠️ Initial post not found in location posts, adding it ⚠️⚠️⚠️');
        posts.insert(0, widget.initialPost);
        initialIndex = 0;
      }

      // Инициализируем контроллер страниц с нужным начальным индексом
      _pageController = PageController(initialPage: initialIndex);
      _pageControllerInitialized = true;

      setState(() {
        _locationPosts = posts;
        _currentIndex = initialIndex;
        _isLoading = false;
      });

      AppLogger.log("✅✅✅ LocationPostsViewer: Loaded ${_locationPosts.length} posts from the same location ✅✅✅");

      // Вывод информации для отладки
      final locationNames = _locationPosts.map((p) => p.locationName).join(', ');
      final coordinates = _locationPosts.map((p) => "${p.location.latitude},${p.location.longitude}").join(' | ');
      final postIds = _locationPosts.map((p) => p.id).join(', ');

      AppLogger.log("📍📍📍 Post locations: $locationNames 📍📍📍");
      AppLogger.log("📍📍📍 Post coordinates: $coordinates 📍📍📍");
      AppLogger.log("📝📝📝 Post IDs: $postIds 📝📝📝");

      // Загружаем информацию об авторах постов
      for (var post in _locationPosts) {
        _loadAuthorInfo(post.user);
      }

      // Подсказка отключена

    } catch (e) {
      AppLogger.log("❌❌❌ Error loading posts from same location: $e ❌❌❌");
      if (mounted) {
        setState(() {
          _locationPosts = [widget.initialPost];
          _isLoading = false;
          _error = e.toString();
        });

        // Инициализируем контроллер даже в случае ошибки
        _pageController = PageController(initialPage: 0);
        _pageControllerInitialized = true;
      }
    }
  }

  // Загрузка информации об авторе поста
  Future<void> _loadAuthorInfo(String userId) async {
    try {
      if (_authorNames.containsKey(userId)) return;

      AppLogger.log("🔄 Загружаем информацию об авторе с ID: $userId");

      // Обработка числовых ID пользователей
      if (int.tryParse(userId) != null) {
        // Для числовых ID получаем информацию из UserService
        final userData = await UserService.getUserInfoById(userId);
        final String firstName = userData['firstName'] ?? '';
        final String lastName = userData['lastName'] ?? '';
        String userName = '';

        if (firstName.isNotEmpty || lastName.isNotEmpty) {
          userName = '$firstName $lastName'.trim();
        } else {
          userName = 'Пользователь $userId';
        }

        AppLogger.log('✅ Получено имя для числового ID: $userName');

        if (!mounted) {
          AppLogger.log("❌ Widget not mounted, skipping setState for author info");
          return;
        }

        setState(() {
          _authorNames[userId] = userName;
          _authorAvatars[userId] = userData['profileImageUrl'];
        });
        return;
      }

      final userName = await UserService.getFullNameByEmail(userId);
      String? avatarUrl = await UserService.getProfileImageByEmail(userId);

      AppLogger.log('✅ Получено имя автора: $userName, аватар: $avatarUrl');

      if (!mounted) {
        AppLogger.log("❌ Widget not mounted, skipping setState for author info");
        return;
      }

      setState(() {
        _authorNames[userId] = userName;
        _authorAvatars[userId] = avatarUrl;
      });
    } catch (e) {
      AppLogger.log("❌ Error loading author info: $e");
      if (mounted) {
        setState(() {
          _authorNames[userId] = 'User $userId';
          _authorAvatars[userId] = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    AppLogger.log('⭐⭐⭐ LocationPostsViewer.build ВЫЗВАН ⭐⭐⭐');
    AppLogger.log('🔄🔄🔄 isLoading=$_isLoading, posts=${_locationPosts.length}, currentIndex=$_currentIndex 🔄🔄🔄');

    if (_isLoading) {
      return Card(
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 0,
        color: Colors.white,
        child: Container(
          height: 300,
          child: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (_locationPosts.length <= 1) {
      // Если только один пост, показываем обычную карточку
      AppLogger.log('⚠️⚠️⚠️ LocationPostsViewer: showing single post card - NO SWIPE AVAILABLE ⚠️⚠️⚠️');
      return PostCard(
        post: _locationPosts.first,
        userProfileImage: widget.userProfileImage,
        userFullName: widget.userFullName,
        authorProfileImage: _authorAvatars[_locationPosts.first.user],
        authorName: _authorNames[_locationPosts.first.user] ?? 'User',
        onShowCommentsModal: widget.onShowCommentsModal,
        onShowOnMap: widget.onShowOnMap,
        onEditPost: widget.onEditPost,
        onDeletePost: widget.onDeletePost,
        isCurrentUserPost: _isCurrentUserPost(_locationPosts.first),
        onLikePost: widget.onLikePost,
        onFavoritePost: widget.onFavoritePost,
        onFollowUser: widget.onFollowUser,
        isFollowing: widget.followingUsers[_locationPosts.first.user] ?? false,
        onImageTap: widget.onImageTap,
        onLocationPostsClick: null, // В LocationPostsViewer отключаем
      );
    }

    // Без микроанимаций
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        height: 520, // Увеличили высоту, чтобы внизу гарантированно помещалась локация
        child: PageView.builder(
          physics: const ClampingScrollPhysics(),
          controller: _pageController,
          itemCount: _locationPosts.length,
          onPageChanged: (index) {
            AppLogger.log('📱📱📱 СТРАНИЦА ИЗМЕНЕНА на $index (из $_currentIndex) 📱📱📱');
            setState(() {
              _currentIndex = index;
            });
          },
          itemBuilder: (context, index) {
            final post = _locationPosts[index];
            // Используем PostCard без Card-обертки
            return PostCard(
              post: post,
              userProfileImage: widget.userProfileImage,
              userFullName: widget.userFullName,
              authorProfileImage: _authorAvatars[post.user],
              authorName: _authorNames[post.user] ?? 'Пользователь ${post.user}',
              onShowCommentsModal: widget.onShowCommentsModal,
              onShowOnMap: widget.onShowOnMap,
              onEditPost: widget.onEditPost,
              onDeletePost: widget.onDeletePost,
              isCurrentUserPost: _isCurrentUserPost(post),
              onLikePost: widget.onLikePost,
              onFavoritePost: widget.onFavoritePost,
              onFollowUser: widget.onFollowUser,
              isFollowing: widget.followingUsers[post.user] ?? false,
              onImageTap: widget.onImageTap,
              onLocationPostsClick: null, // В LocationPostsViewer отключаем
              useCardWrapper: false, // Отключаем Card-обертку
            );
          },
        ),
      ),
    );
  }

  // Публичный метод для выбора конкретного поста внутри группы
  void selectPostById(String postId) {
    if (_locationPosts.isEmpty || !_pageControllerInitialized) return;
    final index = _locationPosts.indexWhere((p) => p.id == postId);
    if (index == -1) return;
    setState(() {
      _currentIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  // Вспомогательный метод для проверки, является ли пост пользователя его собственным
  bool _isCurrentUserPost(Post post) {
    AppLogger.log('📊 DEBUG isCurrentUserPost check for post ${post.id}:');
    AppLogger.log('  - post.user: ${post.user}');
    AppLogger.log('  - _userEmail: $_userEmail');
    AppLogger.log('  - _userId: $_userId');

    // Проверяем, совпадает ли пользователь поста с email текущего пользователя
    if (post.user == _userEmail) {
      AppLogger.log('  ✅ Пост принадлежит текущему пользователю (по email)');
      return true;
    }

    // Проверяем по ID
    if (_userId.isNotEmpty && post.user == _userId) {
      AppLogger.log('  ✅ Пост принадлежит текущему пользователю (по ID)');
      return true;
    }

    // Пытаемся проверить, являются ли числовыми идентификаторами
    try {
      final int? postUserId = int.tryParse(post.user);
      final int? currentUserId = int.tryParse(_userId);

      if (postUserId != null && currentUserId != null && postUserId == currentUserId) {
        AppLogger.log('  ✅ Пост принадлежит текущему пользователю (оба ID - числовые и совпадают)');
        return true;
      }
    } catch (e) {
      // Ошибка парсинга, может означать, что post.user не является числовым ID
    }

    // Специальные значения
    if (post.user == 'current_user' || post.user == 'null') {
      AppLogger.log('  ✅ Пост принадлежит текущему пользователю (специальное значение)');
      return true;
    }

    AppLogger.log('  ❌ Пост НЕ принадлежит текущему пользователю');
    return false;
  }
}