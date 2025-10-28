import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/api_config.dart';
import '../models/post.dart';
import '../models/location.dart';
import '../services/auth_service.dart';
import '../services/user_service.dart';
import '../utils/logger.dart';

class PostService {
  // Простой кэш постов в памяти
  static List<Post>? _inMemoryPosts;
  static DateTime? _inMemoryUpdatedAt;
  static const String _postsCacheKey = 'cached_posts_v1';
  static const String _latestCreatedAtKey = 'latest_photo_created_at';

  // Получение постов из кэша (если есть)
  static Future<List<Post>?> _loadPostsFromCache() async {
    try {
      if (_inMemoryPosts != null && _inMemoryPosts!.isNotEmpty) {
        return _inMemoryPosts;
      }
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_postsCacheKey);
      if (jsonString == null || jsonString.isEmpty) return null;
      final List<dynamic> list = jsonDecode(jsonString);
      final posts = list.map((e) => Post.fromJson(e as Map<String, dynamic>)).toList();
      _inMemoryPosts = posts;
      return posts;
    } catch (e) {
      AppLogger.log('⚠️ Не удалось загрузить кэш постов: $e');
      return null;
    }
  }

  static Future<void> _savePostsToCache(List<Post> posts) async {
    try {
      _inMemoryPosts = posts;
      final prefs = await SharedPreferences.getInstance();
      final jsonList = posts.map((p) => p.toJson()).toList();
      await prefs.setString(_postsCacheKey, jsonEncode(jsonList));
      // Обновляем локальный latestCreatedAt
      if (posts.isNotEmpty) {
        posts.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        await prefs.setString(_latestCreatedAtKey, posts.first.createdAt.toIso8601String());
      }
    } catch (e) {
      AppLogger.log('⚠️ Не удалось сохранить кэш постов: $e');
    }
  }

  static Future<String?> _getLocalLatestCreatedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_latestCreatedAtKey);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _fetchServerLatestCreatedAt() async {
    try {
      final token = await AuthService.getToken();
      final response = await http.get(
        Uri.parse(ApiConfig.getLatestPhotoTimestamp),
        headers: {
          'Cookie': token,
          'Content-Type': 'application/json',
        },
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final String? latest = data['latestCreatedAt'];
          return latest;
        }
      }
    } catch (e) {
      AppLogger.log('⚠️ Ошибка при проверке latestCreatedAt: $e');
    }
    return null;
  }

  // Добавлено: метод для инвалидирования кэша постов после операций изменения данных
  static Future<void> _invalidatePostsCache() async {
    try {
      _inMemoryPosts = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_postsCacheKey);
      await prefs.remove(_latestCreatedAtKey);
    } catch (e) {
      AppLogger.log('⚠️ Не удалось очистить кэш постов: $e');
    }
  }

  // Публичный метод для принудительного обновления постов (очищает кеш и загружает с сервера)
  static Future<List<Post>> forceRefreshPosts() async {
    try {
      AppLogger.log('🔄 Принудительное обновление постов с очисткой кеша');
      
      // Сначала очищаем кеш
      await _invalidatePostsCache();
      
      // Затем загружаем свежие данные с сервера
      final posts = await _fetchAllPostsFromServer();
      
      // Сохраняем в кеш
      await _savePostsToCache(posts);
      
      return posts;
    } catch (e) {
      AppLogger.log('❌ Ошибка при принудительном обновлении постов: $e');
      return [];
    }
  }

  // Получение ВСЕХ постов с сервера (от всех пользователей)
  static Future<List<Post>> getAllPosts() async {
    try {
      // 1) Сначала попробуем кэш, чтобы мгновенно показать данные
      final cached = await _loadPostsFromCache();

      // 2) Проверяем, появились ли новые посты на сервере
      final localLatest = await _getLocalLatestCreatedAt();
      final serverLatest = await _fetchServerLatestCreatedAt();
      
      // Если на сервере новее данные, чем в кэше, загружаем свежие данные
      if (serverLatest != null && (localLatest == null || serverLatest.compareTo(localLatest) > 0)) {
        // AppLogger.log('🔄 Обнаружены новые данные на сервере, обновляем кеш');
        final fresh = await _fetchAllPostsFromServer();
        if (fresh.isNotEmpty) {
          await _savePostsToCache(fresh);
          return fresh; // Возвращаем свежие данные
        }
      }

      // 3) Если кеш есть и он актуальный, возвращаем его
      if (cached != null) {
        return cached;
      }

      // 4) Если кэша нет — делаем сетевую загрузку
      final posts = await _fetchAllPostsFromServer();
      await _savePostsToCache(posts);
      return posts;
    } catch (e) {
      AppLogger.log('Error fetching posts: $e');
      return [];
    }
  }

  static Future<List<Post>> _fetchAllPostsFromServer() async {
    final token = await AuthService.getToken();
    final response = await http.get(
      Uri.parse(ApiConfig.getAllLocations),
      headers: {
        'Cookie': token,
        'Content-Type': 'application/json',
      },
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true && data['data'] != null && data['data']['locations'] != null) {
        final locations = data['data']['locations'] as List<dynamic>;
        List<Post> posts = [];
        for (var location in locations) {
          String userId = location['user_id']?.toString() ?? 'null';
          final List<dynamic> photosList = location['photos'] as List<dynamic>? ?? [];
          List<String> imageUrls = [];
          List<String> originalImageUrls = [];
          List<String> photoIds = [];
          for (var photo in photosList) {
            // Собираем ID всех фотографий
            if (photo['id'] != null) {
              photoIds.add(photo['id'].toString());
            }
            
            // Обрабатываем cropped версию
            if (photo['file_path'] != null) {
              String relativePath = photo['file_path'];
              if (!relativePath.startsWith('http')) {
                if (relativePath.startsWith('/travel/')) {
                  relativePath = relativePath.substring(7);
                } else if (relativePath.startsWith('/')) {
                  relativePath = relativePath.substring(1);
                }
                String fullUrl = "${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}/${relativePath.replaceAll(RegExp(r'^/'), '')}";
                imageUrls.add(fullUrl);
              } else {
                imageUrls.add(relativePath);
              }
            }
            
            // Обрабатываем оригинальную версию
            String? originalPath = photo['original_file_path'] ?? photo['file_path'];
            if (originalPath != null) {
              if (!originalPath.startsWith('http')) {
                if (originalPath.startsWith('/travel/')) {
                  originalPath = originalPath.substring(7);
                } else if (originalPath.startsWith('/')) {
                  originalPath = originalPath.substring(1);
                }
                String fullUrl = "${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}/${originalPath.replaceAll(RegExp(r'^/'), '')}";
                originalImageUrls.add(fullUrl);
              } else {
                originalImageUrls.add(originalPath);
              }
            }
          }
          if (photosList.isNotEmpty) {
            String postId = photosList[0]['id'].toString();
            DateTime createdAt;
            try {
              createdAt = DateTime.parse(location['created_at']);
            } catch (_) {
              createdAt = DateTime.now();
            }
            posts.add(Post(
              id: postId,
              user: userId,
              title: photosList[0]['title'] ?? '',
              description: location['description'] ?? '',
              locationName: location['title'] ?? 'Без названия',
              location: GeoLocation(
                latitude: double.parse(location['latitude'].toString()),
                longitude: double.parse(location['longitude'].toString()),
              ),
              images: [],
              imageUrls: imageUrls,
              originalImageUrls: originalImageUrls,
              photoIds: photoIds,
              createdAt: createdAt,
            ));
          }
        }
        return posts;
      }
    }
    return [];
  }
  
  // Сохранение нового поста на сервере
  static Future<Map<String, dynamic>> savePost(Post post, {File? firstImageOriginal}) async {
    try {
      AppLogger.log('📝 savePost called with firstImageOriginal: ${firstImageOriginal != null ? "NOT NULL" : "NULL"}');
      if (firstImageOriginal != null) {
        AppLogger.log('📝 Original path: ${firstImageOriginal.path}');
        AppLogger.log('📝 File exists: ${await firstImageOriginal.exists()}');
      }
      
      // 1. Сначала добавляем локацию
      final locationResult = await _addLocation(
        title: post.locationName,
        description: post.description,
        latitude: post.location.latitude,
        longitude: post.location.longitude,
      );
      
      if (locationResult['success'] == true && locationResult['location'] != null) {
        final locationId = locationResult['location']['id'].toString();
        
        // 2. Затем загружаем каждую фотографию
        for (int i = 0; i < post.images.length; i++) {
          final image = post.images[i];
          // Для первого изображения передаём оригинал (если есть)
          final original = (i == 0) ? firstImageOriginal : null;
          AppLogger.log('📤 Uploading image $i, original: ${original != null ? "YES" : "NO"}');
          await _uploadPhoto(
            image, 
            locationId, 
            title: post.title, 
            description: post.description,
            originalImage: original,
          );
        }
        
        // Инвалидируем кеш постов после успешного сохранения
        await _invalidatePostsCache();
        AppLogger.log('✅ Кеш постов инвалидирован после сохранения нового поста');
        
        return {'success': true, 'message': 'Post saved successfully'};
      } else {
        return {'success': false, 'error': locationResult['message'] ?? 'Failed to add location'};
      }
    } catch (e) {
      AppLogger.log('Error saving post: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
  
  // Внутренний метод для добавления локации
  static Future<Map<String, dynamic>> _addLocation({
    required String title,
    required String description,
    required double latitude,
    required double longitude,
    String? address,
  }) async {
    try {
      // Получаем куки вместо токена - используем правильный формат авторизации
      final token = await AuthService.getToken();
      
      final response = await http.post(
        Uri.parse(ApiConfig.addLocation),
        headers: {
          'Cookie': token, // Отправляем куки напрямую
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': title,
          'description': description,
          'latitude': latitude,
          'longitude': longitude,
          'address': address ?? '',
        }),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        AppLogger.log('Failed to add location: ${response.statusCode} ${response.body}');
        return {'success': false, 'message': 'Failed to add location'};
      }
    } catch (e) {
      AppLogger.log('Error adding location: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
  
  // Внутренний метод для загрузки фотографии
  static Future<Map<String, dynamic>> _uploadPhoto(
    File image, 
    String locationId, 
    {String? title, String? description, File? originalImage}
  ) async {
    try {
      final token = await AuthService.getToken();
      
      AppLogger.log('Uploading photo to location ID: $locationId');
      
      // Создаем multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.uploadPhoto),
      );
      
      // Добавляем заголовки авторизации в формате куки
      request.headers['Cookie'] = token;
      
      // Добавляем файл (cropped)
      final extension = path.extension(image.path).replaceAll('.', '');
      final mimeType = extension == 'jpg' || extension == 'jpeg' 
          ? 'image/jpeg' 
          : extension == 'png' ? 'image/png' : 'image/gif';
      
      final photoFile = await http.MultipartFile.fromPath(
        'photo',
        image.path,
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(photoFile);
      
      // Добавляем оригинал если есть
      if (originalImage != null) {
        AppLogger.log('🔍 _uploadPhoto: originalImage path: ${originalImage.path}');
        AppLogger.log('🔍 _uploadPhoto: File exists: ${await originalImage.exists()}');
        
        final originalExtension = path.extension(originalImage.path).replaceAll('.', '');
        final originalMimeType = originalExtension == 'jpg' || originalExtension == 'jpeg' 
            ? 'image/jpeg' 
            : originalExtension == 'png' ? 'image/png' : 'image/gif';
        
        final originalPhotoFile = await http.MultipartFile.fromPath(
          'photo_original',
          originalImage.path,
          contentType: MediaType.parse(originalMimeType),
        );
        request.files.add(originalPhotoFile);
        
        AppLogger.log('✅ Adding original image for gallery view');
        AppLogger.log('✅ Request files count: ${request.files.length}');
      } else {
        AppLogger.log('⚠️ NO original image to add');
      }
      
      // Добавляем ID локации
      request.fields['location_id'] = locationId;
      
      // Добавляем title и description если они есть
      if (title != null) {
        request.fields['title'] = title;
      }
      
      if (description != null) {
        request.fields['description'] = description;
      }
      
      AppLogger.log('Sending upload request with location_id: $locationId');
      
      // Отправляем запрос
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      AppLogger.log('Upload response status: ${response.statusCode}');
      AppLogger.log('Upload response body: ${response.body}');
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> result = jsonDecode(response.body);
        if (result['success'] == true) {
          return result;
        } else {
          AppLogger.log('Upload API returned error: ${result['message'] ?? 'Unknown error'}');
          return {'success': false, 'message': result['message'] ?? 'Unknown error'};
        }
      } else {
        AppLogger.log('Failed to upload photo: ${response.statusCode} ${response.body}');
        return {'success': false, 'message': 'Failed to upload photo, status code: ${response.statusCode}'};
      }
    } catch (e) {
      AppLogger.log('Error uploading photo: $e');
      return {'success': false, 'message': e.toString()};
    }
  }
  
  // Получение постов в определенной области карты
  static Future<List<Post>> getPostsInBounds(GeoLocation southwest, GeoLocation northeast) async {
    try {
      // Здесь можно отправить запрос на сервер с координатами области
      // Пока будет просто возвращать все посты
      return await getAllPosts();
    } catch (e) {
      AppLogger.log('Error fetching posts in bounds: $e');
      return [];
    }
  }
  
  // Получение постов конкретного пользователя
  static Future<List<Post>> getUserPosts({required String userId}) async {
    try {
      final token = await AuthService.getToken();

      // Берем общий список локаций и фильтруем по user_id, т.к. get_user_locations.php возвращает только текущего пользователя
      final response = await http.get(
        Uri.parse(ApiConfig.getAllLocations),
        headers: {
          'Cookie': token,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        if (data['success'] == true && data['data'] != null && data['data']['locations'] != null) {
          final String targetUserId = userId;
          final locations = data['data']['locations'] as List<dynamic>;

          // Конвертируем данные с сервера в объекты Post, оставляя только нужного пользователя
          List<Post> posts = [];

          for (var location in locations) {
            final String locationUserId = location['user_id']?.toString() ?? 'null';
            if (locationUserId != targetUserId) continue;

            final List<dynamic> photosList = location['photos'] as List<dynamic>? ?? [];
            List<String> imageUrls = [];
            List<String> originalImageUrls = [];
            List<String> photoIds = [];

            // Создаем список полных URL фотографий для отображения
            for (var photo in photosList) {
              // Собираем ID всех фотографий
              if (photo['id'] != null) {
                photoIds.add(photo['id'].toString());
              }
              
              // Обрабатываем cropped версию
              if (photo['file_path'] != null) {
                String relativePath = photo['file_path'];
                if (!relativePath.startsWith('http')) {
                  if (relativePath.startsWith('/travel/')) {
                    relativePath = relativePath.substring(7);
                  } else if (relativePath.startsWith('/')) {
                    relativePath = relativePath.substring(1);
                  }
                  String fullUrl = "${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}/${relativePath.replaceAll(RegExp(r'^/'), '')}";
                  imageUrls.add(fullUrl);
                } else {
                  imageUrls.add(relativePath);
                }
              }
              
              // Обрабатываем оригинальную версию
              String? originalPath = photo['original_file_path'] ?? photo['file_path'];
              if (originalPath != null) {
                if (!originalPath.startsWith('http')) {
                  if (originalPath.startsWith('/travel/')) {
                    originalPath = originalPath.substring(7);
                  } else if (originalPath.startsWith('/')) {
                    originalPath = originalPath.substring(1);
                  }
                  String fullUrl = "${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}/${originalPath.replaceAll(RegExp(r'^/'), '')}";
                  originalImageUrls.add(fullUrl);
                } else {
                  originalImageUrls.add(originalPath);
                }
              }
            }

            // Если у локации есть хотя бы одна фотография, создаем пост
            if (photosList.isNotEmpty) {
              // Используем ID первой фотографии как ID поста
              String postId = photosList[0]['id'].toString();

              // AppLogger.log("PostService.getUserPosts: Creating post with photo ID $postId filtered by user $targetUserId");

              Post post = Post(
                id: postId,
                user: locationUserId,
                title: photosList[0]['title'] ?? '',
                description: location['description'] ?? '',
                locationName: location['title'] ?? 'Untitled',
                location: GeoLocation(
                  latitude: double.parse(location['latitude'].toString()),
                  longitude: double.parse(location['longitude'].toString()),
                ),
                images: [],
                imageUrls: imageUrls,
                originalImageUrls: originalImageUrls,
                photoIds: photoIds,
                createdAt: DateTime.parse(location['created_at']),
              );

              posts.add(post);
            }
          }

          return posts;
        }
      }
      return [];
    } catch (e) {
      AppLogger.log('Error fetching user posts: $e');
      return [];
    }
  }
  
  // Удаление поста
  static Future<bool> deletePost(String postId) async {
    try {
      final token = await AuthService.getToken();
      AppLogger.log('Attempting to delete post with photo ID: $postId');

      // 1) Получаем информацию о фото, чтобы быстро найти locationId
      final photoInfoResponse = await http.get(
        Uri.parse('${ApiConfig.getPhotoInfo}?photo_id=$postId'),
        headers: {
          'Cookie': token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (photoInfoResponse.statusCode != 200) {
        AppLogger.log('Failed to get photo info for deletion: ${photoInfoResponse.statusCode} ${photoInfoResponse.body}');
        throw Exception('Failed to get photo info');
      }

      final photoInfo = jsonDecode(photoInfoResponse.body);
      if (photoInfo['success'] != true || photoInfo['photo'] == null || photoInfo['photo']['locationId'] == null) {
        AppLogger.log('Photo info response invalid or missing locationId: ${photoInfoResponse.body}');
        return false;
      }

      final String locationId = photoInfo['photo']['locationId'].toString();
      AppLogger.log('Found location ID for deletion via photo info: $locationId');

      // 2) Удаляем локацию по найденному ID
      final deleteResponse = await http.delete(
        Uri.parse('${ApiConfig.deleteLocation}?id=$locationId'),
        headers: {
          'Cookie': token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );

      if (deleteResponse.statusCode == 200) {
        final deleteData = jsonDecode(deleteResponse.body);
        final bool ok = deleteData['success'] == true;

        if (ok) {
          // 3) Инвалидируем кэш постов, чтобы лента обновилась корректно
          await _invalidatePostsCache();
        }

        AppLogger.log('Delete response: ${deleteResponse.body}');
        return ok;
      } else {
        AppLogger.log('Failed to delete location: ${deleteResponse.statusCode} ${deleteResponse.body}');
        throw Exception('Server error on delete');
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при удалении поста: $e');
      throw Exception('Сервер вернул ошибку при удалении поста');
    }
  }
  
  // Обновление существующего поста
  static Future<Map<String, dynamic>> updatePost(Post updatedPost) async {
    try {
      final token = await AuthService.getToken();
      
      AppLogger.log('Attempting to update post with photo ID: ${updatedPost.id}');
      
      // 1. Получаем все локации для поиска нужной
      final infoResponse = await http.get(
        Uri.parse(ApiConfig.getAllLocations),
        headers: {
          'Cookie': token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      
      if (infoResponse.statusCode != 200) {
        AppLogger.log('Failed to get locations: ${infoResponse.statusCode} ${infoResponse.body}');
        return {'success': false, 'error': 'Не удалось получить список локаций'};
      }
      
      final infoData = jsonDecode(infoResponse.body);
      if (!infoData['success'] || infoData['data'] == null || infoData['data']['locations'] == null) {
        return {'success': false, 'error': 'Неверный формат ответа от сервера'};
      }
      
      // Поиск локации. Сначала пытаемся найти по ID фотографии
      final locations = infoData['data']['locations'] as List<dynamic>;
      String? locationId;
      
      for (var location in locations) {
        final photos = location['photos'] as List<dynamic>? ?? [];
        for (var photo in photos) {
          if (photo['id'].toString() == updatedPost.id) {
            locationId = location['id'].toString();
            break;
          }
        }
        if (locationId != null) break;
      }
      
      // Фоллбэк: если не нашли по photoId, ищем по пользователю, названию и близости координат
      if (locationId == null) {
        AppLogger.log('No location found for photo ID ${updatedPost.id}. Fallback by user/location name/coords.');
        double bestScore = double.infinity;
        String? bestId;
        
        for (var location in locations) {
          final String locationUserId = location['user_id']?.toString() ?? '';
          if (locationUserId != updatedPost.user) continue; // Сначала учитываем владельца
          
          final String locTitle = (location['title'] ?? '').toString();
          final bool sameName = locTitle.toLowerCase() == updatedPost.locationName.toLowerCase();
          
          final double lat = double.tryParse(location['latitude'].toString()) ?? 0.0;
          final double lng = double.tryParse(location['longitude'].toString()) ?? 0.0;
          final double distance = _calculateDistance(
            updatedPost.location.latitude, updatedPost.location.longitude,
            lat, lng,
          );
          
          // Приоритет отдаем совпадению названия; иначе добавляем большой штраф
          final double score = sameName ? distance : distance + 1000000.0;
          
          if (score < bestScore) {
            bestScore = score;
            bestId = location['id'].toString();
          }
        }
        
        // Принимаем кандидата, если он достаточно близко (<= 2000м) или название совпало
        if (bestId != null && bestScore < 2000.0 + 1e-6) {
          locationId = bestId;
        }
      }
      
      if (locationId == null) {
        AppLogger.log('No location match by fallback for user ${updatedPost.user} at ${updatedPost.location.latitude}, ${updatedPost.location.longitude} (${updatedPost.locationName})');
        return {'success': false, 'error': 'Не удалось найти локацию для этой фотографии'};
      }
      
      AppLogger.log('Found location ID for update: $locationId');
      
      // 2. Если у поста есть новые изображения, загружаем их
      bool hasNewImages = false;
      List<String> newImageUrls = [];
      if (updatedPost.images.isNotEmpty) {
        for (final image in updatedPost.images) {
          final uploadResult = await _uploadPhoto(image, locationId, title: updatedPost.title, description: updatedPost.description, originalImage: null);
          if (!uploadResult['success']) {
            AppLogger.log('Failed to upload new image: ${uploadResult['message']}');
            return {'success': false, 'error': 'Failed to upload new images'};
          }
          
          if (uploadResult['photo'] != null && uploadResult['photo']['filePath'] != null) {
            newImageUrls.add(uploadResult['photo']['filePath']);
            AppLogger.log('New image uploaded: ${uploadResult['photo']['filePath']}');
          }
          
          hasNewImages = true;
        }
      }
      
      // Объединяем существующие URL с новыми
      final List<String> finalImageUrls = [...updatedPost.imageUrls, ...newImageUrls];
      AppLogger.log('Final image URLs for update: $finalImageUrls');
      
      // 3. Обновляем локацию на сервере
      final response = await http.post(
        Uri.parse(ApiConfig.editLocation),
        headers: {
          'Cookie': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'id': locationId, // Используем ID локации, а не фотографии
          'title': updatedPost.locationName,
          'description': updatedPost.description,
          'latitude': updatedPost.location.latitude,
          'longitude': updatedPost.location.longitude,
          'imageUrls': finalImageUrls,
        }),
      );
      
      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        
        if (result['success'] == true) {
          if (hasNewImages) {
            await Future.delayed(Duration(seconds: 1));
            final updatedResponse = await http.get(
              Uri.parse('${ApiConfig.getPhotoInfo}?id=${updatedPost.id}'),
              headers: {
                'Cookie': token,
                'Content-Type': 'application/json',
              },
            );
            AppLogger.log('Получены обновленные данные фото: ${updatedResponse.statusCode} ${updatedResponse.body}');
          }
          
          // Инвалидируем кеш постов после успешного обновления
          await _invalidatePostsCache();
          AppLogger.log('✅ Кеш постов инвалидирован после обновления поста');
          
          return {'success': true, 'message': 'Post updated successfully'};
        } else {
          return {'success': false, 'error': result['message'] ?? 'Failed to update location'};
        }
      } else {
        AppLogger.log('Failed to update location: ${response.statusCode} ${response.body}');
        return {'success': false, 'error': 'Failed to update location'};
      }
    } catch (e) {
      AppLogger.log('Error updating post: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // Получение всех постов в определенной локации
  static Future<List<Post>> getPostsByLocationId(String locationId) async {
    try {
      final token = await AuthService.getToken();
      
      
      // Получаем все локации и фильтруем по ID
      final response = await http.get(
        Uri.parse(ApiConfig.getAllLocations),
        headers: {
          'Cookie': token,
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null && data['data']['locations'] != null) {
          final locations = data['data']['locations'] as List<dynamic>;
          AppLogger.log('📊 PostService.getPostsByLocationId: Found ${locations.length} locations');
          
          // Находим локацию с нужным ID
          final locationData = locations.firstWhere(
            (location) => location['id'].toString() == locationId,
            orElse: () => null
          );
          
          if (locationData == null) {
            return [];
          }
          
          AppLogger.log('✅ PostService.getPostsByLocationId: Found location: ${locationData['title']} (ID: ${locationData['id']})');
          
          // Получаем все посты в этой локации
          List<Post> posts = [];
          
          // Получаем список фотографий в этой локации
          final List<dynamic> photosList = locationData['photos'] as List<dynamic>? ?? [];
          AppLogger.log('📸 PostService.getPostsByLocationId: Location has ${photosList.length} photos');
          
          // ИЗМЕНЕНИЕ: Добавляем проверку на наличие фотографий
          if (photosList.isEmpty) {
            AppLogger.log('⚠️ PostService.getPostsByLocationId: No photos found in location $locationId');
            return [];
          }
          
          // ИЗМЕНЕНИЕ: Создаем по одному посту для КАЖДОЙ фотографии, а не для каждого пользователя
          for (var photo in photosList) {
            final userId = photo['user_id']?.toString() ?? '';
            final photoId = photo['id'].toString();
            
            AppLogger.log('👤 Processing photo ID $photoId from user $userId');
            
            // ИЗМЕНЕНИЕ: Проверка на валидность ID фотографии
            if (photoId.isEmpty) {
              AppLogger.log('⚠️ Warning: Empty photo ID, skipping');
              continue;
            }
            
            // Формируем URL фотографии (cropped)
            String imageUrl = "";
            if (photo['file_path'] != null) {
              String relativePath = photo['file_path'];
              // Проверяем, начинается ли путь со слеша или http
              if (!relativePath.startsWith('http')) {
                // Проверяем на дублирование /travel в пути
                if (relativePath.startsWith('/travel/')) {
                  // Убираем '/travel' из начала пути, так как он уже есть в baseUrl
                  relativePath = relativePath.substring(7); // длина '/travel' = 7
                } else if (relativePath.startsWith('/')) {
                  // Просто убираем начальный слеш
                  relativePath = relativePath.substring(1);
                }
                
                // Формируем полный URL, избегая двойных слешей
                String fullUrl = "${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}/${relativePath.replaceAll(RegExp(r'^/'), '')}";
                imageUrl = fullUrl;
                AppLogger.log("Location photo URL constructed: $fullUrl");
              } else {
                // Если уже полный URL
                imageUrl = relativePath;
                AppLogger.log("Location photo URL already complete: $relativePath");
              }
            } else {
              // ИЗМЕНЕНИЕ: Если URL фотографии не найден, пропускаем
              AppLogger.log('⚠️ Warning: No file_path for photo ID $photoId, skipping');
              continue;
            }
            
            // Формируем URL оригинального фото
            String originalImageUrl = "";
            String? originalPath = photo['original_file_path'] ?? photo['file_path'];
            if (originalPath != null) {
              if (!originalPath.startsWith('http')) {
                if (originalPath.startsWith('/travel/')) {
                  originalPath = originalPath.substring(7);
                } else if (originalPath.startsWith('/')) {
                  originalPath = originalPath.substring(1);
                }
                originalImageUrl = "${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}/${originalPath.replaceAll(RegExp(r'^/'), '')}";
              } else {
                originalImageUrl = originalPath;
              }
            }
            
            // Создаем пост для этой фотографии
            Post post = Post(
              id: photoId, // Используем ID фотографии
              user: userId,
              title: photo['title'] ?? '',
              description: locationData['description'] ?? '',
              locationName: locationData['title'] ?? 'Без названия',
              location: GeoLocation(
                latitude: double.parse(locationData['latitude'].toString()),
                longitude: double.parse(locationData['longitude'].toString()),
              ),
              images: [], // Пустой список файлов, так как работаем с URL
              imageUrls: [imageUrl], // Список URL для отображения - cropped
              originalImageUrls: originalImageUrl.isNotEmpty ? [originalImageUrl] : [imageUrl], // Оригинал для галереи
              createdAt: DateTime.parse(locationData['created_at']),
            );
            
            posts.add(post);
            AppLogger.log('✅ Created post with ID $photoId for location $locationId');
          }
          
          
          // ИЗМЕНЕНИЕ: Логируем подробности в случае если постов не найдено
          if (posts.isEmpty) {
            AppLogger.log('⚠️ Warning: No valid posts could be created for location $locationId despite having ${photosList.length} photos');
          }
          
          return posts;
        }
      }
      return [];
    } catch (e) {
      AppLogger.log('❌ Error fetching posts by location ID: $e');
      return [];
    }
  }

  // Получение locationId по photoId
  static Future<String?> getLocationIdByPhotoId(String photoId) async {
    try {
      final token = await AuthService.getToken();
      
      
      // Получаем все локации
      final response = await http.get(
        Uri.parse(ApiConfig.getAllLocations),
        headers: {
          'Cookie': token,
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null && data['data']['locations'] != null) {
          final locations = data['data']['locations'] as List<dynamic>;
          AppLogger.log('📊 getLocationIdByPhotoId: Got ${locations.length} locations from API');
          
          // Поиск локации, содержащей фото с указанным ID
          for (var location in locations) {
            final photos = location['photos'] as List<dynamic>? ?? [];
            AppLogger.log('📸 Checking location ${location['id']} with ${photos.length} photos');
            
            for (var photo in photos) {
              AppLogger.log('  - Photo ID: ${photo['id']}, post photo ID: $photoId');
              
              // Проверяем различные варианты сравнения ID
              if (photo['id'].toString() == photoId || 
                  photo['id'].toString().contains(photoId) || 
                  photoId.contains(photo['id'].toString())) {
                final locationId = location['id'].toString();
                AppLogger.log('✅ PostService.getLocationIdByPhotoId: Found location ID: $locationId for photo ID: $photoId');
                return locationId;
              }
            }
          }
          
          // Если по ID не нашли, попробуем более сложную эвристику
          AppLogger.log('⚠️ PostService.getLocationIdByPhotoId: Exact ID match not found, attempting to get location by other means');
          
          // Попытаемся получить пост по этому ID
          final Post? post = await _getPostDetailsByPhotoId(photoId);
          
          if (post != null) {
            // Поиск локации по координатам
            for (var location in locations) {
              final lat = double.parse(location['latitude'].toString());
              final lng = double.parse(location['longitude'].toString());
              
              // Проверяем приблизительное совпадение координат
              if ((lat - post.location.latitude).abs() < 0.0001 && 
                  (lng - post.location.longitude).abs() < 0.0001) {
                final locationId = location['id'].toString();
                AppLogger.log('✅ PostService.getLocationIdByPhotoId: Found location by coordinates: $locationId');
                return locationId;
              }
            }
          }
          
          AppLogger.log('⚠️ PostService.getLocationIdByPhotoId: No location found for photo ID $photoId after checking all locations');
          return null;
        }
      }
      
      AppLogger.log('❌ PostService.getLocationIdByPhotoId: Failed to get location data, status: ${response.statusCode}');
      return null;
    } catch (e) {
      AppLogger.log('❌ Error finding location ID by photo ID: $e');
      return null;
    }
  }
  
  // Вспомогательный метод для получения деталей поста по ID фотографии
  static Future<Post?> _getPostDetailsByPhotoId(String photoId) async {
    try {
      final allPosts = await getAllPosts();
      for (var post in allPosts) {
        if (post.id == photoId) {
          return post;
        }
      }
      return null;
    } catch (e) {
      AppLogger.log('❌ Error getting post details: $e');
      return null;
    }
  }
  
  // Получение всех постов из той же локации, что и указанный пост
  static Future<List<Post>> getPostsInSameLocation(Post post) async {
    try {
      
      // Получаем все посты
      final allPosts = await getAllPosts();
      // AppLogger.log('📊 PostService.getPostsInSameLocation: Got ${allPosts.length} total posts');
      
      // УЛУЧШЕННЫЙ ПОДХОД: Группируем ТОЛЬКО по имени локации и близости координат
      // но с увеличенным радиусом поиска до 2000 метров
      List<Post> result = [post]; // Начинаем с текущего поста
      
      // Закомментированы избыточные логи для уменьшения шума
      // AppLogger.log('🔎 Критерии поиска...');
      
      for (var otherPost in allPosts) {
        // Пропускаем текущий пост
        if (otherPost.id == post.id) continue;
        
        bool sameLocationName = otherPost.locationName.toLowerCase() == post.locationName.toLowerCase();
        
        // Вычисляем расстояние между постами
        double distance = _calculateDistance(
          post.location.latitude, post.location.longitude,
          otherPost.location.latitude, otherPost.location.longitude
        );
        bool closeByCoordinates = distance <= 2000; // Увеличиваем радиус до 2000 метров
        
        // Добавляем пост, если он имеет то же имя локации ИЛИ находится рядом
        if (sameLocationName || closeByCoordinates) {
          result.add(otherPost);
        }
      }
      
      
      if (result.length > 1) {
        // Сортируем по расстоянию, начиная с ближайших
        result.sort((a, b) {
          if (a.id == post.id) return -1; // Текущий пост всегда первый
          if (b.id == post.id) return 1;
          
          final distA = _calculateDistance(
            post.location.latitude, post.location.longitude,
            a.location.latitude, a.location.longitude
          );
          final distB = _calculateDistance(
            post.location.latitude, post.location.longitude,
            b.location.latitude, b.location.longitude
          );
          return distA.compareTo(distB);
        });
        
        // Избыточные логи закомментированы
        // AppLogger.log('✅ Returning ${result.length} posts sorted by distance');
        
        return result;
      }
      
      // Если нашли только один пост (текущий) - просто возвращаем
      // AppLogger.log('⚠️ No other posts found in same location');
      return [post];
    } catch (e) {
      AppLogger.log('❌ Error getting posts in same location: $e');
      return [post]; // Возвращаем хотя бы текущий пост в случае ошибки
    }
  }
  
  // Вспомогательный метод для расчета расстояния между координатами в метрах
  static double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const int earthRadius = 6371000; // радиус Земли в метрах
    
    // Перевод градусов в радианы
    final double phi1 = lat1 * pi / 180;
    final double phi2 = lat2 * pi / 180;
    final double deltaPhi = (lat2 - lat1) * pi / 180;
    final double deltaLambda = (lon2 - lon1) * pi / 180;
    
    // Формула гаверсинусов
    final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
                     cos(phi1) * cos(phi2) *
                     sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    
    return earthRadius * c; // Расстояние в метрах
  }
  
  // Получение постов по близким координатам
  static Future<List<Post>> getPostsByCoordinates(double lat, double lng, double radiusInDegrees) async {
    try {
      final token = await AuthService.getToken();
      
      
      // Получаем все локации
      final response = await http.get(
        Uri.parse(ApiConfig.getAllLocations),
        headers: {
          'Cookie': token,
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode != 200) {
        AppLogger.log('❌ PostService.getPostsByCoordinates: Failed to get locations, status: ${response.statusCode}');
        return [];
      }
      
      final data = jsonDecode(response.body);
      
      if (data['success'] != true || data['data'] == null || data['data']['locations'] == null) {
        AppLogger.log('❌ PostService.getPostsByCoordinates: Invalid response format');
        return [];
      }
      
      final locations = data['data']['locations'] as List<dynamic>;
      AppLogger.log('📊 PostService.getPostsByCoordinates: Checking ${locations.length} locations');
      
      // ИЗМЕНЕНИЕ: Создаем структуру для хранения локаций с их расстоянием до целевой точки
      List<Map<String, dynamic>> locationsByDistance = [];
      
      // Фильтруем локации по близости координат
      for (var location in locations) {
        final locationLat = double.parse(location['latitude'].toString());
        final locationLng = double.parse(location['longitude'].toString());
        
        // Рассчитываем точное расстояние в метрах
        final double distanceInMeters = _calculateDistance(lat, lng, locationLat, locationLng);
        
        // Определяем максимальный радиус поиска в метрах в зависимости от переданного параметра
        final maxDistanceMeters = radiusInDegrees <= 0.002 ? 200.0 : 500.0;
        
        // ИЗМЕНЕНИЕ: Более гибкий радиус поиска - сохраняем все локации в пределах заданного радиуса
        if (distanceInMeters <= maxDistanceMeters) {
          locationsByDistance.add({
            'location': location,
            'distance': distanceInMeters
          });
          
          AppLogger.log('📍 Location ${location['id']} added with distance: ${distanceInMeters.toStringAsFixed(2)}m (${locationLat}, ${locationLng})');
        } else if (distanceInMeters <= 1000) {
          // Выводим в лог близкие, но не включенные локации (для отладки)
          AppLogger.log('📌 Location ${location['id']} is nearby but not included: ${distanceInMeters.toStringAsFixed(2)}m (${locationLat}, ${locationLng})');
        }
      }
      
      // ИЗМЕНЕНИЕ: Сортируем локации по расстоянию (ближайшие первыми)
      locationsByDistance.sort((a, b) => (a['distance'] as double).compareTo(b['distance'] as double));
      
      
      if (locationsByDistance.isEmpty) {
        AppLogger.log('⚠️ No locations found within specified distance radius');
        return [];
      }
      
      // Получаем посты из всех близлежащих локаций
      List<Post> allPosts = [];
      
      // Обрабатываем все найденные локации в пределах установленного радиуса
      for (var locationInfo in locationsByDistance) {
        final location = locationInfo['location'];
        final distance = locationInfo['distance'];
        final locationId = location['id'].toString();
        
        AppLogger.log('🔄 Processing location ID $locationId at distance ${distance.toStringAsFixed(2)}m');
        
        final posts = await getPostsByLocationId(locationId);
        
        if (posts.isNotEmpty) {
          AppLogger.log('📸 Found ${posts.length} posts in location ID $locationId');
          // Добавляем все посты из этой локации, не фильтруя их
          allPosts.addAll(posts);
          
          // Логируем каждый добавленный пост для отладки
          for (var post in posts) {
            AppLogger.log('  - Added post ID ${post.id} from location $locationId');
          }
        } else {
          AppLogger.log('⚠️ No posts found in location ID $locationId despite matching distance criteria');
        }
      }
      
      // Удаляем возможные дубликаты по ID поста
      final uniquePosts = <String, Post>{};
      for (var post in allPosts) {
        uniquePosts[post.id] = post;
      }
      
      final result = uniquePosts.values.toList();
      
      AppLogger.log('📊 PostService.getPostsByCoordinates: Found ${result.length} unique posts from ${locationsByDistance.length} nearby locations');
      return result;
    } catch (e) {
      AppLogger.log('❌ Error getting posts by coordinates: $e');
      return [];
    }
  }

  // Публичный метод для вычисления расстояния между постами
  static double calculateDistanceBetweenPosts(Post post1, Post post2) {
    return _calculateDistance(
      post1.location.latitude, post1.location.longitude,
      post2.location.latitude, post2.location.longitude
    );
  }

  // Получение поста по ID
  static Future<Post?> getPostById(String postId) async {
    try {
      final token = await AuthService.getToken();
      
      
      // Получаем все локации и ищем фото с нужным ID
      final response = await http.get(
        Uri.parse(ApiConfig.getAllLocations),
        headers: {
          'Cookie': token,
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['data'] != null && data['data']['locations'] != null) {
          final locations = data['data']['locations'] as List<dynamic>;
          
          // Ищем фото с указанным ID среди всех локаций
          for (var location in locations) {
            final List<dynamic> photosList = location['photos'] as List<dynamic>? ?? [];
            
            for (var photo in photosList) {
              // Если найдено фото с указанным ID
              if (photo['id'].toString() == postId) {
                // AppLogger.log('✅ PostService.getPostById: Found photo with ID $postId in location ${location['id']}');
                
                // Собираем все photoIds из этой локации
                List<String> photoIds = [];
                for (var p in photosList) {
                  if (p['id'] != null) {
                    photoIds.add(p['id'].toString());
                  }
                }
                
                // Получаем URL фотографии (cropped)
                String imageUrl = "";
                if (photo['file_path'] != null) {
                  String relativePath = photo['file_path'];
                  if (!relativePath.startsWith('http')) {
                    // Проверяем на дублирование /travel в пути
                    if (relativePath.startsWith('/travel/')) {
                      relativePath = relativePath.substring(7);
                    } else if (relativePath.startsWith('/')) {
                      relativePath = relativePath.substring(1);
                    }
                    
                    imageUrl = "${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}/${relativePath.replaceAll(RegExp(r'^/'), '')}";
                  } else {
                    imageUrl = relativePath;
                  }
                }
                
                // Получаем URL оригинального фото
                String originalImageUrl = "";
                String? originalPath = photo['original_file_path'] ?? photo['file_path'];
                if (originalPath != null) {
                  if (!originalPath.startsWith('http')) {
                    if (originalPath.startsWith('/travel/')) {
                      originalPath = originalPath.substring(7);
                    } else if (originalPath.startsWith('/')) {
                      originalPath = originalPath.substring(1);
                    }
                    originalImageUrl = "${ApiConfig.baseUrl.replaceAll(RegExp(r'/$'), '')}/${originalPath.replaceAll(RegExp(r'^/'), '')}";
                  } else {
                    originalImageUrl = originalPath;
                  }
                }
                
                // Создаем объект Post
                final post = Post(
                  id: postId,
                  user: photo['user_id']?.toString() ?? '',
                  title: photo['title'] ?? '',
                  description: location['description'] ?? '',
                  locationName: location['title'] ?? 'Без названия',
                  location: GeoLocation(
                    latitude: double.parse(location['latitude'].toString()),
                    longitude: double.parse(location['longitude'].toString()),
                  ),
                  images: [], // Пустой список файлов
                  imageUrls: [imageUrl], // Список с URL фотографии - cropped
                  originalImageUrls: originalImageUrl.isNotEmpty ? [originalImageUrl] : [imageUrl], // Оригинал для галереи
                  photoIds: photoIds, // Все ID фотографий из локации
                  createdAt: DateTime.parse(location['created_at']),
                );
                
                return post;
              }
            }
          }
          
          AppLogger.log('⚠️ PostService.getPostById: Post with ID $postId not found');
        }
      } else {
        AppLogger.log('❌ PostService.getPostById: Error ${response.statusCode} - ${response.body}');
      }
      
      return null;
    } catch (e) {
      AppLogger.log('❌ PostService.getPostById: Exception: $e');
      return null;
    }
  }
} 