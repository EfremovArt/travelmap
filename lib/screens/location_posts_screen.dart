import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../widgets/post_card.dart';
import '../utils/logger.dart';
import '../screens/comments_screen.dart';
import '../screens/image_viewer/vertical_photo_gallery_screen.dart';
import '../services/social_service.dart';
import '../services/map_filter_service.dart';
import '../screens/main_screen.dart';

/// Экран для просмотра всех постов в определенной локации
class LocationPostsScreen extends StatefulWidget {
  final Post initialPost;
  final String locationName;
  final double latitude;
  final double longitude;

  const LocationPostsScreen({
    Key? key,
    required this.initialPost,
    required this.locationName,
    required this.latitude,
    required this.longitude,
  }) : super(key: key);

  @override
  _LocationPostsScreenState createState() => _LocationPostsScreenState();
}

class _LocationPostsScreenState extends State<LocationPostsScreen> {
  List<Post> _posts = [];
  bool _isLoading = true;
  Map<String, String> _authorNames = {};
  Map<String, String?> _authorAvatars = {};
  String? _userProfileImage;
  String _userFullName = '';
  Map<String, bool> _followingUsers = {};

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
    _loadLocationPosts();
  }

  Future<void> _loadUserInfo() async {
    try {
      final userEmail = await UserService.getEmail();
      final userData = await UserService.getCurrentUserData();
      
      if (mounted) {
        setState(() {
          _userProfileImage = userData['profileImageUrl'];
          _userFullName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
        });
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при загрузке информации о пользователе: $e');
    }
  }

  Future<void> _loadLocationPosts() async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Получаем все посты для данной локации
      final locationPosts = await PostService.getPostsInSameLocation(widget.initialPost);
      
      // Сортируем по дате создания (новые первыми)
      locationPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      // Загружаем информацию об авторах постов
      for (var post in locationPosts) {
        try {
          final userData = await UserService.getUserInfoById(post.user);
          _authorNames[post.user] = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
          _authorAvatars[post.user] = userData['profileImageUrl'];
        } catch (e) {
          AppLogger.log('Ошибка при загрузке данных автора ${post.user}: $e');
          _authorNames[post.user] = 'Пользователь ${post.user}';
          _authorAvatars[post.user] = null;
        }
      }

      // Загружаем статусы подписок
      await _loadFollowingStatus();

      if (mounted) {
        setState(() {
          _posts = locationPosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при загрузке постов локации: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadFollowingStatus() async {
    try {
      final follows = await SocialService.getAllFollows();
      final currentUserEmail = await UserService.getEmail();
      
      for (var post in _posts) {
        bool isFollowing = follows.any((follow) => 
          follow.followerId == currentUserEmail && follow.followedId == post.user);
        _followingUsers[post.user] = isFollowing;
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при загрузке статусов подписок: $e');
    }
  }

  // Обработчики действий с постами
  void _showCommentsModal(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CommentsScreen(
          photoId: post.id,
          photoUrl: post.imageUrls.isNotEmpty
              ? post.imageUrls.first
              : (post.images.isNotEmpty
              ? post.images.first.path
              : 'https://via.placeholder.com/300'),
        ),
      ),
    ).then((_) {
      // Обновляем список постов после закрытия окна комментариев
      _loadLocationPosts();
    });
  }

  void _showOnMap(Post post) {
    if (post.latitude != null && post.longitude != null) {
      
      // Сначала закрываем текущий экран группированных постов
      Navigator.of(context).pop();
      
      // Затем настраиваем фильтры и переключаемся на карту
      final mapFilterService = MapFilterService();
      mapFilterService.setSourceView('feed');
      mapFilterService.setShowOnlyFavorites(false);
      mapFilterService.setHighlightedPost(post);

      // Переключаемся на вкладку с картой (индекс 0) и даем время для закрытия экрана
      Future.delayed(Duration(milliseconds: 100), () {
        if (mainScreenKey.currentState != null) {
          mainScreenKey.currentState!.switchToTab(0);
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Нет данных о геолокации для этого поста'))
      );
    }
  }

  void _editPost(Post post) {
    // TODO: Implement edit functionality
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Редактирование поста')),
    );
  }

  void _deletePost(Post post) async {
    try {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Удалить пост?'),
          content: Text('Это действие нельзя отменить.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Отмена'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text('Удалить', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (result == true) {
        final success = await PostService.deletePost(post.id);
        if (success) {
          setState(() {
            _posts.removeWhere((p) => p.id == post.id);
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Пост удален')),
          );
        }
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при удалении поста: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка при удалении поста')),
      );
    }
  }

  void _likePost(Post post) async {
    try {
      final isLiked = await SocialService.isLiked(post.id);
      if (isLiked) {
        await SocialService.unlikePost(post.id);
      } else {
        await SocialService.likePost(post.id);
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при изменении лайка: $e');
    }
  }

  void _favoritePost(Post post) async {
    try {
      final isFavorite = await SocialService.isFavorite(post.id);
      if (isFavorite) {
        await SocialService.removeFromFavorites(post.id);
      } else {
        await SocialService.addToFavorites(post.id);
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при изменении избранного: $e');
    }
  }

  void _followUser(String userId) async {
    try {
      final isFollowing = _followingUsers[userId] ?? false;
      if (isFollowing) {
        await SocialService.unfollowUser(userId);
      } else {
        await SocialService.followUser(userId);
      }
      
      setState(() {
        _followingUsers[userId] = !isFollowing;
      });
    } catch (e) {
      AppLogger.log('❌ Ошибка при изменении подписки: $e');
    }
  }

  void _openImageViewer(Post post, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VerticalPhotoGalleryScreen(
          post: post,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          widget.locationName,
          style: TextStyle(
            fontFamily: 'Gilroy',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${_posts.length}',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _posts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Постов в этой локации не найдено',
                        style: TextStyle(
                          fontFamily: 'Gilroy',
                          fontSize: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadLocationPosts,
                  child: ListView.separated(
                    padding: EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 90),
                    itemCount: _posts.length,
                    separatorBuilder: (context, index) => SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final post = _posts[index];
                      final currentUserId = UserService.getUserId();
                      
                      return FutureBuilder<String>(
                        future: currentUserId,
                        builder: (context, snapshot) {
                          final isCurrentUserPost = snapshot.data == post.user;
                          
                          return Container(
                            margin: EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: PostCard(
                              post: post,
                              userProfileImage: _userProfileImage,
                              userFullName: _userFullName,
                              authorProfileImage: _authorAvatars[post.user],
                              authorName: _authorNames[post.user] ?? 'Пользователь',
                              onShowCommentsModal: _showCommentsModal,
                              onShowOnMap: _showOnMap,
                              onEditPost: _editPost,
                              onDeletePost: _deletePost,
                              isCurrentUserPost: isCurrentUserPost,
                              onLikePost: _likePost,
                              onFavoritePost: _favoritePost,
                              onFollowUser: _followUser,
                              isFollowing: _followingUsers[post.user] ?? false,
                              onImageTap: _openImageViewer,
                              onLocationPostsClick: null, // Уже на странице постов локации
                              useCardWrapper: false,
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
    );
  }
}
