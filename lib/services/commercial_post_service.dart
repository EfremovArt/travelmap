import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import '../models/commercial_post.dart';
import '../utils/logger.dart';
import 'package:http_parser/http_parser.dart';
import 'auth_service.dart';

class CommercialPostService {
  static const String _baseUrl = ApiConfig.baseUrl;

  // ===== Кэш данных с TTL =====
  static const Duration _postsTtl = Duration(minutes: 10);

  static final Map<int, _AlbumPostsCacheEntry> _albumPostsCache = {};

  static bool _isFresh(DateTime ts) => DateTime.now().difference(ts) < _postsTtl;

  // ===== Стрим-уведомления об изменениях =====
  static final StreamController<int> _albumPostsChangedController =
      StreamController<int>.broadcast();

  static Stream<int> get albumPostsChangedStream => _albumPostsChangedController.stream;

  static void _notifyAlbumChanged(int albumId) {
    AppLogger.log('📣 Уведомляем подписчиков об изменениях в альбоме $albumId');
    _albumPostsChangedController.add(albumId);
  }

  static void invalidateAlbumCache(int albumId) {
    AppLogger.log('🧹 Инвалидация кэша коммерческих постов альбома $albumId');
    _albumPostsCache.remove(albumId);
    _notifyAlbumChanged(albumId);
  }

  static void _evictPostFromCachesById(int postId) {
    int? affectedAlbumId;
    _albumPostsCache.forEach((albumId, entry) {
      final beforeLen = entry.posts.length;
      entry.posts.removeWhere((p) => p.id == postId);
      if (entry.posts.length != beforeLen) {
        affectedAlbumId = albumId;
      }
    });
    if (affectedAlbumId != null) {
      _notifyAlbumChanged(affectedAlbumId!);
    }
  }

  /// Получить коммерческие посты для фото
  static Future<List<CommercialPost>> getCommercialPostsForPhoto(int photoId) async {
    try {
      final url = '$_baseUrl/commercial/get_posts_for_photo.php?photo_id=$photoId';
      // AppLogger.log('🌐 ЗАПРОС к API: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      // AppLogger.log('📡 ОТВЕТ сервера: ${response.statusCode}');
      // AppLogger.log('📄 ТЕЛО ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // AppLogger.log('📊 PARSED DATA: $data');
        if (data['success'] == true) {
          final posts = (data['posts'] as List)
              .map((post) => CommercialPost.fromJson(post))
              .toList();
          // AppLogger.log('✅ РЕЗУЛЬТАТ: ${posts.length} коммерческих постов для фото $photoId');
          return posts;
        } else {
          AppLogger.log('❌ API ОШИБКА: ${data['message']}');
          return [];
        }
      } else {
        AppLogger.log('❌ HTTP ОШИБКА: ${response.statusCode}, body: ${response.body}');
        return [];
      }
    } catch (e) {
      AppLogger.log('❌ EXCEPTION в getCommercialPostsForPhoto: $e');
      return [];
    }
  }

  /// Получить количество коммерческих постов для фото
  static Future<int> getCommercialPostsCountForPhoto(int photoId) async {
    try {
      final url = '$_baseUrl/commercial/get_count_for_photo.php?photo_id=$photoId';
      AppLogger.log('🌐 Запрос к API: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      AppLogger.log('📡 Ответ сервера: ${response.statusCode}');
      AppLogger.log('📄 Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final count = data['count'] ?? 0;
          AppLogger.log('✅ Количество коммерческих постов для фото $photoId: $count');
          return count;
        } else {
          AppLogger.log('❌ API вернул success: false, сообщение: ${data['message']}');
        }
      } else {
        AppLogger.log('❌ HTTP ошибка: ${response.statusCode}');
      }
      return 0;
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении количества коммерческих постов для фото: $e');
      return 0;
    }
  }

  /// Создать коммерческий пост для фото
  static Future<bool> createCommercialPostForPhoto({
    required int userId,
    required int photoId,
    required String title,
    String? description,
    String? imageUrl,
    double? price,
    String currency = 'USD',
    String? contactInfo,
  }) async {
    try {
      // Получаем заголовки с авторизацией
      final headers = AuthService().sessionHeaders;
      
      final response = await http.post(
        Uri.parse('$_baseUrl/commercial/create_post_for_photo.php'),
        headers: headers,
        body: json.encode({
          'user_id': userId,
          'photo_id': photoId,
          'title': title,
          'description': description,
          'image_url': imageUrl,
          'price': price,
          'currency': currency,
          'contact_info': contactInfo,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.log('✅ Коммерческий пост для фото создан успешно');
          return true;
        } else {
          AppLogger.log('❌ Ошибка создания коммерческого поста для фото: ${data['message']}');
          return false;
        }
      } else {
        AppLogger.log('❌ HTTP ошибка: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при создании коммерческого поста для фото: $e');
      return false;
    }
  }

  /// Создать коммерческий пост для фото с изображениями
  static Future<Map<String, dynamic>> createCommercialPostForPhotoWithImages({
    required int userId,
    required int photoId,
    required String title,
    String? description,
    List<File>? images,
    File? firstImageOriginal, // Original version of first image (before crop)
    double? price,
    String currency = 'USD',
    String? contactInfo,
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    try {
      AppLogger.log('🔄 Creating commercial post for photo with images...');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/commercial/create_post_for_photo_with_images.php'),
      );

      // Добавляем заголовки авторизации
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Cookie'] = token;
      }

      // Добавляем основные поля
      request.fields['user_id'] = userId.toString();
      request.fields['photo_id'] = photoId.toString();
      request.fields['title'] = title;
      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }
      if (price != null) {
        request.fields['price'] = price.toString();
      }
      request.fields['currency'] = currency;
      if (contactInfo != null && contactInfo.isNotEmpty) {
        request.fields['contact_info'] = contactInfo;
      }
      
      // Добавляем поля локации
      if (latitude != null && longitude != null) {
        request.fields['latitude'] = latitude.toString();
        request.fields['longitude'] = longitude.toString();
        if (locationName != null && locationName.isNotEmpty) {
          request.fields['location_name'] = locationName;
        }
      }

      // Добавляем изображения
      if (images != null && images.isNotEmpty) {
        for (int i = 0; i < images.length; i++) {
          final image = images[i];
          final fileName = 'commercial_photo_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          
          request.files.add(await http.MultipartFile.fromPath(
            'images[]',
            image.path,
            filename: fileName,
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      }
      
      // Добавляем оригинал первого изображения (для галереи)
      if (firstImageOriginal != null) {
        final fileName = 'commercial_photo_original_${DateTime.now().millisecondsSinceEpoch}_0.jpg';
        request.files.add(await http.MultipartFile.fromPath(
          'first_image_original',
          firstImageOriginal.path,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      AppLogger.log('📤 Отправка запроса на создание коммерческого поста для фото...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      AppLogger.log('📡 Ответ сервера: ${response.statusCode}');
      AppLogger.log('📄 Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.log('✅ Коммерческий пост для фото с изображениями создан успешно');
          return {
            'success': true,
            'message': data['message'] ?? 'Commercial post for photo created successfully',
            'post_id': data['post_id'],
            'images_count': data['images_count'] ?? 0,
          };
        } else {
          AppLogger.log('❌ Ошибка создания коммерческого поста для фото: ${data['message']}');
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to create commercial post for photo',
          };
        }
      } else {
        AppLogger.log('❌ HTTP ошибка: ${response.statusCode}');
        return {
          'success': false,
          'error': 'HTTP error: ${response.statusCode}',
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при создании коммерческого поста для фото: $e');
      return {
        'success': false,
        'error': 'Error creating commercial post for photo: $e',
      };
    }
  }

  /// Привязать существующий коммерческий пост к фото
  static Future<Map<String, dynamic>> attachPostToPhoto(int postId, int photoId) async {
    try {
      // Получаем заголовки с авторизацией
      final headers = AuthService().sessionHeaders;
      
      final response = await http.post(
        Uri.parse('$_baseUrl/commercial/attach_post_to_photo.php'),
        headers: headers,
        body: json.encode({
          'post_id': postId,
          'photo_id': photoId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.log('✅ Коммерческий пост $postId привязан к фото $photoId');
          return {'success': true};
        } else {
          AppLogger.log('❌ Ошибка привязки поста к фото: ${data['message']}');
          return {
            'success': false, 
            'error': data['message'] ?? 'Ошибка при привязке поста'
          };
        }
      } else {
        // Пытаемся получить сообщение об ошибке из ответа сервера
        String errorMessage = 'HTTP ошибка: ${response.statusCode}';
        try {
          final data = json.decode(response.body);
          if (data['message'] != null) {
            errorMessage = data['message'];
          }
        } catch (_) {}
        
        AppLogger.log('❌ HTTP ошибка при привязке поста к фото: ${response.statusCode}');
        AppLogger.log('📄 Тело ответа: ${response.body}');
        return {
          'success': false,
          'error': errorMessage
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при привязке коммерческого поста к фото: $e');
      return {
        'success': false,
        'error': 'Ошибка при привязке поста: $e'
      };
    }
  }

  /// Отвязать коммерческий пост от фото (удалить связь, но сохранить пост)
  static Future<Map<String, dynamic>> detachPostFromPhoto(int postId, int photoId) async {
    try {
      // Получаем заголовки с авторизацией
      final headers = AuthService().sessionHeaders;
      
      final url = '$_baseUrl/commercial/detach_post_from_photo.php';
      AppLogger.log('🌐 Запрос на отвязку поста: $url');
      AppLogger.log('📋 postId: $postId, photoId: $photoId');
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode({
          'post_id': postId,
          'photo_id': photoId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.log('✅ Коммерческий пост $postId отвязан от фото $photoId');
          return {'success': true};
        } else {
          AppLogger.log('❌ Ошибка отвязки поста от фото: ${data['message']}');
          return {
            'success': false, 
            'error': data['message'] ?? 'Ошибка при отвязке поста'
          };
        }
      } else {
        // Пытаемся получить сообщение об ошибке из ответа сервера
        String errorMessage = 'HTTP ошибка: ${response.statusCode}';
        try {
          final data = json.decode(response.body);
          if (data['message'] != null) {
            errorMessage = data['message'];
          }
        } catch (_) {}
        
        AppLogger.log('❌ HTTP ошибка при отвязке поста от фото: ${response.statusCode}');
        AppLogger.log('📄 Тело ответа: ${response.body}');
        return {
          'success': false,
          'error': errorMessage
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при отвязке коммерческого поста от фото: $e');
      return {
        'success': false,
        'error': 'Ошибка при отвязке поста: $e'
      };
    }
  }

  /// Привязать существующий коммерческий пост к альбому
  static Future<bool> attachPostToAlbum(int postId, int albumId) async {
    try {
      // Получаем заголовки с авторизацией
      final headers = AuthService().sessionHeaders;
      
      final response = await http.post(
        Uri.parse('$_baseUrl/commercial/attach_post_to_album.php'),
        headers: headers,
        body: json.encode({
          'post_id': postId,
          'album_id': albumId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.log('✅ Коммерческий пост $postId привязан к альбому $albumId');
          // Инвалидиуем кэш альбома
          invalidateAlbumCache(albumId);
          return true;
        } else {
          AppLogger.log('❌ Ошибка привязки поста к альбому: ${data['message']}');
          return false;
        }
      } else {
        AppLogger.log('❌ HTTP ошибка при привязке поста: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при привязке коммерческого поста к альбому: $e');
      return false;
    }
  }

  /// Отвязать коммерческий пост от альбома (удалить связь, но сохранить пост)
  static Future<Map<String, dynamic>> detachPostFromAlbum(int postId, int albumId) async {
    try {
      // Получаем заголовки с авторизацией
      final headers = AuthService().sessionHeaders;
      
      final url = '$_baseUrl/commercial/detach_post_from_album.php';
      AppLogger.log('🌐 Запрос на отвязку поста от альбома: $url');
      AppLogger.log('📋 postId: $postId, albumId: $albumId');
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode({
          'post_id': postId,
          'album_id': albumId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.log('✅ Коммерческий пост $postId отвязан от альбома $albumId');
          // Инвалидиуем кэш альбома
          invalidateAlbumCache(albumId);
          return {'success': true};
        } else {
          AppLogger.log('❌ Ошибка отвязки поста от альбома: ${data['message']}');
          return {
            'success': false, 
            'error': data['message'] ?? 'Ошибка при отвязке поста'
          };
        }
      } else {
        // Пытаемся получить сообщение об ошибке из ответа сервера
        String errorMessage = 'HTTP ошибка: ${response.statusCode}';
        try {
          final data = json.decode(response.body);
          if (data['message'] != null) {
            errorMessage = data['message'];
          }
        } catch (_) {}
        
        AppLogger.log('❌ HTTP ошибка при отвязке поста от альбома: ${response.statusCode}');
        AppLogger.log('📄 Тело ответа: ${response.body}');
        return {
          'success': false,
          'error': errorMessage
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при отвязке коммерческого поста от альбома: $e');
      return {
        'success': false,
        'error': 'Ошибка при отвязке поста: $e'
      };
    }
  }

  /// Привязать существующий коммерческий пост к обложке альбома
  static Future<Map<String, dynamic>> attachPostToCover(int postId, int coverId) async {
    try {
      // Получаем заголовки с авторизацией
      final headers = AuthService().sessionHeaders;
      
      final response = await http.post(
        Uri.parse('$_baseUrl/commercial/attach_post_to_cover.php'),
        headers: headers,
        body: json.encode({
          'post_id': postId,
          'cover_id': coverId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.log('✅ Коммерческий пост $postId привязан к обложке $coverId');
          return {'success': true};
        } else {
          AppLogger.log('❌ Ошибка привязки поста к обложке: ${data['message']}');
          return {
            'success': false, 
            'error': data['message'] ?? 'Ошибка при привязке поста'
          };
        }
      } else {
        String errorMessage = 'HTTP ошибка: ${response.statusCode}';
        try {
          final data = json.decode(response.body);
          if (data['message'] != null) {
            errorMessage = data['message'];
          }
        } catch (_) {}
        
        AppLogger.log('❌ HTTP ошибка при привязке поста к обложке: ${response.statusCode}');
        AppLogger.log('📄 Тело ответа: ${response.body}');
        return {
          'success': false,
          'error': errorMessage
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при привязке коммерческого поста к обложке: $e');
      return {
        'success': false,
        'error': 'Ошибка при привязке поста: $e'
      };
    }
  }

  /// Отвязать коммерческий пост от обложки альбома (удалить связь, но сохранить пост)
  static Future<Map<String, dynamic>> detachPostFromCover(int postId, int coverId) async {
    try {
      // Получаем заголовки с авторизацией
      final headers = AuthService().sessionHeaders;
      
      final url = '$_baseUrl/commercial/detach_post_from_cover.php';
      AppLogger.log('🌐 Запрос на отвязку поста от обложки: $url');
      AppLogger.log('📋 postId: $postId, coverId: $coverId');
      
      final response = await http.post(
        Uri.parse(url),
        headers: headers,
        body: json.encode({
          'post_id': postId,
          'cover_id': coverId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.log('✅ Коммерческий пост $postId отвязан от обложки $coverId');
          return {'success': true};
        } else {
          AppLogger.log('❌ Ошибка отвязки поста от обложки: ${data['message']}');
          return {
            'success': false, 
            'error': data['message'] ?? 'Ошибка при отвязке поста'
          };
        }
      } else {
        String errorMessage = 'HTTP ошибка: ${response.statusCode}';
        try {
          final data = json.decode(response.body);
          if (data['message'] != null) {
            errorMessage = data['message'];
          }
        } catch (_) {}
        
        AppLogger.log('❌ HTTP ошибка при отвязке поста от обложки: ${response.statusCode}');
        AppLogger.log('📄 Тело ответа: ${response.body}');
        return {
          'success': false,
          'error': errorMessage
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при отвязке коммерческого поста от обложки: $e');
      return {
        'success': false,
        'error': 'Ошибка при отвязке поста: $e'
      };
    }
  }

  /// Получить standalone коммерческие посты пользователя (без альбома)
  static Future<List<CommercialPost>> getStandaloneCommercialPosts(int userId) async {
    try {
      AppLogger.log('🔄 Загрузка standalone постов для пользователя $userId');
      
      final response = await http.get(
        Uri.parse('$_baseUrl/commercial/get_standalone_posts.php?user_id=$userId'),
      );

      AppLogger.log('📡 Ответ сервера: ${response.statusCode}');
      AppLogger.log('📄 Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.log('📊 Parsed data: $data');
        
        if (data != null && data['success'] == true && data['posts'] is List) {
          final posts = <CommercialPost>[];
          final postsList = data['posts'] as List;
          
          for (int i = 0; i < postsList.length; i++) {
            try {
              final postJson = postsList[i];
              if (postJson != null && postJson is Map<String, dynamic>) {
                final post = CommercialPost.fromJson(postJson);
                posts.add(post);
              } else {
                AppLogger.log('⚠️ Пропускаем некорректный пост на позиции $i: $postJson');
              }
            } catch (e) {
              AppLogger.log('❌ Ошибка парсинга поста на позиции $i: $e');
            }
          }
          
          AppLogger.log('✅ Загружено ${posts.length} standalone постов');
          return posts;
        } else {
          AppLogger.log('❌ Некорректные данные от сервера: $data');
        }
      } else {
        AppLogger.log('❌ HTTP ошибка: ${response.statusCode}');
      }
      
      return [];
    } catch (e) {
      AppLogger.log('❌ Критическая ошибка при загрузке standalone постов: $e');
      return [];
    }
  }

  /// Получить все коммерческие посты для альбома
  static Future<List<CommercialPost>> getCommercialPostsForAlbum(int albumId) async {
    try {
      // Отдаём из кэша, если свежий
      final cached = _albumPostsCache[albumId];
      if (cached != null && _isFresh(cached.fetchedAt)) {
        AppLogger.log('💾 КЭШ: ${cached.posts.length} постов для альбома $albumId (свежий)');
        return cached.posts;
      }

      final url = '$_baseUrl/commercial/get_posts.php?album_id=$albumId';
      // AppLogger.log('🌐 ЗАПРОС к API: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      // AppLogger.log('📡 ОТВЕТ сервера: ${response.statusCode}');
      // AppLogger.log('📄 ТЕЛО ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        // AppLogger.log('📊 PARSED DATA: $data');
        if (data['success'] == true) {
          final posts = (data['posts'] as List)
              .map((post) => CommercialPost.fromJson(post))
              .toList();
          // AppLogger.log('✅ РЕЗУЛЬТАТ: ${posts.length} коммерческих постов для альбома $albumId');
          // Обновляем кэш
          _albumPostsCache[albumId] = _AlbumPostsCacheEntry(posts: posts, fetchedAt: DateTime.now());
          return posts;
        } else {
          AppLogger.log('❌ API ОШИБКА: ${data['message']}');
          return [];
        }
      } else {
        AppLogger.log('❌ HTTP ОШИБКА: ${response.statusCode}, body: ${response.body}');
        return [];
      }
    } catch (e) {
      AppLogger.log('❌ EXCEPTION в getCommercialPostsForAlbum: $e');
      return [];
    }
  }

  /// Получить количество коммерческих постов для альбома
  static Future<int> getCommercialPostsCount(int albumId) async {
    try {
      // Если кэш свежий — считаем из него
      final cached = _albumPostsCache[albumId];
      if (cached != null && _isFresh(cached.fetchedAt)) {
        AppLogger.log('💾 КЭШ COUNT: ${cached.posts.length} для альбома $albumId');
        return cached.posts.length;
      }

      final url = '$_baseUrl/commercial/get_count.php?album_id=$albumId';
      AppLogger.log('🌐 Запрос к API: $url');
      
      final response = await http.get(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
      );

      AppLogger.log('📡 Ответ сервера: ${response.statusCode}');
      AppLogger.log('📄 Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final count = data['count'] ?? 0;
          AppLogger.log('✅ Количество коммерческих постов для альбома $albumId: $count');
          return count;
        } else {
          AppLogger.log('❌ API вернул success: false, сообщение: ${data['message']}');
        }
      } else {
        AppLogger.log('❌ HTTP ошибка: ${response.statusCode}');
      }
      return 0;
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении количества коммерческих постов: $e');
      return 0;
    }
  }

  /// Создать новый коммерческий пост
  static Future<bool> createCommercialPost({
    required int userId,
    required int albumId,
    required String title,
    String? description,
    String? imageUrl,
    double? price,
    String currency = 'USD',
  }) async {
    try {
      // Получаем заголовки с авторизацией
      final headers = AuthService().sessionHeaders;
      
      final response = await http.post(
        Uri.parse('$_baseUrl/commercial/create_post.php'),
        headers: headers,
        body: json.encode({
          'user_id': userId,
          'album_id': albumId,
          'title': title,
          'description': description,
          'image_url': imageUrl,
          'price': price,
          'currency': currency,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.log('✅ Коммерческий пост создан успешно');
          // Инвалидиуем кэш альбома и уведомляем подписчиков
          invalidateAlbumCache(albumId);
          return true;
        } else {
          AppLogger.log('❌ Ошибка создания коммерческого поста: ${data['message']}');
          return false;
        }
      } else {
        AppLogger.log('❌ HTTP ошибка: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при создании коммерческого поста: $e');
      return false;
    }
  }

  /// Создать коммерческий пост без привязки к альбому
  static Future<Map<String, dynamic>> createStandaloneCommercialPost({
    required int userId,
    required String title,
    String? description,
    List<File>? images,
    File? firstImageOriginal, // Original version of first image (before crop)
    double? price,
    String currency = 'USD',
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    try {
      AppLogger.log('🔄 Creating standalone commercial post...');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/commercial/create_post_standalone.php'),
      );

      // Добавляем заголовки авторизации
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Cookie'] = token;
      }

      // Добавляем основные поля (без album_id)
      request.fields['user_id'] = userId.toString();
      request.fields['title'] = title;
      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }
      if (price != null) {
        request.fields['price'] = price.toString();
      }
      request.fields['currency'] = currency;
      
      // Добавляем поля локации
      if (latitude != null && longitude != null) {
        request.fields['latitude'] = latitude.toString();
        request.fields['longitude'] = longitude.toString();
        if (locationName != null && locationName.isNotEmpty) {
          request.fields['location_name'] = locationName;
        }
      }

      // Добавляем изображения
      if (images != null && images.isNotEmpty) {
        for (int i = 0; i < images.length; i++) {
          final image = images[i];
          final fileName = 'commercial_image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          
          request.files.add(await http.MultipartFile.fromPath(
            'images[]',
            image.path,
            filename: fileName,
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      }
      
      // Добавляем оригинал первого изображения (для галереи)
      if (firstImageOriginal != null) {
        final fileName = 'commercial_image_original_${DateTime.now().millisecondsSinceEpoch}_0.jpg';
        request.files.add(await http.MultipartFile.fromPath(
          'first_image_original',
          firstImageOriginal.path,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      AppLogger.log('📤 Отправка запроса на создание standalone коммерческого поста...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      AppLogger.log('📡 Ответ сервера: ${response.statusCode}');
      AppLogger.log('📄 Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.log('✅ Standalone коммерческий пост создан успешно');
          return {
            'success': true,
            'post_id': data['post_id'],
            'images_count': data['images_count'] ?? 0,
          };
        } else {
          AppLogger.log('❌ Ошибка создания standalone коммерческого поста: ${data['message']}');
          return {
            'success': false,
            'error': data['message'] ?? 'Unknown error',
          };
        }
      } else {
        AppLogger.log('❌ HTTP ошибка: ${response.statusCode}');
        return {
          'success': false,
          'error': 'Server error: ${response.statusCode}',
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при создании standalone коммерческого поста: $e');
      return {
        'success': false,
        'error': e.toString(),
      };
    }
  }

  /// Создать новый коммерческий пост с изображениями
  static Future<Map<String, dynamic>> createCommercialPostWithImages({
    required int userId,
    required int albumId,
    required String title,
    String? description,
    List<File>? images,
    File? firstImageOriginal, // Original version of first image (before crop)
    double? price,
    String currency = 'USD',
    double? latitude,
    double? longitude,
    String? locationName,
  }) async {
    try {
      AppLogger.log('🔄 Creating commercial post with images...');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/commercial/create_post_with_images.php'),
      );

      // Добавляем заголовки авторизации
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Cookie'] = token;
      }

      // Добавляем основные поля
      request.fields['user_id'] = userId.toString();
      request.fields['album_id'] = albumId.toString();
      request.fields['title'] = title;
      if (description != null && description.isNotEmpty) {
        request.fields['description'] = description;
      }
      if (price != null) {
        request.fields['price'] = price.toString();
      }
      request.fields['currency'] = currency;
      
      // Добавляем поля локации
      if (latitude != null && longitude != null) {
        request.fields['latitude'] = latitude.toString();
        request.fields['longitude'] = longitude.toString();
        if (locationName != null && locationName.isNotEmpty) {
          request.fields['location_name'] = locationName;
        }
      }

      // Добавляем изображения
      if (images != null && images.isNotEmpty) {
        for (int i = 0; i < images.length; i++) {
          final image = images[i];
          final fileName = 'commercial_image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          
          request.files.add(await http.MultipartFile.fromPath(
            'images[]',
            image.path,
            filename: fileName,
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      }
      
      // Добавляем оригинал первого изображения (для галереи)
      if (firstImageOriginal != null) {
        final fileName = 'commercial_image_original_${DateTime.now().millisecondsSinceEpoch}_0.jpg';
        request.files.add(await http.MultipartFile.fromPath(
          'first_image_original',
          firstImageOriginal.path,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'),
        ));
      }

      AppLogger.log('📤 Отправка запроса на создание коммерческого поста...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      AppLogger.log('📡 Ответ сервера: ${response.statusCode}');
      AppLogger.log('📄 Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.log('✅ Коммерческий пост с изображениями создан успешно');
          // Инвалидиуем кэш альбома и уведомляем подписчиков
          invalidateAlbumCache(albumId);
          return {
            'success': true,
            'message': data['message'] ?? 'Commercial post created successfully',
            'post_id': data['post_id'],
            'images_count': data['images_count'] ?? 0,
          };
        } else {
          AppLogger.log('❌ Ошибка создания коммерческого поста: ${data['message']}');
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to create commercial post',
          };
        }
      } else {
        AppLogger.log('❌ HTTP ошибка: ${response.statusCode}');
        return {
          'success': false,
          'error': 'HTTP error: ${response.statusCode}',
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при создании коммерческого поста: $e');
      return {
        'success': false,
        'error': 'Error creating commercial post: $e',
      };
    }
  }

  /// Удалить коммерческий пост
  static Future<bool> deleteCommercialPost(int postId, int userId) async {
    try {
      // Получаем заголовки с авторизацией
      final headers = AuthService().sessionHeaders;
      
      final response = await http.delete(
        Uri.parse('$_baseUrl/commercial/delete_post.php'),
        headers: headers,
        body: json.encode({
          'id': postId,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.log('✅ Коммерческий пост удален успешно');
          // Пытаемся удалить пост из кэша и уведомить конкретный альбом
          _evictPostFromCachesById(postId);
          return true;
        } else {
          AppLogger.log('❌ Ошибка удаления коммерческого поста: ${data['message']}');
          return false;
        }
      } else {
        AppLogger.log('❌ HTTP ошибка: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при удалении коммерческого поста: $e');
      return false;
    }
  }

  /// Обновить коммерческий пост
  static Future<Map<String, dynamic>> updateCommercialPost({
    required int postId,
    required String title,
    String? description,
    List<File>? newImages,
    List<String>? existingImageUrls,
  }) async {
    try {
      AppLogger.log('🔄 Обновление коммерческого поста ID: $postId');

      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/commercial/update_post.php'),
      );

      // Добавляем заголовки авторизации
      final token = await AuthService.getToken();
      if (token != null && token.isNotEmpty) {
        request.headers['Cookie'] = token;
      }

      // Добавляем основные поля
      request.fields['id'] = postId.toString();
      request.fields['title'] = title;
      if (description != null) request.fields['description'] = description;

      // Добавляем существующие URL изображений
      if (existingImageUrls != null && existingImageUrls.isNotEmpty) {
        request.fields['existing_image_urls'] = json.encode(existingImageUrls);
      }

      // Добавляем новые изображения
      if (newImages != null) {
        for (int i = 0; i < newImages.length; i++) {
          final image = newImages[i];
          final fileName = 'commercial_image_${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
          
          request.files.add(await http.MultipartFile.fromPath(
            'new_images[]',
            image.path,
            filename: fileName,
            contentType: MediaType('image', 'jpeg'),
          ));
        }
      }

      AppLogger.log('📤 Отправка запроса на обновление коммерческого поста...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      AppLogger.log('📡 Ответ сервера: ${response.statusCode}');
      AppLogger.log('📄 Тело ответа: ${response.body}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          AppLogger.log('✅ Коммерческий пост обновлен успешно');
          // Обновляем пост в кэше, если он там есть
          _albumPostsCache.forEach((albumId, entry) {
            final index = entry.posts.indexWhere((p) => p.id == postId);
            if (index != -1) {
              final old = entry.posts[index];
              entry.posts[index] = CommercialPost(
                id: old.id,
                userId: old.userId,
                albumId: old.albumId,
                photoId: old.photoId,
                type: old.type,
                title: title,
                description: description ?? old.description,
                imageUrl: old.imageUrl,
                imageUrls: existingImageUrls ?? old.imageUrls,
                price: old.price,
                currency: old.currency,
                contactInfo: old.contactInfo,
                isActive: old.isActive,
                createdAt: old.createdAt,
                updatedAt: DateTime.now(),
                userName: old.userName,
                userProfileImage: old.userProfileImage,
                albumTitle: old.albumTitle,
              );
              _notifyAlbumChanged(albumId);
            }
          });
          return {
            'success': true,
            'message': data['message'] ?? 'Commercial post updated successfully',
          };
        } else {
          AppLogger.log('❌ Ошибка обновления коммерческого поста: ${data['message']}');
          return {
            'success': false,
            'error': data['message'] ?? 'Failed to update commercial post',
          };
        }
      } else {
        AppLogger.log('❌ HTTP ошибка: ${response.statusCode}');
        // Пытаемся получить сообщение об ошибке из ответа
        try {
          final errorData = json.decode(response.body);
          return {
            'success': false,
            'error': errorData['message'] ?? 'HTTP error: ${response.statusCode}',
          };
        } catch (e) {
          return {
            'success': false,
            'error': 'HTTP error: ${response.statusCode}',
          };
        }
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при обновлении коммерческого поста: $e');
      return {
        'success': false,
        'error': 'Error updating commercial post: $e',
      };
    }
  }
}

class _AlbumPostsCacheEntry {
  final List<CommercialPost> posts;
  final DateTime fetchedAt;

  _AlbumPostsCacheEntry({required this.posts, required this.fetchedAt});
}
