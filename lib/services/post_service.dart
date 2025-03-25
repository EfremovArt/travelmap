import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/post.dart';
import '../models/location.dart';

class PostService {
  static const String _postsKey = 'user_posts';
  
  // Получение всех постов
  static Future<List<Post>> getAllPosts() async {
    final prefs = await SharedPreferences.getInstance();
    final postsJson = prefs.getStringList(_postsKey) ?? [];
    
    return postsJson
        .map((jsonString) => Post.fromJson(jsonDecode(jsonString)))
        .toList();
  }
  
  // Сохранение нового поста
  static Future<void> savePost(Post post) async {
    final prefs = await SharedPreferences.getInstance();
    final postsJson = prefs.getStringList(_postsKey) ?? [];
    
    // Конвертируем пост в JSON и добавляем в список
    postsJson.add(jsonEncode(post.toJson()));
    
    // Сохраняем обновленный список
    await prefs.setStringList(_postsKey, postsJson);
  }
  
  // Обновление существующего поста
  static Future<void> updatePost(Post updatedPost) async {
    final prefs = await SharedPreferences.getInstance();
    final postsJson = prefs.getStringList(_postsKey) ?? [];
    
    // Находим и обновляем пост с совпадающим ID
    final updatedPostsJson = postsJson.map((jsonString) {
      final post = Post.fromJson(jsonDecode(jsonString));
      if (post.id == updatedPost.id) {
        // Заменяем старый пост на обновленный
        return jsonEncode(updatedPost.toJson());
      }
      return jsonString;
    }).toList();
    
    // Сохраняем обновленный список
    await prefs.setStringList(_postsKey, updatedPostsJson);
  }
  
  // Получение постов в определенной области карты
  static Future<List<Post>> getPostsInBounds(GeoLocation southwest, GeoLocation northeast) async {
    final allPosts = await getAllPosts();
    
    return allPosts.where((post) {
      // Проверяем, находится ли пост в указанных границах
      final latitude = post.location.latitude;
      final longitude = post.location.longitude;
      
      return latitude >= southwest.latitude &&
             latitude <= northeast.latitude &&
             longitude >= southwest.longitude &&
             longitude <= northeast.longitude;
    }).toList();
  }
  
  // Удаление поста
  static Future<void> deletePost(String postId) async {
    final prefs = await SharedPreferences.getInstance();
    final postsJson = prefs.getStringList(_postsKey) ?? [];
    
    // Фильтруем посты, оставляя все, кроме удаляемого
    final updatedPostsJson = postsJson.where((jsonString) {
      final post = Post.fromJson(jsonDecode(jsonString));
      return post.id != postId;
    }).toList();
    
    // Сохраняем обновленный список
    await prefs.setStringList(_postsKey, updatedPostsJson);
  }
  
  // Получение постов конкретного пользователя
  static Future<List<Post>> getUserPosts(String userId) async {
    final allPosts = await getAllPosts();
    
    return allPosts.where((post) => post.user == userId).toList();
  }
  
  // Копирование изображений во внутреннее хранилище
  // Полезно для приложения, чтобы гарантировать, что изображения останутся,
  // даже если внешние источники (например, временные кэши камеры) будут очищены
  static Future<List<File>> saveImagesToAppStorage(List<File> images) async {
    final List<File> savedImages = [];
    
    // В будущей реализации здесь будет копирование изображений
    // во внутреннее хранилище приложения
    // Пока просто возвращаем те же файлы
    
    return images;
  }
  
  // В будущем здесь могут быть методы для синхронизации с сервером
} 