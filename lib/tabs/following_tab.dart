import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/post.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import '../widgets/post_card.dart';

/// Вкладка с постами от подписок
class FollowingTab extends StatefulWidget {
  const FollowingTab({Key? key}) : super(key: key);

  @override
  _FollowingTabState createState() => _FollowingTabState();
}

class _FollowingTabState extends State<FollowingTab> {
  // Локальный список постов подписок
  List<Post> _followingPosts = [];
  bool _isLoading = true;
  
  // Кэш для данных пользователя
  File? _userProfileImage;
  String _userFullName = 'Пользователь';
  String _currentUserId = '';
  
  @override
  void initState() {
    super.initState();
    
    // Загружаем данные пользователя
    _loadUserData();
    
    // Загружаем посты от подписок
    _loadFollowingPosts();
  }
  
  // Загрузка данных пользователя
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
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
    }
  }
  
  // Загрузка постов от подписок
  Future<void> _loadFollowingPosts() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final followingPosts = await SocialService.getFollowingPosts();
      
      if (mounted) {
        setState(() {
          _followingPosts = followingPosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      print("Error loading following posts: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Обработка комментариев к посту
  void _showCommentsModal(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Комментарии',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 16),
              Expanded(
                child: Center(
                  child: Text('Комментарии будут доступны в ближайшем обновлении'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Показать пост на карте
  void _showOnMap(Post post) {
    // Здесь будет переход на карту с отмеченным постом
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Переход на карту с выделенным постом')),
    );
  }
  
  // Обработка лайка поста
  Future<void> _likePost(Post post) async {
    try {
      final isLiked = await SocialService.isLiked(post.id);
      
      if (isLiked) {
        await SocialService.unlikePost(post.id);
      } else {
        await SocialService.likePost(post.id);
      }
      
      // Обновляем состояние UI
      setState(() {});
    } catch (e) {
      print("Error liking post: $e");
    }
  }
  
  // Обработка добавления/удаления из избранного
  Future<void> _favoritePost(Post post) async {
    try {
      final isFavorite = await SocialService.isFavorite(post.id);
      
      if (isFavorite) {
        await SocialService.removeFromFavorites(post.id);
      } else {
        await SocialService.addToFavorites(post.id);
      }
      
      // Обновляем состояние UI
      setState(() {});
    } catch (e) {
      print("Error favoriting post: $e");
    }
  }
  
  // Обработка подписки на пользователя
  Future<void> _followUser(String userId) async {
    try {
      final isFollowing = await SocialService.isFollowing(userId);
      
      if (isFollowing) {
        await SocialService.unfollowUser(userId);
      } else {
        await SocialService.followUser(userId);
      }
      
      // Обновляем список постов подписок после изменения
      _loadFollowingPosts();
    } catch (e) {
      print("Error following user: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Подписки'),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildFollowingList(),
    );
  }
  
  Widget _buildFollowingList() {
    if (_followingPosts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Нет постов от подписок',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Подпишитесь на других пользователей, чтобы видеть их посты здесь',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadFollowingPosts,
      child: ListView.builder(
        padding: EdgeInsets.only(top: 8),
        itemCount: _followingPosts.length,
        itemBuilder: (context, index) {
          final post = _followingPosts[index];
          return FutureBuilder<bool>(
            future: SocialService.isFollowing(post.user),
            builder: (context, snapshot) {
              final isFollowing = snapshot.data ?? false;
              return PostCard(
                post: post,
                userProfileImage: _userProfileImage,
                userFullName: _userFullName,
                isCurrentUserPost: post.user == _currentUserId,
                onShowCommentsModal: _showCommentsModal,
                onShowOnMap: _showOnMap,
                onEditPost: (_) {}, // Пустой обработчик, так как в ленте подписок нельзя редактировать
                onDeletePost: (_) {}, // Пустой обработчик, так как в ленте подписок нельзя удалять
                onLikePost: _likePost,
                onFavoritePost: _favoritePost,
                onFollowUser: _followUser,
                isFollowing: isFollowing,
              );
            },
          );
        },
      ),
    );
  }
} 