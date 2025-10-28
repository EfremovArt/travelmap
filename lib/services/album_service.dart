import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import '../utils/logger.dart';
import '../services/user_service.dart';
import '../services/post_service.dart';
import '../models/post.dart';
import '../config/api_config.dart';
import 'auth_service.dart';

/// Модель альбома
class Album {
  final String id; // ID (int как строка)
  final String ownerId; // ID пользователя
  String title;
  String description;
  List<String> postIds; // Список ID постов (photoId из Post.id)
  String? coverImageUrl; // Превью альбома (опционально)
  int photosCount;
  bool isPublic;
  DateTime createdAt;
  DateTime updatedAt;

  Album({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.postIds,
    required this.createdAt,
    required this.updatedAt,
    this.coverImageUrl,
    this.photosCount = 0,
    this.isPublic = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'ownerId': ownerId,
        'title': title,
        'description': description,
        'postIds': postIds,
        'coverImageUrl': coverImageUrl,
        'photosCount': photosCount,
        'isPublic': isPublic,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'].toString(),
      ownerId: json['ownerId'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      postIds: (json['postIds'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      coverImageUrl: json['coverImageUrl'],
      photosCount: json['photosCount'] is int
          ? json['photosCount']
          : int.tryParse(json['photosCount']?.toString() ?? '0') ?? 0,
      isPublic: json['isPublic'] == true || json['isPublic'] == 1 || json['isPublic'] == '1',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }

  // Утилита: создать из серверного ответа альбома (строка из albums)
  static Album fromServerRow(Map<String, dynamic> row, {String? coverUrl, List<String>? postIds}) {
    String? computedCover = coverUrl;
    if (computedCover != null && computedCover.isNotEmpty) {
      computedCover = ApiConfig.formatImageUrl(computedCover);
    }
    return Album(
      id: row['id'].toString(),
      ownerId: row['owner_id'].toString(),
      title: (row['title'] ?? '').toString(),
      description: (row['description'] ?? '').toString(),
      postIds: postIds ?? const <String>[],
      coverImageUrl: computedCover,
      photosCount: int.tryParse(row['photos_count']?.toString() ?? '0') ?? 0,
      isPublic: row['is_public'] == 1 || row['is_public'] == true || row['is_public'] == '1',
      createdAt: DateTime.tryParse(row['created_at']?.toString() ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(row['updated_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

/// Сервис для работы с альбомами
class AlbumService {
  static const String _albumsKey = 'albums_store_v1';
  static const String _favoriteAlbumsKey = 'favorite_albums_store_v1';
  static final String _albumApi = '${ApiConfig.baseUrl}/album/index.php';
  // События мгновенных обновлений UI при изменении избранных альбомов
  static final StreamController<void> favoriteAlbumsChanged = StreamController<void>.broadcast();

  // ===== Вспомогательные методы для локального хранилища =====
  static Future<List<Album>> _loadAlbumsFromLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_albumsKey);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list.map((e) => Album.fromJson(Map<String, dynamic>.from(e))).toList();
    } catch (e) {
      AppLogger.log('❌ AlbumService: error reading local albums: $e');
      return [];
    }
  }

  static Future<void> _saveAlbumsToLocal(List<Album> albums) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = albums.map((a) => a.toJson()).toList();
      await prefs.setString(_albumsKey, jsonEncode(data));
    } catch (e) {
      AppLogger.log('❌ AlbumService: error saving local albums: $e');
    }
  }

  // ===== Локальное хранилище избранных альбомов (по аналогии с постами) =====
  // Храним массив объектов вида { ...albumRow, added_by: <currentUserId>, added_at: <ts> }
  static Future<List<Map<String, dynamic>>> _loadFavoriteAlbumsRaw() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? raw = prefs.getString(_favoriteAlbumsKey);
      if (raw == null || raw.isEmpty) return [];
      final List<dynamic> list = jsonDecode(raw);
      return list
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      AppLogger.log('❌ AlbumService: error reading favorite albums: $e');
      return [];
    }
  }

  static Future<void> _saveFavoriteAlbumsRaw(List<Map<String, dynamic>> rows) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_favoriteAlbumsKey, jsonEncode(rows));
    } catch (e) {
      AppLogger.log('❌ AlbumService: error saving favorite albums: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getFavoriteAlbumsForCurrentUser() async {
    // Возвращаем локальные избранные альбомы быстро
    final currentUserId = await UserService.getEmail();
    final allRows = await _loadFavoriteAlbumsRaw();
    final userRows = allRows.where((row) => row['added_by']?.toString() == currentUserId).toList();
    // AppLogger.log('🔍 getFavoriteAlbumsForCurrentUser: пользователь $currentUserId, всего строк: ${allRows.length}, для пользователя: ${userRows.length}');
    // Логи закомментированы для уменьшения шума
    return userRows;
  }
  
  // Отдельный метод для принудительной синхронизации с сервером
  static Future<void> syncFavoriteAlbumsFromServer() async {
    try {
      final rowsFromServer = await getFavoriteAlbumsFromServer();
      if (rowsFromServer.isNotEmpty) {
        await _syncServerFavoriteAlbumsToLocal(rowsFromServer);
        favoriteAlbumsChanged.add(null); // Уведомляем об обновлении
      }
    } catch (e) {
      AppLogger.log('⚠️ Syncing favorite albums from server: $e');
    }
  }

  // Пытаемся получить список избранных альбомов из сервера.
  // Т.к. отдельного эндпоинта может не быть, фоллбэк — получить публичные альбомы и отфильтровать по check_favorite
  static Future<List<Map<String, dynamic>>> getFavoriteAlbumsFromServer({int page = 1, int perPage = 50}) async {
    try {
      final userId = await UserService.getUserId();
      if (userId.isEmpty) return [];

      final allResp = await getAllAlbumsFromServer(page: page, perPage: perPage);
      if (allResp['success'] == true && allResp['albums'] is List) {
        final List<Map<String, dynamic>> all = List<Map<String, dynamic>>.from(allResp['albums']);
        final List<Map<String, dynamic>> favorites = [];
        for (final row in all) {
          final id = row['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          try {
            final favInfo = await getAlbumFavoriteInfo(id);
            final bool isFav = favInfo['isFavorite'] == true || favInfo['favorited'] == true;
            if (isFav) favorites.add(row);
          } catch (_) {}
        }
        return favorites;
      }
    } catch (e) {
      AppLogger.log('❌ Error getting favorite albums from server: $e');
    }
    return [];
  }

  static Future<void> _syncServerFavoriteAlbumsToLocal(List<Map<String, dynamic>> serverRows) async {
    try {
      final currentUserId = await UserService.getEmail();
      // Сохраняем только для текущего пользователя
      final List<Map<String, dynamic>> stamped = serverRows.map((r) {
        final copy = Map<String, dynamic>.from(r);
        copy['added_by'] = currentUserId;
        copy['added_at'] = DateTime.now().toIso8601String();
        return copy;
      }).toList();

      // Загрузим локальные и удалим старые записи текущего пользователя
      final existing = await _loadFavoriteAlbumsRaw();
      final others = existing.where((r) => (r['added_by']?.toString() ?? '') != currentUserId).toList();
      final merged = [...others, ...stamped];
      await _saveFavoriteAlbumsRaw(merged);
      favoriteAlbumsChanged.add(null);
    } catch (e) {
      AppLogger.log('❌ Error syncing favorite albums locally: $e');
    }
  }

  static Future<void> addAlbumToFavoritesLocal(Map<String, dynamic> albumRow) async {
    final currentUserId = await UserService.getEmail();
    final rows = await _loadFavoriteAlbumsRaw();
    final albumId = albumRow['id']?.toString() ?? '';
    AppLogger.log('⭐ Attempting to add album to favorites: $albumId for user $currentUserId');
    AppLogger.log('📄 Album data: $albumRow');
    if (albumId.isEmpty) return;

    // Уникальность по (albumId, added_by)
    final exists = rows.any((r) => r['id']?.toString() == albumId && r['added_by']?.toString() == currentUserId);
    if (!exists) {
      final newRow = Map<String, dynamic>.from(albumRow);
      newRow['added_by'] = currentUserId;
      newRow['added_at'] = DateTime.now().toIso8601String();
      rows.add(newRow);
      await _saveFavoriteAlbumsRaw(rows);
      AppLogger.log('✅ Added album to favorites locally: $albumId');
      AppLogger.log('📊 Total favorite albums: ${rows.length}');
      // Оповещаем подписчиков
      favoriteAlbumsChanged.add(null);
    } else {
      AppLogger.log('⚠️ Album already in favorites: $albumId');
    }
  }

  static Future<void> removeAlbumFromFavoritesLocal(String albumId) async {
    final currentUserId = await UserService.getEmail();
    final rows = await _loadFavoriteAlbumsRaw();
    final before = rows.length;
    rows.removeWhere((r) => r['id']?.toString() == albumId && r['added_by']?.toString() == currentUserId);
    if (rows.length != before) {
      await _saveFavoriteAlbumsRaw(rows);
      AppLogger.log('🗑️ Removed album from favorites locally: $albumId');
      // Оповещаем подписчиков
      favoriteAlbumsChanged.add(null);
    }
  }

  static Future<bool> isAlbumFavoriteLocal(String albumId) async {
    try {
      final currentUserId = await UserService.getEmail();
      final rows = await _loadFavoriteAlbumsRaw();
      return rows.any((r) => r['id']?.toString() == albumId && r['added_by']?.toString() == currentUserId);
    } catch (_) {
      return false;
    }
  }

  // Простой генератор строкового ID (локальный, запасной)
  static String _generateId() {
    final random = Random.secure();
    String fourHex() => random.nextInt(0x10000).toRadixString(16).padLeft(4, '0');
    return '${fourHex()}${fourHex()}-${fourHex()}-${fourHex()}-${fourHex()}-${fourHex()}${fourHex()}${fourHex()}';
  }

  // ===== HTTP helpers =====
  static Map<String, String> _headers() {
    final headers = AuthService().sessionHeaders;
    return {
      ...headers,
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  static Uri _uri(Map<String, dynamic> params) {
    return Uri.parse(_albumApi).replace(queryParameters: {
      ...params.map((k, v) => MapEntry(k, v?.toString() ?? '')),
    });
  }

  static Future<Map<String, dynamic>> _get(Map<String, dynamic> params) async {
    final uri = _uri(params);
    final resp = await http.get(uri, headers: _headers());
    return _decode(resp);
  }

  static Future<Map<String, dynamic>> _post(Map<String, dynamic> params, Map<String, dynamic> body) async {
    final uri = _uri(params);
    final resp = await http.post(uri, headers: _headers(), body: jsonEncode(body));
    return _decode(resp);
  }

  static Future<Map<String, dynamic>> _delete(Map<String, dynamic> params, Map<String, dynamic> body) async {
    final uri = _uri(params);
    final resp = await http.post(uri, headers: _headers(), body: jsonEncode({...body, '_method': 'DELETE'}));
    return _decode(resp);
  }

  static Map<String, dynamic> _decode(http.Response resp) {
    try {
      final Map<String, dynamic> data = jsonDecode(resp.body);
      return data;
    } catch (e) {
      AppLogger.log('❌ AlbumService HTTP decode error: ${resp.statusCode} ${resp.body}');
      return {'success': false, 'error': 'Invalid response: ${resp.statusCode}'};
    }
  }

  // ===== Публичные методы (локальные, для оффлайн/кэша) =====

  static Future<List<Album>> getAllAlbumsLocal() async {
    return await _loadAlbumsFromLocal();
  }

  static Future<List<Album>> getUserAlbumsLocal(String userId) async {
    final all = await _loadAlbumsFromLocal();
    return all.where((a) => a.ownerId == userId).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  static Future<Album> createAlbumLocal({
    required String title,
    required String description,
    required List<String> postIds,
    String? coverImageUrl,
  }) async {
    final ownerId = await UserService.getUserId();
    final now = DateTime.now();

    String? computedCoverUrl = coverImageUrl;
    if ((computedCoverUrl == null || computedCoverUrl.isEmpty) && postIds.isNotEmpty) {
      try {
        final Post? p = await PostService.getPostById(postIds.first);
        if (p != null && p.imageUrls.isNotEmpty) {
          computedCoverUrl = p.imageUrls.first;
        }
      } catch (_) {}
    }

    final album = Album(
      id: _generateId(),
      ownerId: ownerId,
      title: title.trim(),
      description: description.trim(),
      postIds: List<String>.from(postIds),
      coverImageUrl: computedCoverUrl,
      createdAt: now,
      updatedAt: now,
    );

    final all = await _loadAlbumsFromLocal();
    all.add(album);
    await _saveAlbumsToLocal(all);

    AppLogger.log('✅ Created local album: ${album.title} (${album.id}), posts: ${album.postIds.length}');
    return album;
  }

  static Future<Album?> updateAlbumLocal(Album updated) async {
    final all = await _loadAlbumsFromLocal();
    final idx = all.indexWhere((a) => a.id == updated.id);
    if (idx == -1) return null;
    all[idx] = Album(
      id: updated.id,
      ownerId: updated.ownerId,
      title: updated.title.trim(),
      description: updated.description.trim(),
      postIds: List<String>.from(updated.postIds),
      coverImageUrl: updated.coverImageUrl,
      createdAt: updated.createdAt,
      updatedAt: DateTime.now(),
      photosCount: updated.photosCount,
      isPublic: updated.isPublic,
    );
    await _saveAlbumsToLocal(all);
    AppLogger.log('✏️ Updated local album: ${updated.id}');
    return all[idx];
  }

  static Future<bool> deleteAlbumLocal(String albumId) async {
    final all = await _loadAlbumsFromLocal();
    final before = all.length;
    all.removeWhere((a) => a.id == albumId);
    final changed = all.length != before;
    if (changed) {
      await _saveAlbumsToLocal(all);
      AppLogger.log('🗑️ Deleted local album: $albumId');
    }
    return changed;
  }

  static Future<Album?> getAlbumByIdLocal(String albumId) async {
    final all = await _loadAlbumsFromLocal();
    try {
      return all.firstWhere((a) => a.id == albumId);
    } catch (_) {
      return null;
    }
  }

  // ===== Сетевые методы (основные) =====

  // Создать альбом на сервере
  static Future<Map<String, dynamic>> createAlbumServer({
    required String title,
    required String description,
    required List<String> postIds,
    bool isPublic = true,
    String? coverPhotoId,
  }) async {
    try {
      final result = await _post({'action': 'create'}, {
        'title': title,
        'description': description,
        'is_public': isPublic ? 1 : 0,
        'cover_photo_id': coverPhotoId,
        'post_ids': postIds,
      });
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Обновить альбом
  static Future<Map<String, dynamic>> updateAlbumServer({
    required String albumId,
    String? title,
    String? description,
    bool? isPublic,
    String? coverPhotoId,
  }) async {
    try {
      final body = <String, dynamic>{'album_id': albumId};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;
      if (isPublic != null) body['is_public'] = isPublic ? 1 : 0;
      if (coverPhotoId != null) body['cover_photo_id'] = coverPhotoId;
      final result = await _post({'action': 'update'}, body);
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Удалить альбом
  static Future<Map<String, dynamic>> deleteAlbumServer(String albumId) async {
    try {
      final result = await _delete({'action': 'delete'}, {'album_id': albumId});
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Получить детали альбома + фото
  static Future<Map<String, dynamic>> getAlbumDetails(String albumId) async {
    try {
      final result = await _get({'action': 'get_album', 'album_id': albumId});
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Получить альбомы пользователя
  static Future<Map<String, dynamic>> getUserAlbumsFromServer(String userId, {int page = 1, int perPage = 20}) async {
    try {
      final result = await _get({
        'action': 'get_user_albums',
        'user_id': userId,
        'page': page,
        'per_page': perPage,
      });
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Получить все публичные альбомы
  static Future<Map<String, dynamic>> getAllAlbumsFromServer({int page = 1, int perPage = 20}) async {
    try {
      final result = await _get({
        'action': 'get_all_albums',
        'page': page,
        'per_page': perPage,
      });
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Добавить фото в альбом
  static Future<Map<String, dynamic>> addPhotosToAlbum(String albumId, List<String> postIds) async {
    try {
      final result = await _post({'action': 'add_photos'}, {
        'album_id': albumId,
        'post_ids': postIds,
      });
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Удалить фото из альбома
  static Future<Map<String, dynamic>> removePhotosFromAlbum(String albumId, List<String> postIds) async {
    try {
      final result = await _post({'action': 'remove_photos'}, {
        'album_id': albumId,
        'post_ids': postIds,
      });
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Сменить обложку
  static Future<Map<String, dynamic>> setAlbumCover(String albumId, String coverPhotoId) async {
    try {
      final result = await _post({'action': 'set_cover'}, {
        'album_id': albumId,
        'cover_photo_id': coverPhotoId,
      });
      return result;
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Лайки альбомов
  static Future<Map<String, dynamic>> likeAlbum(String albumId) async {
    try {
      return await _post({'action': 'like'}, {'album_id': albumId});
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> unlikeAlbum(String albumId) async {
    try {
      return await _delete({'action': 'unlike'}, {'album_id': albumId});
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getAlbumLikeInfo(String albumId) async {
    try {
      return await _get({'action': 'check_like', 'album_id': albumId});
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getAlbumLikesList(String albumId) async {
    try {
      return await _get({'action': 'get_likes', 'album_id': albumId});
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Избранное альбомов
  static Future<Map<String, dynamic>> favoriteAlbum(String albumId) async {
    try {
      return await _post({'action': 'favorite'}, {'album_id': albumId});
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> unfavoriteAlbum(String albumId) async {
    try {
      return await _delete({'action': 'unfavorite'}, {'album_id': albumId});
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> getAlbumFavoriteInfo(String albumId) async {
    try {
      return await _get({'action': 'check_favorite', 'album_id': albumId});
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Комментарии к альбомам
  static Future<Map<String, dynamic>> getAlbumComments(String albumId, {int page = 1, int perPage = 20}) async {
    try {
      return await _get({
        'action': 'get_comments',
        'album_id': albumId,
        'page': page,
        'per_page': perPage,
      });
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> addAlbumComment(String albumId, String comment) async {
    try {
      return await _post({'action': 'comment'}, {
        'album_id': albumId,
        'comment': comment,
      });
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> deleteAlbumComment(String commentId) async {
    try {
      return await _delete({'action': 'delete_comment'}, {
        'comment_id': commentId,
      });
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  // Утилита для сборки coverImageUrl из file_path
  static String? makeCoverUrl(String? filePath) {
    if (filePath == null || filePath.isEmpty) return null;
    return ApiConfig.formatImageUrl(filePath);
  }
}
