import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/commercial_post.dart';
import '../services/commercial_post_service.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';
import 'create_commercial_post_screen.dart';
import 'image_viewer/commercial_post_gallery_screen.dart';
import 'edit_commercial_post_screen.dart';
import 'commercial_post_map_screen.dart';
import '../widgets/commercial_post_card.dart';

class CommercialPostsScreen extends StatefulWidget {
  final int albumId;
  final String albumTitle;
  final int? currentUserId;

  const CommercialPostsScreen({
    Key? key,
    required this.albumId,
    required this.albumTitle,
    this.currentUserId,
  }) : super(key: key);

  @override
  State<CommercialPostsScreen> createState() => _CommercialPostsScreenState();
}

class _CommercialPostsScreenState extends State<CommercialPostsScreen> {
  List<CommercialPost> _commercialPosts = [];
  bool _isLoading = true;
  String? _error;
  String? _currentUserProfileImage;
  String _currentUserFullName = '';

  @override
  void initState() {
    super.initState();
    _loadCommercialPosts();
    _loadCurrentUserData();
  }

  // Загрузка данных текущего пользователя
  Future<void> _loadCurrentUserData() async {
    try {
      final userData = await UserService.getCurrentUserData();
      setState(() {
        _currentUserProfileImage = userData['profileImageUrl'];
        _currentUserFullName = '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim();
        if (_currentUserFullName.isEmpty) {
          _currentUserFullName = 'User';
        }
      });
    } catch (e) {
      AppLogger.log('❌ Ошибка загрузки данных пользователя: $e');
    }
  }

  Future<void> _loadCommercialPosts() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final posts = await CommercialPostService.getCommercialPostsForAlbum(widget.albumId);
      setState(() {
        _commercialPosts = posts;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Ошибка загрузки коммерческих постов: $e';
        _isLoading = false;
      });
      AppLogger.log('❌ Ошибка загрузки коммерческих постов: $e');
    }
  }

  Future<void> _createCommercialPost() async {
    if (widget.currentUserId == null) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateCommercialPostScreen(
          userId: widget.currentUserId!,
          albumId: widget.albumId,
        ),
      ),
    );

    if (result == true) {
      // Обновляем список после создания поста
      _loadCommercialPosts();
    }
  }

  // Редактирование коммерческого поста
  Future<void> _editCommercialPost(CommercialPost post) async {
    if (widget.currentUserId == null) return;

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EditCommercialPostScreen(post: post),
      ),
    );

    if (result == true) {
      // Обновляем список после редактирования поста
      _loadCommercialPosts();
    }
  }

  // Удаление коммерческого поста
  Future<void> _deleteCommercialPost(CommercialPost post) async {
    if (widget.currentUserId == null) return;

    // Показываем диалог подтверждения
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Delete'),
          content: Text('Are you sure you want to delete this commercial post?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      final success = await CommercialPostService.deleteCommercialPost(
        post.id,
        widget.currentUserId!,
      );

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Commercial post deleted successfully')),
        );
        // Обновляем список после удаления
        _loadCommercialPosts();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete commercial post'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      AppLogger.log("Error deleting commercial post: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting commercial post'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Лайк коммерческого поста обрабатывается внутри CommercialLikeButton
  // Удалено чтобы избежать двойного вызова и рассинхронизации счётчика

  // Callback для уведомления о изменении избранного
  // Логика добавления/удаления обрабатывается в CommercialFavoriteButton
  Future<void> _favoriteCommercialPost(CommercialPost post) async {
    // Здесь можно добавить дополнительные действия при изменении избранного
    // Например, обновление UI, отправка аналитики и т.д.
    // НО не нужно повторно вызывать SocialService методы - это уже делает CommercialFavoriteButton
    
    // Если нужно обновить состояние экрана, можно вызвать setState
    if (mounted) {
      setState(() {
        // Обновляем UI если нужно
      });
    }
  }

  // Переход к изображениям
  void _onImageTap(CommercialPost post, int index) {
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
    
    // Навигируем к экрану карты коммерческого поста
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommercialPostMapScreen(
          post: post,
          onPostTap: (tappedPost) {
            // Когда пользователь нажимает "Return to Post" на карте,
            // мы можем прокрутить к этому посту или выделить его
            AppLogger.log("📍 User returned from map to commercial post ${tappedPost.id}");
            // Можно добавить логику прокрутки к конкретному посту
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Commercial Posts',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (widget.currentUserId != null)
            IconButton(
              icon: Icon(Icons.add, color: Colors.orange.shade600),
              onPressed: _createCommercialPost,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blue.shade600),
            ),
            SizedBox(height: 16),
            Text(
              'Loading commercial posts...',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadCommercialPosts,
              child: Text('Повторить'),
            ),
          ],
        ),
      );
    }

    if (_commercialPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.shopping_bag_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            SizedBox(height: 16),
            Text(
              'Пока нет коммерческих предложений',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Связанные с альбомом "${widget.albumTitle}"',
              style: TextStyle(
                color: Colors.grey.shade500,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadCommercialPosts,
      child: ListView.separated(
        padding: EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 90),
        itemCount: _commercialPosts.length,
        separatorBuilder: (context, index) => SizedBox(height: 4),
        itemBuilder: (context, index) {
          final post = _commercialPosts[index];
          return Container(
            margin: EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
            ),
            child: CommercialPostCard(
              post: post,
              userProfileImage: _currentUserProfileImage,
              userFullName: _currentUserFullName,
              onEditPost: _editCommercialPost,
              onDeletePost: _deleteCommercialPost,
              isCurrentUserPost: widget.currentUserId == post.userId,
              // Лайк обрабатывается внутри CommercialLikeButton
              onLikePost: null,
              onFavoritePost: _favoriteCommercialPost,
              onImageTap: _onImageTap,
              isFollowing: false,
              onShowOnMap: _showCommercialPostOnMap,
            ),
          );
        },
      ),
    );
  }

}
