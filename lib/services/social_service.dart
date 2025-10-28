import 'dart:convert';
import 'dart:math';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/favorite.dart';
import '../models/commercial_favorite.dart';
import '../models/follow.dart';
import '../models/like.dart';
import '../models/post.dart';
import '../models/commercial_post.dart';
import 'post_service.dart';
import 'commercial_post_service.dart';
import 'user_service.dart';
import 'album_service.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';
import '../utils/logger.dart';
import '../models/location.dart';
/// Сервис для работы с социальными функциями приложения
class SocialService {
  static final SocialService _instance = SocialService._internal();
  final AuthService _authService = AuthService();
  
  factory SocialService() {
    return _instance;
  }
  
  SocialService._internal();

  // StreamController для уведомлений об изменениях избранного
  static final StreamController<void> _favoritesChangedController = StreamController<void>.broadcast();
  static Stream<void> get favoritesChanged => _favoritesChangedController.stream;

  // StreamController для уведомлений об изменениях коммерческого избранного
  static final StreamController<void> _commercialFavoritesChangedController = StreamController<void>.broadcast();
  static Stream<void> get commercialFavoritesChanged => _commercialFavoritesChangedController.stream;

  // Ключи для SharedPreferences
  static const String _favoritesKey = 'user_favorites';
  static const String _commercialFavoritesKey = 'user_commercial_favorites';
  static const String _likesKey = 'user_likes';
  static const String _followsKey = 'user_follows';
  static const String _commentsKey = 'photo_comments';

  // Кэширование результатов
  static List<Favorite>? _favoritesCache;
  static List<CommercialFavorite>? _commercialFavoritesCache;
  static List<Like>? _likesCache;
  static DateTime? _favoritesCacheTime;
  static DateTime? _commercialFavoritesCacheTime;
  static DateTime? _likesCacheTime;
  static const int _cacheDurationSeconds = 30; // Длительность кэша в секундах

  // ИЗБРАННОЕ
  
  // Получение всех избранных постов с кэшированием результата
  static Future<List<Favorite>> getAllFavorites() async {
    // Проверяем актуальность кэша
    final now = DateTime.now();
    if (_favoritesCache != null && _favoritesCacheTime != null) {
      final diff = now.difference(_favoritesCacheTime!);
      if (diff.inSeconds < _cacheDurationSeconds) {
        return _favoritesCache!;
      }
    }
    
    // Загружаем данные из SharedPreferences, если кэш устарел
    final prefs = await SharedPreferences.getInstance();
    final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
    
    final favorites = favoritesJson
        .map((jsonString) => Favorite.fromJsonString(jsonString))
        .toList();
    
    // Обновляем кэш
    _favoritesCache = favorites;
    _favoritesCacheTime = now;
    
    return favorites;
  }
  
  // Добавление поста в избранное
  static Future<void> addToFavorites(String postId) async {
    // Быстрое локальное обновление
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getAllFavorites();
    final userId = await UserService.getEmail();
    
    // Проверяем, что пост еще не в избранном
    final isAlreadyFavorite = favorites.any(
      (favorite) => favorite.postId == postId && favorite.userId == userId
    );
    
    // Если уже в избранном, ничего не делаем
    if (isAlreadyFavorite) {
      AppLogger.log('⭐ Пост $postId уже в избранном');
      return;
    }
    
    // Создаем новый объект избранного
    final newFavorite = Favorite(
      userId: userId,
      postId: postId,
      createdAt: DateTime.now(),
    );
    
    // Обновляем локальный список и кэш
    final updatedFavorites = List<Favorite>.from(favorites)..add(newFavorite);
    _favoritesCache = updatedFavorites;
    _favoritesCacheTime = DateTime.now();
    
    // Сохраняем в SharedPreferences
    final favoritesJson = updatedFavorites.map((f) => f.toJsonString()).toList();
    await prefs.setStringList(_favoritesKey, favoritesJson);
    
    // Уведомляем подписчиков об изменении избранного
    _favoritesChangedController.add(null);
    
    // Очищаем кэш для принудительного обновления
    clearFavoritesCache();
    
    AppLogger.log('⭐ Добавлен в избранное пост: $postId');
    
    // Асинхронно отправляем на сервер (не блокируя UI)
    Future.microtask(() async {
      try {
        final service = SocialService();
        
        // Сначала пробуем преобразовать в числовой ID
        final numericPhotoId = int.tryParse(postId);
        if (numericPhotoId != null) {
          await service.addPhotoToFavorites(numericPhotoId);
        } else {
          // Для UUID или других форматов ID используем строковый тип
          await service.addPhotoToFavoritesString(postId);
        }
      } catch (e) {
        AppLogger.log('❌ Ошибка при отправке добавления в избранное на сервер: $e');
      }
    });
  }
  
  // Получение всех избранных постов текущего пользователя
  static Future<List<Post>> getFavoritePosts() async {
    try {
      // Сначала пробуем получить данные с сервера
      final service = SocialService();
      final result = await service.getFavorites();
      
      if (result['success'] == true) {
        final List<Post> combinedServerFavorites = [];
        
        // Новый формат API: data.photos
        if (result['data'] != null && result['data'] is Map && result['data']['photos'] is List) {
          final List<dynamic> photos = result['data']['photos'];
          final serverFavoriteIds = photos
              .map((p) => p['id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
          
          // AppLogger.log('📦 Получено ${serverFavoriteIds.length} избранных постов с сервера (data.photos)');
          
          // Получаем все посты и фильтруем по ID из избранного
          final allPosts = await PostService.getAllPosts();
          final serverFavoritePosts = allPosts.where(
              (post) => serverFavoriteIds.contains(post.id)
          ).toList();
          
          if (serverFavoritePosts.isNotEmpty) {
            combinedServerFavorites.addAll(serverFavoritePosts);
            await _syncServerFavoritesToLocal(serverFavoriteIds);
          }
        }
        // Старый формат API: favorites: [{ photo_id: ... }]
        else if (result['favorites'] != null && result['favorites'] is List) {
          final serverFavoriteIds = (result['favorites'] as List)
              .map((fav) => fav['photo_id']?.toString() ?? '')
              .where((id) => id.isNotEmpty)
              .toList();
          
          // AppLogger.log('📦 Получено ${serverFavoriteIds.length} избранных постов с сервера (favorites)');
          
          final allPosts = await PostService.getAllPosts();
          final serverFavoritePosts = allPosts.where(
              (post) => serverFavoriteIds.contains(post.id)
          ).toList();
          
          if (serverFavoritePosts.isNotEmpty) {
            combinedServerFavorites.addAll(serverFavoritePosts);
            await _syncServerFavoritesToLocal(serverFavoriteIds);
          }
        }
        
        // Коммерческие избранные теперь обрабатываются отдельным методом
        
        if (combinedServerFavorites.isNotEmpty) {
          // Можно отсортировать по дате избранного, если потребуется, сейчас вернём как есть
          return combinedServerFavorites;
        }
      }
      
      // Если с сервера не получены данные, используем локальные
      // AppLogger.log('🔄 Используем локальное хранилище для избранных постов');
      return await _getFavoritePostsFromLocal();
    } catch (e) {
      AppLogger.log('❌ Ошибка при загрузке избранных постов: $e');
      // В случае ошибки используем локальные данные
      return await _getFavoritePostsFromLocal();
    }
  }
  
  // Получение избранных постов из локального хранилища
  static Future<List<Post>> _getFavoritePostsFromLocal() async {
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

  
  // Синхронизация избранных постов с сервера в локальное хранилище
  static Future<void> _syncServerFavoritesToLocal(List<String> serverFavoriteIds) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = await UserService.getEmail();
      
      // Очищаем старые избранные для этого пользователя
      final favorites = await getAllFavorites();
      final otherUsersFavorites = favorites.where((fav) => fav.userId != userId).toList();
      
      // Создаем новые записи из серверных данных
      List<Favorite> newFavorites = [];
      for (final postId in serverFavoriteIds) {
        newFavorites.add(Favorite(
          userId: userId,
          postId: postId,
          createdAt: DateTime.now(),
        ));
      }
      
      // Объединяем с избранным других пользователей
      final allFavorites = [...otherUsersFavorites, ...newFavorites];
      
      // Сохраняем обновленный список
      final favoritesJson = allFavorites.map((fav) => fav.toJsonString()).toList();
      await prefs.setStringList(_favoritesKey, favoritesJson);
      
      AppLogger.log('✅ Локальные избранные успешно синхронизированы с сервером');
    } catch (e) {
      AppLogger.log('❌ Ошибка при синхронизации избранных постов: $e');
    }
  }
  
  // Получение количества лайков поста c обновлением с сервера
  static Future<int> getPostLikesCount(String postId) async {
    try {
      // Пытаемся получить данные с сервера
      final numericPhotoId = int.tryParse(postId);
      
      // Выполняем запрос к серверу с имеющимся ID (числовой или строковый)
      final photoIdForRequest = numericPhotoId != null ? numericPhotoId.toString() : postId;
      
      // Проверяем авторизацию перед запросом
      final isAuthenticated = await UserService.isLoggedIn();
      if (!isAuthenticated) {
        AppLogger.log('⚠️ Пользователь не авторизован, используем локальные данные');
        final likes = await getAllLikes();
        return likes.where((like) => like.postId == postId).length;
      }
      
      // Получаем актуальные заголовки сессии (уже включают Accept: application/json)
      final headers = AuthService().sessionHeaders;
      
      // Получаем информацию о лайках с сервера через check_like.php
      final url = '${ApiConfig.baseUrl}/social/check_like.php?photo_id=$photoIdForRequest';
      
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      // Обработка ошибки авторизации
      if (response.statusCode == 401) {
        await UserService.checkAuth();
        
        // Обновляем заголовки сессии
        final retryHeaders = AuthService().sessionHeaders;
        
        final retryResponse = await http.get(
          Uri.parse(url),
          headers: retryHeaders,
        );
        
        if (retryResponse.statusCode == 200) {
          final data = jsonDecode(retryResponse.body);
          if (data['success'] == true) {
            final likesCount = data['likesCount'] as int? ?? 0;
            return likesCount;
          }
        }
        
        final likes = await getAllLikes();
        return likes.where((like) => like.postId == postId).length;
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final likesCount = data['likesCount'] as int? ?? 0;
          return likesCount;
        } else {
          AppLogger.log('❌ getPostLikesCount: Ответ с успехом=false: ${data['message'] ?? "Нет сообщения"}');
        }
      } else {
        AppLogger.log('❌ getPostLikesCount: Неудачный статус: ${response.statusCode}, тело: ${response.body}');
        
        // Если получили 404, это означает, что эндпоинт недоступен
        if (response.statusCode == 404) {
          AppLogger.log('⚠️ Эндпоинт check_like.php недоступен, используем локальные данные');
          final likes = await getAllLikes();
          return likes.where((like) => like.postId == postId).length;
        }
      }
      
      // Если не удалось получить с сервера, используем локальные данные
      final likes = await getAllLikes();
      return likes.where((like) => like.postId == postId).length;
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении количества лайков: $e');
      // В случае ошибки используем локальные данные
      final likes = await getAllLikes();
      return likes.where((like) => like.postId == postId).length;
    }
  }

  // ЛАЙКИ
  
  // Получение всех лайков с кэшированием результата
  static Future<List<Like>> getAllLikes() async {
    // Проверяем актуальность кэша
    final now = DateTime.now();
    if (_likesCache != null && _likesCacheTime != null) {
      final diff = now.difference(_likesCacheTime!);
      if (diff.inSeconds < _cacheDurationSeconds) {
        return _likesCache!;
      }
    }
    
    // Загружаем данные из SharedPreferences, если кэш устарел
    final prefs = await SharedPreferences.getInstance();
    final likesJson = prefs.getStringList(_likesKey) ?? [];
    
    final likes = likesJson
        .map((jsonString) => Like.fromJsonString(jsonString))
        .toList();
    
    // Обновляем кэш
    _likesCache = likes;
    _likesCacheTime = now;
    
    return likes;
  }
  
  // Лайк поста
  static Future<void> likePost(String postId) async {
    // Быстрое локальное обновление
    final prefs = await SharedPreferences.getInstance();
    final likes = await getAllLikes();
    final userId = await UserService.getEmail();
    
    // Проверяем, лайкнут ли пост
    final isAlreadyLiked = likes.any(
      (like) => like.postId == postId && like.userId == userId
    );
    
    List<Like> updatedLikes;
    
    if (isAlreadyLiked) {
      // Убираем лайк локально
      updatedLikes = likes.where(
        (like) => !(like.postId == postId && like.userId == userId)
      ).toList();
    } else {
      // Добавляем лайк локально
      final newLike = Like(
        userId: userId,
        postId: postId,
        createdAt: DateTime.now(),
      );
      updatedLikes = List<Like>.from(likes)..add(newLike);
    }
    
    // Обновляем кэш сразу, без ожидания SharedPreferences
    _likesCache = updatedLikes;
    _likesCacheTime = DateTime.now();
    
    // Сохраняем обновлённое состояние локально (немедленно)
    final likesJson = updatedLikes.map((like) => like.toJsonString()).toList();
    await prefs.setStringList(_likesKey, likesJson);
    
    // Асинхронно отправляем на сервер (не блокируя UI)
    Future.microtask(() async {
      try {
        final service = SocialService();
        
        // Пробуем преобразовать в числовой ID
        final numericPhotoId = int.tryParse(postId);
        if (numericPhotoId != null) {
          if (isAlreadyLiked) {
            // Убираем лайк на сервере
            await service.unlikePhoto(numericPhotoId);
          } else {
            // Ставим лайк на сервере
            await service.likePhoto(numericPhotoId);
          }
        } else {
          // Используем строковый ID
          if (isAlreadyLiked) {
            // Метод для удаления лайка со строковым ID
            await service.unlikePhotoString(postId);
          } else {
            // Метод для лайка со строковым ID
            await service.likePhotoString(postId);
          }
        }
      } catch (e) {
        AppLogger.log('❌ Ошибка при синхронизации лайка с сервером: $e');
      }
    });
  }
  
  // Создаем метод для удаления лайка со строковым ID
  Future<Map<String, dynamic>> unlikePhotoString(String photoId) async {
    try {
      // Отправляем запрос на удаление лайка
      final url = '${ApiConfig.baseUrl}/social/unlike.php';
      
      final response = await http.post(
        Uri.parse(url),
        headers: _authService.sessionHeaders,
        body: {
          'photo_id': photoId,
        },
      );
      
      if (response.statusCode == 401) {
        // Проверяем авторизацию и пробуем еще раз
        await UserService.checkAuth();
        final repeatResponse = await http.post(
          Uri.parse(url),
          headers: _authService.sessionHeaders,
          body: {
            'photo_id': photoId,
          },
        );
        
        if (_isValidJson(repeatResponse.body)) {
          final data = jsonDecode(repeatResponse.body);
          return data;
        } else {
          return {'success': false, 'error': 'Invalid response format'};
        }
      }
      
      if (_isValidJson(response.body)) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        return {'success': false, 'error': 'Invalid response format'};
      }
    } catch (e) {
      return {'success': false, 'error': e.toString()};
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
    
    // Отправка на сервер
    try {
      final service = SocialService();
      // Конвертируем строковый ID в числовой для серверного API
      final numericPhotoId = int.tryParse(postId);
      if (numericPhotoId != null) {
        await service.unlikePhoto(numericPhotoId);
        AppLogger.log('✅ Удаление лайка успешно отправлено на сервер для поста $postId');
      } else {
        AppLogger.log('⚠️ Не удалось преобразовать ID поста в число: $postId');
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при отправке удаления лайка на сервер: $e');
    }
  }
  
  // Проверка, лайкнут ли пост (быстрая, без сервера)
  static Future<bool> isLiked(String postId) async {
    final likes = await getAllLikes();
    final userId = await UserService.getEmail();
    
    return likes.any(
      (like) => like.postId == postId && like.userId == userId
    );
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
    
    // Проверяем, что пользователь не подписывается на самого себя
    if (followerId == followedId) {
      AppLogger.log("Попытка подписаться на самого себя: $followerId. Операция отменена.");
      return;
    }
    
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
      
      // Новое: сразу синхронизируем с сервером
      _syncFollowToServer(followedId, true);
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
    
    // Новое: сразу синхронизируем с сервером
    _syncFollowToServer(followedId, false);
  }
  
  // Проверка, подписан ли текущий пользователь на указанного пользователя
  static Future<bool> isFollowing(String followedId) async {
    try {
      final follows = await getAllFollows();
      final followerNumericId = await UserService.getUserId();
      final followerEmail = await UserService.getEmail();
      
      // AppLogger.log('⚙️ isFollowing check: follower(email)=$followerEmail, follower(id)=$followerNumericId, followed=$followedId');
      
      final result = follows.any(
        (follow) => follow.followedId == followedId && (follow.followerId == followerNumericId || follow.followerId == followerEmail)
      );

      // AppLogger.log('⚙️ isFollowing result: $result');
      return result;
    } catch (e) {
      AppLogger.log('❌ Error checking follow status: $e');
      return false;
    }
  }
  
  // Получение списка ID пользователей, на которых подписан текущий пользователь
  static Future<List<String>> getFollowingIds() async {
    try {
      final follows = await getAllFollows();
      final followerId = await UserService.getEmail();
      final userIdNumeric = await UserService.getUserId();
      
      // Собираем ID пользователей, на которых подписан текущий пользователь
      List<String> followingIds = follows
          .where((follow) => follow.followerId == followerId || follow.followerId == userIdNumeric)
          .map((follow) => follow.followedId)
          .toList();
      
      // AppLogger.log('⚙️ getFollowingIds: найдено ${followingIds.length} подписок для пользователя $followerId / $userIdNumeric');
      
      return followingIds;
    } catch (e) {
      AppLogger.log('❌ Error getting following IDs: $e');
      return [];
    }
  }
  
  // Получение постов от пользователей, на которых подписан текущий пользователь
  static Future<List<Post>> getFollowingPosts() async {
    try {
      final followingIds = await getFollowingIds();
      final allPosts = await PostService.getAllPosts();
      
      if (followingIds.isEmpty) {
        AppLogger.log('⚠️ No following users found, returning empty posts list');
        return [];
      }
      
      // Дополнительное логирование для отладки
      AppLogger.log('⚙️ getFollowingPosts: Ищем посты от ${followingIds.length} подписок среди ${allPosts.length} постов');
      
      // Пытаемся получить текущий ID пользователя разными способами
      final currentEmail = await UserService.getEmail();
      final currentUserId = await UserService.getUserId();
      
      AppLogger.log('⚙️ getFollowingPosts: Текущий пользователь - Email: $currentEmail, ID: $currentUserId');
      
      // Фильтруем посты от подписок, проверяя разные варианты ID
      List<Post> followingPosts = [];
      for (var post in allPosts) {
        // Пропускаем свои посты
        if (post.user == currentEmail || post.user == currentUserId) {
          AppLogger.log('⏩ Пропускаем собственный пост от $currentEmail / $currentUserId');
          continue;
        }
        
        if (followingIds.contains(post.user)) {
          followingPosts.add(post);
          AppLogger.log('✅ Найден пост от пользователя ${post.user}');
        } else {
          // Дополнительные проверки для разных форматов ID
          // Пытаемся сравнить числовые ID
          try {
            final postUserId = int.tryParse(post.user);
            for (var followedId in followingIds) {
              final followedNumId = int.tryParse(followedId);
              if (postUserId != null && followedNumId != null && postUserId == followedNumId) {
                followingPosts.add(post);
                AppLogger.log('✅ Найден пост от пользователя ${post.user} (числовое совпадение)');
                break;
              }
            }
          } catch (e) {
            // Если ошибка конвертации, продолжаем
            AppLogger.log('⚠️ Ошибка при попытке конвертации ID: $e');
          }
        }
      }
      
      AppLogger.log('⚙️ getFollowingPosts: найдено ${followingPosts.length} постов от подписок');
      
      // Сортируем по дате создания, сначала новые
      followingPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return followingPosts;
    } catch (e) {
      AppLogger.log('❌ Error getting following posts: $e');
      return [];
    }
  }

  // Получение постов от пользователей, на которых подписан текущий пользователь
  Future<Map<String, dynamic>> getFollowingPostsFromServer({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.getFollowingPosts}?page=$page&per_page=$perPage'),
        headers: _authService.sessionHeaders,
      );

      if (response.statusCode == 401) {
        await UserService.checkAuth();
        
        final retryResponse = await http.get(
          Uri.parse('${ApiConfig.getFollowingPosts}?page=$page&per_page=$perPage'),
          headers: _authService.sessionHeaders,
        );
        
        if (retryResponse.statusCode == 200) {
          return jsonDecode(retryResponse.body);
        }
        
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при получении постов: $e',
      };
    }
  }

  // Получить список подписчиков или подписок
  Future<Map<String, dynamic>> getFollows({
    required String type, // 'followers' или 'following'
    int? userId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      String url = '${ApiConfig.getFollows}?type=$type&page=$page&per_page=$perPage';
      if (userId != null) {
        url += '&user_id=$userId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _authService.sessionHeaders,
      );

      if (response.statusCode == 401) {
        await UserService.checkAuth();
        
        final retryResponse = await http.get(
          Uri.parse(url),
          headers: _authService.sessionHeaders,
        );
        
        if (retryResponse.statusCode == 200) {
          return jsonDecode(retryResponse.body);
        }
        
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при получении списка: $e',
      };
    }
  }

  // Получить избранные фотографии
  Future<Map<String, dynamic>> getFavorites({
    int? userId,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      String url = '${ApiConfig.getFavorites}?page=$page&per_page=$perPage';
      if (userId != null) {
        url += '&user_id=$userId';
      }

      final response = await http.get(
        Uri.parse(url),
        headers: _authService.sessionHeaders,
      );

      if (response.statusCode == 401) {
        await UserService.checkAuth();
        
        final retryResponse = await http.get(
          Uri.parse(url),
          headers: _authService.sessionHeaders,
        );
        
        if (retryResponse.statusCode == 200) {
          return jsonDecode(retryResponse.body);
        }
        
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при получении избранных фотографий: $e',
      };
    }
  }

  // Лайкнуть фотографию
  Future<Map<String, dynamic>> likePhoto(int photoId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.like),
        headers: _authService.sessionHeaders,
        body: jsonEncode({'photo_id': photoId}),
      );

      if (response.statusCode == 401) {
        await UserService.checkAuth();
        
        final retryResponse = await http.post(
          Uri.parse(ApiConfig.like),
          headers: _authService.sessionHeaders,
          body: jsonEncode({'photo_id': photoId}),
        );
        
        if (retryResponse.statusCode == 200) {
          final data = jsonDecode(retryResponse.body);
          return data;
        }
        
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      if (_isValidJson(response.body)) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        AppLogger.log('❌ likePhoto: Ответ не является валидным JSON');
        return {
          'success': false,
          'error': 'Невалидный формат ответа от сервера',
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при добавлении лайка: $e');
      return {
        'success': false,
        'error': 'Ошибка при добавлении лайка: $e',
      };
    }
  }

  // Удалить лайк с фотографии
  Future<Map<String, dynamic>> unlikePhoto(int photoId) async {
    try {
      final request = http.Request('DELETE', Uri.parse(ApiConfig.like));
      request.headers.addAll(_authService.sessionHeaders);
      request.body = jsonEncode({'photo_id': photoId});

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        await UserService.checkAuth();
        
        final retryRequest = http.Request('DELETE', Uri.parse(ApiConfig.like));
        retryRequest.headers.addAll(_authService.sessionHeaders);
        retryRequest.body = jsonEncode({'photo_id': photoId});
        
        final retryStreamedResponse = await retryRequest.send();
        final retryResponse = await http.Response.fromStream(retryStreamedResponse);
        
        if (retryResponse.statusCode == 200) {
          return jsonDecode(retryResponse.body);
        }
        
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при удалении лайка: $e',
      };
    }
  }

  // Получить комментарии к фотографии
  Future<Map<String, dynamic>> getComments(String photoId, {int page = 1, int perPage = 20}) async {
    try {
      // Проверяем валидность ID фотографии
      if (photoId == null || photoId.isEmpty || photoId == 'undefined' || photoId == 'null') {
        AppLogger.log('❌ Некорректный ID фотографии: $photoId');
        return {
          'success': false,
          'error': 'Некорректный идентификатор фотографии',
          'comments': [],
          'pagination': {
            'total': 0,
            'perPage': perPage,
            'currentPage': page,
            'lastPage': 1
          },
        };
      }
      
      // Получаем статус авторизации и куки
      final isLoggedIn = await UserService.isLoggedIn();
      
      // Если пользователь не авторизован, возвращаем локальные комментарии
      if (!isLoggedIn) {
        AppLogger.log('⚠️ Пользователь не авторизован, используем локальные комментарии');
        final List<Map<String, dynamic>> localComments = await _getLocalComments(photoId);
        final int startIndex = (page - 1) * perPage;
        final int totalComments = localComments.length;
        
        return {
          'success': true,
          'comments': localComments.isEmpty ? [] : localComments
              .skip(startIndex)
              .take(perPage)
              .toList(),
          'pagination': {
            'total': totalComments,
            'perPage': perPage,
            'currentPage': page,
            'lastPage': (totalComments / perPage).ceil(),
          },
        };
      }
      
      // Добавляем заголовки для корректной работы с сессией
      final headers = Map<String, String>.from(_authService.sessionHeaders);
      headers['Accept'] = 'application/json'; // Явно запрашиваем JSON
      
      // Формируем URL-запрос к API
      final url = ApiConfig.getCommentsUrl(photoId, page, perPage);
      
      // Отправляем запрос на сервер
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      // В случае ошибки сервера, возвращаем локально сохраненные комментарии
      if (response.statusCode != 200) {
        AppLogger.log('⚠️ Сервер вернул ошибку ${response.statusCode}, используем локальные комментарии');
        
        // Если получили 404, это означает, что эндпоинт недоступен
        if (response.statusCode == 404) {
          AppLogger.log('⚠️ Эндпоинт get_comments.php недоступен, используем локальные комментарии');
        }
        
        final List<Map<String, dynamic>> localComments = await _getLocalComments(photoId);
        final int startIndex = (page - 1) * perPage;
        final int totalComments = localComments.length;
        
        return {
          'success': true,
          'comments': localComments.isEmpty ? [] : localComments
              .skip(startIndex)
              .take(perPage)
              .toList(),
          'pagination': {
            'total': totalComments,
            'perPage': perPage,
            'currentPage': page,
            'lastPage': (totalComments / perPage).ceil(),
          },
        };
      }

      // Обрабатываем успешный ответ сервера
      if (_isValidJson(response.body)) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        if (data['success'] == true && data['comments'] is List) {
          // Если в ответе есть photoOwnerId, добавляем его в каждый комментарий
          if (data.containsKey('photoOwnerId')) {
            final photoOwnerId = data['photoOwnerId'];
            final List<dynamic> comments = data['comments'];
            for (var i = 0; i < comments.length; i++) {
              if (comments[i] is Map<String, dynamic>) {
                comments[i]['photoOwnerId'] = photoOwnerId;
              }
            }
          }
          
          return data;
        } else {
          AppLogger.log('⚠️ Некорректный формат данных в ответе от сервера');
          return {
            'success': false,
            'error': data['message'] ?? 'Некорректный формат данных от сервера',
            'comments': [],
            'pagination': {
              'total': 0,
              'perPage': perPage,
              'currentPage': page,
              'lastPage': 1
            },
          };
        }
      } else {
        AppLogger.log('❌ Ответ не является валидным JSON');
        return {
          'success': false,
          'error': 'Невалидный формат ответа от сервера',
          'comments': [],
          'pagination': {
            'total': 0,
            'perPage': perPage,
            'currentPage': page,
            'lastPage': 1
          },
        };
      }
    } catch (e) {
      AppLogger.log('❌ Сетевая ошибка при получении комментариев: $e');
      return {
        'success': false,
        'error': 'Ошибка при получении комментариев: $e',
        'comments': [],
        'pagination': {
          'total': 0,
          'perPage': perPage,
          'currentPage': page,
          'lastPage': 1
        },
      };
    }
  }

  // Получение локально сохраненных комментариев
  Future<List<Map<String, dynamic>>> _getLocalComments(String photoId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? commentsJson = prefs.getString('$_commentsKey:$photoId');
      
      if (commentsJson != null && commentsJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(commentsJson);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении локальных комментариев: $e');
    }
    
    return [];
  }

  // Проверка, является ли строка валидным JSON
  bool _isValidJson(String jsonString) {
    try {
      jsonDecode(jsonString);
      return true;
    } catch (e) {
      return false;
    }
  }

  // Сохранение комментария локально
  Future<void> _saveLocalComment(String photoId, Map<String, dynamic> comment) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> currentComments = await _getLocalComments(photoId);
      
      // Добавляем новый комментарий в начало списка
      currentComments.insert(0, comment);
      
      // Сохраняем обновленный список
      await prefs.setString('$_commentsKey:$photoId', jsonEncode(currentComments));
    } catch (e) {
      AppLogger.log('❌ Ошибка при сохранении локального комментария: $e');
    }
  }

  // Добавить комментарий к фотографии
  Future<Map<String, dynamic>> addComment(String photoId, String comment) async {
    try {
      // Проверяем валидность ID фотографии
      if (photoId == null || photoId.isEmpty || photoId == 'undefined' || photoId == 'null') {
        AppLogger.log('❌ Некорректный ID фотографии: $photoId');
        return {
          'success': false,
          'error': 'Некорректный идентификатор фотографии',
        };
      }
      
      // Получаем статус авторизации и куки
      final isLoggedIn = await UserService.checkAuth();
      
      // Добавляем заголовки для корректной работы с сессией
      final headers = Map<String, String>.from(_authService.sessionHeaders);
      headers['Accept'] = 'application/json'; // Явно запрашиваем JSON
      headers['Content-Type'] = 'application/json; charset=UTF-8'; // Указываем тип отправляемого контента
      
      // Формируем URL для запроса
      final url = ApiConfig.comment;
      
      // Отправляем запрос на сервер
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: jsonEncode({
          'photo_id': photoId,
          'comment': comment,
        }),
      );
      
      // В случае ошибки сервера, создаем комментарий локально
      if (response.statusCode != 200) {
        AppLogger.log('⚠️ Сервер вернул ошибку, создаем комментарий локально');
        
        // Получаем данные текущего пользователя
        final userData = await UserService.getCurrentUserData();
        
        // Создаем комментарий с данными из профиля пользователя
        final commentId = DateTime.now().millisecondsSinceEpoch;
        
        final Map<String, dynamic> newComment = {
          'id': commentId,
          'userId': userData['id'] ?? 1,
          'photoId': photoId,
          'text': comment,
          'createdAt': DateTime.now().toIso8601String(),
          'userFirstName': userData['firstName'] ?? 'Пользователь',
          'userLastName': userData['lastName'] ?? '',
          'userProfileImageUrl': userData['profileImageUrl'] ?? ''
        };
        
        // Сохраняем комментарий локально
        await _saveLocalComment(photoId, newComment);
        
        return {
          'success': true,
          'message': 'Комментарий успешно добавлен (локально)',
          'comment': newComment
        };
      }
      
      // Обрабатываем успешный ответ сервера
      if (_isValidJson(response.body)) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          // Сохраняем комментарий локально для резервного копирования
          if (data['comment'] != null) {
            await _saveLocalComment(photoId, Map<String, dynamic>.from(data['comment']));
          }
          
          return data;
        } else {
          AppLogger.log('⚠️ Ошибка при добавлении комментария: ${data['message'] ?? 'Неизвестная ошибка'}');
          return {
            'success': false,
            'error': data['message'] ?? 'Не удалось добавить комментарий',
          };
        }
      } else {
        AppLogger.log('❌ Ответ не является валидным JSON');
        return {
          'success': false,
          'error': 'Невалидный формат ответа от сервера',
        };
      }
    } catch (e) {
      AppLogger.log('❌ Сетевая ошибка при добавлении комментария: $e');
      return {
        'success': false,
        'error': 'Ошибка при добавлении комментария: $e',
      };
    }
  }

  // Удалить комментарий
  Future<Map<String, dynamic>> deleteComment(int commentId) async {
    try {
      AppLogger.log('🗑️ Пытаемся удалить комментарий с ID: $commentId');
      
      // Получаем статус авторизации и куки
      final isLoggedIn = await UserService.checkAuth();
      AppLogger.log('👤 Статус авторизации: $isLoggedIn');
      
      // Добавляем заголовки для корректной работы с сессией
      final headers = Map<String, String>.from(_authService.sessionHeaders);
      headers['Accept'] = 'application/json';
      headers['Content-Type'] = 'application/json; charset=UTF-8';
      
      // Формируем URL для запроса
      final url = ApiConfig.deleteComment;
      AppLogger.log('🔗 URL для удаления: $url');
      
      // Отправляем запрос на сервер методом POST с параметром _method=DELETE
      final requestBody = jsonEncode({
        'comment_id': commentId,
        '_method': 'DELETE'
      });
      
      AppLogger.log('📤 Отправка запроса с данными: $requestBody');
      AppLogger.log('📤 Заголовки запроса: $headers');
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: requestBody,
      );
      
      AppLogger.log('📥 Получен ответ, статус код: ${response.statusCode}');
      AppLogger.log('📥 Тело ответа: ${response.body}');
      
      if (response.statusCode != 200) {
        AppLogger.log('⚠️ Сервер вернул ошибку при удалении комментария: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Ошибка при удалении комментария (${response.statusCode})',
        };
      }
      
      // Обрабатываем успешный ответ сервера
      if (_isValidJson(response.body)) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        if (data['success'] == true) {
          AppLogger.log('✅ Комментарий успешно удален');
          return data;
        } else {
          AppLogger.log('⚠️ Ошибка при удалении комментария: ${data['message'] ?? 'Неизвестная ошибка'}');
          return {
            'success': false,
            'error': data['message'] ?? 'Не удалось удалить комментарий',
          };
        }
      } else {
        AppLogger.log('❌ Ответ не является валидным JSON: ${response.body}');
        return {
          'success': false,
          'error': 'Невалидный формат ответа от сервера',
        };
      }
    } catch (e) {
      AppLogger.log('❌ Сетевая ошибка при удалении комментария: $e');
      return {
        'success': false,
        'error': 'Ошибка при удалении комментария: $e',
      };
    }
  }

  // Добавить фотографию в избранное
  Future<Map<String, dynamic>> addPhotoToFavorites(int photoId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.favorite),
        headers: _authService.sessionHeaders,
        body: jsonEncode({'photo_id': photoId}),
      );

      if (response.statusCode == 401) {
        await UserService.checkAuth();
        
        final retryResponse = await http.post(
          Uri.parse(ApiConfig.favorite),
          headers: _authService.sessionHeaders,
          body: jsonEncode({'photo_id': photoId}),
        );
        
        if (retryResponse.statusCode == 200) {
          final data = jsonDecode(retryResponse.body);
          return data;
        }
        
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      if (_isValidJson(response.body)) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        AppLogger.log('❌ Ответ не является валидным JSON');
        return {
          'success': false,
          'error': 'Невалидный формат ответа от сервера',
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при добавлении в избранное: $e');
      return {
        'success': false,
        'error': 'Ошибка при добавлении в избранное: $e',
      };
    }
  }

  // Удалить фотографию из избранного
  Future<Map<String, dynamic>> removePhotoFromFavorites(int photoId) async {
    try {
      final request = http.Request('DELETE', Uri.parse(ApiConfig.favorite));
      request.headers.addAll(_authService.sessionHeaders);
      request.body = jsonEncode({'photo_id': photoId});

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        await UserService.checkAuth();
        
        final retryRequest = http.Request('DELETE', Uri.parse(ApiConfig.favorite));
        retryRequest.headers.addAll(_authService.sessionHeaders);
        retryRequest.body = jsonEncode({'photo_id': photoId});
        
        final retryStreamedResponse = await retryRequest.send();
        final retryResponse = await http.Response.fromStream(retryStreamedResponse);
        
        if (retryResponse.statusCode == 200) {
          return jsonDecode(retryResponse.body);
        }
        
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при удалении из избранного: $e',
      };
    }
  }

  // Подписаться на пользователя
  static Future<void> toggleFollow(String followedId) async {
    try {
      // Проверяем, подписан ли уже на пользователя
      bool isUserFollowing = await isFollowing(followedId);
      
      if (isUserFollowing) {
        // Если уже подписан, отписываемся
        await _removeFollow(followedId);
      } else {
        // Если не подписан, подписываемся
        await _addFollow(followedId);
      }
    } catch (e) {
      AppLogger.log('❌ Error toggling follow status: $e');
      throw e;
    }
  }
  
  // Добавление подписки на пользователя
  static Future<void> _addFollow(String followedId) async {
    try {
      final follows = await getAllFollows();
      final followerId = await UserService.getUserId();
      
      // Проверяем, существует ли уже такая подписка
      final isAlreadyFollowing = follows.any(
        (follow) => follow.followedId == followedId && follow.followerId == followerId
      );
      
      if (!isAlreadyFollowing) {
        AppLogger.log('⚙️ _addFollow: создаем новую подписку: follower=$followerId, followed=$followedId');
        
        // Создаем новую подписку
        final newFollow = Follow(
          followerId: followerId,
          followedId: followedId,
          createdAt: DateTime.now(),
        );
        
        // Добавляем в локальный список
        final updatedFollows = List<Follow>.from(follows)..add(newFollow);
        
        // Сохраняем в SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        final followsJson = updatedFollows.map((f) => f.toJsonString()).toList();
        await prefs.setStringList(_followsKey, followsJson);
        
        // Асинхронная отправка на сервер (если есть API)
        _syncFollowToServer(followedId, true);
      } else {
        AppLogger.log('⚠️ _addFollow: подписка уже существует: follower=$followerId, followed=$followedId');
      }
    } catch (e) {
      AppLogger.log('❌ Error adding follow: $e');
      throw e;
    }
  }
  
  // Удаление подписки на пользователя
  static Future<void> _removeFollow(String followedId) async {
    try {
      final follows = await getAllFollows();
      final followerId = await UserService.getUserId();
      
      AppLogger.log('⚙️ _removeFollow: удаляем подписку: follower=$followerId, followed=$followedId');
      
      // Фильтруем список подписок
      final updatedFollows = follows.where(
        (follow) => !(follow.followedId == followedId && follow.followerId == followerId)
      ).toList();
      
      // Сохраняем в SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final followsJson = updatedFollows.map((f) => f.toJsonString()).toList();
      await prefs.setStringList(_followsKey, followsJson);
      
      // Асинхронная отправка на сервер (если есть API)
      _syncFollowToServer(followedId, false);
    } catch (e) {
      AppLogger.log('❌ Error removing follow: $e');
      throw e;
    }
  }
  
  // Синхронизация действия подписки/отписки с сервером
  static Future<void> _syncFollowToServer(String followedId, bool isFollow) async {
    try {
      final instance = SocialService();
      final headers = AuthService().sessionHeaders;
      final followerId = await UserService.getUserId();
      final followerEmail = await UserService.getEmail();
      
      // Правильный URL: один и тот же follow.php для обоих действий
      final url = ApiConfig.follow;
      
      // Также отправляем больше данных для дебага
      AppLogger.log('🔄 ${isFollow ? 'Подписка' : 'Отписка'} - follower: $followerId, followed: $followedId');
      
      // Подготавливаем JSON-данные для запроса
      final Map<String, dynamic> requestBody = {
        'follow_id': followedId,
      };
      final jsonBody = jsonEncode(requestBody);
      
      // Добавляем Content-Type для указания, что отправляем JSON
      final Map<String, String> requestHeaders = Map.from(headers);
      requestHeaders['Content-Type'] = 'application/json';
      
      http.Response response;
      if (isFollow) {
        response = await http.post(
          Uri.parse(url),
          headers: requestHeaders,
          body: jsonBody,
        );
      } else {
        final request = http.Request('DELETE', Uri.parse(url));
        request.headers.addAll(requestHeaders);
        request.body = jsonBody;
        final streamedResponse = await request.send();
        response = await http.Response.fromStream(streamedResponse);
      }
      
      if (response.statusCode == 200) {
        AppLogger.log('✅ ${isFollow ? 'Подписка' : 'Отписка'} успешно синхронизирована с сервером');
        try {
          final data = jsonDecode(response.body);
          AppLogger.log('📊 Ответ сервера: ${data.toString()}');
          
          // Обновляем локальное хранилище после успешного ответа сервера
          if (data['success'] == true) {
            _updateLocalFollowsAfterServerSync(followerId, followedId, isFollow);
          }
        } catch (e) {
          AppLogger.log('⚠️ Не удалось прочитать ответ сервера: $e');
        }
      } else {
        AppLogger.log('❌ Ошибка при синхронизации ${isFollow ? 'подписки' : 'отписки'}: ${response.statusCode}, ${response.body}');
        
        // Повторная попытка с обновленным токеном
        await UserService.checkAuth();
        
        http.Response retryResponse;
        if (isFollow) {
          retryResponse = await http.post(
            Uri.parse(url),
            headers: requestHeaders,
            body: jsonBody,
          );
        } else {
          final retryRequest = http.Request('DELETE', Uri.parse(url));
          retryRequest.headers.addAll(requestHeaders);
          retryRequest.body = jsonBody;
          final retryStreamedResponse = await retryRequest.send();
          retryResponse = await http.Response.fromStream(retryStreamedResponse);
        }
        
        if (retryResponse.statusCode == 200) {
          AppLogger.log('✅ ${isFollow ? 'Подписка' : 'Отписка'} успешно синхронизирована с сервером (повторная попытка)');
          try {
            final data = jsonDecode(retryResponse.body);
            AppLogger.log('📊 Ответ сервера (повторная попытка): ${data.toString()}');
            if (data['success'] == true) {
              _updateLocalFollowsAfterServerSync(followerId, followedId, isFollow);
            }
          } catch (e) {
            AppLogger.log('⚠️ Не удалось прочитать ответ сервера: $e');
          }
        } else {
          AppLogger.log('❌ Повторная ошибка при синхронизации: ${retryResponse.statusCode}, ${retryResponse.body}');
        }
      }
    } catch (e) {
      AppLogger.log('❌ Исключение при синхронизации подписки: $e');
      // Не выбрасываем исключение, т.к. локальные изменения уже сохранены
    }
  }
  
  // Метод для обновления локального хранилища после успешной синхронизации с сервером
  static Future<void> _updateLocalFollowsAfterServerSync(String followerId, String followedId, bool isFollow) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final followsJson = prefs.getStringList(_followsKey) ?? [];
      
      if (isFollow) {
        // Проверяем, существует ли уже такая подписка локально
        final isAlreadyFollowing = followsJson.any((jsonString) {
          final follow = Follow.fromJsonString(jsonString);
          return follow.followerId == followerId && follow.followedId == followedId;
        });
        
        if (!isAlreadyFollowing) {
          // Создаем новую запись о подписке
          final newFollow = Follow(
            followerId: followerId, 
            followedId: followedId,
            createdAt: DateTime.now(),
          );
          
          // Добавляем в локальный список
          followsJson.add(newFollow.toJsonString());
          await prefs.setStringList(_followsKey, followsJson);
          AppLogger.log('✅ Локальные подписки обновлены после синхронизации с сервером');
        }
      } else {
        // Удаляем подписку из локального хранилища
        final updatedFollowsJson = followsJson.where((jsonString) {
          final follow = Follow.fromJsonString(jsonString);
          return !(follow.followerId == followerId && follow.followedId == followedId);
        }).toList();
        
        if (updatedFollowsJson.length != followsJson.length) {
          await prefs.setStringList(_followsKey, updatedFollowsJson);
          AppLogger.log('✅ Локальные подписки обновлены после синхронизации с сервером (удаление)');
        }
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при обновлении локальных подписок: $e');
    }
  }

  // Подписаться на пользователя
  Future<Map<String, dynamic>> followUserById(int followId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.follow),
        headers: _authService.sessionHeaders,
        body: jsonEncode({'follow_id': followId}),
      );

      if (response.statusCode == 401) {
        await UserService.checkAuth();
        
        final retryResponse = await http.post(
          Uri.parse(ApiConfig.follow),
          headers: _authService.sessionHeaders,
          body: jsonEncode({'follow_id': followId}),
        );
        
        if (retryResponse.statusCode == 200) {
          return jsonDecode(retryResponse.body);
        }
        
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при подписке на пользователя: $e',
      };
    }
  }

  // Отписаться от пользователя
  Future<Map<String, dynamic>> unfollowUserById(int followId) async {
    try {
      final request = http.Request('DELETE', Uri.parse(ApiConfig.follow));
      request.headers.addAll(_authService.sessionHeaders);
      request.body = jsonEncode({'follow_id': followId});

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        await UserService.checkAuth();
        
        final retryRequest = http.Request('DELETE', Uri.parse(ApiConfig.follow));
        retryRequest.headers.addAll(_authService.sessionHeaders);
        retryRequest.body = jsonEncode({'follow_id': followId});
        
        final retryStreamedResponse = await retryRequest.send();
        final retryResponse = await http.Response.fromStream(retryStreamedResponse);
        
        if (retryResponse.statusCode == 200) {
          return jsonDecode(retryResponse.body);
        }
        
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при отписке от пользователя: $e',
      };
    }
  }

  // Добавить фотографию в избранное (строковый ID)
  Future<Map<String, dynamic>> addPhotoToFavoritesString(String photoId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.favorite),
        headers: _authService.sessionHeaders,
        body: jsonEncode({'photo_id': photoId}),
      );

      if (response.statusCode == 401) {
        await UserService.checkAuth();
        
        final retryResponse = await http.post(
          Uri.parse(ApiConfig.favorite),
          headers: _authService.sessionHeaders,
          body: jsonEncode({'photo_id': photoId}),
        );
        
        if (retryResponse.statusCode == 200) {
          final data = jsonDecode(retryResponse.body);
          return data;
        }
        
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      if (_isValidJson(response.body)) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        AppLogger.log('❌ Ответ не является валидным JSON');
        return {
          'success': false,
          'error': 'Невалидный формат ответа от сервера',
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при добавлении в избранное: $e');
      return {
        'success': false,
        'error': 'Ошибка при добавлении в избранное: $e',
      };
    }
  }

  // Лайкнуть фотографию (строковый ID)
  Future<Map<String, dynamic>> likePhotoString(String photoId) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.like),
        headers: _authService.sessionHeaders,
        body: jsonEncode({'photo_id': photoId}),
      );

      if (response.statusCode == 401) {
        await UserService.checkAuth();
        
        final retryResponse = await http.post(
          Uri.parse(ApiConfig.like),
          headers: _authService.sessionHeaders,
          body: jsonEncode({'photo_id': photoId}),
        );
        
        if (retryResponse.statusCode == 200) {
          final data = jsonDecode(retryResponse.body);
          return data;
        }
        
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      if (_isValidJson(response.body)) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        return data;
      } else {
        AppLogger.log('❌ Ответ не является валидным JSON');
        return {
          'success': false,
          'error': 'Невалидный формат ответа от сервера',
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при добавлении лайка: $e');
      return {
        'success': false,
        'error': 'Ошибка при добавлении лайка: $e',
      };
    }
  }

  // Сбрасываем кэш лайков
  static void clearLikesCache() {
    _likesCache = null;
    _likesCacheTime = null;
  }
  
  // Сбрасываем кэш избранного
  static void clearFavoritesCache() {
    _favoritesCache = null;
    _favoritesCacheTime = null;
  }

  // =============== КОММЕРЧЕСКИЕ ИЗБРАННЫЕ ===============

  // Получение всех избранных коммерческих постов с кэшированием результата
  static Future<List<CommercialFavorite>> getAllCommercialFavorites() async {
    // Проверяем актуальность кэша
    final now = DateTime.now();
    if (_commercialFavoritesCache != null && _commercialFavoritesCacheTime != null) {
      final diff = now.difference(_commercialFavoritesCacheTime!);
      if (diff.inSeconds < _cacheDurationSeconds) {
        return _commercialFavoritesCache!;
      }
    }
    
    // Загружаем данные из SharedPreferences, если кэш устарел
    final prefs = await SharedPreferences.getInstance();
    final commercialFavoritesJson = prefs.getStringList(_commercialFavoritesKey) ?? [];
    
    final commercialFavorites = commercialFavoritesJson
        .map((jsonString) => CommercialFavorite.fromJsonString(jsonString))
        .toList();
    
    // Обновляем кэш
    _commercialFavoritesCache = commercialFavorites;
    _commercialFavoritesCacheTime = now;
    
    return commercialFavorites;
  }

  // Добавление коммерческого поста в избранное
  static Future<void> addToCommercialFavorites(String postId) async {
    // Быстрое локальное обновление
    final prefs = await SharedPreferences.getInstance();
    final commercialFavorites = await getAllCommercialFavorites();
    final userId = await UserService.getEmail();
    
    // Проверяем, что пост еще не в избранном
    final isAlreadyFavorite = commercialFavorites.any(
      (favorite) => favorite.postId == postId && favorite.userId == userId
    );
    
    // Если уже в избранном, ничего не делаем
    if (isAlreadyFavorite) {
      AppLogger.log('⭐ Коммерческий пост $postId уже в избранном');
      return;
    }
    
    // Создаем новый объект избранного
    final newFavorite = CommercialFavorite(
      userId: userId,
      postId: postId,
      createdAt: DateTime.now(),
    );
    
    // Обновляем локальный список и кэш
    final updatedFavorites = List<CommercialFavorite>.from(commercialFavorites)..add(newFavorite);
    _commercialFavoritesCache = updatedFavorites;
    _commercialFavoritesCacheTime = DateTime.now();
    
    // Сохраняем в SharedPreferences
    final favoritesJson = updatedFavorites.map((f) => f.toJsonString()).toList();
    await prefs.setStringList(_commercialFavoritesKey, favoritesJson);
    
    // Уведомляем подписчиков об изменении коммерческого избранного
    _commercialFavoritesChangedController.add(null);
    
    // Очищаем кэш для принудительного обновления
    clearCommercialFavoritesCache();
    
    AppLogger.log('⭐ Добавлен в избранное коммерческий пост: $postId');
    
    // Асинхронно отправляем на сервер (не блокируя UI)
    Future.microtask(() async {
      try {
        final service = SocialService();
        
        // Сначала пробуем преобразовать в числовой ID
        final numericPhotoId = int.tryParse(postId);
        if (numericPhotoId != null) {
          await service.addPhotoToFavorites(numericPhotoId);
        } else {
          // Для UUID или других форматов ID используем строковый тип
          await service.addPhotoToFavoritesString(postId);
        }
      } catch (e) {
        AppLogger.log('❌ Ошибка при отправке добавления коммерческого поста в избранное на сервер: $e');
      }
    });
  }

  // Удаление коммерческого поста из избранного
  static Future<void> removeFromCommercialFavorites(String postId) async {
    // Быстрое локальное обновление
    final prefs = await SharedPreferences.getInstance();
    final commercialFavorites = await getAllCommercialFavorites();
    final userId = await UserService.getEmail();
    
    // Фильтруем список избранного
    final updatedFavorites = commercialFavorites.where((favorite) {
      return !(favorite.postId == postId && favorite.userId == userId);
    }).toList();
    
    // Обновляем кэш сразу
    _commercialFavoritesCache = updatedFavorites;
    _commercialFavoritesCacheTime = DateTime.now();
    
    // Сохраняем в SharedPreferences
    final favoritesJson = updatedFavorites.map((f) => f.toJsonString()).toList();
    await prefs.setStringList(_commercialFavoritesKey, favoritesJson);
    
    // Уведомляем подписчиков об изменении коммерческого избранного
    _commercialFavoritesChangedController.add(null);
    
    // Очищаем кэш для принудительного обновления
    clearCommercialFavoritesCache();
    
    AppLogger.log('❌ Коммерческий пост $postId удален из избранного');
    
    // Отправка на сервер асинхронно
    Future.microtask(() async {
      try {
        final service = SocialService();
        final numericPhotoId = int.tryParse(postId);
        if (numericPhotoId != null) {
          await service.removePhotoFromFavorites(numericPhotoId);
        } else {
          await service.removePhotoFromFavoritesString(postId);
        }
      } catch (e) {
        AppLogger.log('❌ Ошибка при отправке удаления коммерческого поста из избранного на сервер: $e');
      }
    });
  }

  // Проверка, находится ли коммерческий пост в избранном (быстрая, без сервера)
  static Future<bool> isCommercialFavorite(String postId) async {
    final commercialFavorites = await getAllCommercialFavorites();
    final userId = await UserService.getEmail();
    
    return commercialFavorites.any(
      (favorite) => favorite.postId == postId && favorite.userId == userId
    );
  }

  // Сбрасываем кэш коммерческих избранных
  static void clearCommercialFavoritesCache() {
    _commercialFavoritesCache = null;
    _commercialFavoritesCacheTime = null;
  }

  // Проверка, находится ли пост в избранном (быстрая, без сервера)
  static Future<bool> isFavorite(String postId) async {
    final favorites = await getAllFavorites();
    final userId = await UserService.getEmail();
    
    return favorites.any(
      (favorite) => favorite.postId == postId && favorite.userId == userId
    );
  }
  
  // Удаление поста из избранного
  static Future<void> removeFromFavorites(String postId) async {
    // Быстрое локальное обновление
    final prefs = await SharedPreferences.getInstance();
    final favorites = await getAllFavorites();
    final userId = await UserService.getEmail();
    
    // Фильтруем список избранного
    final updatedFavorites = favorites.where((favorite) {
      return !(favorite.postId == postId && favorite.userId == userId);
    }).toList();
    
    // Обновляем кэш сразу
    _favoritesCache = updatedFavorites;
    _favoritesCacheTime = DateTime.now();
    
    // Сохраняем в SharedPreferences
    final favoritesJson = updatedFavorites.map((f) => f.toJsonString()).toList();
    await prefs.setStringList(_favoritesKey, favoritesJson);
    
    // Уведомляем подписчиков об изменении избранного
    _favoritesChangedController.add(null);
    
    // Очищаем кэш для принудительного обновления
    clearFavoritesCache();
    
    // Отправка на сервер асинхронно
    Future.microtask(() async {
      try {
        final service = SocialService();
        final numericPhotoId = int.tryParse(postId);
        if (numericPhotoId != null) {
          await service.removePhotoFromFavorites(numericPhotoId);
        } else {
          await service.removePhotoFromFavoritesString(postId);
        }
      } catch (e) {
        AppLogger.log('❌ Ошибка при отправке удаления из избранного на сервер: $e');
      }
    });
  }

  // Получение списка пользователей, лайкнувших пост
  Future<Map<String, dynamic>> getLikesList(String postId) async {
    try {
      // Проверяем тип ID поста
      final numericPhotoId = int.tryParse(postId);
      
      // Формируем URL с учетом типа ID
      final photoIdForRequest = numericPhotoId != null ? numericPhotoId.toString() : postId;
      final url = '${ApiConfig.baseUrl}/social/get_likes.php?photo_id=$photoIdForRequest';
      
      // Получаем актуальные заголовки сессии (уже включают Accept: application/json)
      final headers = AuthService().sessionHeaders;
      
      AppLogger.log('🔄 Запрос списка лайков для поста ID: $postId, URL: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      // Обработка ошибки авторизации
      if (response.statusCode == 401) {
        AppLogger.log('⚠️ Ошибка авторизации при получении списка лайков, пробуем обновить сессию');
        await UserService.checkAuth();
        
        // Обновляем заголовки сессии
        final retryHeaders = AuthService().sessionHeaders;
        
        final retryResponse = await http.get(
          Uri.parse(url),
          headers: retryHeaders,
        );
        
        if (retryResponse.statusCode == 200) {
          final data = jsonDecode(retryResponse.body);
          AppLogger.log('✅ Список лайков успешно получен после повторной авторизации');
          return data;
        }
        
        // В случае повторной ошибки авторизации, возвращаем локальные данные
        return {'success': false, 'error': 'Ошибка авторизации', 'likes': []};
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.log('✅ Список лайков успешно получен: ${data.toString().substring(0, min(100, data.toString().length))}...');
        
        // Если API не возвращает структуру success, оборачиваем ответ
        if (data['success'] == null) {
          if (data is List) {
            return {'success': true, 'likes': data};
          } else {
            return {'success': true, 'likes': data['likes'] ?? []};
          }
        }
        
        return data;
      } else {
        AppLogger.log('❌ Ошибка при получении списка лайков: ${response.statusCode}, ${response.body}');
        return {'success': false, 'error': 'Ошибка сервера: ${response.statusCode}'};
      }
    } catch (e) {
      AppLogger.log('❌ Исключение при получении списка лайков: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Получение списка всех пользователей
  Future<Map<String, dynamic>> getAllUsers() async {
    try {
      // Формируем URL запроса
      final url = '${ApiConfig.baseUrl}/user/get_all_users.php';
      
      // Получаем актуальные заголовки сессии (уже включают Accept: application/json)
      final headers = AuthService().sessionHeaders;
      
      AppLogger.log('🔄 Запрос списка всех пользователей, URL: $url');
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      // Обработка ошибки авторизации
      if (response.statusCode == 401) {
        AppLogger.log('⚠️ Ошибка авторизации при получении списка пользователей, пробуем обновить сессию');
        await UserService.checkAuth();
        
        // Обновляем заголовки сессии
        final retryHeaders = AuthService().sessionHeaders;
        
        final retryResponse = await http.get(
          Uri.parse(url),
          headers: retryHeaders,
        );
        
        if (retryResponse.statusCode == 200) {
          final data = jsonDecode(retryResponse.body);
          AppLogger.log('✅ Список пользователей успешно получен после повторной авторизации');
          return data;
        }
        
        // В случае повторной ошибки авторизации, возвращаем пустой результат
        return {'success': false, 'error': 'Ошибка авторизации', 'users': []};
      }
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.log('✅ Список пользователей успешно получен');
        
        // Если API не возвращает структуру success, оборачиваем ответ
        if (data['success'] == null) {
          if (data is List) {
            return {'success': true, 'users': data};
          } else {
            return {'success': true, 'users': data['users'] ?? []};
          }
        }
        
        return data;
      } else {
        AppLogger.log('❌ Ошибка при получении списка пользователей: ${response.statusCode}, ${response.body}');
        return {'success': false, 'error': 'Ошибка сервера: ${response.statusCode}', 'users': []};
      }
    } catch (e) {
      AppLogger.log('❌ Исключение при получении списка пользователей: $e');
      return {'success': false, 'error': e.toString(), 'users': []};
    }
  }

  // Удаление подписок по email и перенос их на ID
  static Future<void> cleanupFollowsByEmail() async {
    try {
      // Получаем текущий email и ID пользователя
      final userEmail = await UserService.getEmail();
      final userId = await UserService.getUserId();
      
      // AppLogger.log('🧹 Cleaning up follows: email=$userEmail, id=$userId');
      
      // Получаем все подписки
      final prefs = await SharedPreferences.getInstance();
      final followsJson = prefs.getStringList(_followsKey) ?? [];
      
      // Получаем список подписок в объектном виде
      final follows = followsJson
          .map((jsonString) => Follow.fromJsonString(jsonString))
          .toList();
      
      // Группируем подписки, которые имеют одинаковый followedId, но разные followerId (email и id)
      final Map<String, List<Follow>> followsByFollowedId = {};
      
      // Наполняем группы
      for (final follow in follows) {
        if (!followsByFollowedId.containsKey(follow.followedId)) {
          followsByFollowedId[follow.followedId] = [];
        }
        followsByFollowedId[follow.followedId]!.add(follow);
      }
      
      // Список подписок, которые нужно сохранить
      final List<Follow> followsToKeep = [];
      
      // Проходим по всем группам
      followsByFollowedId.forEach((followedId, followsList) {
        // Если в группе только одна подписка, сохраняем её
        if (followsList.length == 1) {
          followsToKeep.add(followsList.first);
          return;
        }
        
        // Если в группе несколько подписок, проверяем, есть ли среди них наша с email
        final myEmailFollows = followsList.where((f) => 
          f.followerId == userEmail || 
          (f.followerId.contains('@') && f.followedId == followedId)
        ).toList();
        
        final myIdFollows = followsList.where((f) => 
          f.followerId == userId && f.followedId == followedId
        ).toList();
        
        // Если есть подписка с ID, удаляем подписку с email
        if (myIdFollows.isNotEmpty) {
          followsToKeep.add(myIdFollows.first);
          // Добавляем все остальные подписки, кроме с email
          followsToKeep.addAll(followsList.where((f) => 
            f.followerId != userEmail && 
            !(f.followerId.contains('@') && f.followedId == followedId)
          ));
        } 
        // Если нет подписки с ID, но есть с email, конвертируем её в ID
        else if (myEmailFollows.isNotEmpty) {
          // Создаем новую подписку с ID вместо email
          final newFollow = Follow(
            followerId: userId,
            followedId: followedId,
            createdAt: myEmailFollows.first.createdAt,
          );
          followsToKeep.add(newFollow);
          
          // Добавляем все остальные подписки, кроме с email
          followsToKeep.addAll(followsList.where((f) => 
            f.followerId != userEmail && 
            !(f.followerId.contains('@') && f.followedId == followedId)
          ));
        } 
        // Если нет ни с ID, ни с email, сохраняем все
        else {
          followsToKeep.addAll(followsList);
        }
      });
      
      // Сохраняем обновленный список подписок
      final updatedFollowsJson = followsToKeep.map((f) => f.toJsonString()).toList();
      await prefs.setStringList(_followsKey, updatedFollowsJson);
      
      // AppLogger.log('✅ Follows cleanup completed: removed ${follows.length - followsToKeep.length} duplicate follows');
    } catch (e) {
      AppLogger.log('❌ Error cleaning up follows: $e');
    }
  }

  // Полная очистка всех подписок (радикальное решение)
  static Future<void> clearAllFollows() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_followsKey);
      AppLogger.log('✅ Все подписки успешно удалены из локального хранилища');
    } catch (e) {
      AppLogger.log('❌ Ошибка при удалении подписок: $e');
    }
  }

  // Удаление дубликатов подписок с одинаковыми follower/followed ID
  static Future<void> removeDuplicateFollows() async {
    try {
      // Получаем все подписки
      final prefs = await SharedPreferences.getInstance();
      final followsJson = prefs.getStringList(_followsKey) ?? [];
      
      if (followsJson.isEmpty) {
        AppLogger.log('⚠️ Нет подписок для обработки');
        return;
      }
      
      // AppLogger.log('🔍 Начинаем удаление дубликатов подписок. Всего подписок: ${followsJson.length}');
      
      // Получаем список подписок в объектном виде
      final follows = followsJson
          .map((jsonString) => Follow.fromJsonString(jsonString))
          .toList();
      
      // Создаем Set для хранения уникальных пар ID
      final Set<String> uniquePairs = {};
      final List<Follow> uniqueFollows = [];
      
      // Проходим по всем подпискам и оставляем только уникальные
      for (final follow in follows) {
        // Создаем уникальный ключ для пары follower-followed
        final pairKey = '${follow.followerId}-${follow.followedId}';
        
        // Если такой пары еще не было, добавляем подписку
        if (!uniquePairs.contains(pairKey)) {
          uniquePairs.add(pairKey);
          uniqueFollows.add(follow);
        } else {
          AppLogger.log('🗑️ Удаляем дублирующую подписку: $pairKey');
        }
      }
      
      // Если были найдены дубликаты, сохраняем обновленный список
      if (uniqueFollows.length < follows.length) {
        final updatedFollowsJson = uniqueFollows.map((f) => f.toJsonString()).toList();
        await prefs.setStringList(_followsKey, updatedFollowsJson);
        AppLogger.log('✅ Удалено ${follows.length - uniqueFollows.length} дубликатов подписок');
      } else {
        // AppLogger.log('✅ Дубликатов подписок не найдено');
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при удалении дубликатов подписок: $e');
    }
  }

  // Получить информацию о фотографии
  Future<Map<String, dynamic>> getPhotoInfo(String photoId) async {
    try {
      AppLogger.log('🔍 Получение информации о фото ID: $photoId');
      
      // Получаем статус авторизации и куки
      final isLoggedIn = await UserService.checkAuth();
      
      // Добавляем заголовки для корректной работы с сессией
      final headers = Map<String, String>.from(_authService.sessionHeaders);
      headers['Accept'] = 'application/json';
      
      // Формируем URL для запроса API
      final url = '${ApiConfig.getPhotoInfo}?photo_id=$photoId';
      AppLogger.log('🔗 URL для получения информации о фото: $url');
      
      // Отправляем запрос на сервер
      final response = await http.get(
        Uri.parse(url),
        headers: headers,
      );
      
      AppLogger.log('📥 Статус ответа: ${response.statusCode}');
      
      if (response.statusCode != 200) {
        // В случае отсутствия специального API, извлекаем информацию из результатов getComments
        // Так как комментарии связаны с фото и содержат ссылку на владельца
        final commentsResult = await getComments(photoId, page: 1, perPage: 1);
        
        if (commentsResult['success'] == true && 
            commentsResult['comments'] is List && 
            (commentsResult['comments'] as List).isNotEmpty) {
          
          // Пытаемся извлечь информацию о владельце фото из первого комментария
          // (Это временное решение, пока нет специального API)
          return {
            'success': true,
            'photo': {
              'id': photoId,
              'userId': extractPhotoOwnerIdFromComments(commentsResult['comments']),
            }
          };
        }
        
        AppLogger.log('❌ Ошибка при получении информации о фото: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Ошибка сервера: ${response.statusCode}',
        };
      }
      
      if (_isValidJson(response.body)) {
        final data = jsonDecode(response.body);
        return data;
      } else {
        AppLogger.log('❌ Получен невалидный JSON: ${response.body}');
        return {
          'success': false,
          'error': 'Невалидный формат данных',
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении информации о фото: $e');
      return {
        'success': false,
        'error': 'Ошибка: $e',
      };
    }
  }
  
  // Вспомогательный метод для извлечения ID владельца фото из комментариев
  int extractPhotoOwnerIdFromComments(List<dynamic> comments) {
    if (comments.isEmpty) return 0;
    
    try {
      // Проверяем разные варианты нахождения ID владельца в данных
      final comment = comments[0];
      
      // Вариант 1: Прямое поле photoOwnerId
      if (comment is Map && comment.containsKey('photoOwnerId')) {
        final ownerId = comment['photoOwnerId'];
        return ownerId is int ? ownerId : int.tryParse(ownerId.toString()) ?? 0;
      }
      
      // Вариант 2: Поле photo_owner_id
      if (comment is Map && comment.containsKey('photo_owner_id')) {
        final ownerId = comment['photo_owner_id'];
        return ownerId is int ? ownerId : int.tryParse(ownerId.toString()) ?? 0;
      }
      
      // Вариант 3: Необходим дополнительный запрос к API
      // В этом случае метод просто вернет 0, а полная информация
      // о фото будет получена отдельным запросом
    } catch (e) {
      AppLogger.log('❌ Ошибка при извлечении ID владельца: $e');
    }
    
    return 0;
  }

  // Новое: Удалить фотографию из избранного (строковый ID)
  Future<Map<String, dynamic>> removePhotoFromFavoritesString(String photoId) async {
    try {
      final request = http.Request('DELETE', Uri.parse(ApiConfig.favorite));
      request.headers.addAll(_authService.sessionHeaders);
      request.body = jsonEncode({'photo_id': photoId});

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        await UserService.checkAuth();

        final retryRequest = http.Request('DELETE', Uri.parse(ApiConfig.favorite));
        retryRequest.headers.addAll(_authService.sessionHeaders);
        retryRequest.body = jsonEncode({'photo_id': photoId});

        final retryStreamedResponse = await retryRequest.send();
        final retryResponse = await http.Response.fromStream(retryStreamedResponse);

        if (retryResponse.statusCode == 200) {
          return jsonDecode(retryResponse.body);
        }

        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      if (_isValidJson(response.body)) {
        return jsonDecode(response.body);
      } else {
        return {'success': false, 'error': 'Невалидный формат ответа от сервера'};
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при удалении из избранного: $e',
      };
    }
  }

  /// Получение альбомов от пользователей, на которых подписан текущий пользователь
  static Future<List<Map<String, dynamic>>> getFollowingAlbums() async {
    try {
      final followingIds = await getFollowingIds();
      if (followingIds.isEmpty) {
        AppLogger.log('⚠️ No following users found, returning empty albums list');
        return [];
      }

      // AppLogger.log('⚙️ getFollowingAlbums: Ищем альбомы от ${followingIds.length} подписок');

      // Получаем текущего пользователя
      final currentEmail = await UserService.getEmail();
      final currentUserId = await UserService.getUserId();

      List<Map<String, dynamic>> followingAlbums = [];

      // Получаем альбомы для каждого пользователя из подписок
      for (String followedId in followingIds) {
        try {
          // Пропускаем собственные альбомы
          if (followedId == currentEmail || followedId == currentUserId) {
            continue;
          }

          final resp = await AlbumService.getUserAlbumsFromServer(followedId, page: 1, perPage: 50);
          if (resp['success'] == true && resp['albums'] is List) {
            final userAlbums = List<Map<String, dynamic>>.from(resp['albums']);
            
            // Добавляем только публичные альбомы
            final publicAlbums = userAlbums.where((album) => 
              album['is_public'] == 1 || album['is_public'] == true || album['is_public'] == '1'
            ).toList();
            
            followingAlbums.addAll(publicAlbums);
            // AppLogger.log('✅ Найдено ${publicAlbums.length} публичных альбомов от пользователя $followedId');
          }
        } catch (e) {
          AppLogger.log('⚠️ Ошибка при получении альбомов от пользователя $followedId: $e');
          continue;
        }
      }

      // Сортируем по дате создания, сначала новые
      followingAlbums.sort((a, b) {
        final dateA = DateTime.tryParse(a['created_at']?.toString() ?? '') ?? DateTime.now();
        final dateB = DateTime.tryParse(b['created_at']?.toString() ?? '') ?? DateTime.now();
        return dateB.compareTo(dateA);
      });

      // AppLogger.log('⚙️ getFollowingAlbums: найдено ${followingAlbums.length} альбомов от подписок');
      return followingAlbums;

    } catch (e) {
      AppLogger.log('❌ Error getting following albums: $e');
      return [];
    }
  }

  /// Получение отдельных постов (не в альбомах) от пользователей подписок
  static Future<List<Post>> getFollowingNonAlbumPosts() async {
    try {
      final followingIds = await getFollowingIds();
      final allPosts = await PostService.getAllPosts();
      
      if (followingIds.isEmpty) {
        AppLogger.log('⚠️ No following users found, returning empty posts list');
        return [];
      }
      
      // Получаем альбомы от подписок, чтобы исключить посты, которые в них входят
      final followingAlbums = await getFollowingAlbums();
      final Set<String> albumPostIds = {};
      
      // Собираем ID всех постов, которые входят в альбомы
      for (var album in followingAlbums) {
        try {
          final albumId = album['id'].toString();
          final albumDetails = await AlbumService.getAlbumDetails(albumId);
          if (albumDetails['success'] == true && albumDetails['photos'] is List) {
            final photos = List<Map<String, dynamic>>.from(albumDetails['photos']);
            for (var photo in photos) {
              final photoId = photo['id']?.toString();
              if (photoId != null && photoId.isNotEmpty) {
                albumPostIds.add(photoId);
              }
            }
          }
        } catch (e) {
          AppLogger.log('⚠️ Ошибка при получении деталей альбома: $e');
        }
      }

      // AppLogger.log('⚙️ getFollowingNonAlbumPosts: исключаем ${albumPostIds.length} постов из альбомов');

      // Пытаемся получить текущий ID пользователя разными способами
      final currentEmail = await UserService.getEmail();
      final currentUserId = await UserService.getUserId();
      
      // AppLogger.log('⚙️ getFollowingNonAlbumPosts: Текущий пользователь - Email: $currentEmail, ID: $currentUserId');
      
      // Фильтруем посты от подписок, исключая посты из альбомов
      List<Post> followingPosts = [];
      for (var post in allPosts) {
        // Пропускаем свои посты
        if (post.user == currentEmail || post.user == currentUserId) {
          continue;
        }

        // Пропускаем посты, которые входят в альбомы
        if (albumPostIds.contains(post.id)) {
          continue;
        }
        
        if (followingIds.contains(post.user)) {
          followingPosts.add(post);
          // AppLogger.log('✅ Найден отдельный пост от пользователя ${post.user}');
        } else {
          // Дополнительные проверки для разных форматов ID
          try {
            final postUserId = int.tryParse(post.user);
            for (var followedId in followingIds) {
              final followedNumId = int.tryParse(followedId);
              if (postUserId != null && followedNumId != null && postUserId == followedNumId) {
                followingPosts.add(post);
                AppLogger.log('✅ Найден отдельный пост от пользователя ${post.user} (числовое совпадение)');
                break;
              }
            }
          } catch (e) {
            // Если ошибка конвертации, продолжаем
            AppLogger.log('⚠️ Ошибка при попытке конвертации ID: $e');
          }
        }
      }
      
      // AppLogger.log('⚙️ getFollowingNonAlbumPosts: найдено ${followingPosts.length} отдельных постов от подписок');
      
      // Сортируем по дате создания, сначала новые
      followingPosts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      
      return followingPosts;
    } catch (e) {
      AppLogger.log('❌ Error getting following non-album posts: $e');
      return [];
    }
  }
} 