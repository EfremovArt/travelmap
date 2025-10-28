import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

import '../services/album_service.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../models/post.dart';
import '../screens/upload/upload_description_screen.dart';
import '../screens/upload/upload_album_cover_screen.dart';
import '../services/album_cover_service.dart';
import 'package:intl/intl.dart';
import '../widgets/post_card.dart';
import '../widgets/album_card.dart';
import '../screens/image_viewer/network_image_viewer_screen.dart';
import '../screens/image_viewer/vertical_photo_gallery_screen.dart';
import '../screens/comments_screen.dart';
import '../screens/edit/edit_post_screen.dart';
import '../screens/location_posts_screen.dart';
import '../services/social_service.dart';
import '../utils/logger.dart';
import '../models/location.dart';
import 'dart:math';
import 'dart:io';
import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';
import '../screens/image_crop_screen.dart';
import 'package:path/path.dart' as path;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../utils/map_helper.dart';
import '../config/mapbox_config.dart';

// Общая функция для вычисления расстояния между двумя координатами в метрах (Haversine)
double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadius = 6371000.0; // метры
  final double phi1 = lat1 * pi / 180.0;
  final double phi2 = lat2 * pi / 180.0;
  final double dPhi = (lat2 - lat1) * pi / 180.0;
  final double dLambda = (lon2 - lon1) * pi / 180.0;

  final double a = sin(dPhi / 2) * sin(dPhi / 2) +
      cos(phi1) * cos(phi2) * sin(dLambda / 2) * sin(dLambda / 2);
  final double c = 2 * atan2(sqrt(a.abs()), sqrt((1 - a).abs()));
  return earthRadius * c;
}

class AlbumsTab extends StatefulWidget {
  const AlbumsTab({Key? key}) : super(key: key);

  @override
  State<AlbumsTab> createState() => _AlbumsTabState();
}

class _AlbumsTabState extends State<AlbumsTab> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  List<Map<String, dynamic>> _allAlbums = [];
  List<Map<String, dynamic>> _myAlbums = [];
  String? _currentUserId;
  String _userId = '';

  // Переменные для поиска
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _filteredAllAlbums = [];
  List<Map<String, dynamic>> _filteredMyAlbums = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final userId = await UserService.getUserId();
      _currentUserId = userId;
      _userId = userId;

      final allResp = await AlbumService.getAllAlbumsFromServer(page: 1, perPage: 50);
      final myResp = await AlbumService.getUserAlbumsFromServer(userId, page: 1, perPage: 50);

      List<Map<String, dynamic>> all = [];
      List<Map<String, dynamic>> mine = [];

      if (allResp['success'] == true && allResp['albums'] is List) {
        all = List<Map<String, dynamic>>.from(allResp['albums']);
      }
      if (myResp['success'] == true && myResp['albums'] is List) {
        mine = List<Map<String, dynamic>>.from(myResp['albums']);
      }

      // Теперь cover_url приходит напрямую из API, поэтому _attachCovers больше не нужна

      if (!mounted) return;
      setState(() {
        _allAlbums = all;
        _myAlbums = mine;
        _filterAlbums();
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Функция _attachCovers удалена, так как теперь cover_url приходит напрямую из API

  Future<void> _refresh() async {
    setState(() => _isRefreshing = true);
    await _loadData();
    if (mounted) setState(() => _isRefreshing = false);
  }

  // Методы для поиска
  void _filterAlbums() {
    final query = _searchQuery.toLowerCase().trim();
    
    if (query.isEmpty) {
      _filteredAllAlbums = List.from(_allAlbums);
      _filteredMyAlbums = List.from(_myAlbums);
    } else {
      _filteredAllAlbums = _allAlbums.where((album) => _matchesSearch(album, query)).toList();
      _filteredMyAlbums = _myAlbums.where((album) => _matchesSearch(album, query)).toList();
    }
  }

  bool _matchesSearch(Map<String, dynamic> album, String query) {
    final title = (album['title'] ?? '').toString().toLowerCase();
    final description = (album['description'] ?? '').toString().toLowerCase();
    
    // Поиск по заголовку
    if (title.contains(query)) {
      return true;
    }
    
    // Поиск по хештегам в описании
    if (description.contains(query)) {
      return true;
    }
    
    // Поиск по хештегам (слова, начинающиеся с #)
    final hashtags = RegExp(r'#\w+').allMatches(description);
    for (final match in hashtags) {
      final hashtag = match.group(0)?.toLowerCase() ?? '';
      if (hashtag.contains(query) || hashtag.substring(1).contains(query)) {
        return true;
      }
    }
    
    return false;
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _filterAlbums();
    });
  }

  void _openCreateAlbum() async {
    final created = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const CreateAlbumScreen()),
    );
    if (created == true) {
      _refresh();
    }
  }

  void _openAlbumDetails(int albumId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AlbumDetailScreen(albumId: albumId.toString(), currentUserId: _userId)),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                  // Поле поиска
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(bottom: BorderSide(color: Color(0xFFE5E5E5))),
                    ),
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: InputDecoration(
                        hintText: 'Search by albums and hashtags......',
                        prefixIcon: const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.grey),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged(''); 
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE5E5E5)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Colors.blue),
                        ),
                        filled: true,
                        fillColor: const Color(0xFFF8F9FA),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                  // Список альбомов
                  Expanded(
                    child: ((_filteredAllAlbums.isEmpty && _filteredMyAlbums.isEmpty)
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _refresh,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
                              itemCount: _filteredAllAlbums.length,
                              itemBuilder: (context, index) {
                                final albumRow = _filteredAllAlbums[index];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: AlbumCard(
                            albumRow: albumRow,
                            currentUserId: _userId,
                            onChanged: _refresh,
                            onTap: (albumId) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => AlbumDetailScreen(
                                    albumId: albumId,
                                    currentUserId: _userId,
                                  ),
                                ),
                              );
                            },
                            onEditAlbum: (albumId, album, photos) async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EditAlbumScreen(
                                    albumId: albumId,
                                    initialTitle: album['title']?.toString() ?? '',
                                    initialDescription: album['description']?.toString() ?? '',
                                    initialPhotos: photos,
                                  ),
                                ),
                              );
                              await _refresh();
                            },
                          ),
                        );
                      },
                    ),
                  )),
                  ),
                ],
              ),
      ),
    );
  }
}

Widget _buildEmptyState() {
  return Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.photo_album_outlined, size: 64, color: Colors.grey),
        SizedBox(height: 16),
        Text(
          'No albums created yet',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8),
        Text(
          'Create your first album to organize your travel memories',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey),
        ),
      ],
    ),
  );
}

class _AlbumFeedCard extends StatefulWidget {
  final Map<String, dynamic> albumRow;
  final String? currentUserId;
  final FutureOr<void> Function() onChanged;
  const _AlbumFeedCard({required this.albumRow, required this.currentUserId, required this.onChanged});

  @override
  State<_AlbumFeedCard> createState() => _AlbumFeedCardState();
}

class _AlbumFeedCardState extends State<_AlbumFeedCard> {
  Map<String, dynamic>? _album; // details
  List<Map<String, dynamic>> _photos = [];
  bool _loading = true;
  bool _liked = false;
  int _likes = 0;
  bool _favorite = false;
  int _favoritesCount = 0;
  int _page = 0;
  String _locationName = '';
  String _ownerName = '';
  String _ownerAvatar = '';
  DateTime? _createdAt;
  String? _coverUrl;

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
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
        try {
          if (ownerId.isNotEmpty) {
            final user = await UserService.getUserInfoById(ownerId);
            final first = (user['firstName'] ?? '').toString();
            final last = (user['lastName'] ?? '').toString();
            ownerName = (first + ' ' + last).trim();
            final rawAvatar = (user['profileImageUrl'] ?? '').toString();
            ownerAvatar = rawAvatar.isNotEmpty ? ApiConfig.formatImageUrl(rawAvatar) : '';
          }
        } catch (_) {}

        // Дата создания
        DateTime? createdAt;
        try {
          createdAt = DateTime.tryParse(album['created_at']?.toString() ?? '') ?? DateTime.now();
        } catch (_) {}

        // URL обложки - приоритет загруженной обложке
        String? coverUrl;
        
        // Сначала проверяем, есть ли загруженная обложка в данных альбома из API
        if (album['cover_url']?.toString().isNotEmpty ?? false) {
          coverUrl = ApiConfig.formatImageUrl(album['cover_url']!.toString());
        } 
        // ТОЛЬКО если нет обложки, используем первое фото как fallback
        else if (photos.isNotEmpty) {
          final fp = (photos.first['file_path'] ?? photos.first['filePath'] ?? '').toString();
          if (fp.isNotEmpty) coverUrl = ApiConfig.formatImageUrl(fp);
        }

        if (!mounted) return;
        setState(() {
          _album = album;
          _photos = photos;
          _likes = likeInfo['likesCount'] ?? 0;
          _liked = likeInfo['isLiked'] == true;
          _favorite = favInfo['isFavorite'] == true;
          _favoritesCount = int.tryParse((favInfo['favoritesCount'] ?? favInfo['favorites_count'] ?? '0').toString()) ?? 0;
          _locationName = locName;
          _ownerName = ownerName;
          _ownerAvatar = ownerAvatar;
          _createdAt = createdAt;
          _coverUrl = coverUrl;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleLike() async {
    final id = widget.albumRow['id'].toString();
    setState(() {
      _liked = !_liked;
      _likes = _liked ? _likes + 1 : (_likes > 0 ? _likes - 1 : 0);
    });
    if (_liked) {
      await AlbumService.likeAlbum(id);
    } else {
      await AlbumService.unlikeAlbum(id);
    }
  }

  Future<void> _toggleFavorite() async {
    final id = widget.albumRow['id'].toString();
    setState(() {
      _favorite = !_favorite;
      _favoritesCount = (_favoritesCount + (_favorite ? 1 : -1)).clamp(0, 1 << 30).toInt();
    });
    if (_favorite) {
      await AlbumService.favoriteAlbum(id);
      try {
        // Сохраняем текущую «строку альбома» как избранную
        await AlbumService.addAlbumToFavoritesLocal(widget.albumRow);
      } catch (_) {}
    } else {
      await AlbumService.unfavoriteAlbum(id);
      try {
        await AlbumService.removeAlbumFromFavoritesLocal(id);
      } catch (_) {}
    }
  }

  void _openComments() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AlbumCommentsSheet(albumId: widget.albumRow['id'].toString()),
    );
    _load();
  }

  Future<void> _editAlbum() async {
    if (_album == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditAlbumScreen(
          albumId: widget.albumRow['id'].toString(),
          initialTitle: _album!['title']?.toString() ?? '',
          initialDescription: _album!['description']?.toString() ?? '',
          initialPhotos: _photos,
        ),
      ),
    );
    await _load();
    await widget.onChanged();
  }

  Future<void> _deleteAlbum() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete album?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try {
        final res = await AlbumService.deleteAlbumServer(widget.albumRow['id'].toString());
        if (res['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Album deleted')),
            );
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res['message']?.toString() ?? 'Failed to delete album'), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete album'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = (widget.albumRow['title'] ?? '').toString();
    final description = (widget.albumRow['description'] ?? '').toString();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        height: 420,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок с автором и датой, как в посте
            Padding(
              padding: const EdgeInsets.all(6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Аватар автора
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.transparent,
                    backgroundImage: _ownerAvatar.isNotEmpty
                        ? CachedNetworkImageProvider(_ownerAvatar)
                        : null,
                    child: _ownerAvatar.isEmpty
                        ? Icon(
                            Icons.person,
                            size: 22,
                            color: Colors.grey.shade600,
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  // Имя автора
                  Expanded(
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
            ),
            
            // Блок информации об альбоме по всей ширине
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Индикатор альбома и заголовок
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
                  // Описание альбома по всей ширине
                  if (description.isNotEmpty) ...[
                    SizedBox(height: 6),
                    Text(
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
                  ],
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Одна обложка альбома
            Expanded(
              child: Container(
                margin: EdgeInsets.zero,
                width: double.infinity,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    if (_loading)
                      const Center(child: CircularProgressIndicator())
                    else
                      GestureDetector(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => AlbumDetailScreen(
                                albumId: widget.albumRow['id'].toString(),
                                currentUserId: widget.currentUserId,
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Positioned.fill(
                              child: _coverUrl != null && _coverUrl!.isNotEmpty
                                  ? CachedNetworkImage(
                                      imageUrl: _coverUrl!,
                                      fit: BoxFit.cover,
                                      useOldImageOnUrlChange: false,
                                      fadeInDuration: const Duration(milliseconds: 300),
                                      fadeOutDuration: const Duration(milliseconds: 100),
                                    )
                                  : Container(color: Colors.grey.shade200),
                            ),
                          ],
                        ),
                      ),
                    // Вертикальная колонка иконок справа, как у постов
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (_isOwner) ...[
                              IconButton(
                                icon: Image.asset('assets/Images/heart.png', width: 28, height: 28, color: _liked ? Colors.red : Colors.white),
                                onPressed: _toggleLike,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                              if (_likes > 0)
                                Text('$_likes', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              Container(height: 1, width: 20, color: Colors.white.withOpacity(0.3)),
                              IconButton(
                                icon: Image.asset('assets/Images/comment.png', width: 28, height: 28, color: Colors.white),
                                onPressed: _openComments,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                              Container(height: 1, width: 20, color: Colors.white.withOpacity(0.3)),
                              IconButton(
                                icon: Image.asset('assets/Images/edit.png', width: 28, height: 28, color: Colors.white),
                                onPressed: _editAlbum,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                              Container(height: 1, width: 20, color: Colors.white.withOpacity(0.3)),
                              IconButton(
                                icon: Image.asset('assets/Images/delete.png', width: 28, height: 28, color: Colors.white),
                                onPressed: _deleteAlbum,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                            ] else ...[
                              // Кнопка избранного - точно как в FavoriteButton из постов
                              Column(
                                children: [
                                  IconButton(
                                    icon: Image.asset('assets/Images/star.png', width: 28, height: 28, color: _favorite ? Colors.yellow : Colors.white),
                                    onPressed: _toggleFavorite,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                  ),
                                  if (_favoritesCount > 0)
                                    Text(
                                      '$_favoritesCount',
                                      style: const TextStyle(
                                        fontFamily: 'Gilroy',
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              Container(height: 1, width: 20, color: Colors.white.withOpacity(0.3)),
                              // Кнопка лайка - точно как в LikeButton из постов  
                              Column(
                                children: [
                                  IconButton(
                                    icon: Image.asset('assets/Images/heart.png', width: 28, height: 28, color: _liked ? Colors.red : Colors.white),
                                    onPressed: _toggleLike,
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                                  ),
                                  if (_likes > 0)
                                    Text(
                                      '$_likes',
                                      style: const TextStyle(
                                        fontFamily: 'Gilroy',
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                              Container(height: 1, width: 20, color: Colors.white.withOpacity(0.3)),
                              IconButton(
                                icon: Image.asset('assets/Images/comment.png', width: 28, height: 28, color: Colors.white),
                                onPressed: _openComments,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // без нижнего блока геолокации по требованиям
          ],
        ),
      ),
    );
  }
}

// ===================== Create Album Flow =====================

class CreateAlbumScreen extends StatefulWidget {
  const CreateAlbumScreen({Key? key}) : super(key: key);

  @override
  State<CreateAlbumScreen> createState() => _CreateAlbumScreenState();
}

class _CreateAlbumScreenState extends State<CreateAlbumScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  List<String> _selectedPostIds = [];
  bool _submitting = false;
  String? _coverPhotoId;
  String? _coverPreviewUrl;

  Future<void> _selectPosts() async {
    final userId = await UserService.getUserId();
    final res = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => SelectPostsScreen(userId: userId, initiallySelected: _selectedPostIds)),
    );
    if (res != null) {
      setState(() => _selectedPostIds = res);
    }
  }

  Future<void> _uploadNewPhotos() async {
    // Полный флоу загрузки новых фото с выбором локации и описания
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UploadDescriptionScreen()),
    );

    // Автодобавление всех фото из только что опубликованной локации
    try {
      if (result is GeoLocation) {
        final photoIds = await _collectRecentLocationPhotoIds(result);
        if (photoIds.isNotEmpty) {
          final newIds = <String>{..._selectedPostIds, ...photoIds};
          setState(() => _selectedPostIds = newIds.toList());

          // Предзаполним предпросмотр обложки, если ещё не выбран
          if (_coverPhotoId == null) {
            // Попробуем получить URL первой фото через PostService (по первому photoId)
            try {
              final firstId = photoIds.first;
              final post = await PostService.getPostById(firstId);
              if (post != null && post.imageUrls.isNotEmpty) {
                setState(() {
                  _coverPhotoId = firstId;
                  _coverPreviewUrl = post.imageUrls.first;
                });
              }
            } catch (_) {}
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Added photos: ${photoIds.length}')),
            );
          }
        } else {
          // Fallback: если не удалось собрать photoIds по локации,
          // пробуем найти самые свежие посты текущего пользователя рядом с точкой
          try {
            final String currentUserId = await UserService.getUserId();
            final List<Post> allPosts = await PostService.getAllPosts();
            // Простая метрика расстояния (Гаверсин)
            double distanceMeters(double lat1, double lon1, double lat2, double lon2) {
              const double R = 6371000.0;
              final double dLat = (lat2 - lat1) * pi / 180.0;
              final double dLon = (lon2 - lon1) * pi / 180.0;
              final double a = sin(dLat / 2) * sin(dLat / 2) +
                  cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) *
                  sin(dLon / 2) * sin(dLon / 2);
              final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
              return R * c;
            }

            final DateTime threshold = DateTime.now().subtract(const Duration(minutes: 20));
            final List<Post> nearbyRecent = allPosts.where((p) {
              if (p.user != currentUserId) return false;
              if (p.location == null) return false;
              if (p.createdAt.isBefore(threshold)) return false;
              final double d = distanceMeters(
                result.latitude,
                result.longitude,
                p.location.latitude,
                p.location.longitude,
              );
              return d <= 250.0; // 250м от выбранной точки
            }).toList();

            if (nearbyRecent.isNotEmpty) {
              final List<String> ids = nearbyRecent.map((e) => e.id).toList();
              final newIds = <String>{..._selectedPostIds, ...ids};
              setState(() => _selectedPostIds = newIds.toList());

              if (_coverPhotoId == null) {
                final first = nearbyRecent.first;
                if (first.imageUrls.isNotEmpty) {
                  setState(() {
                    _coverPhotoId = first.id;
                    _coverPreviewUrl = first.imageUrls.first;
                  });
                }
              }

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Added photos: ${ids.length}')),
                );
              }
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  // Ищем ближайшую недавно созданную локацию пользователя и возвращаем все её photo_id
  Future<List<String>> _collectRecentLocationPhotoIds(GeoLocation geo) async {
    try {
      final uri = Uri.parse(ApiConfig.getAllLocations);
      final resp = await http.get(uri, headers: AuthService().sessionHeaders);
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body);
      if (data['success'] != true) return [];
      final List<dynamic> locations = data['data']?['locations'] ?? [];

      // Найдём ближайшую локацию (<= 150м) с самой свежей датой создания (за последние 15 минут)
      double bestDistance = double.infinity;
      Map<String, dynamic>? target;
      final now = DateTime.now();
      for (final loc in locations) {
        final lat = double.tryParse(loc['latitude']?.toString() ?? '');
        final lng = double.tryParse(loc['longitude']?.toString() ?? '');
        if (lat == null || lng == null) continue;
        final d = _distanceMeters(geo.latitude, geo.longitude, lat, lng);
        if (d > 150) continue;
        DateTime createdAt;
        try {
          createdAt = DateTime.parse(loc['created_at']?.toString() ?? '');
        } catch (_) {
          createdAt = now.subtract(const Duration(days: 365));
        }
        if (now.difference(createdAt) > const Duration(minutes: 15)) continue;
        if (d < bestDistance) {
          bestDistance = d;
          target = loc as Map<String, dynamic>;
        }
      }

      if (target == null) return [];
      final photos = (target['photos'] as List<dynamic>? ?? []);
      final ids = <String>[];
      for (final p in photos) {
        final id = p['id']?.toString();
        if (id != null && id.isNotEmpty) ids.add(id);
      }
      return ids;
    } catch (_) {
      return [];
    }
  }

  // Расстояние между двумя точками в метрах (haversine)
  double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    // Делегируем вычисление общей функции уровня файла
    return _distanceMeters(lat1, lon1, lat2, lon2);
  }

  Future<void> _uploadCoverFromGallery() async {
    // Открываем упрощенный экран загрузки обложки альбома
    final selectedImage = await Navigator.of(context).push<File>(
      MaterialPageRoute(builder: (_) => const UploadAlbumCoverScreen()),
    );
    
    if (selectedImage != null) {
      setState(() {
        _submitting = true;
      });
      
      try {
        // Загружаем обложку через упрощенный сервис
        final result = await AlbumCoverService.uploadCover(selectedImage);
        
        if (result['success'] == true) {
          setState(() {
            _coverPhotoId = result['cover_id']?.toString();
            _coverPreviewUrl = ApiConfig.formatImageUrl(result['cover_url']);
          });
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Album cover uploaded successfully')),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading cover: ${result['error']}')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading cover: $e')),
        );
      } finally {
        if (mounted) {
          setState(() {
            _submitting = false;
          });
        }
      }
    }
  }

  Future<void> _create() async {
    if (_titleCtrl.text.trim().isEmpty) return;
    setState(() => _submitting = true);
    try {
      final resp = await AlbumService.createAlbumServer(
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        postIds: _selectedPostIds,
        isPublic: true,
        coverPhotoId: _coverPhotoId,
      );
      if (resp['success'] == true) {
        if (!mounted) return;
        Navigator.of(context).pop(true);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message']?.toString() ?? 'Failed to create album')));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFE5E5E5),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Color(0xFF2D2D2D),
                        size: 18,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Create Album',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D2D),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    const Text(
                      'Album Details',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Give your album a memorable name and description',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Title Field
                    _buildTextField(
                      controller: _titleCtrl,
                      label: 'Album Title',
                      hint: 'Enter a title for your album',
                      icon: Icons.collections_bookmark_outlined,
                    ),
                    const SizedBox(height: 24),
                    
                    // Description Field
                    _buildTextField(
                      controller: _descCtrl,
                      label: 'Description',
                      hint: 'Tell us about this album...',
                      icon: Icons.description_outlined,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 40),
                    
                    // Cover Section
                    const Text(
                      'Album Cover',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a stunning cover image for your album',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Cover Preview
                    _buildCoverPreview(),
                    const SizedBox(height: 40),
                    
                    // Content Section
                    const Text(
                      'Add Content',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Select existing posts or upload new photos',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Action Buttons
                    _buildActionButtons(),
                    const SizedBox(height: 32),
                    
                    // Selected Posts Count
                    if (_selectedPostIds.isNotEmpty) _buildSelectedInfo(),
                    const SizedBox(height: 40),
                    
                    // Create Button
                    _buildCreateButton(),
                    const SizedBox(height: 16),
                    
                    // Help Text
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE9ECEF),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6C757D),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You can also upload new posts later and add them to this album.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[700],
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,  
      children: [
        Text(
          label, 
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D2D2D),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E5E5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF2D2D2D),
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 16, right: 12),
                child: Icon(
                  icon,
                  color: Colors.grey[400],
                  size: 22,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverPreview() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E5E5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _coverPreviewUrl != null && _coverPreviewUrl!.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _coverPreviewUrl!,
                    fit: BoxFit.cover,
                    useOldImageOnUrlChange: false,
                    fadeInDuration: const Duration(milliseconds: 300),
                    fadeOutDuration: const Duration(milliseconds: 100),
                  ),
                  // Overlay with actions
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildCoverAction(
                          icon: Icons.edit_outlined,
                          onTap: _uploadCoverFromGallery,
                        ),
                        const SizedBox(width: 8),
                        _buildCoverAction(
                          icon: Icons.delete_outline,
                          onTap: () => setState(() {
                            _coverPhotoId = null;
                            _coverPreviewUrl = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.grey[400],
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No cover selected',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'First photo will be used as cover',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _uploadCoverFromGallery,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Upload Cover',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCoverAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: const Color(0xFF2D2D2D),
          size: 18,
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: _buildActionButton(
            title: 'Select Posts',
            subtitle: 'From existing posts',
            icon: Icons.collections_outlined,
            onTap: _selectPosts,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildActionButton(
            title: 'Create Post',
            subtitle: 'New photos',
            icon: Icons.file_upload_outlined,
            onTap: _uploadNewPhotos,
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFE5E5E5),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: const Color(0xFF2D2D2D),
                size: 22,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Color(0xFF2D2D2D),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFB3D9FF),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF007AFF),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '${_selectedPostIds.length} ${_selectedPostIds.length == 1 ? 'post' : 'posts'} selected',
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF007AFF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _submitting || _titleCtrl.text.trim().isEmpty ? null : _create,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2D2D2D),
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[300],
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _submitting
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Text(
                'Create Album',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
      ),
    );
  }
}

class SelectPostsScreen extends StatefulWidget {
  final String userId;
  final List<String> initiallySelected;
  const SelectPostsScreen({Key? key, required this.userId, this.initiallySelected = const []}) : super(key: key);

  @override
  State<SelectPostsScreen> createState() => _SelectPostsScreenState();
}

class _SelectPostsScreenState extends State<SelectPostsScreen> {
  bool _loading = true;
  List<Post> _posts = [];
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.initiallySelected);
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final posts = await PostService.getUserPosts(userId: widget.userId);
      if (!mounted) return;
      setState(() => _posts = posts);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(Post post) {
    setState(() {
      // Если пост уже выбран, удаляем все его фотографии
      if (_selected.contains(post.id)) {
        // Удаляем все photoIds этого поста
        for (String photoId in post.photoIds) {
          _selected.remove(photoId);
        }
      } else {
        // Добавляем все photoIds этого поста
        for (String photoId in post.photoIds) {
          _selected.add(photoId);
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select posts', style: TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selected.toList()),
            child: const Text('Done'),
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _posts.length,
              itemBuilder: (_, i) {
                final p = _posts[i];
                final imageUrl = p.imageUrls.isNotEmpty ? p.imageUrls.first : '';
                final selected = _selected.contains(p.id);
                return GestureDetector(
                  onTap: () => _toggle(p),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      imageUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              fit: BoxFit.cover,
                              useOldImageOnUrlChange: true,
                              fadeInDuration: Duration(milliseconds: 0),
                              fadeOutDuration: Duration(milliseconds: 0),
                            )
                          : Container(color: Colors.grey.shade200),
                      Positioned(
                        top: 6,
                        right: 6,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: selected ? Colors.blue : Colors.white,
                          child: Icon(selected ? Icons.check : Icons.add, size: 16, color: selected ? Colors.white : Colors.black87),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

// ===================== Album Details =====================

class AlbumDetailScreen extends StatefulWidget {
  final String albumId;
  final String? currentUserId;
  const AlbumDetailScreen({Key? key, required this.albumId, this.currentUserId}) : super(key: key);

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  bool _loading = true;
  Map<String, dynamic>? _album;
  List<Map<String, dynamic>> _photos = [];
  int _page = 0;
  bool _liked = false;
  int _likes = 0;
  bool _favorite = false;
  int _favoritesCount = 0;
  List<Post> _albumPosts = [];
  String _currentUserName = '';
  String _currentUserAvatar = '';
  final Map<String, Map<String, String>> _authors = {}; // userId -> {name, profileImageUrl}
  String _albumOwnerId = '';
  String _albumOwnerName = 'User';
  String _albumOwnerAvatar = '';
  final ScrollController _listController = ScrollController();
  String? _pendingScrollPostId;
  Timer? _scrollRetryTimer;
  int _scrollAttempts = 0;

  String _normalize(String? value) {
    final s = (value ?? '').toString().trim();
    if (s.isEmpty) return '';
    final lowered = s.toLowerCase();
    if (lowered == 'null' || lowered == 'undefined' || lowered == 'none' || lowered == 'nan') return '';
    return s;
  }

  String _makeFullName(String? first, String? last) {
    final f = _normalize(first);
    final l = _normalize(last);
    if (f.isEmpty && l.isEmpty) return 'User';
    if (f.isEmpty) return l;
    if (l.isEmpty) return f;
    return '$f $l';
  }

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final resp = await AlbumService.getAlbumDetails(widget.albumId);
      if (resp['success'] == true) {
        final album = Map<String, dynamic>.from(resp['album']);
        final photos = List<Map<String, dynamic>>.from(resp['photos'] ?? []);
        final likeInfo = await AlbumService.getAlbumLikeInfo(widget.albumId);
        final favInfo = await AlbumService.getAlbumFavoriteInfo(widget.albumId);

        // Текущий пользователь (для PostCard)
        try {
          _currentUserName = await UserService.getFullName();
          _currentUserAvatar = await UserService.getProfileImage();
        } catch (_) {}

        // Построим список постов (как в ленте) на основе фото альбома
        final posts = await _buildPostsFromAlbumPhotos(photos);

        if (!mounted) return;
        setState(() {
          _album = album;
          _photos = photos;
          _likes = likeInfo['likesCount'] ?? 0;
          _liked = likeInfo['isLiked'] == true;
          _favorite = favInfo['isFavorite'] == true;
          _favoritesCount = int.tryParse((favInfo['favoritesCount'] ?? favInfo['favorites_count'] ?? '0').toString()) ?? 0;
          _albumPosts = posts;
          _albumOwnerId = album['owner_id']?.toString() ?? '';
        });

        // Префетчим авторов для корректного отображения имени/аватара
        await _prefetchAuthors(posts);

        // Загружаем имя владельца альбома и аватар для дефолта
        if (_albumOwnerId.isNotEmpty) {
          try {
            final info = await UserService.getUserInfoById(_albumOwnerId);
            final ownerName = _makeFullName(info['firstName']?.toString(), info['lastName']?.toString());
            final rawAvatar = _normalize(info['profileImageUrl']?.toString());
            final ownerAvatar = rawAvatar.isNotEmpty ? ApiConfig.formatImageUrl(rawAvatar) : '';
            if (mounted) {
              setState(() {
                _albumOwnerName = ownerName;
                _albumOwnerAvatar = ownerAvatar;
              });
            }
          } catch (_) {}
        }
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(resp['message']?.toString() ?? 'Failed to load album')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<Post>> _buildPostsFromAlbumPhotos(List<Map<String, dynamic>> photos) async {
    // Группируем фото по locationId
    final Map<String, List<Map<String, dynamic>>> byLocation = {};
    for (final p in photos) {
      final photoId = (p['id'] ?? p['photo_id'] ?? '').toString();
      if (photoId.isEmpty) continue;
      String? locationId = await PostService.getLocationIdByPhotoId(photoId);
      locationId ??= 'photo_$photoId';
      byLocation.putIfAbsent(locationId, () => []).add(p);
    }

    final List<Post> result = [];
    for (final entry in byLocation.entries) {
      final locPhotos = entry.value;
      if (locPhotos.isEmpty) continue;
      final firstId = (locPhotos.first['id'] ?? locPhotos.first['photo_id'] ?? '').toString();
      final basePost = await PostService.getPostById(firstId);
      if (basePost == null) continue;

      // Собираем список URL только из фото, входящих в альбом
      final urls = <String>[];
      for (final lp in locPhotos) {
        final fp = (lp['file_path'] ?? lp['filePath'] ?? '').toString();
        if (fp.isEmpty) continue;
        urls.add(ApiConfig.formatImageUrl(fp));
      }

      result.add(Post(
        id: basePost.id,
        user: basePost.user,
        title: basePost.title,
        description: basePost.description,
        locationName: basePost.locationName,
        location: basePost.location,
        images: const [],
        imageUrls: urls.isNotEmpty ? urls : basePost.imageUrls,
        createdAt: basePost.createdAt,
      ));
    }

    return result;
  }

  Future<void> _prefetchAuthors(List<Post> posts) async {
    final Set<String> ids = {for (final p in posts) p.user};
    for (final id in ids) {
      if (_authors.containsKey(id)) continue;
      try {
        final isNumericId = RegExp(r'^\d+$').hasMatch(id);
        if (!isNumericId && id.contains('@')) {
          // Идентификатор похож на email — получаем по email
          final name = await UserService.getFullNameByEmail(id);
          final profile = await UserService.getProfileImageByEmail(id) ?? '';
          _authors[id] = {
            'name': _normalize(name),
            'profileImageUrl': _normalize(profile),
          };
        } else {
          // Числовой ID — получаем по ID
          final info = await UserService.getUserInfoById(id);
          final name = _makeFullName(info['firstName']?.toString(), info['lastName']?.toString());
          final rawProfile = _normalize(info['profileImageUrl']?.toString());
          final profile = rawProfile.isNotEmpty ? ApiConfig.formatImageUrl(rawProfile) : '';
          _authors[id] = {'name': name, 'profileImageUrl': profile};
        }
        if (mounted) setState(() {});
      } catch (_) {
        // Фолбэк при ошибке — хотя бы не пустое имя
        _authors[id] = {'name': 'User', 'profileImageUrl': ''};
        if (mounted) setState(() {});
      }
    }
  }

  Future<void> _toggleLike() async {
    setState(() {
      _liked = !_liked;
      _likes = _liked ? _likes + 1 : (_likes > 0 ? _likes - 1 : 0);
    });
    if (_liked) {
      await AlbumService.likeAlbum(widget.albumId);
    } else {
      await AlbumService.unlikeAlbum(widget.albumId);
    }
  }

  Future<void> _toggleFavorite() async {
    setState(() {
      _favorite = !_favorite;
      _favoritesCount = (_favoritesCount + (_favorite ? 1 : -1)).clamp(0, 1 << 30).toInt();
    });
    if (_favorite) {
      await AlbumService.favoriteAlbum(widget.albumId);
      try {
        // Построим минимальный albumRow для локального хранения
        final row = <String, dynamic>{
          'id': widget.albumId,
          'title': (_album?['title'] ?? '').toString(),
          'description': (_album?['description'] ?? '').toString(),
          'owner_id': (_album?['owner_id'] ?? '').toString(),
          'cover_photo_id': (_album?['cover_photo_id'] ?? '').toString(),
        };
        await AlbumService.addAlbumToFavoritesLocal(row);
      } catch (_) {}
    } else {
      await AlbumService.unfavoriteAlbum(widget.albumId);
      try {
        await AlbumService.removeAlbumFromFavoritesLocal(widget.albumId);
      } catch (_) {}
    }
  }

  void _openComments() async {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _AlbumCommentsSheet(albumId: widget.albumId),
    ).then((_) => _load());
  }

  Future<void> _editAlbum() async {
    if (_album == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditAlbumScreen(
          albumId: widget.albumId,
          initialTitle: _album!['title']?.toString() ?? '',
          initialDescription: _album!['description']?.toString() ?? '',
          initialPhotos: _photos,
        ),
      ),
    );
    await _load();
  }

  Future<void> _deleteAlbum() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete album?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      try {
        final res = await AlbumService.deleteAlbumServer(widget.albumId);
        if (res['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Album deleted')),
            );
            Navigator.pop(context);
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(res['message']?.toString() ?? 'Failed to delete album'), backgroundColor: Colors.red),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete album'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Если есть отложенный скролл — пробуем выполнить его сразу после отрисовки кадра
    if (_pendingScrollPostId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final id = _pendingScrollPostId;
        if (id != null) {
          final ok = await _scrollToPostById(id);
          if (ok) {
            _pendingScrollPostId = null;
          } else if (_scrollRetryTimer == null || !_scrollRetryTimer!.isActive) {
            _startScrollRetry();
          }
        }
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_album?['title']?.toString() ?? 'Album', style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
        actions: [
          if (_isOwner) IconButton(icon: const Icon(Icons.edit), onPressed: _editAlbum),
          if (_isOwner) IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteAlbum),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _albumPosts.isEmpty
              ? const Center(child: Text('No photos in this album yet'))
              : ListView.builder(
                  controller: _listController,
                  itemCount: _albumPosts.length,
                  itemBuilder: (context, index) {
                    final post = _albumPosts[index];
                    final isCurrentUserPost = widget.currentUserId != null && post.user == widget.currentUserId;
                    
                    final authorName = _albumOwnerName;
                    final authorImage = _albumOwnerAvatar;
                    final key = _postKeys.putIfAbsent(post.id, () => GlobalKey());
                    return Padding(
                      key: key,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      child: PostCard(
                        post: post,
                        userProfileImage: _currentUserAvatar,
                        userFullName: _currentUserName,
                        authorProfileImage: authorImage,
                        authorName: authorName,
                        isCurrentUserPost: isCurrentUserPost,
                        onShowCommentsModal: _showCommentsModal,
                        onShowOnMap: _showOnMap,
                        onEditPost: _editPost,
                        onDeletePost: _deletePost,
                        onLikePost: _likePost,
                        onFavoritePost: _favoritePost,
                        onLocationPostsClick: _openLocationPostsScreen,
                        onImageTap: (post, imageIndex) {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => VerticalPhotoGalleryScreen(
                                post: post,
                                initialIndex: imageIndex,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
    );
  }

  // ===== Методы для функционала постов =====
  
  /// Открыть страницу с постами локации
  void _openLocationPostsScreen(Post post) {
    AppLogger.log('🔄 Открытие экрана постов локации: ${post.locationName}');
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LocationPostsScreen(
          initialPost: post,
          locationName: post.locationName,
          latitude: post.location.latitude,
          longitude: post.location.longitude,
        ),
      ),
    );
  }
  
  /// Показать модальное окно с комментариями к посту
  void _showCommentsModal(Post post) {
    showModalBottomSheet(
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
          child: CommentsScreen(
            photoId: post.id,
            photoUrl: post.imageUrls.isNotEmpty
                ? post.imageUrls.first
                : (post.images.isNotEmpty
                ? post.images.first.path
                : 'https://via.placeholder.com/300'),
          ),
        );
      },
    ).then((_) {
      // Обновляем список постов после закрытия окна комментариев
      _load();
    });
  }

  /// Показать пост на карте
  void _showOnMap(Post post) {
    // Переходим на экран альбома с картой для конкретного поста
    _openAlbumMapForPost(post);
  }

  /// Редактировать пост
  void _editPost(Post post) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostScreen(post: post),
      ),
    ).then((_) => _load());
  }

  /// Удалить пост
  Future<void> _deletePost(Post post) async {
    try {
      await PostService.deletePost(post.id);
      await _load(); // Обновляем список постов в альбоме
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Post deleted successfully')),
      );
    } catch (e) {
      AppLogger.log("Error deleting post: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to delete post')),
      );
    }
  }

  /// Лайкнуть/убрать лайк с поста
  Future<void> _likePost(Post post) async {
    try {
      final isLiked = await SocialService.isLiked(post.id);
      
      if (isLiked) {
        await SocialService.unlikePost(post.id);
      } else {
        await SocialService.likePost(post.id);
      }
      
      // UI будет обновлен автоматически через PostCard
    } catch (e) {
      AppLogger.log("Error liking post: $e");
    }
  }

  /// Добавить/убрать пост из избранного
  Future<void> _favoritePost(Post post) async {
    try {
      final isFavorite = await SocialService.isFavorite(post.id);
      
      if (isFavorite) {
        await SocialService.removeFromFavorites(post.id);
      } else {
        await SocialService.addToFavorites(post.id);
      }
      
      // UI будет обновлен автоматически через PostCard
    } catch (e) {
      AppLogger.log("Error favoriting post: $e");
    }
  }


  // Хранение ключей карточек постов для прокрутки к ним после возврата с карты
  final Map<String, GlobalKey> _postKeys = {};

  Future<void> _openAlbumMapForPost(Post centerPost) async {
    final selectedId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => AlbumMapScreen(
          posts: _albumPosts,
          selectedPostId: centerPost.id,
          title: _album?['title']?.toString() ?? 'Album map',
        ),
      ),
    );
    if (selectedId != null) {
      _pendingScrollPostId = selectedId;
      _startScrollRetry();
    }
  }

  Future<bool> _scrollToPostById(String postId) async {
    // Нормализуем ID (защита от случайных пробелов)
    final normalizedId = postId.trim();

    // Попытка через ключ
    final key = _postKeys[normalizedId];
    if (key?.currentContext != null) {
      // Гарантируем, что выравнивание произойдёт после кадра
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final ctx = key?.currentContext;
        if (ctx != null) {
          await Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 350),
            alignment: 0.05,
          );
        }
      });
      return true;
    }

    // Фолбэк: прокрутка по индексу
    int index = _albumPosts.indexWhere((p) => p.id == normalizedId);
    if (index != -1 && _listController.hasClients) {
      final double offset = (index * 496.0).toDouble();
      _listController.jumpTo(offset.clamp(0.0, _listController.position.maxScrollExtent));
      // Дополнительно выравниваем после следующего кадра, когда элемент точно построен
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final retryKey = _postKeys[normalizedId];
        final ctx = retryKey?.currentContext;
        if (ctx != null) {
          await Scrollable.ensureVisible(
            ctx,
            duration: const Duration(milliseconds: 250),
            alignment: 0.05,
          );
        }
      });
      return true;
    }

    // Дополнительный фолбэк: пост по ID не найден среди _albumPosts.
    // Бывает, если ID отличается (агрегация по локации/порядок фото). Попробуем найти по координатам/названию.
    try {
      final resolvedPost = await PostService.getPostById(normalizedId);
      if (resolvedPost != null) {
        // Ищем наилучшее совпадение в текущем списке постов альбома
        const double maxDistanceMeters = 50.0;
        int bestIndex = -1;
        double bestDistance = double.infinity;
        for (int i = 0; i < _albumPosts.length; i++) {
          final p = _albumPosts[i];
          final sameName = p.locationName.trim().toLowerCase() == resolvedPost.locationName.trim().toLowerCase();
          final dist = _distanceMeters(
            resolvedPost.location.latitude,
            resolvedPost.location.longitude,
            p.location.latitude,
            p.location.longitude,
          );
          final isClose = dist <= maxDistanceMeters;
          if (sameName || isClose) {
            // Выбираем ближайший
            if (dist < bestDistance) {
              bestDistance = dist;
              bestIndex = i;
            }
          }
        }

        if (bestIndex != -1 && _listController.hasClients) {
          final double offset = (bestIndex * 496.0).toDouble();
          _listController.jumpTo(offset.clamp(0.0, _listController.position.maxScrollExtent));
          // Выравниваем после кадра, когда элемент построен
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            if (!mounted) return;
            final matchedId = _albumPosts[bestIndex].id;
            final key2 = _postKeys[matchedId];
            final ctx2 = key2?.currentContext;
            if (ctx2 != null) {
              await Scrollable.ensureVisible(
                ctx2,
                duration: const Duration(milliseconds: 300),
                alignment: 0.05,
              );
            }
          });
          return true;
        }
      }
    } catch (_) {}

    return false;
  }

  void _startScrollRetry() {
    _scrollRetryTimer?.cancel();
    _scrollAttempts = 0;
    if (_pendingScrollPostId == null) return;
    // Увеличиваем окно ретраев и интервал — даём списку время построиться и подгрузить данные
    const int maxAttempts = 60; // ~9 секунд при 150 мс
    const Duration interval = Duration(milliseconds: 150);
    _scrollRetryTimer = Timer.periodic(interval, (t) async {
      _scrollAttempts++;
      if (_pendingScrollPostId == null) {
        t.cancel();
        return;
      }
      final ok = await _scrollToPostById(_pendingScrollPostId!);
      if (ok || _scrollAttempts > maxAttempts) {
        _pendingScrollPostId = null;
        t.cancel();
      }
    });
  }

  Future<void> _uploadNewPhotosAndAddToPost(Post targetPost) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UploadDescriptionScreen()),
    );

    try {
      if (result is GeoLocation) {
        // Проверим, что выбранная при публикации локация соответствует целевому посту
        final dist = _distanceMeters(
          targetPost.location.latitude,
          targetPost.location.longitude,
          result.latitude,
          result.longitude,
        );
        if (dist > 250) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Selected location is far from target post')), // информируем о расхождении
            );
          }
        }

        // В любом случае пробуем подобрать ближайшую свежую локацию и добавить все её фото
        final ids = await _collectRecentLocationPhotoIdsDetail(result);
        if (ids.isNotEmpty) {
          await AlbumService.addPhotosToAlbum(widget.albumId, ids);
          await _load();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Added photos: ${ids.length}')),
            );
          }
        }
      }
    } catch (_) {}
  }

  Future<List<String>> _collectRecentLocationPhotoIdsDetail(GeoLocation geo) async {
    try {
      final uri = Uri.parse(ApiConfig.getAllLocations);
      final resp = await http.get(uri, headers: AuthService().sessionHeaders);
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body);
      if (data['success'] != true) return [];
      final List<dynamic> locations = data['data']?['locations'] ?? [];

      double bestDistance = double.infinity;
      Map<String, dynamic>? target;
      final now = DateTime.now();
      for (final loc in locations) {
        final lat = double.tryParse(loc['latitude']?.toString() ?? '');
        final lng = double.tryParse(loc['longitude']?.toString() ?? '');
        if (lat == null || lng == null) continue;
        final d = _distanceMeters(geo.latitude, geo.longitude, lat, lng);
        if (d > 150) continue;
        DateTime createdAt;
        try { createdAt = DateTime.parse(loc['created_at']?.toString() ?? ''); } catch (_) { createdAt = now.subtract(const Duration(days: 365)); }
        if (now.difference(createdAt) > const Duration(minutes: 15)) continue;
        if (d < bestDistance) { bestDistance = d; target = loc as Map<String, dynamic>; }
      }
      if (target == null) return [];
      final photos = (target['photos'] as List<dynamic>? ?? []);
      return photos.map((p) => p['id']?.toString()).whereType<String>().where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }
}

class _AlbumCommentsSheet extends StatefulWidget {
  final String albumId;
  const _AlbumCommentsSheet({Key? key, required this.albumId}) : super(key: key);

  @override
  State<_AlbumCommentsSheet> createState() => _AlbumCommentsSheetState();
}

class _AlbumCommentsSheetState extends State<_AlbumCommentsSheet> {
  bool _loading = true;
  List<Map<String, dynamic>> _comments = [];
  final _ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final resp = await AlbumService.getAlbumComments(widget.albumId, page: 1, perPage: 50);
    if (mounted) {
      setState(() {
        _comments = List<Map<String, dynamic>>.from(resp['comments'] ?? []);
        _loading = false;
      });
    }
  }

  Future<void> _send() async {
    if (_ctrl.text.trim().isEmpty) return;
    await AlbumService.addAlbumComment(widget.albumId, _ctrl.text.trim());
    _ctrl.clear();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: MediaQuery.of(context).viewInsets,
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade400, borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 12),
              const Text('Comments', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(height: 16),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.separated(
                        itemCount: _comments.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (_, i) {
                          final c = _comments[i];
                          final name = ((c['first_name'] ?? '') + ' ' + (c['last_name'] ?? '')).trim();
                          final text = (c['comment'] ?? '').toString();
                          return ListTile(
                            leading: const CircleAvatar(child: Icon(Icons.person)),
                            title: Text(name.isEmpty ? 'User' : name, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(text),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _ctrl,
                        decoration: const InputDecoration(hintText: 'Write a comment...'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: _send, child: const Text('Send')),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ===================== Edit Album Screen =====================

class EditAlbumScreen extends StatefulWidget {
  final String albumId;
  final String initialTitle;
  final String initialDescription;
  final List<Map<String, dynamic>> initialPhotos;
  const EditAlbumScreen({Key? key, required this.albumId, required this.initialTitle, required this.initialDescription, required this.initialPhotos}) : super(key: key);

  @override
  State<EditAlbumScreen> createState() => _EditAlbumScreenState();
}
 
class _EditAlbumScreenState extends State<EditAlbumScreen> {
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late List<Map<String, dynamic>> _photos; // фото внутри альбома
  bool _saving = false;
  String? _coverPhotoId;
  String? _coverPreviewUrl;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: widget.initialTitle);
    _descCtrl = TextEditingController(text: widget.initialDescription);
    _photos = List<Map<String, dynamic>>.from(widget.initialPhotos);
    _loadCover();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveBaseInfo() async {
    setState(() => _saving = true);
    try {
      await AlbumService.updateAlbumServer(
        albumId: widget.albumId,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Album updated')));
      
      // Закрываем экран редактирования и возвращаемся назад
      Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _removePhotoFromAlbum(String photoId) async {
    setState(() => _saving = true);
    try {
      await AlbumService.removePhotosFromAlbum(widget.albumId, [photoId]);
      setState(() {
        _photos.removeWhere((p) => (p['id']?.toString() ?? p['photo_id']?.toString() ?? '') == photoId);
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addPhotosFromMyPosts() async {
    final userId = await UserService.getUserId();
    final res = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(builder: (_) => SelectPostsScreen(userId: userId)),
    );
    if (res == null || res.isEmpty) return;

    setState(() => _saving = true);
    try {
      await AlbumService.addPhotosToAlbum(widget.albumId, res);
      // Обновим локальный список: получим детали альбома заново
      final details = await AlbumService.getAlbumDetails(widget.albumId);
      if (details['success'] == true) {
        setState(() {
          _photos = List<Map<String, dynamic>>.from(details['photos'] ?? []);
          _coverPhotoId = details['album']?['cover_photo_id']?.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _uploadNewPhotosAndAdd() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const UploadDescriptionScreen()),
    );

    try {
      if (result is GeoLocation) {
        final ids = await _collectRecentLocationPhotoIdsEdit(result);
        if (ids.isNotEmpty) {
          setState(() => _saving = true);
          try {
            await AlbumService.addPhotosToAlbum(widget.albumId, ids);
            final details = await AlbumService.getAlbumDetails(widget.albumId);
            if (details['success'] == true) {
              setState(() {
                _photos = List<Map<String, dynamic>>.from(details['photos'] ?? []);
                _coverPhotoId = details['album']?['cover_photo_id']?.toString();
              });
            }
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added photos: ${ids.length}')),
              );
            }
          } finally {
            if (mounted) setState(() => _saving = false);
          }
        }
      }
    } catch (_) {}
  }

  Future<List<String>> _collectRecentLocationPhotoIdsEdit(GeoLocation geo) async {
    try {
      final uri = Uri.parse(ApiConfig.getAllLocations);
      final resp = await http.get(uri, headers: AuthService().sessionHeaders);
      if (resp.statusCode != 200) return [];
      final data = jsonDecode(resp.body);
      if (data['success'] != true) return [];
      final List<dynamic> locations = data['data']?['locations'] ?? [];

      double bestDistance = double.infinity;
      Map<String, dynamic>? target;
      final now = DateTime.now();
      for (final loc in locations) {
        final lat = double.tryParse(loc['latitude']?.toString() ?? '');
        final lng = double.tryParse(loc['longitude']?.toString() ?? '');
        if (lat == null || lng == null) continue;
        final d = _distanceMeters(geo.latitude, geo.longitude, lat, lng);
        if (d > 150) continue;
        DateTime createdAt;
        try { createdAt = DateTime.parse(loc['created_at']?.toString() ?? ''); } catch (_) { createdAt = now.subtract(const Duration(days: 365)); }
        if (now.difference(createdAt) > const Duration(minutes: 15)) continue;
        if (d < bestDistance) { bestDistance = d; target = loc as Map<String, dynamic>; }
      }
      if (target == null) return [];
      final photos = (target['photos'] as List<dynamic>? ?? []);
      return photos.map((p) => p['id']?.toString()).whereType<String>().where((s) => s.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Custom App Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(
                    color: Color(0xFFE5E5E5),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        color: Color(0xFF2D2D2D),
                        size: 18,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Edit Album',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2D2D2D),
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: _saving ? null : _saveBaseInfo,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _saving || _titleCtrl.text.trim().isEmpty
                            ? Colors.grey[300]
                            : const Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section
                    const Text(
                      'Album Details',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.8,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Update your album information and manage content',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 40),
                    
                    // Title Field
                    _buildEditTextField(
                      controller: _titleCtrl,
                      label: 'Album Title',
                      hint: 'Enter a title for your album',
                      icon: Icons.collections_bookmark_outlined,
                    ),
                    const SizedBox(height: 24),
                    
                    // Description Field
                    _buildEditTextField(
                      controller: _descCtrl,
                      label: 'Description',
                      hint: 'Tell us about this album...',
                      icon: Icons.description_outlined,
                      maxLines: 4,
                    ),
                    const SizedBox(height: 40),
                    
                    // Cover Section
                    const Text(
                      'Album Cover',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Choose a stunning cover image for your album',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Cover Preview
                    _buildEditCoverPreview(),
                    const SizedBox(height: 32),
                    
                    // Action Buttons Section
                    const Text(
                      'Manage Content',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add photos from existing posts or upload new ones',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Action Buttons
                    _buildEditActionButtons(),
                    const SizedBox(height: 40),
                    
                    // Album Content Section
                    const Text(
                      'Album Content',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_photos.length} ${_photos.length == 1 ? 'photo' : 'photos'} in this album',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 20),
                    
                    // Photo Grid
                    _buildPhotoGrid(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Color(0xFF2D2D2D),
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFFE5E5E5),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF2D2D2D),
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: Colors.grey[400],
                fontSize: 16,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.only(left: 16, right: 12),
                child: Icon(
                  icon,
                  color: Colors.grey[400],
                  size: 22,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minWidth: 0,
                minHeight: 0,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 18,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEditActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildEditActionButton(
                title: 'Add from Posts',
                subtitle: 'Existing posts',
                icon: Icons.collections_outlined,
                onTap: _saving ? null : _addPhotosFromMyPosts,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildEditActionButton(
                title: 'create post',
                subtitle: 'New photos',
                icon: Icons.file_upload_outlined,
                onTap: _saving ? null : _uploadNewPhotosAndAdd,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildEditActionButton(
          title: 'Add to Specific Post',
          subtitle: 'Upload to existing location',
          icon: Icons.add_photo_alternate_outlined,
          onTap: _saving ? null : _addPhotosToSpecificPost,
          fullWidth: true,
        ),
      ],
    );
  }

  Widget _buildEditActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: onTap == null ? Colors.grey[100] : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: onTap == null ? Colors.grey[300]! : const Color(0xFFE5E5E5),
            width: 1.5,
          ),
          boxShadow: onTap == null ? null : [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: fullWidth
            ? Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: onTap == null ? Colors.grey[300] : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: onTap == null ? Colors.grey[500] : const Color(0xFF2D2D2D),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: onTap == null ? Colors.grey[600] : const Color(0xFF2D2D2D),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            color: onTap == null ? Colors.grey[400] : Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: onTap == null ? Colors.grey[300] : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      color: onTap == null ? Colors.grey[500] : const Color(0xFF2D2D2D),
                      size: 22,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: onTap == null ? Colors.grey[600] : const Color(0xFF2D2D2D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: onTap == null ? Colors.grey[400] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildPhotoGrid() {
    if (_photos.isEmpty) {
      return Container(
        height: 200,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE5E5E5),
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                Icons.photo_library_outlined,
                color: Colors.grey[400],
                size: 30,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No photos yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Add photos to see them here',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[400],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E5E5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
        ),
        itemCount: _photos.length,
        itemBuilder: (_, i) {
          final p = _photos[i];
          final id = (p['id'] ?? p['photo_id'] ?? '').toString();
          final filePath = (p['file_path'] ?? p['filePath'] ?? '').toString();
          final url = ApiConfig.formatImageUrl(filePath);
          final isCover = _coverPhotoId != null && _coverPhotoId == id;
          
          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    useOldImageOnUrlChange: true,
                    fadeInDuration: Duration(milliseconds: 0),
                    fadeOutDuration: Duration(milliseconds: 0),
                  ),
                  
                  // Cover Badge
                  if (isCover)
                    Positioned(
                      left: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF007AFF),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Text(
                          'COVER',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  
                  // Actions
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Set as Cover
                        GestureDetector(
                          onTap: _saving ? null : () async {
                            if (_saving) return;
                            setState(() => _saving = true);
                            try {
                              final resp = await AlbumService.setAlbumCover(widget.albumId, id);
                              if (resp['success'] == true) {
                                setState(() => _coverPhotoId = id);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Cover updated')),
                                  );
                                }
                              } else {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(resp['message']?.toString() ?? 'Failed to set cover')),
                                  );
                                }
                              }
                            } finally {
                              if (mounted) setState(() => _saving = false);
                            }
                          },
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: isCover
                                  ? const Color(0xFF007AFF)
                                  : Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/Images/star.png',
                              width: 18,
                              height: 18,
                              color: isCover ? Colors.white : const Color(0xFF2D2D2D),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        
                        // Delete
                        GestureDetector(
                          onTap: _saving ? null : () => _removePhotoFromAlbum(id),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.9),
                              borderRadius: BorderRadius.circular(8),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.1),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/Images/delete.png',
                              width: 18,
                              height: 18,
                              color: const Color(0xFF2D2D2D),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadCover() async {
    try {
      final details = await AlbumService.getAlbumDetails(widget.albumId);
      if (details['success'] == true) {
        setState(() {
          _coverPhotoId = details['album']?['cover_photo_id']?.toString();
          // Загружаем URL обложки из поля cover_url в ответе API
          final coverUrl = details['album']?['cover_url']?.toString();
          if (coverUrl != null && coverUrl.isNotEmpty) {
            _coverPreviewUrl = ApiConfig.formatImageUrl(coverUrl);
          } else {
            // Если нет cover_url, ищем фото с этим ID в списке фото альбома как fallback
            final coverPhotoId = _coverPhotoId;
            if (coverPhotoId != null && coverPhotoId.isNotEmpty) {
              final photos = details['photos'] as List<dynamic>? ?? [];
              for (final photo in photos) {
                if (photo['id']?.toString() == coverPhotoId) {
                  final filePath = photo['file_path']?.toString();
                  if (filePath != null && filePath.isNotEmpty) {
                    _coverPreviewUrl = ApiConfig.formatImageUrl(filePath);
                  }
                  break;
                }
              }
            }
          }
        });
      }
    } catch (_) {}
  }

  Future<void> _uploadCoverFromGallery() async {
    // Открываем упрощенный экран загрузки обложки альбома
    final selectedImage = await Navigator.of(context).push<File>(
      MaterialPageRoute(builder: (_) => const UploadAlbumCoverScreen()),
    );
    
    if (selectedImage != null) {
      setState(() {
        _saving = true;
      });
      
      try {
        // Загружаем обложку через упрощенный сервис
        final result = await AlbumCoverService.uploadCover(selectedImage);
        
        if (result['success'] == true) {
          setState(() {
            _coverPhotoId = result['cover_id']?.toString();
            final filePath = result['cover_url']?.toString();
            if (filePath != null && filePath.isNotEmpty) {
              // Добавляем timestamp для предотвращения кэширования
              final baseUrl = ApiConfig.formatImageUrl(filePath);
              _coverPreviewUrl = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
            }
          });
          
          // Обновляем обложку на сервере
          await AlbumService.updateAlbumServer(
            albumId: widget.albumId,
            coverPhotoId: _coverPhotoId,
          );
          
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Album cover updated successfully')),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error uploading cover: ${result['error']}')),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading cover: $e')),
        );
      } finally {
        if (mounted) setState(() => _saving = false);
      }
    }
  }

  Widget _buildEditCoverPreview() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFFE5E5E5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: _coverPreviewUrl != null && _coverPreviewUrl!.isNotEmpty
            ? Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: _coverPreviewUrl!,
                    fit: BoxFit.cover,
                    useOldImageOnUrlChange: false,
                    fadeInDuration: const Duration(milliseconds: 300),
                    fadeOutDuration: const Duration(milliseconds: 100),
                  ),
                  // Overlay with actions
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.3),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    right: 16,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildEditCoverAction(
                          icon: Icons.edit_outlined,
                          onTap: _uploadCoverFromGallery,
                        ),
                        const SizedBox(width: 8),
                        _buildEditCoverAction(
                          icon: Icons.delete_outline,
                          onTap: () => setState(() {
                            _coverPhotoId = null;
                            _coverPreviewUrl = null;
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      Icons.image_outlined,
                      color: Colors.grey[400],
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No cover image',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Upload a cover to make your album stand out',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _uploadCoverFromGallery,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2D2D2D),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Upload Cover',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildEditCoverAction({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          icon,
          color: const Color(0xFF2D2D2D),
          size: 18,
        ),
      ),
    );
  }

  // ====== Добавление фото в конкретный пост (по существующей локации) ======
  Future<void> _addPhotosToSpecificPost() async {
    try {
      // 1) Построим список постов (групп по локации) в этом альбоме
      final groups = await _buildPostGroupsForEdit();
      if (!mounted) return;

      if (groups.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No posts found in this album')),
        );
        return;
      }

      // 2) Даем выбрать целевой пост
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (ctx) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8.0),
                    child: Text('Select post to add photos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (_, i) {
                        final g = groups[i];
                        final preview = g['previewUrl'] as String?;
                        final title = g['post']?.locationName ?? 'Post';
                        final count = g['count'] as int? ?? 0;
                        return ListTile(
                          leading: preview != null && preview.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(6),
                                  child: CachedNetworkImage(
                                    imageUrl: preview,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
                                    useOldImageOnUrlChange: true,
                                    fadeInDuration: Duration(milliseconds: 0),
                                    fadeOutDuration: Duration(milliseconds: 0),
                                  ),
                                )
                              : const SizedBox(width: 52, height: 52),
                          title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                          subtitle: Text('$count photos'),
                          onTap: () => Navigator.of(ctx).pop(g),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );

      if (selected == null) return;
      final locationId = selected['locationId']?.toString();
      if (locationId == null || locationId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to resolve target location')),
        );
        return;
      }

      // 3) Выбираем изображения и загружаем их в существующую локацию
      await _pickImagesAndUploadToLocation(locationId);

      // 4) Обновляем альбом
      final details = await AlbumService.getAlbumDetails(widget.albumId);
      if (details['success'] == true && mounted) {
        setState(() {
          _photos = List<Map<String, dynamic>>.from(details['photos'] ?? []);
          _coverPhotoId = details['album']?['cover_photo_id']?.toString();
        });
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to add photos: $e')),
      );
    }
  }

  Future<List<Map<String, dynamic>>> _buildPostGroupsForEdit() async {
    // Группируем фото альбома по locationId и составляем превью/инфо
    final Map<String, List<Map<String, dynamic>>> byLoc = {};
    for (final p in _photos) {
      final photoId = (p['id'] ?? p['photo_id'] ?? '').toString();
      if (photoId.isEmpty) continue;
      String? locId = await PostService.getLocationIdByPhotoId(photoId);
      locId ??= 'photo_$photoId';
      byLoc.putIfAbsent(locId, () => []).add(p);
    }

    final List<Map<String, dynamic>> result = [];
    for (final entry in byLoc.entries) {
      final locId = entry.key;
      final photos = entry.value;
      if (photos.isEmpty) continue;
      final firstId = (photos.first['id'] ?? photos.first['photo_id'] ?? '').toString();
      final basePost = await PostService.getPostById(firstId);
      // Превью берем из первого фото группы
      String? previewUrl;
      final fp = (photos.first['file_path'] ?? photos.first['filePath'] ?? '').toString();
      if (fp.isNotEmpty) previewUrl = ApiConfig.formatImageUrl(fp);
      result.add({
        'locationId': locId,
        'post': basePost,
        'count': photos.length,
        'previewUrl': previewUrl,
      });
    }
    return result;
  }

  Future<File?> _cropImage(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      
      final croppedImage = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(
          builder: (context) => ImageCropScreen(imageBytes: imageBytes),
        ),
      );

      if (croppedImage != null) {
        final tempDir = await getTemporaryDirectory();
        final croppedFile = File('${tempDir.path}/cropped_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await croppedFile.writeAsBytes(croppedImage);
        return croppedFile;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> _pickImagesAndUploadToLocation(String locationId) async {
    // Выбор изображений
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage();
    if (picked.isEmpty) return;

    setState(() => _saving = true);
    final uploadedPhotoIds = <String>[];
    try {
      final token = await AuthService.getToken();
      
      // Обрабатываем изображения: первое через crop, остальные без изменений
      for (int i = 0; i < picked.length; i++) {
        final x = picked[i];
        final file = File(x.path);
        
        File fileToUpload;
        File? originalFile;
        
        // Только первое изображение проходит через crop
        if (i == 0) {
          // Сохраняем оригинал
          originalFile = file;
          // Открываем редактор для выбора квадратной области
          final croppedFile = await _cropImage(file);
          if (croppedFile == null) continue; // Пропускаем если пользователь отменил обрезку
          fileToUpload = croppedFile;
        } else {
          // Остальные изображения загружаем в исходном размере
          fileToUpload = file;
        }
        
        final extension = path.extension(fileToUpload.path).replaceAll('.', '');
        final mimeType = extension == 'jpg' || extension == 'jpeg'
            ? 'image/jpeg'
            : extension == 'png'
                ? 'image/png'
                : 'image/gif';

        final request = http.MultipartRequest('POST', Uri.parse(ApiConfig.uploadPhoto));
        request.headers['Cookie'] = token;
        final photoFile = await http.MultipartFile.fromPath(
          'photo',
          fileToUpload.path,
          contentType: MediaType.parse(mimeType),
        );
        request.files.add(photoFile);
        request.fields['location_id'] = locationId;
        
        // Добавляем оригинал первого изображения (для галереи)
        if (i == 0 && originalFile != null) {
          final originalPhotoFile = await http.MultipartFile.fromPath(
            'photo_original',
            originalFile.path,
            contentType: MediaType.parse(mimeType),
          );
          request.files.add(originalPhotoFile);
        }

        final streamed = await request.send();
        final response = await http.Response.fromStream(streamed);
        if (response.statusCode == 200) {
          final Map<String, dynamic> body = jsonDecode(response.body);
          if (body['success'] == true) {
            final id = body['photo']?['id']?.toString();
            if (id != null && id.isNotEmpty) uploadedPhotoIds.add(id);
          }
        }
      }

      if (uploadedPhotoIds.isNotEmpty) {
        await AlbumService.addPhotosToAlbum(widget.albumId, uploadedPhotoIds);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Added photos: ${uploadedPhotoIds.length}')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

// ===================== Album Map Screen =====================

class AlbumMapScreen extends StatefulWidget {
  final List<Post> posts;
  final String selectedPostId;
  final String title;
  const AlbumMapScreen({Key? key, required this.posts, required this.selectedPostId, required this.title}) : super(key: key);

  @override
  State<AlbumMapScreen> createState() => _AlbumMapScreenState();
}

class _AlbumMapScreenState extends State<AlbumMapScreen> {
  MapboxMap? _map;
  PointAnnotationManager? _manager;
  final Map<String, String> _annotationIdToPostId = {};
  bool _isSettingUp = false;
  String? _currentSelectedPostId;

  @override
  void initState() {
    super.initState();
    _currentSelectedPostId = widget.selectedPostId;
  }

  @override
  void dispose() {
    // Попробуем безопасно удалить менеджер аннотаций
    try {
      if (_map != null && _manager != null) {
        _map!.annotations.removeAnnotationManager(_manager!);
      }
    } catch (_) {}
    super.dispose();
  }

  Future<void> _onMapCreated(MapboxMap map) async {
    _map = map;
    
    // Отключаем шкалу зума
    try {
      await map.scaleBar.updateSettings(
        ScaleBarSettings(
          enabled: false,
        )
      );
    } catch (e) {
      // Игнорируем ошибки
    }
  }

  Future<void> _setupAfterStyleLoaded() async {
    if (_map == null) return;
    if (_isSettingUp) return;
    _isSettingUp = true;

    // Регистрируем базовые изображения, затем миниатюры постов
    await MapboxConfig.registerMapboxMarkerImages(_map!);
    await MapboxConfig.preloadMarkerImagesForPosts(_map!, widget.posts);

    // Удаляем прежний менеджер, если он был
    try {
      if (_manager != null) {
        await _map!.annotations.removeAnnotationManager(_manager!);
      }
    } catch (_) {}

    // Создаем новый менеджер
    _manager = await MapHelper.createAnnotationManager(_map!);
    if (_manager == null) return;

    _annotationIdToPostId.clear();

    // Обработчик кликов по маркеру
    await MapHelper.addClickListenerToAnnotation(_manager!, (annotationId) {
      final postId = _annotationIdToPostId[annotationId];
      if (postId != null) {
        // Если кликнули на уже выбранный маркер - закрываем экран
        if (_currentSelectedPostId == postId) {
          Navigator.of(context).pop(postId);
        } else {
          // Иначе выделяем этот маркер
          setState(() {
            _currentSelectedPostId = postId;
          });
          _redrawMarkers();
        }
      }
    });

    // Добавляем маркеры
    await _addMarkers();

    // Центрируем камеру на выбранном посте
    final center = widget.posts.firstWhere((p) => p.id == widget.selectedPostId, orElse: () => widget.posts.first);
    await MapHelper.moveCamera(
      mapboxMap: _map!,
      latitude: center.location.latitude,
      longitude: center.location.longitude,
      zoom: 1.5,
      animate: true,
    );
    _isSettingUp = false;
  }

  Future<void> _addMarkers() async {
    if (_map == null || _manager == null) return;

    for (final post in widget.posts) {
      final isSelected = post.id == _currentSelectedPostId;
      // Используем зарегистрированное изображение поста как иконку
      final iconId = "post-marker-${post.id}"; // совпадает с MapboxConfig.registerPostImageAsMarker
      // Если вдруг не зарегистрировано, используем стандартный
      bool hasImage = false;
      try { hasImage = await _map!.style.hasStyleImage(iconId); } catch (_) {}
      final String imageToUse = hasImage ? iconId : 'custom-marker';

      final options = PointAnnotationOptions(
        geometry: Point(coordinates: Position(post.location.longitude, post.location.latitude)),
        iconImage: imageToUse,
        iconSize: isSelected ? 0.5 : 0.25,
        iconAnchor: IconAnchor.BOTTOM,
      );
      PointAnnotation? annotation;
      try {
        // Пробуем создать маркер
        annotation = await _manager!.create(options);
      } catch (e) {
        // Если менеджер недействителен — пересоздаем и повторяем один раз
        final msg = e.toString();
        if (msg.contains('No manager found')) {
          try {
            if (_manager != null) {
              await _map!.annotations.removeAnnotationManager(_manager!);
            }
          } catch (_) {}
          _manager = await MapHelper.createAnnotationManager(_map!);
          if (_manager != null) {
            try { annotation = await _manager!.create(options); } catch (_) {}
          }
        }
      }
      if (annotation != null) {
        _annotationIdToPostId[annotation.id] = post.id;
      }
    }
  }

  Future<void> _redrawMarkers() async {
    if (_map == null || _manager == null) return;
    
    // Удаляем все существующие маркеры
    try {
      await _manager!.deleteAll();
      _annotationIdToPostId.clear();
    } catch (e) {
      // Игнорируем ошибки
    }
    
    // Создаем маркеры заново с обновленными размерами
    await _addMarkers();
  }

  void _onMapTap(MapContentGestureContext mapContext) {
    // Сбрасываем выделение при нажатии на пустое место карты
    if (_currentSelectedPostId != null) {
      setState(() {
        _currentSelectedPostId = null;
      });
      _redrawMarkers();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(color: Colors.black87)),
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
        elevation: 0,
      ),
      body: MapWidget(
        key: const ValueKey('album_map_widget'),
        styleUri: MapboxConfig.DEFAULT_STYLE_URI,
        onMapCreated: _onMapCreated,
        onStyleLoadedListener: (_) => _setupAfterStyleLoaded(),
        onTapListener: _onMapTap,
      ),
    );
  }
}