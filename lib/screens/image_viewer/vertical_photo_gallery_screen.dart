import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import '../../models/post.dart';
import '../../utils/logger.dart';

/// Экран для вертикального просмотра фотографий поста
/// Фотографии листаются вертикально, при нажатии на фото оно увеличивается
class VerticalPhotoGalleryScreen extends StatefulWidget {
  final Post post;
  final int initialIndex;

  const VerticalPhotoGalleryScreen({
    Key? key,
    required this.post,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _VerticalPhotoGalleryScreenState createState() => _VerticalPhotoGalleryScreenState();
}

class _VerticalPhotoGalleryScreenState extends State<VerticalPhotoGalleryScreen> {
  late ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Используем оригинальные изображения для галереи, cropped для ленты
    final List<String> imagesToShow = widget.post.originalImageUrls.isNotEmpty
        ? widget.post.originalImageUrls
        : widget.post.imageUrls;
    
    final hasNetworkImages = imagesToShow.isNotEmpty;
    final imageCount = hasNetworkImages 
        ? imagesToShow.length 
        : widget.post.images.length;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: IconThemeData(color: Colors.white),
        title: Text(
          widget.post.title.isNotEmpty ? widget.post.title : 'Фотографии',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Gilroy',
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.only(top: 30),
        itemCount: imageCount,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(bottom: 30),
            child: GestureDetector(
                onTap: () => _openFullScreenPhoto(index),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: hasNetworkImages
                      ? CachedNetworkImage(
                          imageUrl: imagesToShow[index],
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Center(
                            child: CircularProgressIndicator(
                              color: Colors.white,
                            ),
                          ),
                          errorWidget: (context, url, error) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Не удалось загрузить изображение',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Gilroy',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Image.file(
                          widget.post.images[index],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) => Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image,
                                  color: Colors.white,
                                  size: 48,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Не удалось загрузить изображение',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Gilroy',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
          );
        },
      ),
    );
  }

  /// Открывает фотографию в полноэкранном режиме с возможностью увеличения
  void _openFullScreenPhoto(int index) {
    AppLogger.log('🔍 Открываем фото в полноэкранном режиме: индекс $index');
    
    // Используем оригинальные изображения для полноэкранного просмотра
    final List<String> imagesToShow = widget.post.originalImageUrls.isNotEmpty
        ? widget.post.originalImageUrls
        : widget.post.imageUrls;
    
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        pageBuilder: (context, animation, secondaryAnimation) => _FullScreenPhotoViewer(
          imageProvider: imagesToShow.isNotEmpty
              ? CachedNetworkImageProvider(imagesToShow[index]) as ImageProvider
              : FileImage(widget.post.images[index]),
          tag: 'photo_$index',
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
    );
  }
}

/// Полноэкранный просмотрщик фото с поддержкой свайпа вниз для закрытия
class _FullScreenPhotoViewer extends StatefulWidget {
  final ImageProvider imageProvider;
  final String tag;

  const _FullScreenPhotoViewer({
    required this.imageProvider,
    required this.tag,
  });

  @override
  State<_FullScreenPhotoViewer> createState() => _FullScreenPhotoViewerState();
}

class _FullScreenPhotoViewerState extends State<_FullScreenPhotoViewer> {
  double _dragDistance = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    // Разрешаем все ориентации для полноэкранного просмотра
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    // Возвращаем только портретную ориентацию при выходе
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    super.dispose();
  }

  void _handleVerticalDragUpdate(DragUpdateDetails details) {
    setState(() {
      _dragDistance += details.delta.dy;
      _isDragging = true;
      // Ограничиваем драг только вниз
      if (_dragDistance < 0) _dragDistance = 0;
    });
  }

  void _handleVerticalDragEnd(DragEndDetails details) {
    // Если перетащили больше чем на 100 пикселей - закрываем
    if (_dragDistance > 100) {
      Navigator.of(context).pop();
    } else {
      // Иначе возвращаем на место
      setState(() {
        _dragDistance = 0;
        _isDragging = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final opacity = (1.0 - (_dragDistance / 300)).clamp(0.0, 1.0);
    
    return Scaffold(
      backgroundColor: Colors.black.withOpacity(opacity),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: Colors.white.withOpacity(opacity)),
        elevation: 0,
      ),
      body: GestureDetector(
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: _handleVerticalDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragDistance),
          child: Center(
            child: PhotoView(
              imageProvider: widget.imageProvider,
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              initialScale: PhotoViewComputedScale.contained,
              heroAttributes: PhotoViewHeroAttributes(tag: widget.tag),
              backgroundDecoration: BoxDecoration(color: Colors.transparent),
              loadingBuilder: (context, event) => Center(
                child: CircularProgressIndicator(
                  color: Colors.white,
                  value: event == null 
                      ? null 
                      : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                ),
              ),
              errorBuilder: (context, error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 64,
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Не удалось загрузить изображение',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Gilroy',
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
