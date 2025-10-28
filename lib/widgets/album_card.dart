import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../services/album_service.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';
import 'package:intl/intl.dart';
import '../screens/user_profile_screen.dart';
import '../screens/main_screen.dart';
import '../screens/album_comments_screen.dart';
import '../screens/create_commercial_post_screen.dart';
import 'commercial_posts_indicator.dart';
import '../models/commercial_post.dart';
import '../services/commercial_post_service.dart';

/// Общий виджет карточки альбома для переиспользования
class AlbumCard extends StatefulWidget {
  final Map<String, dynamic> albumRow;
  final String? currentUserId;
  final FutureOr<void> Function() onChanged;
  final Function(String albumId)? onTap;
  final FutureOr<void> Function(String albumId, Map<String, dynamic> album, List<Map<String, dynamic>> photos)? onEditAlbum; // optional external edit flow

  const AlbumCard({
    Key? key,
    required this.albumRow,
    required this.currentUserId,
    required this.onChanged,
    this.onTap,
    this.onEditAlbum,
  }) : super(key: key);

  @override
  State<AlbumCard> createState() => _AlbumCardState();
}

class _AlbumCardState extends State<AlbumCard> {
  Map<String, dynamic>? _album; // details
  List<Map<String, dynamic>> _photos = [];
  bool _loading = true;
  bool _liked = false;
  int _likes = 0;
  bool _favorite = false;
  int _favoritesCount = 0;
  int _commentsCount = 0; // Количество комментариев к альбому
  String _locationName = '';
  String _ownerName = '';
  String _ownerAvatar = '';
  DateTime? _createdAt;
  String? _coverUrl;
  StreamSubscription<void>? _favSub;
  int _postsCount = 0; // Количество уникальных постов (локаций)

  bool get _isOwner {
    if (_album == null) {
      return false;
    }
    
    final ownerIdFromAlbum = _album!['owner_id']?.toString() ?? '';
    final currentUserId = widget.currentUserId ?? '';
    
    if (ownerIdFromAlbum.isEmpty || currentUserId.isEmpty) {
      return false;
    }
    
    return ownerIdFromAlbum == currentUserId;
  }

  // Кэш-менеджер для обложек альбомов (TTL 3 дня)
  final BaseCacheManager _albumCoverCacheManager = CacheManager(
    Config(
      'album_covers_cache',
      stalePeriod: Duration(days: 3),
      maxNrOfCacheObjects: 400,
    ),
  );

  @override
  void initState() {
    super.initState();
    _load();
    _loadCommentsCount();
    _favSub = AlbumService.favoriteAlbumsChanged.stream.listen((_) {
      _syncFavoriteState();
    });
    _syncFavoriteState();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final id = widget.albumRow['id'].toString();
      final resp = await AlbumService.getAlbumDetails(id);
      if (resp['success'] == true) {
        final album = Map<String, dynamic>.from(resp['album']);
        final photos = List<Map<String, dynamic>>.from(resp['photos'] ?? []);
        final likeInfo = await AlbumService.getAlbumLikeInfo(id);
        final favInfo = await AlbumService.getAlbumFavoriteInfo(id);

        // Попробуем получить название локации по первому фото
        String locName = '';
        if (photos.isNotEmpty) {
          final firstId = photos.first['id']?.toString();
          if (firstId != null && firstId.isNotEmpty) {
            final p = await PostService.getPostById(firstId);
            if (p != null) locName = p.locationName;
          }
        }

        // Автор и дата создания
        String ownerId = album['owner_id']?.toString() ?? '';
        String ownerName = '';
        String ownerAvatar = '';
        
        // Сначала пробуем использовать данные из widget.albumRow (они теперь приходят из API напрямую)
        if (widget.albumRow['author_name'] != null) {
          final authorNameFromRow = widget.albumRow['author_name'].toString().trim();
          if (authorNameFromRow.isNotEmpty && authorNameFromRow != 'null' && authorNameFromRow != ' ') {
            ownerName = authorNameFromRow;
            // AppLogger.log('✅ Используем author_name из albumRow: $ownerName');
          }
        }
        
        // Получаем аватарку из widget.albumRow (приходит из API напрямую)
        if (widget.albumRow['profile_image_url'] != null) {
          final avatarFromRow = widget.albumRow['profile_image_url'].toString().trim();
          if (avatarFromRow.isNotEmpty && avatarFromRow != 'null') {
            ownerAvatar = ApiConfig.formatImageUrl(avatarFromRow);
            // AppLogger.log('✅ Используем profile_image_url из albumRow: $ownerAvatar');
          }
        }
        
        // Если данные не найдены в albumRow, загружаем через API как fallback
        if ((ownerName.isEmpty || ownerAvatar.isEmpty) && ownerId.isNotEmpty) {
          try {
            final userInfo = await UserService.getUserInfoById(ownerId);
            if (ownerName.isEmpty) {
              final firstName = userInfo['firstName']?.toString().trim() ?? '';
              final lastName = userInfo['lastName']?.toString().trim() ?? '';
              ownerName = '$firstName $lastName'.trim();
              AppLogger.log('✅ Загружено имя автора через API fallback: $ownerName');
            }
            if (ownerAvatar.isEmpty) {
              final rawAvatar = userInfo['profileImageUrl'] ?? '';
              if (rawAvatar.isNotEmpty) {
                ownerAvatar = ApiConfig.formatImageUrl(rawAvatar);
                AppLogger.log('✅ Загружен аватар автора через API fallback: $ownerAvatar');
              }
            }
          } catch (e) {
            AppLogger.log('Error loading owner info: $e');
          }
        }
        
        // Если имя все еще пустое, используем fallback
        if (ownerName.isEmpty) {
          ownerName = 'Unknown User';
          AppLogger.log('⚠️ Используем fallback имя: $ownerName');
        }

        final createdAtStr = album['created_at']?.toString() ?? '';
        DateTime? createdAt;
        try {
          createdAt = DateTime.tryParse(createdAtStr);
        } catch (_) {}

        // Получаем URL обложки - сначала пробуем из widget.albumRow (приходит из API напрямую)
        String? coverUrl;
        if (widget.albumRow['cover_url'] != null) {
          final coverFromRow = widget.albumRow['cover_url'].toString().trim();
          if (coverFromRow.isNotEmpty && coverFromRow != 'null') {
            coverUrl = ApiConfig.formatImageUrl(coverFromRow);
            // AppLogger.log('✅ Используем cover_url из albumRow: $coverUrl');
          }
        }
        
        // Если cover_url не найден в albumRow, используем старую логику как fallback
        if (coverUrl == null || coverUrl.isEmpty) {
          final coverPhotoId = album['cover_photo_id']?.toString();
          if (coverPhotoId != null && coverPhotoId.isNotEmpty && photos.isNotEmpty) {
            try {
              final coverPhoto = photos.firstWhere((p) => p['id'].toString() == coverPhotoId);
              final filePath = coverPhoto['file_path']?.toString() ?? '';
              if (filePath.isNotEmpty) {
                coverUrl = ApiConfig.formatImageUrl(filePath);
                AppLogger.log('✅ Получена обложка через cover_photo_id fallback: $coverUrl');
              }
            } catch (_) {
              // Если обложку не найдём, используем первое фото
              if (photos.isNotEmpty) {
                final filePath = photos.first['file_path']?.toString() ?? '';
                if (filePath.isNotEmpty) {
                  coverUrl = ApiConfig.formatImageUrl(filePath);
                  AppLogger.log('⚠️ Используем первое фото как обложку: $coverUrl');
                }
              }
            }
          } else if (photos.isNotEmpty) {
            // Используем первое фото как обложку
            final filePath = photos.first['file_path']?.toString() ?? '';
            if (filePath.isNotEmpty) {
              coverUrl = ApiConfig.formatImageUrl(filePath);
              AppLogger.log('⚠️ Используем первое фото как обложку (no cover_photo_id): $coverUrl');
            }
          }
        }

        // Разбор like/favorite по фактическим полям API
        final bool parsedIsLiked = likeInfo['isLiked'] == true || likeInfo['liked'] == true;
        final dynamic likesCountRaw = likeInfo['likesCount'] ?? likeInfo['likes_count'];
        final int parsedLikes = int.tryParse((likesCountRaw ?? '0').toString()) ?? 0;
        final bool parsedIsFavorite = favInfo['isFavorite'] == true || favInfo['favorited'] == true;
        final dynamic favCountRaw = favInfo['favoritesCount'] ?? favInfo['favorites_count'];
        final int parsedFavorites = int.tryParse((favCountRaw ?? '0').toString()) ?? 0;

        // Получаем количество постов с сервера, если доступно
        int postsCount = 0;
        if (resp['postsCount'] != null) {
          postsCount = int.tryParse(resp['postsCount'].toString()) ?? 0;
          AppLogger.log('📊 Album posts count from server: $postsCount');
        } else {
          // Fallback: подсчитываем количество уникальных постов (локаций) на клиенте
          final Set<String> uniqueLocationIds = {};
          int photosWithoutLocation = 0;
          
          for (var photo in photos) {
            final locationId = photo['location_id']?.toString();
            if (locationId != null && locationId.isNotEmpty && locationId != 'null') {
              uniqueLocationIds.add(locationId);
            } else {
              photosWithoutLocation++;
            }
          }
          
          postsCount = uniqueLocationIds.isEmpty && photos.isNotEmpty 
              ? 1 
              : uniqueLocationIds.length;
          
          AppLogger.log('📊 Album posts count (fallback): $postsCount, unique locations: ${uniqueLocationIds.length}, photos without location: $photosWithoutLocation, total photos: ${photos.length}');
        }

        if (mounted) {
          setState(() {
            _album = album;
            _photos = photos;
            _liked = parsedIsLiked;
            _likes = parsedLikes;
            _favorite = parsedIsFavorite;
            _favoritesCount = parsedFavorites;
            _locationName = locName;
            _ownerName = ownerName;
            _ownerAvatar = ownerAvatar;
            _createdAt = createdAt;
            _coverUrl = coverUrl;
            _postsCount = postsCount;
          });
        }
      }
    } catch (e) {
      AppLogger.log('Error loading album details: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _syncFavoriteState() async {
    try {
      final id = widget.albumRow['id']?.toString() ?? '';
      if (id.isEmpty || !mounted) return;
      final isFavLocal = await AlbumService.isAlbumFavoriteLocal(id);
      // AppLogger.log("🔄 AlbumCard sync: альбом $id, isFavorite: $isFavLocal");
      if (mounted) setState(() => _favorite = isFavLocal);
      try {
        final favInfo = await AlbumService.getAlbumFavoriteInfo(id);
        final dynamic favCountRaw = favInfo['favoritesCount'] ?? favInfo['favorites_count'];
        final int serverFavorites = int.tryParse((favCountRaw ?? _favoritesCount).toString()) ?? _favoritesCount;
        // AppLogger.log("📊 AlbumCard sync: альбом $id, favoritesCount: $serverFavorites");
        if (mounted) setState(() => _favoritesCount = serverFavorites);
      } catch (_) {}
    } catch (_) {}
  }

  // Загружаем количество комментариев
  Future<void> _loadCommentsCount() async {
    try {
      final id = widget.albumRow['id']?.toString() ?? '';
      if (id.isEmpty) {
        AppLogger.log('❌ Некорректный ID альбома: $id');
        return;
      }

      if (!mounted) {
        AppLogger.log('⚠️ Виджет больше не монтирован, отменяем загрузку комментариев');
        return;
      }

      // Получаем комментарии альбома через AlbumService
      final result = await AlbumService.getAlbumComments(id);
      
      if (!mounted) {
        return;
      }
      
      if (result['success'] == true) {
        final comments = result['comments'] as List<dynamic>? ?? [];
        setState(() {
          _commentsCount = comments.length;
        });
      } else {
        // В случае ошибки просто устанавливаем 0 комментариев
        setState(() {
          _commentsCount = 0;
        });
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при загрузке количества комментариев альбома: $e');
      if (mounted) {
        setState(() {
          _commentsCount = 0;
        });
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_album == null || _loading) return;
    final String id = _album!['id'].toString();

    // Оптимистичное обновление UI без перезагрузки списка
    final bool wasLiked = _liked;
    if (mounted) {
      setState(() {
        _liked = !wasLiked;
        _likes = (_likes + (_liked ? 1 : -1)).clamp(0, 1 << 30).toInt();
      });
    }

    try {
      if (wasLiked) {
        await AlbumService.unlikeAlbum(id);
      } else {
        await AlbumService.likeAlbum(id);
      }

      // Асинхронная сверка с сервером без дергания родителя
      try {
        final likeInfo = await AlbumService.getAlbumLikeInfo(id);
        if (mounted) {
          final dynamic likesCountRaw = likeInfo['likesCount'] ?? likeInfo['likes_count'];
          final int serverLikes = int.tryParse((likesCountRaw ?? _likes).toString()) ?? _likes;
          final bool serverIsLiked = likeInfo['isLiked'] == true || likeInfo['liked'] == true;
          setState(() {
            _likes = serverLikes;
            _liked = serverIsLiked;
          });
        }
      } catch (_) {}
    } catch (e) {
      // Откат в случае ошибки
      if (mounted) {
        setState(() {
          _liked = wasLiked;
          _likes = (_likes + (wasLiked ? 1 : -1)).clamp(0, 1 << 30).toInt();
        });
      }
      AppLogger.log('Error toggling like: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    if (_album == null || _loading) return;
    final String id = _album!['id'].toString();

    // Оптимистичное обновление UI
    final bool wasFavorite = _favorite;
    if (mounted) {
      setState(() {
        _favorite = !wasFavorite;
        // Убираем оптимистичное обновление счетчика, так как он обновляется через стрим
      });
    }

    try {
      if (wasFavorite) {
        await AlbumService.unfavoriteAlbum(id);
        // Локально удалить из избранного
        await AlbumService.removeAlbumFromFavoritesLocal(id);
      } else {
        await AlbumService.favoriteAlbum(id);
        // Локально сохранить «как в списке альбомов»
        try {
          await AlbumService.addAlbumToFavoritesLocal(widget.albumRow);
        } catch (e) {
          AppLogger.log('AlbumCard: ошибка локального сохранения избранного альбома: $e');
        }
      }

      // Сверка состояния с сервером (без обновления родителя)
      try {
        final favInfo = await AlbumService.getAlbumFavoriteInfo(id);
        if (mounted) {
          final bool serverFavorite = favInfo['isFavorite'] == true || favInfo['favorited'] == true;
          final dynamic favCountRaw = favInfo['favoritesCount'] ?? favInfo['favorites_count'];
          final int serverFavorites = int.tryParse((favCountRaw ?? _favoritesCount).toString()) ?? _favoritesCount;
          setState(() {
            _favorite = serverFavorite;
            _favoritesCount = serverFavorites;
          });
        }
      } catch (_) {}
    } catch (e) {
      // Откат
      if (mounted) {
        setState(() {
          _favorite = wasFavorite;
          // Счетчик обновится через стрим-синхронизацию
        });
      }
      AppLogger.log('Error toggling favorite: $e');
    }
  }

  Future<void> _confirmDeleteAlbum() async {
    if (_album == null) return;
    final id = _album!['id'].toString();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Album'),
        content: const Text('Are you sure you want to delete this album?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      final result = await AlbumService.deleteAlbumServer(id);
      if (result['success'] == true) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Album deleted')));
        await widget.onChanged();
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result['error']?.toString() ?? 'Failed to delete')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  void dispose() {
    try { _favSub?.cancel(); } catch (_) {}
    super.dispose();
  }

  Future<void> _editAlbumDialog() async {
    if (_album == null) return;

    // Если передан внешний обработчик редактирования — используем его
    if (widget.onEditAlbum != null) {
      await widget.onEditAlbum!(_album!['id'].toString(), _album!, _photos);
      if (!mounted) return;
      await _load();
      await widget.onChanged();
      return;
    }

    final id = _album!['id'].toString();
    final titleController = TextEditingController(text: (_album!['title'] ?? '').toString());
    final descriptionController = TextEditingController(text: (_album!['description'] ?? '').toString());

    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Album'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );

    if (saved == true) {
      try {
        final res = await AlbumService.updateAlbumServer(
          albumId: id,
          title: titleController.text.trim(),
          description: descriptionController.text.trim(),
        );
        if (res['success'] == true) {
          if (!mounted) return;
          await _load();
          await widget.onChanged();
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Album updated')));
        } else {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['error']?.toString() ?? 'Failed to update')));
        }
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _handleTap() {
    final albumId = widget.albumRow['id'].toString();
    if (widget.onTap != null) {
      widget.onTap!(albumId);
    }
  }

  /// Безопасно преобразует currentUserId в int
  /// Возвращает null если currentUserId не является числом
  int? _getCurrentUserIdAsInt() {
    if (widget.currentUserId == null) return null;
    
    try {
      // Пытаемся преобразовать в int
      return int.parse(widget.currentUserId!);
    } catch (e) {
      // Если не удалось преобразовать (например, это email), возвращаем null
      AppLogger.log('⚠️ currentUserId не является числом: ${widget.currentUserId}');
      return null;
    }
  }

  // Открытие профиля автора альбома
  void _openAuthorProfile(BuildContext context) async {
    if (_album == null) return;
    
    try {
      final ownerId = _album!['owner_id']?.toString() ?? '';
      if (ownerId.isEmpty) return;
      
      // Проверяем, не пытается ли пользователь открыть свой собственный профиль
      final isCurrentUser = widget.currentUserId != null && ownerId == widget.currentUserId;
      
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(
              userId: ownerId,
              initialName: _ownerName.isNotEmpty ? _ownerName : 'Unknown User',
              initialProfileImage: _ownerAvatar.isNotEmpty ? _ownerAvatar : null,
              sourceTabIndex: mainScreenKey.currentState?.currentTabIndex ?? 0,
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при открытии профиля автора альбома: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Не удалось открыть профиль автора'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openAlbumComments() async {
    if (_album == null) return;
    final String albumId = _album!['id'].toString();
    final String albumTitle = _album!['title']?.toString() ?? 'Album';

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: AlbumCommentsScreen(
            albumId: albumId,
            albumTitle: albumTitle,
            albumImageUrl: _coverUrl,
          ),
        );
      },
    );
    
    // Обновляем счетчик комментариев после закрытия модального окна
    if (mounted) {
      _loadCommentsCount();
    }
  }

  // Показать диалог выбора между созданием нового поста или выбором существующего
  Future<void> _createCommercialPost() async {
    if (widget.currentUserId == null || _album == null) return;

    final userId = _getCurrentUserIdAsInt();
    if (userId == null) return;

    _showCommercialPostOptionsDialog(userId);
  }

  // Диалог выбора опций для коммерческого поста
  void _showCommercialPostOptionsDialog(int userId) {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Add Commercial Post',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 10),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange.shade100,
                child: Icon(Icons.add, color: Colors.orange.shade700),
              ),
              title: Text('Create New Post'),
              subtitle: Text('Create a new commercial post for this album'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _createNewCommercialPost(userId);
              },
            ),
            ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.blue.shade100,
                child: Icon(Icons.library_add, color: Colors.blue.shade700),
              ),
              title: Text('Choose Existing Post'),
              subtitle: Text('Select from your standalone commercial posts'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _selectExistingCommercialPost(userId);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Создание нового коммерческого поста
  Future<void> _createNewCommercialPost(int userId) async {
    final albumId = int.tryParse(_album!['id'].toString());
    
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CreateCommercialPostScreen(
          userId: userId,
          albumId: albumId, // Передаем ID альбома для создания поста в альбоме
        ),
      ),
    );

    // Если пост был создан, обновляем данные
    if (result == true) {
      // Обновляем данные альбома
      widget.onChanged();
    }
  }

  // Выбор существующего коммерческого поста
  Future<void> _selectExistingCommercialPost(int userId) async {
    try {
      // Загружаем standalone коммерческие посты пользователя
      final standalonePosts = await CommercialPostService.getStandaloneCommercialPosts(userId);
      
      if (standalonePosts.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No standalone commercial posts found. Create one first!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      _showExistingPostsDialog(standalonePosts, userId);
      
    } catch (e) {
      AppLogger.log('❌ Error loading standalone posts: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading posts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Диалог выбора существующего поста
  void _showExistingPostsDialog(List<CommercialPost> posts, int userId) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: EdgeInsets.symmetric(vertical: 20),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Select Commercial Post',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Spacer(),
                  IconButton(
                    icon: Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return ListTile(
                    leading: post.hasImages && post.imageUrls.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: ApiConfig.formatImageUrl(post.imageUrls.first),
                              width: 50,
                              height: 50,
                              fit: BoxFit.cover,
                              errorWidget: (context, url, error) => 
                                Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey.shade200,
                                  child: Icon(Icons.business, color: Colors.grey),
                                ),
                            ),
                          )
                        : Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(Icons.business, color: Colors.orange.shade700),
                          ),
                    title: Text(
                      post.title,
                      style: TextStyle(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      post.description?.isNotEmpty == true 
                          ? post.description! 
                          : 'No description',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Icon(Icons.add_circle_outline, color: Colors.green),
                    onTap: () {
                      Navigator.pop(context);
                      _attachPostToAlbum(post, userId);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Привязка существующего поста к альбому
  Future<void> _attachPostToAlbum(CommercialPost post, int userId) async {
    try {
      final albumId = int.tryParse(_album!['id'].toString());
      if (albumId == null) return;

      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(child: CircularProgressIndicator()),
      );

      final success = await CommercialPostService.attachPostToAlbum(post.id, albumId);
      
      // Закрываем индикатор загрузки
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Commercial post attached to album successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
        // Обновляем данные альбома
        widget.onChanged();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to attach post to album'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Закрываем индикатор загрузки в случае ошибки
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      AppLogger.log('❌ Error attaching post to album: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Пожаловаться (заглушка)
  void _reportAlbum() {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Report functionality coming soon'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Отображение списка пользователей, добавивших альбом в избранное
  Future<void> _showFavoritesList(BuildContext context) async {
    if (_album == null) return;
    
    AppLogger.log('🔄 Открываем список добавивших в избранное альбом ${_album!['id']}');
    try {
      // Показываем индикатор загрузки
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return Center(
            child: CircularProgressIndicator(),
          );
        },
      );
      
      if (_favoritesCount <= 0) {
        // Закрываем диалог загрузки
        if (context.mounted) {
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No one has favorited this album yet'))
          );
        }
        return;
      }

      // Список пользователей с данными профиля
      List<Map<String, dynamic>> usersData = [];
      
      // Здесь нужно получить список пользователей из API
      // Пока используем заглушку
      AppLogger.log('📊 Количество добавлений в избранное для альбома ${_album!['id']}: $_favoritesCount');
      
      // Закрываем диалог загрузки
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      if (!context.mounted) {
        AppLogger.log('❌ Контекст больше не актуален, прерываем отображение');
        return;
      }
      
      AppLogger.log('🎯 Показываем модальное окно со списком добавивших в избранное');
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Text(
                      'Users who favorited this album ($_favoritesCount)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    IconButton(
                      icon: Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Divider(),
              Expanded(
                child: usersData.isEmpty
                    ? Center(
                        child: Text(
                          'List is loading or empty',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            color: Colors.grey,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: usersData.length,
                        itemBuilder: (context, index) {
                          final user = usersData[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty
                                  ? CachedNetworkImageProvider(ApiConfig.formatImageUrl(user['profileImageUrl']))
                                  : null,
                              child: (user['profileImageUrl'] == null || user['profileImageUrl'].isEmpty)
                                  ? Text(
                                      user['name']?.substring(0, 1).toUpperCase() ?? 'U',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                  : null,
                            ),
                            title: Text(
                              user['name'] != null && user['name'].isNotEmpty 
                                  ? user['name'] 
                                  : 'User ${user['id']}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении списка избранного: $e');
      // Закрываем диалог загрузки если он открыт
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load favorites list'))
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.albumRow['title'] ?? '').toString();
    final description = (widget.albumRow['description'] ?? '').toString();

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.hardEdge,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Шапка альбома (аватар, имя, количество постов автора и дата) - точно как у поста
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Аватарка автора (из профиля) - radius 28 как у поста
                    GestureDetector(
                      onTap: () => _openAuthorProfile(context),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.transparent,
                        backgroundImage: _ownerAvatar.isNotEmpty
                            ? CachedNetworkImageProvider(_ownerAvatar)
                            : null,
                        child: _ownerAvatar.isEmpty
                            ? Icon(
                                Icons.person,
                                color: Colors.grey.shade600,
                                size: 28,
                              )
                            : null,
                      ),
                    ),
                    
                    SizedBox(width: 12),
                    
                    // Информация о пользователе
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Верхняя строка: имя пользователя, иконка с постами и дата
                          Row(
                            children: [
                              // Имя пользователя
                              Expanded(
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => _openAuthorProfile(context),
                                      child: Text(
                                        _ownerName.isNotEmpty ? _ownerName : 'Unknown User',
                                        style: TextStyle(
                                          fontFamily: 'Gilroy',
                                          fontStyle: FontStyle.normal,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    // Иконка с количеством постов автора
                                    FutureBuilder<int>(
                                      future: _getAuthorPostsCount(),
                                      builder: (context, snapshot) {
                                        final postsCount = snapshot.data ?? 0;
                                        return Container(
                                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Image.asset(
                                                'assets/Images/location.png',
                                                width: 16,
                                                height: 16,
                                              ),
                                              SizedBox(width: 4),
                                              Text(
                                                '$postsCount',
                                                style: TextStyle(
                                                  fontFamily: 'Gilroy',
                                                  fontSize: 12,
                                                  color: Colors.blue,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(width: 8),
                              // Дата публикации
                              if (_createdAt != null)
                                Text(
                                  DateFormat('dd.MM.yyyy').format(_createdAt!),
                                  style: TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontStyle: FontStyle.normal,
                                    fontWeight: FontWeight.w400,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                          
                          SizedBox(height: 4),
                          
                          // Индикатор альбома и заголовок на одной строке
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.blue.shade200, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.photo_library,
                                      size: 14,
                                      color: Colors.blue.shade600,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Album',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.blue.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Заголовок альбома на одной строке с индикатором
                              if (title.isNotEmpty) ...[
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title,
                                    style: TextStyle(
                                      fontFamily: 'Gilroy',
                                      fontStyle: FontStyle.normal,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 16,
                                      color: Colors.black,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Описание альбома (вынесено ниже шапки)
          if (description.isNotEmpty) ...[
            SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                description,
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontStyle: FontStyle.normal,
                  fontWeight: FontWeight.w400,
                  fontSize: 14,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
          
          SizedBox(height: 6),

          // Обложка альбома - горизонтальный прямоугольник (как горизонтальное фото)
          Center(
            child: Container(
              width: MediaQuery.of(context).size.width - 30, // 15px с каждой стороны как у постов
              height: (MediaQuery.of(context).size.width - 30) * 3 / 4, // 4:3 aspect ratio
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
              ),
                child: CommercialPostsIndicator(
                  albumId: int.parse(widget.albumRow['id'].toString()),
                  albumTitle: title,
                  currentUserId: _getCurrentUserIdAsInt(),
                  child: Stack(
                    children: [
                      if (_loading)
                        const Center(child: CircularProgressIndicator())
                      else
                        GestureDetector(
                          onTap: _handleTap,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Positioned.fill(
                                child: _coverUrl != null && _coverUrl!.isNotEmpty
                                    ? CachedNetworkImage(
                                        imageUrl: _coverUrl!,
                                        fit: BoxFit.cover,
                                        cacheManager: _albumCoverCacheManager,
                                        fadeInDuration: Duration(milliseconds: 0),
                                        fadeOutDuration: Duration(milliseconds: 0),
                                        useOldImageOnUrlChange: true,
                                      )
                                    : Container(color: Colors.grey.shade200),
                              ),
                              
                              // Счетчик постов в левом верхнем углу
                              Positioned(
                                top: 8,
                                left: 8,
                                child: Container(
                                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.7),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.photo_camera,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        '$_postsCount',
                                        style: TextStyle(
                                          fontFamily: 'Gilroy',
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // Меню с тремя точками (только для чужих альбомов)
                      if (!_isOwner)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: Colors.white,
                                size: 18,
                              ),
                              itemBuilder: (context) => [
                                if (widget.currentUserId != null)
                                  PopupMenuItem(
                                    value: 'add_commercial',
                                    child: Row(
                                      children: [
                                        Icon(Icons.add_business, size: 20, color: Colors.orange.shade600),
                                        SizedBox(width: 8),
                                        Text('Add commercial post'),
                                      ],
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'report',
                                  child: Row(
                                    children: [
                                      Icon(Icons.report, size: 20, color: Colors.red.shade600),
                                      SizedBox(width: 8),
                                      Text('Report'),
                                    ],
                                  ),
                                ),
                              ],
                              onSelected: (value) {
                                switch (value) {
                                  case 'add_commercial':
                                    _createCommercialPost();
                                    break;
                                  case 'report':
                                    _reportAlbum();
                                    break;
                                }
                              },
                              padding: EdgeInsets.all(4),
                              constraints: BoxConstraints(
                                minWidth: 28,
                                minHeight: 28,
                              ),
                            ),
                          ),
                        ),
                      
                      // Вертикальная колонка только нужных иконок
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: _isOwner ? _buildOwnerControls() : _buildOtherControls(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          SizedBox(height: 6),
        ],
      ),
    );
  }

  // Получить количество постов автора альбома
  Future<int> _getAuthorPostsCount() async {
    if (_album == null) return 0;
    try {
      final ownerId = _album!['owner_id']?.toString() ?? '';
      if (ownerId.isEmpty) return 0;
      
      final posts = await PostService.getUserPosts(userId: ownerId);
      return posts.length;
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении количества постов автора альбома: $e');
      return 0;
    }
  }

  // Контролы для чужого альбома: Избранное (36), Лайк (34), Комментарий (34)
  Widget _buildOtherControls() {
    return Column(
      children: [
        // Кнопка добавления в избранное
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _toggleFavorite,
              child: Container(
                height: 32,
                width: 40,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/Images/star.png',
                  width: 36,
                  height: 36,
                  color: _favorite ? Colors.yellow : Colors.white,
                ),
              ),
            ),
            if (_favoritesCount > 0)
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Text(
                  _favoritesCount.toString(),
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        
        SizedBox(height: 4),
        
        // Кнопка лайка
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _toggleLike,
              child: Container(
                height: 32,
                width: 40,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/Images/heart.png',
                  width: 34,
                  height: 34,
                  color: _liked ? Colors.red : Colors.white,
                ),
              ),
            ),
            if (_likes > 0)
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Text(
                  _likes.toString(),
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        
        SizedBox(height: 4),
        
        // Кнопка комментариев
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _openAlbumComments,
              child: Container(
                height: 32,
                width: 40,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/Images/comment.png',
                  width: 34,
                  height: 34,
                  color: Colors.white,
                ),
              ),
            ),
            if (_commentsCount > 0)
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Text(
                  _commentsCount.toString(),
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // Контролы для своего альбома: Избранное (28), Лайк (28), Комментарий (28), Редактировать (28), Удалить (28)
  Widget _buildOwnerControls() {
    return Column(
      children: [
        // Кнопка избранного и счетчик
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                AppLogger.log('👆 Нажата кнопка просмотра избранного альбома');
                _showFavoritesList(context);
              },
              child: Container(
                height: 32,
                width: 40,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/Images/star.png',
                  width: 28,
                  height: 28,
                  color: Colors.white,
                ),
              ),
            ),
            if (_favoritesCount > 0)
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Text(
                  _favoritesCount.toString(),
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        
        SizedBox(height: 4),
        
        // Кнопка лайков и счетчик
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _toggleLike,
              child: Container(
                height: 32,
                width: 40,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/Images/heart.png',
                  width: 28,
                  height: 28,
                  color: _liked ? Colors.red : Colors.white,
                ),
              ),
            ),
            if (_likes > 0)
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Text(
                  _likes.toString(),
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        
        SizedBox(height: 4),
        
        // Кнопка комментариев
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: _openAlbumComments,
              child: Container(
                height: 32,
                width: 40,
                alignment: Alignment.center,
                child: Image.asset(
                  'assets/Images/comment.png',
                  width: 28,
                  height: 28,
                  color: Colors.white,
                ),
              ),
            ),
            if (_commentsCount > 0)
              Padding(
                padding: EdgeInsets.only(top: 1),
                child: Text(
                  _commentsCount.toString(),
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        
        SizedBox(height: 4),
        
        // Кнопка редактирования
        GestureDetector(
          onTap: _editAlbumDialog,
          child: Container(
            height: 40,
            width: 40,
            alignment: Alignment.center,
            child: Image.asset(
              'assets/Images/edit.png',
              width: 28,
              height: 28,
              color: Colors.white,
            ),
          ),
        ),
        
        SizedBox(height: 4),
        
        // Кнопка удаления
        GestureDetector(
          onTap: _confirmDeleteAlbum,
          child: Container(
            height: 40,
            width: 40,
            alignment: Alignment.center,
            child: Image.asset(
              'assets/Images/delete.png',
              width: 28,
              height: 28,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}

