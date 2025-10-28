import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/api_config.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../services/social_service.dart';
import 'package:intl/intl.dart';
import '../widgets/post_card.dart';
import '../screens/edit/edit_post_screen.dart';
import '../screens/comments_screen.dart';
import '../screens/image_viewer/image_viewer_screen.dart';
import '../screens/image_viewer/network_image_viewer_screen.dart';
import '../utils/logger.dart';
import '../screens/user_profile_screen.dart';

class MyMapTab extends StatefulWidget {
  const MyMapTab({Key? key}) : super(key: key);

  @override
  State<MyMapTab> createState() => _MyMapTabState();
}

class _MyMapTabState extends State<MyMapTab> with WidgetsBindingObserver {
  // New fields for handling user posts
  List<Post> _userPosts = [];
  bool _isLoading = true;
  Timer? _postsRefreshTimer;
  
  // Cache for user data
  String? _userProfileImage;
  String _userFullName = 'User';
  String _userEmail = '';
  String _userId = '';
  bool _userDataLoaded = false;

  @override
  void initState() {
    super.initState();
    
    // Register with the widget binding observer
    WidgetsBinding.instance.addObserver(this);
    
    // Load user data
    _loadUserData();
    
    // Load user posts
    _loadUserPosts();
    
    // Start timer for periodic posts refresh
    _startPostsRefreshTimer();
  }
  
  @override
  void dispose() {
    // Unregister from the widget binding observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel the timer
    if (_postsRefreshTimer != null) {
      _postsRefreshTimer?.cancel();
      _postsRefreshTimer = null;
      AppLogger.log("Posts refresh timer cancelled.");
    }
    
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
          _userEmail = email;
          _userId = userId;
          _userDataLoaded = true;
        });
      }
    } catch (e) {
      AppLogger.log("Error loading user data: $e");
    }
  }
  
  // Load user posts
  Future<void> _loadUserPosts() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Get current user ID
      final userId = await UserService.getUserId();
      
      // AppLogger.log("🔍 MY MAP TAB: Loading posts for user: id=$userId");
      
      // Load user's own posts
      final userOwnPosts = await PostService.getUserPosts(userId: userId);
      
      // Логирование отключено для уменьшения шума
      
      if (mounted) {
        setState(() {
          _userPosts = userOwnPosts;
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.log("🔍 MY MAP TAB: Error loading user posts: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Start timer for periodic post updates
  void _startPostsRefreshTimer() {
    _postsRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadUserPosts();
    });
  }

  // Show comments modal
  void _showCommentsModal(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CommentsScreen(
          photoId: post.id,
          photoUrl: post.imageUrls.isNotEmpty ? post.imageUrls.first : '',
        ),
      ),
    ).then((_) {
      // Обновляем список постов после закрытия окна комментариев
      _loadUserPosts();
    });
  }

  // Show post on map
  void _showOnMap(Post post) {
    // This functionality is not needed in the feed view
  }

  // Edit post
  void _editPost(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostScreen(post: post),
      ),
    ).then((_) => _loadUserPosts());
  }

  // Delete post
  Future<void> _deletePost(Post post) async {
    try {
      await PostService.deletePost(post.id);
      _loadUserPosts();
    } catch (e) {
      AppLogger.log("Error deleting post: $e");
    }
  }

  // Like post
  Future<void> _likePost(Post post) async {
    try {
      await SocialService.likePost(post.id);
      _loadUserPosts();
    } catch (e) {
      AppLogger.log("Error liking post: $e");
    }
  }

  // Favorite post
  Future<void> _favoritePost(Post post) async {
    try {
      await SocialService.addToFavorites(post.id);
      _loadUserPosts();
    } catch (e) {
      AppLogger.log("Error favoriting post: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _userDataLoaded && _userId.isNotEmpty
          ? UserProfileScreen(
              userId: _userId,
              initialName: _userFullName,
              initialProfileImage: _userProfileImage,
              sourceTabIndex: 3, // MyMapTab всегда на индексе 3
              initialPosts: _userPosts,
            )
          : Center(child: CircularProgressIndicator()),
    );
  }
} 