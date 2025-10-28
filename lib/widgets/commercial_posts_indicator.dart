import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/commercial_post_service.dart';
import '../screens/commercial_posts_screen.dart';
import '../utils/logger.dart';
import '../config/api_config.dart';
import 'dart:async';

class CommercialPostsIndicator extends StatefulWidget {
  final int albumId;
  final String albumTitle;
  final Widget child;
  final int? currentUserId;

  const CommercialPostsIndicator({
    Key? key,
    required this.albumId,
    required this.albumTitle,
    required this.child,
    this.currentUserId,
  }) : super(key: key);

  @override
  State<CommercialPostsIndicator> createState() => _CommercialPostsIndicatorState();
}

class _CommercialPostsIndicatorState extends State<CommercialPostsIndicator> 
    with TickerProviderStateMixin {
  int _commercialPostsCount = 0;
  bool _isLoading = true;
  List<Map<String, dynamic>> _commercialPosts = [];
  
  late AnimationController _floatingController;
  StreamSubscription<int>? _albumChangesSub;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      duration: Duration(seconds: 2),
      vsync: this,
    )..repeat();
    _loadCommercialPostsCount();

    // Подписываемся на изменения коммерческих постов по альбомам
    _albumChangesSub = CommercialPostService.albumPostsChangedStream.listen((albumId) {
      if (!mounted) return;
      if (albumId == widget.albumId) {
        _loadCommercialPostsCount();
      }
    });
  }
  
  @override
  void dispose() {
    _floatingController.dispose();
    _albumChangesSub?.cancel();
    super.dispose();
  }

  Future<void> _loadCommercialPostsCount() async {
    try {
      // Загружаем полный список постов для получения изображений
      final posts = await CommercialPostService.getCommercialPostsForAlbum(widget.albumId);
      
      if (mounted) {
        setState(() {
          _commercialPostsCount = posts.length;
          _commercialPosts = posts.map((post) => {
            'id': post.id,
            'imageUrl': post.firstImageUrl, // Используем firstImageUrl который корректно работает с новыми постами
            'title': post.title,
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка загрузки коммерческих постов для альбома ${widget.albumId}: $e');
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
            builder: (context) => CommercialPostsScreen(
              albumId: widget.albumId,
              albumTitle: widget.albumTitle,
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
        
        // Убираю отладочные индикаторы
        
        // Плавающие миниатюры коммерческих постов внизу с анимацией
        if (!_isLoading && _commercialPostsCount > 0)
          Positioned(
            bottom: 10, // Немного поднимаю от края
            left: 12, // Увеличиваю левый отступ
            child: AnimatedOpacity(
              opacity: _isLoading ? 0.0 : 1.0,
              duration: Duration(milliseconds: 300),
              child: AnimatedSlide(
                offset: _isLoading ? Offset(0, 0.2) : Offset.zero,
                duration: Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
                child: _buildFloatingThumbnails(),
              ),
            ),
          ),
          
        // Убираю отладочную информацию
      ],
    );
  }

  Widget _buildFloatingThumbnails() {
    // Показываем максимум 5 миниатюр + 1 кружок с количеством (увеличиваю до 5)
    const maxThumbnails = 5;
    final showCount = _commercialPostsCount > maxThumbnails;
    final thumbnailCount = showCount ? maxThumbnails : _commercialPostsCount;
    
    return Container(
      height: 40, // Увеличиваю высоту
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
        final offset = 2.0 * math.sin((_floatingController.value * 2 * math.pi) + (index * 0.5));
        
        if (index >= _commercialPosts.length) {
          return Transform.translate(
            offset: Offset(0, offset),
            child: Container(
              margin: EdgeInsets.only(right: 6), // Увеличиваю отступ
              child: Container(
                width: 40, // Увеличиваю размер
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white,
                    width: 2.5, // Делаю границу толще
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4), // Увеличиваю тень
                      blurRadius: 6,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17.5),
                  child: Container(
                    color: Colors.orange.shade600,
                    child: Icon(
                      Icons.shopping_bag,
                      size: 20, // Увеличиваю размер иконки
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
            margin: EdgeInsets.only(right: 6), // Увеличиваю отступ
            child: GestureDetector(
              onTap: _navigateToCommercialPosts,
              child: Container(
                width: 40, // Увеличиваю размер
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white,
                    width: 2.5, // Делаю границу толще
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4), // Увеличиваю тень
                      blurRadius: 6,
                      offset: Offset(0, 3 + offset), // Добавляю смещение к тени
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(17.5),
                  child: imageUrl != null && imageUrl.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: ApiConfig.formatImageUrl(imageUrl),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          placeholder: (context, url) {
                            return Container(
                              color: Colors.orange.shade600,
                              child: Center(
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
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
                                size: 20,
                                color: Colors.white,
                              ),
                            );
                          },
                        )
                      : Container(
                          color: Colors.orange.shade600,
                          child: Icon(
                            Icons.shopping_bag,
                            size: 20, // Увеличиваю размер иконки
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
    final remainingCount = _commercialPostsCount - 5; // Обновляю для 5 миниатюр
    return AnimatedBuilder(
      animation: _floatingController,
      builder: (context, child) {
        // Покачивание с фазой для кружочка с количеством
        final offset = 2.0 * math.sin((_floatingController.value * 2 * math.pi) + (5 * 0.5));
        
        return Transform.translate(
          offset: Offset(0, offset),
          child: Container(
            margin: EdgeInsets.only(left: 6), // Увеличиваю отступ
            child: GestureDetector(
              onTap: _navigateToCommercialPosts,
              child: Container(
                width: 40, // Увеличиваю размер
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.orange.shade600,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white,
                    width: 2.5, // Делаю границу толще
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.4), // Увеличиваю тень
                      blurRadius: 6,
                      offset: Offset(0, 3 + offset), // Добавляю смещение к тени
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    '+$remainingCount',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12, // Увеличиваю размер шрифта
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
