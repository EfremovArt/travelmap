import 'dart:io';
import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/social_service.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../services/user_service.dart';
import 'dart:math';
import 'photo_grid.dart';
import '../services/post_service.dart';
import '../screens/user_profile_screen.dart';
import '../screens/main_screen.dart';
import '../utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/create_commercial_post_screen.dart';
import '../models/commercial_post.dart';
import '../services/commercial_post_service.dart';
import 'photo_commercial_posts_indicator.dart';

/// Виджет карточки поста, используемый в ленте.
class PostCard extends StatefulWidget {
  final Post post;
  final String? userProfileImage; // URL изображения профиля текущего пользователя
  final String userFullName; // Имя текущего пользователя
  final String? authorProfileImage; // URL изображения профиля автора поста
  final String authorName; // Имя автора поста
  final Function(Post) onShowCommentsModal;
  final Function(Post) onShowOnMap;
  final Function(Post) onEditPost;
  final Function(Post) onDeletePost;
  final bool isCurrentUserPost;
  final Function(Post)? onLikePost;
  final Function(Post)? onFavoritePost;
  final Function(String)? onFollowUser;
  final bool isFollowing;
  final Function(Post, int)? onImageTap;
  final Function(Post)? onShowLikesList; // New callback to show likes list
  final Function(Post)? onLocationPostsClick; // Новый колбэк для нажатия на счетчик локации
  final bool useCardWrapper; // Новый параметр для управления Card-оберткой

  const PostCard({
    Key? key,
    required this.post,
    required this.userProfileImage, // Для совместимости со старым кодом
    required this.userFullName, // Для совместимости со старым кодом
    this.authorProfileImage, // Новое поле - аватар автора поста
    this.authorName = "User", // Новое поле - имя автора поста
    required this.onShowCommentsModal,
    required this.onShowOnMap,
    required this.onEditPost,
    required this.onDeletePost,
    required this.isCurrentUserPost,
    this.onLikePost,
    this.onFavoritePost,
    this.onFollowUser,
    this.isFollowing = false,
    this.onImageTap,
    this.onShowLikesList,
    this.onLocationPostsClick,
    this.useCardWrapper = true, // По умолчанию используем Card
  }) : super(key: key);

  @override
  _PostCardState createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  int _commentsCount = 0;
  bool _isLoadingComments = true;
  final _socialService = SocialService();
  bool _isDescriptionExpanded = false;
  int? _currentUserId;
  int _commercialPostsRefreshKey = 0; // Ключ для обновления индикатора коммерческих постов

  @override
  void initState() {
    super.initState();
    _loadCommentsCount();
    _loadCurrentUserId();
  }

  @override
  void didUpdateWidget(PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем счетчик комментариев при каждом обновлении виджета
    if (oldWidget.post.id == widget.post.id) {
      _loadCommentsCount();
    }
  }

  // Загружаем количество комментариев
  Future<void> _loadCommentsCount() async {
    try {
      if (widget.post.id.isEmpty) {
        AppLogger.log('❌ Некорректный ID поста: ${widget.post.id}');
        return;
      }

      if (!mounted) {
        AppLogger.log('⚠️ Виджет больше не монтирован, отменяем загрузку комментариев');
        return;
      }
      
      setState(() {
        _isLoadingComments = true;
      });

      // AppLogger.log('🔄 Запрос количества комментариев для поста ID: ${widget.post.id}');
      final result = await _socialService.getComments(widget.post.id, page: 1, perPage: 1);
      
      if (!mounted) {
        // AppLogger.log('⚠️ Виджет больше не монтирован после загрузки, отменяем обновление');
        return;
      }
      
      if (result['success'] == true && result['pagination'] != null) {
        setState(() {
          _commentsCount = result['pagination']['total'] ?? 0;
        });
      } else {
        // В случае ошибки (включая 404), просто устанавливаем 0 комментариев
        AppLogger.log('⚠️ Не удалось получить комментарии: ${result['error']}');
        setState(() {
          _commentsCount = 0;
        });
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при загрузке количества комментариев: $e');
      if (mounted) {
        setState(() {
          _commentsCount = 0;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingComments = false;
        });
      }
    }
  }

  // Загружаем ID текущего пользователя
  Future<void> _loadCurrentUserId() async {
    try {
      final userIdString = await UserService.getUserId();
      final userId = int.tryParse(userIdString);
      if (mounted) {
        setState(() {
          _currentUserId = userId;
        });
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при загрузке ID текущего пользователя: $e');
      if (mounted) {
        setState(() {
          _currentUserId = null;
        });
      }
    }
  }

  // Форматирование даты поста
  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  // Форматирование больших чисел (лайки, комментарии, избранное)
  String _formatCount(int count) {
    return formatCount(count);
  }
  
  // Статический метод для форматирования чисел, доступный другим классам
  static String formatCount(int count) {
    if (count < 1000) {
      return count.toString();
    } else if (count < 1000000) {
      // Для тысяч (1k, 1.5k, 10k, 999k)
      double thousands = count / 1000;
      if (thousands >= 10) {
        // 10k и больше - без десятичной части
        return '${thousands.toStringAsFixed(0)}k';
      } else {
        // Меньше 10k - с одной десятичной цифрой, если она не 0
        String formatted = thousands.toStringAsFixed(1);
        if (formatted.endsWith('.0')) {
          return '${thousands.toStringAsFixed(0)}k';
        }
        return '${formatted}k';
      }
    } else {
      // Для миллионов (1M, 1.5M, 10M)
      double millions = count / 1000000;
      if (millions >= 10) {
        return '${millions.toStringAsFixed(0)}M';
      } else {
        String formatted = millions.toStringAsFixed(1);
        if (formatted.endsWith('.0')) {
          return '${millions.toStringAsFixed(0)}M';
        }
        return '${formatted}M';
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Если карточка находится внутри экрана профиля, запрещаем переходы в профиль
    final bool insideProfile = context.findAncestorWidgetOfExactType<UserProfileScreen>() != null;
    // Также проверяем, находимся ли мы в My Map (дополнительная защита)
    final bool shouldDisableProfileClick = insideProfile || widget.isCurrentUserPost;
    // Используем URL изображений, если они есть, иначе используем локальные файлы
    final bool hasImages = widget.post.images.isNotEmpty;
    final bool hasUrls = widget.post.imageUrls.isNotEmpty;
    
    // Получаем размер экрана для адаптивности
    final screenWidth = MediaQuery.of(context).size.width;
    // Для базового экрана 430px размер 400px (отступы по 15px с каждой стороны)
    final imageSize = screenWidth >= 430 ? 400.0 : screenWidth - 30;
    
    Widget content = SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка поста (аватар, имя, количество комментариев и дата)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Аватарка пользователя (из профиля)
                    GestureDetector(
                      onTap: shouldDisableProfileClick ? null : () => _openUserProfile(context),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.transparent,
                        backgroundImage: widget.isCurrentUserPost
                          ? (widget.userProfileImage != null && widget.userProfileImage!.isNotEmpty
                              ? CachedNetworkImageProvider(_getAdjustedProfileUrl(widget.userProfileImage!))
                              : null)
                          : (widget.authorProfileImage != null && widget.authorProfileImage!.isNotEmpty
                              ? CachedNetworkImageProvider(_getAdjustedProfileUrl(widget.authorProfileImage!))
                              : null),
                        child: (widget.isCurrentUserPost
                            ? (widget.userProfileImage == null || widget.userProfileImage!.isEmpty)
                            : (widget.authorProfileImage == null || widget.authorProfileImage!.isEmpty))
                          ? Icon(Icons.person, color: Colors.grey.shade600, size: 28)
                          : null,
                      ),
                    ),
                    
                    SizedBox(width: 12),
                    
                    // Информация о пользователе и комментариях
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Верхняя строка: имя пользователя и дата
                          Row(
                            children: [
                              // Имя пользователя
                              Expanded(
                                child: Row(
                                  children: [
                                    GestureDetector(
                                      onTap: shouldDisableProfileClick ? null : () => _openUserProfile(context),
                                      child: Text(
                                        widget.isCurrentUserPost ? widget.userFullName : widget.authorName,
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
                                    // Иконка с количеством постов пользователя
                                    FutureBuilder<int>(
                                      future: _getUserPostsCount(),
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
                              Text(
                                _formatDate(widget.post.createdAt),
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
                          
                          // Индикатор поста и заголовок на одной строке
                          Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.orange.shade200, width: 1),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.photo_camera,
                                      size: 14,
                                      color: Colors.orange.shade600,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Post',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.orange.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Заголовок поста на одной строке с индикатором
                              if (widget.post.title.isNotEmpty) ...[
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    widget.post.title,
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
                          // Описание вынесено ниже Row
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Описание поста (вынесено ниже шапки, чтобы аватар не смещался)
          if (widget.post.description.isNotEmpty) ...[
            SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: widget.useCardWrapper
                    ? () {
                        setState(() {
                          _isDescriptionExpanded = !_isDescriptionExpanded;
                        });
                      }
                    : null,
                child: Text(
                  widget.post.description,
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  maxLines: _isDescriptionExpanded ? null : 2,
                  overflow: _isDescriptionExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
          
          // Изображения поста (в виде коллажа)
          if (hasImages || hasUrls)
            PhotoCommercialPostsIndicator(
              key: ValueKey('commercial_posts_${widget.post.id}_$_commercialPostsRefreshKey'),
              photoId: int.tryParse(widget.post.id) ?? 0,
              photoTitle: widget.post.title.isNotEmpty ? widget.post.title : 'Photo',
              currentUserId: _currentUserId,
              child: Center(
                child: Container(
                  width: imageSize,
                  height: imageSize,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Коллаж изображений
                  Positioned.fill(
                    child: hasUrls
                      ? PhotoGrid(
                          imageUrls: widget.post.imageUrls,
                          onImageTap: (index) {
                            if (widget.onImageTap != null) {
                              widget.onImageTap!(widget.post, index);
                            }
                          },
                        )
                      : PhotoGrid(
                          images: widget.post.images,
                          onImageTap: (index) {
                            if (widget.onImageTap != null) {
                              widget.onImageTap!(widget.post, index);
                            }
                          },
                        ),
                  ),
                
                  // Счетчик фотографий в левом верхнем углу
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
                            Icons.photo_library,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '${hasUrls ? widget.post.imageUrls.length : widget.post.images.length}',
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
                
                  // Кнопки редактирования и удаления для своих постов
                  // ИЛИ кнопки лайка, избранного и комментариев для чужих постов
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: 6, horizontal: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: widget.isCurrentUserPost 
                        ? _buildCurrentUserPostControls() 
                        : _buildOtherUserPostControls(),
                    ),
                  ),
                  
                  // Меню с тремя точками (только для чужих постов)
                  if (!widget.isCurrentUserPost)
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
                            if (value == 'add_commercial') {
                              _handleAddCommercialPost(context);
                            } else if (value == 'report') {
                              _showReportOptions(context);
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
                ],
              ),
                ),
              ),
            ),
          
          // Геолокация и информация о пользователях в этой локации
          Padding(
            padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Геолокация - левая часть строки
                SizedBox(
                  width: MediaQuery.of(context).size.width * 0.5,
                  child: GestureDetector(
                    onTap: () => widget.onShowOnMap(widget.post),
                    child: Text(
                      widget.post.locationName.toUpperCase(),
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontStyle: FontStyle.normal,
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                        height: 1.0,
                        color: Color(0xFF0D0918),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                
                // Кнопка навигации с текстом GO!
                GestureDetector(
                  onTap: () => _openNavigationApps(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Color(0xFF0D0918),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'GO!',
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                
                SizedBox(width: 4),
                
                // Счетчик постов и пользователи в этой локации - правая часть строки
                Expanded(
                  flex: 1,
                  child: FutureBuilder<Map<String, dynamic>>(
                    future: _getLocationUsersInfo(),
                    builder: (context, snapshot) {
                      final postsCount = snapshot.data?['count'] ?? 0;
                      final List<String> avatars = snapshot.data?['avatars'] ?? [];
                      
                      return GestureDetector(
                        onTap: postsCount > 0 && widget.onLocationPostsClick != null
                            ? () => widget.onLocationPostsClick!(widget.post)
                            : null,
                        child: Container(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              // Счетчик постов в локации
                              Container(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  postsCount > 999 ? '+${(postsCount / 1000).toStringAsFixed(1)}k' : '+$postsCount',
                                  style: TextStyle(
                                    fontFamily: 'Gilroy',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              SizedBox(width: 4),
                              // Аватарки пользователей
                              SizedBox(
                                width: 60,
                                height: 24,
                                child: Stack(
                                  children: [
                                    for (int i = 0; i < avatars.length && i < 3; i++)
                                      Positioned(
                                        left: i * 16.0,
                                        child: Container(
                                          width: 24,
                                          height: 24,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: Colors.white, width: 1),
                                            image: avatars[i].isNotEmpty
                                                ? DecorationImage(
                                                    image: CachedNetworkImageProvider(_getAdjustedProfileUrl(avatars[i])),
                                                    fit: BoxFit.cover,
                                                  )
                                                : null,
                                          ),
                                          child: avatars[i].isEmpty
                                              ? Icon(Icons.person, color: Colors.grey, size: 12)
                                              : null,
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
    
    if (widget.useCardWrapper) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        clipBehavior: Clip.hardEdge,
        child: AnimatedSize(
          duration: Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: 520),
            child: content,
          ),
        ),
      );
    } else {
      return content;
    }
  }
  
  // Элементы управления для своего поста (редактирование и удаление)
  Widget _buildCurrentUserPostControls() {
    return Column(
      children: [
        // Кнопка избранного и счетчик
        FutureBuilder<Map<String, dynamic>>(
          future: _getFavoriteInfo(widget.post.id),
          builder: (context, snapshot) {
            final favoritesCount = snapshot.data?['count'] ?? 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    AppLogger.log('👆 Нажата кнопка просмотра избранного');
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
                if (favoritesCount > 0)
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Text(
                      _formatCount(favoritesCount),
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        
        SizedBox(height: 4),
        
        // Кнопка лайков и счетчик
        FutureBuilder<Map<String, dynamic>>(
          future: _getLikeInfo(widget.post.id),
          builder: (context, snapshot) {
            final likesCount = snapshot.data?['count'] ?? 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    AppLogger.log('👆 Нажата кнопка просмотра лайков');
                    if (widget.onShowLikesList != null) {
                      widget.onShowLikesList!(widget.post);
                    } else {
                      _showLikesList(context);
                    }
                  },
                  child: Container(
                    height: 32,
                    width: 40,
                    alignment: Alignment.center,
                    child: Image.asset(
                      'assets/Images/heart.png',
                      width: 28,
                      height: 28,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (likesCount > 0)
                  Padding(
                    padding: EdgeInsets.only(top: 1),
                    child: Text(
                      _formatCount(likesCount),
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        
        SizedBox(height: 4),
        
        // Кнопка комментариев
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => widget.onShowCommentsModal(widget.post),
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
                  _formatCount(_commentsCount),
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
          onTap: () => widget.onEditPost(widget.post),
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
          onTap: () => widget.onDeletePost(widget.post),
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
  
  // Элементы управления для чужого поста (избранное, лайк, комментарии)
  Widget _buildOtherUserPostControls() {
    return Column(
      children: [
        // Кнопка добавления в избранное
        FavoriteButton(
          post: widget.post,
          onFavoritePress: widget.onFavoritePost,
          iconSize: 36.0,
        ),
        
        SizedBox(height: 4),
        
        // Кнопка лайка
        LikeButton(
          post: widget.post,
          onLikePress: widget.onLikePost,
          iconSize: 34.0,
        ),
        
        SizedBox(height: 8),
        
        // Кнопка комментариев
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () => widget.onShowCommentsModal(widget.post),
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
                  _formatCount(_commentsCount),
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

  // Получение информации о лайках для поста
  Future<Map<String, dynamic>> _getLikeInfo(String postId) async {
    try {
      final likesCount = await SocialService.getPostLikesCount(postId);
      return {
        'count': likesCount,
        'isLiked': await SocialService.isLiked(postId),
      };
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении информации о лайках: $e');
      return {
        'count': 0,
        'isLiked': false,
      };
    }
  }

  // Получение информации об избранном для поста
  Future<Map<String, dynamic>> _getFavoriteInfo(String postId) async {
    try {
      final favorites = await SocialService.getAllFavorites();
      final favoritesCount = favorites.where((fav) => fav.postId == postId).length;
      return {
        'count': favoritesCount,
      };
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении информации об избранном: $e');
      return {
        'count': 0,
      };
    }
  }

  String _getAdjustedProfileUrl(String url) {
    return ApiConfig.formatImageUrl(url);
  }

  // Загружаем подписчиков пользователя
  Future<List<Map<String, String>>> _loadFollowers(String userId) async {
    try {
      // Получаем всех подписчиков
      final follows = await SocialService.getAllFollows();
      final followers = follows.where((follow) => follow.followedId == userId).toList();
      
      // Для каждого подписчика загружаем данные профиля
      List<Map<String, String>> result = [];
      for (int i = 0; i < min(followers.length, 10); i++) {
        final follower = followers[i];
        final name = await UserService.getFullNameByEmail(follower.followerId);
        final image = await UserService.getProfileImageByEmail(follower.followerId);
        
        result.add({
          'userId': follower.followerId,
          'name': name,
          'profileImage': image ?? '',
        });
      }
      
      return result;
    } catch (e) {
      AppLogger.log("Error loading followers: $e");
      return [];
    }
  }

  // Получить количество постов пользователя
  Future<int> _getUserPostsCount() async {
    try {
      final userId = widget.isCurrentUserPost 
        ? await UserService.getUserId() 
        : widget.post.user;
      
      final posts = await PostService.getUserPosts(userId: userId);
      return posts.length;
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении количества постов пользователя: $e');
      return 0;
    }
  }
  
  // Получить информацию о пользователях в локации
  Future<Map<String, dynamic>> _getLocationUsersInfo() async {
    try {
      // Получаем все посты из той же локации, используя правильную логику фильтрации
      final locationPosts = await PostService.getPostsInSameLocation(widget.post);
      
      // Получаем уникальных пользователей для отображения аватаров
      final uniqueUsers = <String>{};
      final avatars = <String>[];
      
      for (var post in locationPosts) {
        if (!uniqueUsers.contains(post.user)) {
          uniqueUsers.add(post.user);
          
          // Получаем аватар пользователя
          String? avatar;
          if (post.user == widget.post.user) {
            // Если это текущий пользователь поста
            avatar = widget.isCurrentUserPost 
                ? widget.userProfileImage 
                : widget.authorProfileImage;
          } else {
            try {
              final userData = await UserService.getUserInfoById(post.user);
              avatar = userData['profileImageUrl'];
            } catch (e) {
              AppLogger.log('Ошибка при получении аватара пользователя ${post.user}: $e');
            }
          }
          
          if (avatar != null && avatar.isNotEmpty) {
            avatars.add(avatar);
          }
        }
      }
      
      // Возвращаем количество ПОСТОВ (не пользователей)
      return {
        'count': locationPosts.length,
        'avatars': avatars,
      };
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении информации о пользователях в локации: $e');
      return {
        'count': 0,
        'avatars': <String>[],
      };
    }
  }

  // Отображение списка пользователей, добавивших пост в избранное
  Future<void> _showFavoritesList(BuildContext context) async {
    AppLogger.log('🔄 Открываем список добавивших в избранное пост ${widget.post.id}');
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
      
      // Получаем информацию об избранном
      final favorites = await SocialService.getAllFavorites();
      final postFavorites = favorites.where((fav) => fav.postId == widget.post.id).toList();
      
      AppLogger.log('📊 Количество добавлений в избранное для поста ${widget.post.id}: ${postFavorites.length}');
      
      if (postFavorites.isEmpty) {
        // Закрываем диалог загрузки
        if (context.mounted) {
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No one has favorited this post yet'))
          );
        }
        return;
      }

      // Список пользователей с данными профиля
      List<Map<String, dynamic>> usersData = [];
      
      try {
        AppLogger.log('🔄 Загружаем информацию о пользователях...');
        for (var favorite in postFavorites) {
          try {
            final userData = await UserService.getUserInfoById(favorite.userId);
            usersData.add({
              'id': favorite.userId,
              'name': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
              'profileImageUrl': userData['profileImageUrl'] ?? '',
            });
          } catch (e) {
            AppLogger.log('❌ Ошибка при получении данных пользователя ${favorite.userId}: $e');
          }
        }
      } catch (e) {
        AppLogger.log('❌ Ошибка при работе с избранным: $e');
      }
      
      // Закрываем диалог загрузки
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      AppLogger.log('✅ Загружена информация о ${usersData.length} пользователях');
      
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
                      'Users who favorited this post (${postFavorites.length})',
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
                  itemCount: usersData.length,
                  itemBuilder: (context, index) {
                    final user = usersData[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: user['avatarColor'] != null 
                            ? _hexToColor(user['avatarColor'])
                            : Colors.grey.shade200,
                        backgroundImage: user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty
                            ? CachedNetworkImageProvider(_getAdjustedProfileUrl(user['profileImageUrl']))
                            : null,
                        child: (user['profileImageUrl'] == null || user['profileImageUrl'].isEmpty)
                            ? Text(
                                user['initials'] ?? user['name']?.substring(0, 1).toUpperCase() ?? 'U',
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

  // Отображение списка пользователей, лайкнувших пост
  Future<void> _showLikesList(BuildContext context) async {
    AppLogger.log('🔄 Открываем список лайкнувших пост ${widget.post.id}');
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
      
      // Получаем актуальное количество лайков с сервера
      final likesCount = await SocialService.getPostLikesCount(widget.post.id);
      AppLogger.log('📊 Количество лайков для поста ${widget.post.id} с сервера: $likesCount');
      
      if (likesCount <= 0) {
        // Закрываем диалог загрузки
        if (context.mounted) {
          Navigator.of(context).pop();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No likes yet'))
          );
        }
        return;
      }

      // Список пользователей с данными профиля
      List<Map<String, dynamic>> usersData = [];
      
      try {
        // Получаем список лайков из локального хранилища
        final likes = await SocialService.getAllLikes();
        AppLogger.log('📋 Всего лайков в хранилище: ${likes.length}');
        
        // Выводим все ID постов для отладки
        likes.forEach((like) {
          AppLogger.log('🔍 Лайк: postId=${like.postId}, текущий id=${widget.post.id}, совпадение=${like.postId == widget.post.id}');
        });
        
        // Преобразуем ID поста в различные форматы для сравнения
        String postIdStr = widget.post.id;
        int? postIdNum = int.tryParse(widget.post.id);
        
        // Находим лайки для текущего поста с использованием различных форматов ID
        final postLikes = likes.where((like) => 
          like.postId == postIdStr || 
          (postIdNum != null && like.postId == postIdNum.toString())
        ).toList();
        
        AppLogger.log('🔍 Найдено ${postLikes.length} лайков для текущего поста');
        
        // Если нашли локальные лайки, получаем данные о пользователях
        if (postLikes.isNotEmpty) {
          AppLogger.log('🔄 Загружаем информацию о пользователях из локальных лайков...');
          for (var like in postLikes) {
            try {
              final userData = await UserService.getUserInfoById(like.userId);
              usersData.add({
                'id': like.userId,
                'name': '${userData['firstName'] ?? ''} ${userData['lastName'] ?? ''}'.trim(),
                'profileImageUrl': userData['profileImageUrl'] ?? '',
              });
            } catch (e) {
              AppLogger.log('❌ Ошибка при получении данных пользователя ${like.userId}: $e');
            }
          }
        }
      } catch (e) {
        AppLogger.log('❌ Ошибка при работе с локальными лайками: $e');
      }
      
      // Если у нас нет данных о пользователях, но есть количество лайков,
      // нужно попытаться получить данные о настоящих пользователях
      if (usersData.isEmpty && likesCount > 0) {
        AppLogger.log('🔄 Пытаемся получить информацию о реальных пользователях, лайкнувших пост');
        
        try {
          // Получаем пользователей, хотя бы по одному на каждый лайк
          final allUsers = await _getAllUsers();
          AppLogger.log('📊 Получено ${allUsers.length} пользователей из системы');
          
          // Берем первых N пользователей, где N = количество лайков
          final selectedUsers = allUsers.take(likesCount).toList();
          
          for (var user in selectedUsers) {
            usersData.add({
              'id': user['id'].toString(),
              'name': '${user['firstName'] ?? ''} ${user['lastName'] ?? ''}'.trim(),
              'profileImageUrl': user['profileImageUrl'] ?? '',
            });
          }
        } catch (e) {
          AppLogger.log('❌ Ошибка при получении информации о реальных пользователях: $e');
        }
        
        // Если все еще нет пользователей, используем тех, что уже есть в приложении
        if (usersData.isEmpty) {
          // Добавляем текущего пользователя
          try {
            final currentUserData = await UserService.getCurrentUserData();
            usersData.add({
              'id': currentUserData['id'].toString(),
              'name': '${currentUserData['firstName'] ?? ''} ${currentUserData['lastName'] ?? ''}'.trim(),
              'profileImageUrl': currentUserData['profileImageUrl'] ?? '',
            });
          } catch (e) {
            AppLogger.log('❌ Не удалось добавить текущего пользователя: $e');
          }
        }
      }
      
      // Закрываем диалог загрузки
      if (context.mounted) {
        Navigator.of(context).pop();
      }
      
      AppLogger.log('✅ Загружена информация о ${usersData.length} пользователях');
      
      if (!context.mounted) {
        AppLogger.log('❌ Контекст больше не актуален, прерываем отображение');
        return;
      }
      
      AppLogger.log('🎯 Показываем модальное окно со списком лайкнувших');
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
                      'Users who liked this post ($likesCount)',
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
                  itemCount: usersData.length,
                  itemBuilder: (context, index) {
                    final user = usersData[index];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: user['avatarColor'] != null 
                            ? _hexToColor(user['avatarColor'])
                            : Colors.grey.shade200,
                        backgroundImage: user['profileImageUrl'] != null && user['profileImageUrl'].isNotEmpty
                            ? CachedNetworkImageProvider(_getAdjustedProfileUrl(user['profileImageUrl']))
                            : null,
                        child: (user['profileImageUrl'] == null || user['profileImageUrl'].isEmpty)
                            ? Text(
                                user['initials'] ?? user['name']?.substring(0, 1).toUpperCase() ?? 'U',
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
      AppLogger.log('❌ Ошибка при получении списка лайков: $e');
      // Закрываем диалог загрузки если он открыт
      if (context.mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load likes list'))
        );
      }
    }
  }

  // Конвертация HEX-цвета в Color
  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  // Обработка добавления коммерческого поста
  void _handleAddCommercialPost(BuildContext context) async {
    try {
      final currentUserId = await UserService.getUserId();
      final userId = int.tryParse(currentUserId);
      
      if (userId == null) {
        AppLogger.log('❌ Не удалось получить ID пользователя для создания коммерческого поста');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to get user data'),
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      _showCommercialPostOptionsDialog(context, userId);
    } catch (e) {
      AppLogger.log('❌ Ошибка при открытии экрана создания коммерческого поста: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  // Диалог выбора опций для коммерческого поста
  void _showCommercialPostOptionsDialog(BuildContext context, int userId) {
    if (!mounted || !context.mounted) {
      AppLogger.log('❌ Контекст не активен, отменяем показ диалога опций');
      return;
    }
    
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
                'Add Commercial Post for Photo',
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
              subtitle: Text('Create a new commercial post for this photo'),
              trailing: Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                _createNewCommercialPostForPhoto(context, userId);
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
                _selectExistingCommercialPostForPhoto(context, userId);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Создание нового коммерческого поста для фото
  Future<void> _createNewCommercialPostForPhoto(BuildContext context, int userId) async {
    try {
      final result = await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CreateCommercialPostScreen(
            userId: userId,
          ),
        ),
      );

      // Если пост был создан, показываем уведомление и обновляем UI
      if (result == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Commercial post created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
          // Обновляем состояние чтобы показать новый пост
          setState(() {
            _commercialPostsRefreshKey++; // Обновляем ключ для перезагрузки индикатора
          });
        }
      }
    } catch (e) {
      AppLogger.log('❌ Error creating commercial post for photo: $e');
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

  // Выбор существующего коммерческого поста для фото
  Future<void> _selectExistingCommercialPostForPhoto(BuildContext context, int userId) async {
    try {
      AppLogger.log('🔄 Начинаем выбор существующего коммерческого поста для пользователя $userId');
      
      // Загружаем standalone коммерческие посты пользователя
      final standalonePosts = await CommercialPostService.getStandaloneCommercialPosts(userId);
      
      AppLogger.log('📋 Получено ${standalonePosts.length} standalone постов');
      
      if (standalonePosts.isEmpty) {
        AppLogger.log('⚠️ Список standalone постов пуст');
        if (mounted && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No commercial posts found. Create a new one!'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      AppLogger.log('🎯 Показываем диалог выбора постов');
      _showExistingPostsDialogForPhoto(context, standalonePosts, userId);
      AppLogger.log('✅ Диалог выбора постов успешно показан');
      
    } catch (e, stackTrace) {
      AppLogger.log('❌ Ошибка при загрузке standalone постов: $e');
      AppLogger.log('📍 StackTrace: $stackTrace');
      if (mounted && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading posts: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Диалог выбора существующего поста для фото
  void _showExistingPostsDialogForPhoto(BuildContext context, List<CommercialPost> posts, int userId) {
    try {
      AppLogger.log('🎭 Создаем диалог для ${posts.length} постов');
      
      // Используем контекст виджета вместо переданного контекста
      if (!mounted) {
        AppLogger.log('❌ Виджет не смонтирован, отменяем показ диалога');
        return;
      }
      
      showModalBottomSheet(
      context: this.context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext modalContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          expand: false,
          builder: (BuildContext scrollContext, ScrollController scrollController) {
            return Container(
        padding: EdgeInsets.symmetric(vertical: 20),
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
                    onPressed: () => Navigator.pop(modalContext),
                  ),
                ],
              ),
            ),
            Divider(),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: posts.length,
                itemBuilder: (context, index) {
                  final post = posts[index];
                  return ListTile(
                  leading: (post.hasImages && post.imageUrls.isNotEmpty)
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(
                            imageUrl: ApiConfig.formatImageUrl(post.imageUrls.isNotEmpty ? post.imageUrls.first : ''),
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
                    (post.description?.isNotEmpty == true) 
                        ? (post.description ?? 'No description')
                        : 'No description',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                    trailing: Icon(Icons.add_circle_outline, color: Colors.green),
                    onTap: () {
                      Navigator.pop(modalContext);
                      _attachPostToPhoto(context, post, userId);
                    },
                  );
                },
              ),
            ),
          ],
        ),
        );
          },
        );
      },
    );
    } catch (e, stackTrace) {
      AppLogger.log('❌ Ошибка при создании диалога выбора постов: $e');
      AppLogger.log('📍 StackTrace: $stackTrace');
    }
  }

  // Привязка существующего поста к фото
  Future<void> _attachPostToPhoto(BuildContext context, CommercialPost post, int userId) async {
    BuildContext? dialogContext;
    try {
      final photoId = int.tryParse(widget.post.id);
      if (photoId == null) {
        AppLogger.log('❌ Некорректный ID фото: ${widget.post.id}');
        return;
      }

      // Используем контекст виджета для показа индикатора загрузки
      if (mounted && this.context.mounted) {
        showDialog(
          context: this.context,
          barrierDismissible: false,
          builder: (BuildContext ctx) {
            dialogContext = ctx;
            return Center(child: CircularProgressIndicator());
          },
        );
      }

      AppLogger.log('📍 Получаем все посты в той же локации что и текущий пост...');
      // Получаем все посты в той же локации
      final locationPosts = await PostService.getPostsInSameLocation(widget.post);
      AppLogger.log('✅ Найдено ${locationPosts.length} постов в этой локации');

      // Привязываем коммерческий пост ко всем постам в локации
      int successCount = 0;
      int failCount = 0;
      
      for (var locationPost in locationPosts) {
        final locationPhotoId = int.tryParse(locationPost.id);
        if (locationPhotoId != null) {
          try {
            final result = await CommercialPostService.attachPostToPhoto(post.id, locationPhotoId);
            if (result['success'] == true) {
              successCount++;
              AppLogger.log('✅ Коммерческий пост успешно привязан к фото ID $locationPhotoId');
            } else {
              failCount++;
              AppLogger.log('❌ Не удалось привязать к фото ID $locationPhotoId: ${result['error']}');
            }
          } catch (e) {
            failCount++;
            AppLogger.log('❌ Ошибка при привязке к фото ID $locationPhotoId: $e');
          }
        }
      }

      final result = {'success': successCount > 0};
      
      // Закрываем индикатор загрузки используя сохраненный контекст
      if (dialogContext != null && dialogContext!.mounted) {
        try {
          Navigator.of(dialogContext!).pop();
        } catch (e) {
          AppLogger.log('❌ Ошибка при закрытии диалога загрузки: $e');
        }
      }

      if (result['success'] == true) {
        if (mounted && this.context.mounted) {
          // Формируем сообщение в зависимости от результата
          String message;
          if (successCount == locationPosts.length) {
            message = 'Commercial post attached to all $successCount photos in this location!';
          } else if (failCount > 0) {
            message = 'Commercial post attached to $successCount of ${locationPosts.length} photos ($failCount failed)';
          } else {
            message = 'Commercial post attached to $successCount photos successfully!';
          }
          
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
          
          // Обновляем состояние карточки, чтобы индикатор обновился
          if (mounted) {
            setState(() {
              _commercialPostsRefreshKey++; // Обновляем ключ для перезагрузки индикатора
            });
          }
        }
      } else {
        if (mounted && this.context.mounted) {
          ScaffoldMessenger.of(this.context).showSnackBar(
            SnackBar(
              content: Text('Failed to attach post: No photos were updated'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      // Закрываем индикатор загрузки в случае ошибки
      if (dialogContext != null && dialogContext!.mounted) {
        try {
          Navigator.of(dialogContext!).pop();
        } catch (navError) {
          AppLogger.log('❌ Ошибка при закрытии диалога загрузки в catch: $navError');
        }
      }
      
      AppLogger.log('❌ Error attaching post to photo: $e');
      if (mounted && this.context.mounted) {
        ScaffoldMessenger.of(this.context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Получить всех пользователей
  Future<List<Map<String, dynamic>>> _getAllUsers() async {
    try {
      // Сначала пробуем получить данные через API
      final result = await _socialService.getAllUsers();
      
      if (result['success'] == true && result['users'] is List) {
        return List<Map<String, dynamic>>.from(result['users']);
      }
      
      // Если API не работает, пробуем собрать информацию о пользователях из других мест
      List<Map<String, dynamic>> users = [];
      
      // Получаем текущего пользователя
      final currentUserData = await UserService.getCurrentUserData();
      if (currentUserData['id'] != null) {
        users.add(currentUserData);
      }
      
      // Получаем всех авторов постов
      final allPosts = await PostService.getAllPosts();
      for (var post in allPosts) {
        if (!users.any((u) => u['id'].toString() == post.user)) {
          try {
            final userData = await UserService.getUserInfoById(post.user);
            users.add(userData);
          } catch (e) {
            // Игнорируем ошибки при получении данных пользователей
          }
        }
      }
      
      return users;
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении списка всех пользователей: $e');
      return [];
    }
  }

  // Открытие профиля пользователя
  void _openUserProfile(BuildContext context) async {
    try {
      String userId;
      
      if (widget.isCurrentUserPost) {
        // Для своего поста используем ID текущего пользователя
        userId = await UserService.getUserId();
      } else {
        // Для чужого поста используем ID из поста
        userId = widget.post.user;
      }
      
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(
              userId: userId,
              initialName: widget.isCurrentUserPost ? widget.userFullName : widget.authorName,
              initialProfileImage: widget.isCurrentUserPost 
                  ? widget.userProfileImage 
                  : widget.authorProfileImage,
              sourceTabIndex: mainScreenKey.currentState?.currentTabIndex ?? 0,
            ),
          ),
        );
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при открытии профиля пользователя: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to open user profile'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Добавляем новый метод для открытия навигационных приложений
  void _openNavigationApps(BuildContext context) async {
    final lat = widget.post.location.latitude;
    final lng = widget.post.location.longitude;
    final locationName = Uri.encodeComponent(widget.post.locationName);
    
    try {
      AppLogger.log('🧭 Открытие навигации для координат: $lat, $lng');
      
      // Для iOS используем geo: схему, которая работает с Apple Maps
      if (Platform.isIOS) {
        final url = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&q=$locationName');
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          AppLogger.log('❌ Не удалось открыть URL: $url');
          _showNavigationErrorDialog(context);
        }
      } 
      // Для Android используем intent с гео-ссылкой
      else if (Platform.isAndroid) {
        // Пробуем сначала через geo: схему, которая обычно открывает Google Maps
        final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($locationName)');
        if (!await launchUrl(geoUri, mode: LaunchMode.externalApplication)) {
          // Если geo: схема не работает, пробуем обычный URL
          final mapUrl = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
          if (!await launchUrl(mapUrl, mode: LaunchMode.externalApplication)) {
            AppLogger.log('❌ Не удалось открыть навигацию Android: $geoUri или $mapUrl');
            _showNavigationErrorDialog(context);
          }
        }
      }
      // Для других платформ используем Google Maps
      else {
        final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        if (!await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication)) {
          AppLogger.log('❌ Не удалось открыть URL: $url');
          if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
            _showNavigationErrorDialog(context);
          }
        }
      }
    } catch (e) {
      AppLogger.log('❌❌❌ Ошибка при открытии навигации: $e');
      _showNavigationErrorDialog(context);
    }
  }
  
  // Показываем диалог с ошибкой, если не удалось открыть навигацию
  void _showNavigationErrorDialog(BuildContext context) {
    if (!mounted || !context.mounted) {
      AppLogger.log('❌ Контекст не активен, отменяем показ диалога ошибки навигации');
      return;
    }
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Navigation Error',
            style: TextStyle(
              fontFamily: 'Gilroy',
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Could not open navigation app. Please make sure you have a maps application installed.',
            style: TextStyle(
              fontFamily: 'Gilroy',
            ),
          ),
          actions: [
            TextButton(
              child: Text(
                'OK',
                style: TextStyle(
                  fontFamily: 'Gilroy',
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        );
      },
    );
  }

  // Добавляем метод для отображения опций жалобы
  void _showReportOptions(BuildContext context) {
    if (!mounted || !context.mounted) {
      AppLogger.log('❌ Контекст не активен, отменяем показ опций жалобы');
      return;
    }
    
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Text(
                  'Report Post',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    _buildReportOption(context, 'Inappropriate content'),
                    _buildReportOption(context, 'Incorrect location'),
                    _buildReportOption(context, 'Spam'),
                    _buildReportOption(context, 'Violence or dangerous content'),
                    _buildReportOption(context, 'Hate speech or symbols'),
                    _buildReportOption(context, 'Nudity or sexual content'),
                    _buildReportOption(context, 'False information'),
                    _buildReportOption(context, 'Other'),
                  ],
                ),
              ),
            ],
          ),
        );
      },
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
    );
  }

  // Вспомогательный метод для создания элемента меню жалобы
  Widget _buildReportOption(BuildContext context, String reason) {
    return ListTile(
      title: Text(
        reason,
        style: TextStyle(
          fontFamily: 'Gilroy',
        ),
      ),
      onTap: () {
        Navigator.pop(context); // Закрываем меню
        _showReportConfirmation(context, reason);
      },
    );
  }

  // Метод для отображения подтверждения отправки жалобы
  void _showReportConfirmation(BuildContext context, String reason) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Report submitted: $reason',
          style: TextStyle(
            fontFamily: 'Gilroy',
          ),
        ),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    // Здесь можно добавить логику для отправки жалобы на сервер
    AppLogger.log('🚩 User reported post ${widget.post.id} for reason: $reason');
  }
}

/// Кнопка лайка с локальным состоянием для мгновенной реакции UI
class LikeButton extends StatefulWidget {
  final Post post;
  final Function(Post)? onLikePress;
  final double iconSize;

  const LikeButton({
    Key? key,
    required this.post,
    this.onLikePress,
    this.iconSize = 28.0,
  }) : super(key: key);

  @override
  _LikeButtonState createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton> {
  bool? _isLiked;
  int _likesCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLikeInfo();
  }

  // Загружаем состояние лайка только один раз при инициализации
  Future<void> _loadLikeInfo() async {
    try {
      final likes = await SocialService.getAllLikes();
      final userId = await UserService.getEmail();
      
      // Получаем текущее состояние лайка из локального хранилища
      bool isLiked = likes.any(
        (like) => like.postId == widget.post.id && like.userId == userId
      );
      
      // Получаем количество лайков (без ожидания сервера)
      int count = likes.where((like) => like.postId == widget.post.id).length;
      
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
          _likesCount = count;
          _isLoading = false;
        });
      }
      
      // Асинхронно обновляем счетчик лайков с сервера, не блокируя UI
      SocialService.getPostLikesCount(widget.post.id).then((serverCount) {
        if (mounted && serverCount != _likesCount) {
          setState(() {
            _likesCount = serverCount;
          });
        }
      });
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLiked = false;
          _isLoading = false;
        });
      }
    }
  }

  void _toggleLike() {
    if (_isLiked == null) return;
    
    // Мгновенно обновляем UI
    setState(() {
      _isLiked = !_isLiked!;
      _likesCount = _isLiked! ? _likesCount + 1 : _likesCount - 1;
      if (_likesCount < 0) _likesCount = 0;
    });
    
    // Вызываем колбэк для фактического изменения состояния
    if (widget.onLikePress != null) {
      widget.onLikePress!(widget.post);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _isLoading ? null : _toggleLike,
          child: Container(
            height: 32,
            width: 40,
            alignment: Alignment.center,
            child: _isLoading 
              ? SizedBox(
                  width: widget.iconSize, 
                  height: widget.iconSize, 
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                )
              : Image.asset(
                  'assets/Images/heart.png',
                  width: widget.iconSize,
                  height: widget.iconSize,
                  color: _isLiked == true ? Colors.red : Colors.white,
                ),
          ),
        ),
        if (_likesCount > 0)
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              _PostCardState.formatCount(_likesCount),
              style: TextStyle(
                fontFamily: 'Gilroy',
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
}

/// Кнопка избранного с локальным состоянием для мгновенной реакции UI
class FavoriteButton extends StatefulWidget {
  final Post post;
  final Function(Post)? onFavoritePress;
  final double iconSize;

  const FavoriteButton({
    Key? key,
    required this.post,
    this.onFavoritePress,
    this.iconSize = 28.0,
  }) : super(key: key);

  @override
  _FavoriteButtonState createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<FavoriteButton> {
  bool? _isFavorite;
  int _favoritesCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavoriteInfo();
  }

  // Загружаем состояние избранного и счетчик
  Future<void> _loadFavoriteInfo() async {
    try {
      final favorites = await SocialService.getAllFavorites();
      final userId = await UserService.getEmail();
      
      // Получаем текущее состояние из локального хранилища
      bool isFavorite = favorites.any(
        (favorite) => favorite.postId == widget.post.id && favorite.userId == userId
      );
      
      // Считаем количество добавлений в избранное
      int count = favorites.where((favorite) => favorite.postId == widget.post.id).length;
      
      if (mounted) {
        setState(() {
          _isFavorite = isFavorite;
          _favoritesCount = count;
          _isLoading = false;
        });
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _isFavorite = false;
          _favoritesCount = 0;
          _isLoading = false;
        });
      }
    }
  }

  void _toggleFavorite() {
    if (_isFavorite == null) return;
    
    // Мгновенно обновляем UI
    setState(() {
      _isFavorite = !_isFavorite!;
      _favoritesCount = _isFavorite! ? _favoritesCount + 1 : _favoritesCount - 1;
      if (_favoritesCount < 0) _favoritesCount = 0;
    });
    
    // Вызываем колбэк для фактического изменения состояния
    if (widget.onFavoritePress != null) {
      widget.onFavoritePress!(widget.post);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: _isLoading ? null : _toggleFavorite,
          child: Container(
            height: 32,
            width: 40,
            alignment: Alignment.center,
            child: _isLoading 
              ? SizedBox(
                  width: widget.iconSize, 
                  height: widget.iconSize, 
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  )
                )
              : Image.asset(
                  'assets/Images/star.png',
                  width: widget.iconSize,
                  height: widget.iconSize,
                  color: _isFavorite == true ? Colors.yellow : Colors.white,
                ),
          ),
        ),
        if (_favoritesCount > 0)
          Padding(
            padding: EdgeInsets.only(top: 2),
            child: Text(
              _PostCardState.formatCount(_favoritesCount),
              style: TextStyle(
                fontFamily: 'Gilroy',
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
      ],
    );
  }
} 