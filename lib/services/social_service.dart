import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite.dart';
import '../models/follow.dart';
import '../models/like.dart';
import '../models/post.dart';
import 'post_service.dart';
import 'user_service.dart';

/// Сервис для работы с социальными функциями приложения
class SocialService {
  // Ключи для SharedPreferences
  static const String _favoritesKey = 'user_favorites';
  static const String _likesKey = 'user_likes';
  static const String _followsKey = 'user_follows';

  // ИЗБРАННОЕ
  
  // Получение всех избранных постов
  static Future<List<Favorite>> getAllFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
    
    return favoritesJson
        .map((jsonString) => Favorite.fromJsonString(jsonString))
        .toList();
  }
  
  // Добавление поста в избранное
  static Future<void> addToFavorites(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getAllFavorites();
    final userId = await UserService.getEmail();
    
    // Проверяем, что пост еще не в избранном
    final isAlreadyFavorite = favorites.any(
      (favorite) => favorite.postId == postId && favorite.userId == userId
    );
    
    if (!isAlreadyFavorite) {
      final newFavorite = Favorite(
        userId: userId,
        postId: postId,
        createdAt: DateTime.now(),
      );
      
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
      favoritesJson.add(newFavorite.toJsonString());
      
      await prefs.setStringList(_favoritesKey, favoritesJson);
    }
  }
  
  // Удаление поста из избранного
  static Future<void> removeFromFavorites(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
    final userId = await UserService.getEmail();
    
    // Фильтруем список избранного
    final updatedFavoritesJson = favoritesJson.where((jsonString) {
      final favorite = Favorite.fromJsonString(jsonString);
      return !(favorite.postId == postId && favorite.userId == userId);
    }).toList();
    
    await prefs.setStringList(_favoritesKey, updatedFavoritesJson);
  }
  
  // Проверка, находится ли пост в избранном
  static Future<bool> isFavorite(String postId) async {
    final favorites = await getAllFavorites();
    final userId = await UserService.getEmail();
    
    return favorites.any(
      (favorite) => favorite.postId == postId && favorite.userId == userId
    );
  }
  
  // Получение избранных постов текущего пользователя
  static Future<List<Post>> getFavoritePosts() async {
    final favorites = await getAllFavorites();
    final userId = await UserService.getEmail();
    final userFavorites = favorites.where((favorite) => favorite.userId == userId).toList();
    
    // Получаем все посты
    final allPosts = await PostService.getAllPosts();
    
    // Фильтруем по ID из избранного
    final favoritePosts = allPosts.where(
      (post) => userFavorites.any((favorite) => favorite.postId == post.id)
    ).toList();
    
    return favoritePosts;
  }

  // ЛАЙКИ
  
  // Получение всех лайков
  static Future<List<Like>> getAllLikes() async {
    final prefs = await SharedPreferences.getInstance();
    final likesJson = prefs.getStringList(_likesKey) ?? [];
    
    return likesJson
        .map((jsonString) => Like.fromJsonString(jsonString))
        .toList();
  }
  
  // Добавление лайка к посту
  static Future<void> likePost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final likes = await getAllLikes();
    final userId = await UserService.getEmail();
    
    // Проверяем, что пост еще не лайкнут
    final isAlreadyLiked = likes.any(
      (like) => like.postId == postId && like.userId == userId
    );
    
    if (!isAlreadyLiked) {
      final newLike = Like(
        userId: userId,
        postId: postId,
        createdAt: DateTime.now(),
      );
      
      final likesJson = prefs.getStringList(_likesKey) ?? [];
      likesJson.add(newLike.toJsonString());
      
      await prefs.setStringList(_likesKey, likesJson);
    }
  }
  
  // Удаление лайка с поста
  static Future<void> unlikePost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final likesJson = prefs.getStringList(_likesKey) ?? [];
    final userId = await UserService.getEmail();
    
    // Фильтруем список лайков
    final updatedLikesJson = likesJson.where((jsonString) {
      final like = Like.fromJsonString(jsonString);
      return !(like.postId == postId && like.userId == userId);
    }).toList();
    
    await prefs.setStringList(_likesKey, updatedLikesJson);
  }
  
  // Проверка, лайкнут ли пост
  static Future<bool> isLiked(String postId) async {
    final likes = await getAllLikes();
    final userId = await UserService.getEmail();
    
    return likes.any(
      (like) => like.postId == postId && like.userId == userId
    );
  }
  
  // Получение количества лайков поста
  static Future<int> getPostLikesCount(String postId) async {
    final likes = await getAllLikes();
    return likes.where((like) => like.postId == postId).length;
  }

  // ПОДПИСКИ
  
  // Получение всех подписок
  static Future<List<Follow>> getAllFollows() async {
    final prefs = await SharedPreferences.getInstance();
    final followsJson = prefs.getStringList(_followsKey) ?? [];
    
    return followsJson
        .map((jsonString) => Follow.fromJsonString(jsonString))
        .toList();
  }
  
  // Подписка на пользователя
  static Future<void> followUser(String followedId) async {
    final prefs = await SharedPreferences.getInstance();
    final follows = await getAllFollows();
    final followerId = await UserService.getEmail();
    
    // Проверяем, что пользователь еще не подписан
    final isAlreadyFollowing = follows.any(
      (follow) => follow.followedId == followedId && follow.followerId == followerId
    );
    
    if (!isAlreadyFollowing && followerId != followedId) {
      final newFollow = Follow(
        followerId: followerId,
        followedId: followedId,
        createdAt: DateTime.now(),
      );
      
      final followsJson = prefs.getStringList(_followsKey) ?? [];
      followsJson.add(newFollow.toJsonString());
      
      await prefs.setStringList(_followsKey, followsJson);
    }
  }
  
  // Отписка от пользователя
  static Future<void> unfollowUser(String followedId) async {
    final prefs = await SharedPreferences.getInstance();
    final followsJson = prefs.getStringList(_followsKey) ?? [];
    final followerId = await UserService.getEmail();
    
    // Фильтруем список подписок
    final updatedFollowsJson = followsJson.where((jsonString) {
      final follow = Follow.fromJsonString(jsonString);
      return !(follow.followedId == followedId && follow.followerId == followerId);
    }).toList();
    
    await prefs.setStringList(_followsKey, updatedFollowsJson);
  }
  
  // Проверка, подписан ли текущий пользователь на определенного пользователя
  static Future<bool> isFollowing(String followedId) async {
    final follows = await getAllFollows();
    final followerId = await UserService.getEmail();
    
    return follows.any(
      (follow) => follow.followedId == followedId && follow.followerId == followerId
    );
  }
  
  // Получение списка ID пользователей, на которых подписан текущий пользователь
  static Future<List<String>> getFollowingIds() async {
    final follows = await getAllFollows();
    final followerId = await UserService.getEmail();
    
    return follows
        .where((follow) => follow.followerId == followerId)
        .map((follow) => follow.followedId)
        .toList();
  }
  
  // Получение постов от пользователей, на которых подписан текущий пользователь
  static Future<List<Post>> getFollowingPosts() async {
    final followingIds = await getFollowingIds();
    final allPosts = await PostService.getAllPosts();
    
    return allPosts.where((post) => 
      followingIds.contains(post.user)
    ).toList();
  }
} 