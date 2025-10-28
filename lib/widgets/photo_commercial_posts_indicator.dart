import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/commercial_post_service.dart';
import '../screens/photo_commercial_posts_screen.dart';
import '../utils/logger.dart';
import '../config/api_config.dart';
import 'dart:async';

class PhotoCommercialPostsIndicator extends StatefulWidget {
  final int photoId;
  final String photoTitle;
  final Widget child;
  final int? currentUserId;

  const PhotoCommercialPostsIndicator({
    Key? key,
    required this.photoId,
    required this.photoTitle,
    required this.child,
    this.currentUserId,
  }) : super(key: key);

  @override
  State<PhotoCommercialPostsIndicator> createState() => _PhotoCommercialPostsIndicatorState();
}

class _PhotoCommercialPostsIndicatorState extends State<PhotoCommercialPostsIndicator> 
    with TickerProviderStateMixin {
  int _commercialPostsCount = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _commercialPosts = [];
  
  late AnimationController _floatingController;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _loadCommercialPostsCount();
  }
  
  @override
  void didUpdateWidget(PhotoCommercialPostsIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Перезагружаем данные когда виджет обновляется (например, после добавления поста)
    if (oldWidget.photoId == widget.photoId) {
      _loadCommercialPostsCount();
    }
  }
  
  @override
  void dispose() {
    _floatingController.dispose();
    super.dispose();
  }

  Future<void> _loadCommercialPostsCount() async {
    try {
      // Загружаем полный список постов для получения изображений
      final posts = await CommercialPostService.getCommercialPostsForPhoto(widget.photoId);
      
      if (mounted) {
        setState(() {
          _commercialPostsCount = posts.length;
          _commercialPosts = posts.map((post) => {
            'id': post.id,
            'imageUrl': post.firstImageUrl,
            'title': post.title,
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка загрузки коммерческих постов для фото ${widget.photoId}: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToCommercialPosts() {
    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => PhotoCommercialPostsScreen(
              photoId: widget.photoId,
              photoTitle: widget.photoTitle,
              currentUserId: widget.currentUserId,
            ),
          ),
        )
        .then((_) {
          if (mounted) {
            _loadCommercialPostsCount();
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        
        // Плавающие миниатюры коммерческих постов внизу слева с анимацией
        if (!_isLoading && _commercialPostsCount > 0)
          Positioned(
            bottom: 10,
            left: 12,
            child: AnimatedOpacity(
              opacity: _isLoading ? 0.0 : 1.0,
              duration: Duration(milliseconds: 300),
              child: AnimatedSlide(
                offset: _isLoading ? Offset(-0.2, 0) : Offset.zero,
                duration: Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                child: _buildFloatingThumbnails(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFloatingThumbnails() {
    // Показываем максимум 3 миниатюры + 1 кружок с количеством для фото
    const maxThumbnails = 3;
    final showCount = _commercialPostsCount > maxThumbnails;
    final thumbnailCount = showCount ? maxThumbnails : _commercialPostsCount;
    
    return Container(
      height: 35, // Немного меньше чем для альбомов
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Миниатюры коммерческих постов
          for (int i = 0; i < thumbnailCount; i++)
            _buildThumbnail(i),
          
          // Кружок с количеством оставшихся постов
          if (showCount)
            _buildCountCircle(),
        ],
      ),
    );
  }

  Widget _buildThumbnail(int index) {
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        // Небольшое покачивание с разными фазами для каждого кружочка
        final offset = 1.5 * math.sin((_floatingController.value * 2 * math.pi) + (index * 0.5));
        
        if (index >= _commercialPosts.length) {
          return Transform.translate(
            offset: Offset(0, offset),
            child: Container(
              margin: EdgeInsets.only(right: 4),
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17.5),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15.5),
                  child: Container(
                    color: Colors.orange.shade600,
                    child: Icon(
                      Icons.shopping_bag,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final post = _commercialPosts[index];
        final imageUrl = post['imageUrl'] as String?;

        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            margin: EdgeInsets.only(right: 4),
            child: GestureDetector(
              onTap: _navigateToCommercialPosts,
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17.5),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2 + offset),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15.5),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: ApiConfig.formatImageUrl(imageUrl),
                          width: 35,
                          height: 35,
                          fit: BoxFit.cover,
                          placeholder: (context, url) {
                            return Container(
                              color: Colors.orange.shade600,
                              child: Center(
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                              ),
                            );
                          },
                          errorWidget: (context, url, error) {
                            return Container(
                              color: Colors.orange.shade600,
                              child: Icon(
                                Icons.shopping_bag,
                                size: 18,
                                color: Colors.white,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.orange.shade600,
                          child: Icon(
                            Icons.shopping_bag,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCountCircle() {
    final remainingCount = _commercialPostsCount - 3;
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        // Покачивание с фазой для кружочка с количеством
        final offset = 1.5 * math.sin((_floatingController.value * 2 * math.pi) + (3 * 0.5));
        
        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            margin: EdgeInsets.only(left: 4),
            child: GestureDetector(
              onTap: _navigateToCommercialPosts,
              child: Container(
                width: 35,
                height: 35,
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(17.5),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 4,
                      offset: Offset(0, 2 + offset),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '+$remainingCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
