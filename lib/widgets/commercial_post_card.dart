import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/commercial_post.dart';
import '../services/social_service.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../services/user_service.dart';
import 'dart:math';
import '../services/commercial_post_service.dart';
import '../screens/user_profile_screen.dart';
import '../screens/main_screen.dart';
import '../utils/logger.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../screens/comments_screen.dart';
import '../services/post_service.dart';

/// Виджет карточки коммерческого поста с полным функционалом
class CommercialPostCard extends StatefulWidget {
  final CommercialPost post;
  final String? userProfileImage;
  final String userFullName;
  final Function(CommercialPost) onEditPost;
  final Function(CommercialPost) onDeletePost;
  final bool isCurrentUserPost;
  final Function(CommercialPost)? onLikePost;
  final Function(CommercialPost)? onFavoritePost;
  final Function(String)? onFollowUser;
  final bool isFollowing;
  final Function(CommercialPost, int)? onImageTap;
  final Function(CommercialPost)? onShowLikesList;
  final Function(CommercialPost)? onShowOnMap;

  const CommercialPostCard({
    Key? key,
    required this.post,
    required this.userProfileImage,
    required this.userFullName,
    required this.onEditPost,
    required this.onDeletePost,
    required this.isCurrentUserPost,
    this.onLikePost,
    this.onFavoritePost,
    this.onFollowUser,
    this.isFollowing = false,
    this.onImageTap,
    this.onShowLikesList,
    this.onShowOnMap,
  }) : super(key: key);

  @override
  _CommercialPostCardState createState() => _CommercialPostCardState();
}

class _CommercialPostCardState extends State<CommercialPostCard> {
  int _commentsCount = 0;
  bool _isLoadingComments = true;
  bool _isDescriptionExpanded = false;
  final _socialService = SocialService();

  @override
  void initState() {
    super.initState();
    _loadCommentsCount();
  }

  @override
  void didUpdateWidget(CommercialPostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Обновляем счетчик комментариев при каждом обновлении виджета
    if (oldWidget.post.id == widget.post.id) {
      _loadCommentsCount();
    }
  }

  // Загружаем количество комментариев
  Future<void> _loadCommentsCount() async {
    try {
      if (widget.post.id.toString().isEmpty) {
        AppLogger.log('❌ Invalid commercial post ID: ${widget.post.id}');
        return;
      }

      if (!mounted) {
        AppLogger.log('⚠️ Виджет больше не монтирован, отменяем загрузку комментариев');
        return;
      }
      
      setState(() {
        _isLoadingComments = true;
      });

      AppLogger.log('🔄 Запрос количества комментариев для коммерческого поста ID: ${widget.post.id}');
      final result = await _socialService.getComments(widget.post.id.toString(), page: 1, perPage: 1);
      
      if (!mounted) {
        AppLogger.log('⚠️ Виджет больше не монтирован после загрузки, отменяем обновление');
        return;
      }
      
      if (result['success'] == true && result['pagination'] != null) {
        setState(() {
          _commentsCount = result['pagination']['total'] ?? 0;
        });
      } else {
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

  // Форматирование даты поста
  String _formatDate(DateTime date) {
    return DateFormat('dd.MM.yyyy').format(date);
  }

  // Проверяем, нужно ли показывать кнопку "Показать больше"
  bool _shouldShowExpandButton(String description) {
    // Создаем TextPainter для измерения текста
    final textPainter = TextPainter(
      text: TextSpan(
        text: description,
        style: TextStyle(
          fontFamily: 'Gilroy',
          fontStyle: FontStyle.normal,
          fontWeight: FontWeight.w400,
          fontSize: 14,
          color: Colors.black87,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
      maxLines: 2,
    );
    
    // Максимальная ширина (примерно ширина экрана минус отступы)
    const maxWidth = 300.0;
    textPainter.layout(maxWidth: maxWidth);
    
    // Если текст не помещается в 2 строки, показываем кнопку
    return textPainter.didExceedMaxLines;
  }

  @override
  Widget build(BuildContext context) {
    // Используем URL изображений
    final bool hasImages = widget.post.hasImages || 
                          (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty);
    
    // Получаем размер экрана для адаптивности (как в обычном посте)
    final screenWidth = MediaQuery.of(context).size.width;
    final imageSize = screenWidth >= 430 ? 400.0 : screenWidth - 30;
    
    Widget content = SingleChildScrollView(
      physics: NeverScrollableScrollPhysics(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка поста (аватар, имя, количество постов и дата)
          Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Аватар автора
                    GestureDetector(
                      onTap: widget.isCurrentUserPost ? null : () => _openUserProfile(context),
                      child: CircleAvatar(
                        radius: 28,
                        backgroundColor: Colors.transparent,
                        backgroundImage: widget.post.userProfileImage != null
                            ? CachedNetworkImageProvider(
                                ApiConfig.formatImageUrl(widget.post.userProfileImage!),
                              )
                            : null,
                        child: widget.post.userProfileImage == null
                            ? Icon(
                                Icons.person,
                                size: 28,
                                color: Colors.grey.shade600,
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
                          // Верхняя строка: имя пользователя и дата
                          Row(
                            children: [
                              // Имя пользователя
                              Expanded(
                                child: GestureDetector(
                                  onTap: widget.isCurrentUserPost ? null : () => _openUserProfile(context),
                                  child: Text(
                                    widget.post.userName ?? 'User',
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
                          
                          // Индикатор коммерческого поста и заголовок на одной строке
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
                                      Icons.business,
                                      size: 14,
                                      color: Colors.orange.shade600,
                                    ),
                                    SizedBox(width: 4),
                                    Text(
                                      'Commercial',
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
          if (widget.post.description != null && widget.post.description!.isNotEmpty) ...[
            SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: GestureDetector(
                onTap: () {
                  if (_shouldShowExpandButton(widget.post.description!)) {
                    setState(() {
                      _isDescriptionExpanded = !_isDescriptionExpanded;
                    });
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.post.description!,
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
                    if (_shouldShowExpandButton(widget.post.description!) && !_isDescriptionExpanded)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Show more...',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontStyle: FontStyle.normal,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ),
                    if (_shouldShowExpandButton(widget.post.description!) && _isDescriptionExpanded)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Show less',
                          style: TextStyle(
                            fontFamily: 'Gilroy',
                            fontStyle: FontStyle.normal,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                            color: Colors.blue.shade600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          
          // Изображения поста
          if (hasImages)
            Center(
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
                    // Изображение
                    Positioned.fill(
                      child: _buildImageSection(),
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
                              '${widget.post.hasImages ? widget.post.imageUrls.length : 1}',
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
                    
                    // Кнопки управления постом
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
                    
                    // Кнопка "Пожаловаться" - только для чужих постов
                    if (!widget.isCurrentUserPost)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: IconButton(
                            icon: Icon(Icons.flag, color: Colors.white, size: 18),
                            onPressed: () => _showReportOptions(context),
                            padding: EdgeInsets.all(4),
                            constraints: BoxConstraints(
                              minWidth: 28,
                              minHeight: 28,
                            ),
                            tooltip: "Report",
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          
          // Секция локации (после изображений, как в обычных постах)
          if (widget.post.hasLocation) _buildLocationSection(),
        ],
      ),
    );
    
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 0,
      color: Colors.white,
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
  }

  Widget _buildImageSection() {
    List<String> imagesToShow = [];
    if (widget.post.hasImages) {
      imagesToShow = widget.post.imageUrls;
    } else if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty) {
      imagesToShow = [widget.post.imageUrl!];
    }

    if (imagesToShow.isEmpty) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () {
        if (widget.onImageTap != null) {
          widget.onImageTap!(widget.post, 0);
        }
      },
      child: CachedNetworkImage(
        imageUrl: ApiConfig.formatImageUrl(imagesToShow.first),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (context, url) => Container(
          color: Colors.grey.shade200,
          child: const Center(
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (context, url, error) => Container(
          color: Colors.grey.shade200,
          child: Icon(
            Icons.image_not_supported,
            color: Colors.grey.shade400,
            size: 48,
          ),
        ),
      ),
    );
  }
  
  // Элементы управления для своего поста
  Widget _buildCurrentUserPostControls() {
    return Column(
      children: [
        // Кнопка избранного и счетчик
        FutureBuilder<Map<String, dynamic>>(
          future: _getFavoriteInfo(widget.post.id.toString()),
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
                      favoritesCount.toString(),
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
          future: _getLikeInfo(widget.post.id.toString()),
          builder: (context, snapshot) {
            final likesCount = snapshot.data?['count'] ?? 0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () {
                    AppLogger.log('👆 Нажата кнопка просмотра лайков коммерческого поста');
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
                      likesCount.toString(),
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
              onTap: () => _showCommentsModal(),
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
  
  // Элементы управления для чужого поста
  Widget _buildOtherUserPostControls() {
    return Column(
      children: [
        // Кнопка добавления в избранное
        CommercialFavoriteButton(
          post: widget.post,
          onFavoritePress: widget.onFavoritePost,
          iconSize: 36.0,
        ),
        
        SizedBox(height: 4),
        
        // Кнопка лайка
        CommercialLikeButton(
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
              onTap: () => _showCommentsModal(),
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

  // Получение URL фотографии для экрана комментариев
  String _getPhotoUrlForComments() {
    // Приоритет: imageUrls -> imageUrl -> заглушка
    if (widget.post.hasImages && widget.post.imageUrls.isNotEmpty) {
      return ApiConfig.formatImageUrl(widget.post.imageUrls.first);
    } else if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty) {
      return ApiConfig.formatImageUrl(widget.post.imageUrl!);
    } else {
      return 'https://via.placeholder.com/400x300?text=Commercial+Post';
    }
  }

  // Показать модальное окно с комментариями
  void _showCommentsModal() {
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
            photoId: widget.post.id.toString(),
            photoUrl: _getPhotoUrlForComments(),
          ),
        );
      },
    ).then((_) {
      // Обновляем счетчик комментариев после закрытия окна
      _loadCommentsCount();
    });
  }

  // Получение информации о лайках для коммерческого поста
  Future<Map<String, dynamic>> _getLikeInfo(String postId) async {
    try {
      // Сначала считаем локальные лайки
      final localLikes = await SocialService.getAllLikes();
      final localCount = localLikes.where((like) => like.postId == postId).length;
      final isLiked = await SocialService.isLiked(postId);

      // Пытаемся получить серверный счётчик (для обычных постов он актуален)
      final serverCount = await SocialService.getPostLikesCount(postId);

      // Если сервер вернул > 0 — используем его; иначе оставляем локальный
      final effectiveCount = serverCount > 0 ? serverCount : localCount;

      return {
        'count': effectiveCount,
        'isLiked': isLiked,
      };
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении информации о лайках коммерческого поста: $e');
      return {
        'count': 0,
        'isLiked': false,
      };
    }
  }

  // Получение информации об избранном для коммерческого поста
  Future<Map<String, dynamic>> _getFavoriteInfo(String postId) async {
    try {
      final favorites = await SocialService.getAllCommercialFavorites();
      final favoritesCount = favorites.where((fav) => fav.postId == postId).length;
      return {
        'count': favoritesCount,
      };
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении информации об избранном коммерческого поста: $e');
      return {
        'count': 0,
      };
    }
  }

  // Отображение списка пользователей, добавивших пост в избранное
  Future<void> _showFavoritesList(BuildContext context) async {
    AppLogger.log('🔄 Открываем список добавивших в избранное коммерческий пост ${widget.post.id}');
    try {
      final favorites = await SocialService.getAllCommercialFavorites();
      final postFavorites = favorites.where((fav) => fav.postId == widget.post.id.toString()).toList();
      
      if (postFavorites.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No one has favorited this post yet'))
        );
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${postFavorites.length} people favorited this post'))
      );
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении списка избранного: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load favorites list'))
      );
    }
  }

  // Отображение списка пользователей, лайкнувших пост
  Future<void> _showLikesList(BuildContext context) async {
    AppLogger.log('🔄 Открываем список лайкнувших коммерческий пост ${widget.post.id}');
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
      final likesCount = await SocialService.getPostLikesCount(widget.post.id.toString());
      AppLogger.log('📊 Количество лайков для коммерческого поста ${widget.post.id} с сервера: $likesCount');
      
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

      // Здесь можно добавить логику получения списка пользователей
      // Пока что показываем простое сообщение
      
      // Закрываем диалог загрузки
      if (context.mounted) {
        Navigator.of(context).pop();
        
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$likesCount people liked this post'))
          );
      }
      
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении списка лайков коммерческого поста: $e');
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

  // Открытие профиля пользователя
  void _openUserProfile(BuildContext context) async {
    try {
      String userId = widget.post.userId.toString();
      
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => UserProfileScreen(
              userId: userId,
              initialName: widget.post.userName ?? 'User',
              initialProfileImage: widget.post.userProfileImage,
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
            content: Text('Unable to open user profile'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Показать опции жалобы
  void _showReportOptions(BuildContext context) {
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
                  'Report Commercial Post',
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
                    _buildReportOption(context, 'Misleading information'),
                    _buildReportOption(context, 'Spam'),
                    _buildReportOption(context, 'Scam or fraud'),
                    _buildReportOption(context, 'False advertising'),
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

  // Элемент меню жалобы
  Widget _buildReportOption(BuildContext context, String reason) {
    return ListTile(
      title: Text(
        reason,
        style: TextStyle(
          fontFamily: 'Gilroy',
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        _showReportConfirmation(context, reason);
      },
    );
  }

  // Подтверждение отправки жалобы
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
    
    AppLogger.log('🚩 User reported commercial post ${widget.post.id} for reason: $reason');
  }

  // Секция отображения локации (как в обычных постах)
  Widget _buildLocationSection() {
    if (!widget.post.hasLocation) return const SizedBox.shrink();
    
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 16, 6, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Геолокация - левая часть строки
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.5,
            child: GestureDetector(
              onTap: () {
                if (widget.onShowOnMap != null) {
                  widget.onShowOnMap!(widget.post);
                }
              },
              child: Text(
                (widget.post.locationName ?? 'Location').toUpperCase(),
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
              future: _getLocationPostsInfo(),
              builder: (context, snapshot) {
                final postsCount = snapshot.data?['count'] ?? 0;
                final List<String> avatars = snapshot.data?['avatars'] ?? [];
                
                return GestureDetector(
                  onTap: postsCount > 0 && widget.onShowOnMap != null
                      ? () => widget.onShowOnMap!(widget.post)
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
                                              image: CachedNetworkImageProvider(ApiConfig.formatImageUrl(avatars[i])),
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
    );
  }

  // Получить информацию о постах в этой локации
  Future<Map<String, dynamic>> _getLocationPostsInfo() async {
    try {
      if (!widget.post.hasLocation) {
        return {
          'count': 0,
          'avatars': <String>[],
        };
      }

      // Для коммерческих постов пока возвращаем только текущий пост
      // TODO: Добавить API для получения всех коммерческих постов в локации
      final avatars = <String>[];
      if (widget.post.userProfileImage != null && widget.post.userProfileImage!.isNotEmpty) {
        avatars.add(widget.post.userProfileImage!);
      }
      
      return {
        'count': 1,
        'avatars': avatars,
      };
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении информации о постах в локации: $e');
      return {
        'count': 0,
        'avatars': <String>[],
      };
    }
  }

  // Открытие навигационных приложений
  void _openNavigationApps(BuildContext context) async {
    if (!widget.post.hasLocation) return;
    
    final lat = widget.post.latitude;
    final lng = widget.post.longitude;
    final locationName = Uri.encodeComponent(widget.post.locationName ?? 'Location');
    
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
        final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($locationName)');
        if (!await launchUrl(geoUri, mode: LaunchMode.externalApplication)) {
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
}

/// Кнопка лайка для коммерческого поста
class CommercialLikeButton extends StatefulWidget {
  final CommercialPost post;
  final Function(CommercialPost)? onLikePress;
  final double iconSize;

  const CommercialLikeButton({
    Key? key,
    required this.post,
    this.onLikePress,
    this.iconSize = 28.0,
  }) : super(key: key);

  @override
  _CommercialLikeButtonState createState() => _CommercialLikeButtonState();
}

class _CommercialLikeButtonState extends State<CommercialLikeButton> {
  bool? _isLiked;
  int _likesCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLikeInfo();
  }

  Future<void> _loadLikeInfo() async {
    try {
      final likes = await SocialService.getAllLikes();
      final userId = await UserService.getEmail();
      
      bool isLiked = likes.any(
        (like) => like.postId == widget.post.id.toString() && like.userId == userId
      );
      
      int count = likes.where((like) => like.postId == widget.post.id.toString()).length;
      
      if (mounted) {
        setState(() {
          _isLiked = isLiked;
          _likesCount = count;
          _isLoading = false;
        });
      }
      
      SocialService.getPostLikesCount(widget.post.id.toString()).then((serverCount) {
        if (!mounted) return;
        // Не перезаписываем локальный положительный счётчик нулём с сервера (для коммерческих постов)
        final effective = serverCount > 0 ? serverCount : _likesCount;
        if (effective != _likesCount) {
          setState(() {
            _likesCount = effective;
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
    
    setState(() {
      _isLiked = !_isLiked!;
      _likesCount = _isLiked! ? _likesCount + 1 : _likesCount - 1;
      if (_likesCount < 0) _likesCount = 0;
    });
    
    // Выполняем лайк через SocialService
    SocialService.likePost(widget.post.id.toString());
    
    if (widget.onLikePress != null) {
      widget.onLikePress!(widget.post);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: _isLoading 
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
          onPressed: _isLoading ? null : _toggleLike,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
        ),
        if (_likesCount > 0)
          Text(
            _likesCount.toString(),
            style: TextStyle(
              fontFamily: 'Gilroy',
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}

/// Кнопка избранного для коммерческого поста
class CommercialFavoriteButton extends StatefulWidget {
  final CommercialPost post;
  final Function(CommercialPost)? onFavoritePress;
  final double iconSize;

  const CommercialFavoriteButton({
    Key? key,
    required this.post,
    this.onFavoritePress,
    this.iconSize = 28.0,
  }) : super(key: key);

  @override
  _CommercialFavoriteButtonState createState() => _CommercialFavoriteButtonState();
}

class _CommercialFavoriteButtonState extends State<CommercialFavoriteButton> {
  bool? _isFavorite;
  int _favoritesCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFavoriteInfo();
  }

  Future<void> _loadFavoriteInfo() async {
    try {
      final commercialFavorites = await SocialService.getAllCommercialFavorites();
      final userId = await UserService.getEmail();
      
      bool isFavorite = commercialFavorites.any(
        (favorite) => favorite.postId == widget.post.id.toString() && favorite.userId == userId
      );
      
      int count = commercialFavorites.where((favorite) => favorite.postId == widget.post.id.toString()).length;
      
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
    
    setState(() {
      _isFavorite = !_isFavorite!;
      _favoritesCount = _isFavorite! ? _favoritesCount + 1 : _favoritesCount - 1;
      if (_favoritesCount < 0) _favoritesCount = 0;
    });
    
    // Выполняем операцию через новые методы для коммерческих постов
    if (_isFavorite!) {
      SocialService.addToCommercialFavorites(widget.post.id.toString());
    } else {
      SocialService.removeFromCommercialFavorites(widget.post.id.toString());
    }
    
    // Уведомляем родительский виджет об изменении (для обновления UI)
    if (widget.onFavoritePress != null) {
      widget.onFavoritePress!(widget.post);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        IconButton(
          icon: _isLoading 
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
          onPressed: _isLoading ? null : _toggleFavorite,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
        ),
        if (_favoritesCount > 0)
          Text(
            _favoritesCount.toString(),
            style: TextStyle(
              fontFamily: 'Gilroy',
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
      ],
    );
  }
}