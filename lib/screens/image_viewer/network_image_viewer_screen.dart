import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:travelmap/models/post.dart';

class NetworkImageViewerScreen extends StatefulWidget {
  final List<String> imagesToShow;
  final int initialIndex;
  final Post? parentPost; // необязательный, для совместимости с вызовами
  const NetworkImageViewerScreen({super.key, required this.imagesToShow, this.initialIndex = 0, this.parentPost});

  @override
  State<NetworkImageViewerScreen> createState() => _NetworkImageViewerScreenState();
}

class _NetworkImageViewerScreenState extends State<NetworkImageViewerScreen> {
  late final PageController _photoController;
  int _currentPhotoIndex = 0;
  double _dragDistance = 0;
  bool _isDragging = false;

  List<String> get imagesToShow => widget.imagesToShow;

  @override
  void initState() {
    super.initState();
    _currentPhotoIndex = widget.initialIndex;
    _photoController = PageController(initialPage: widget.initialIndex);
    
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
    _photoController.dispose();
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
        title: Text(
          '${_currentPhotoIndex + 1}/${imagesToShow.length}',
          style: TextStyle(color: Colors.white.withOpacity(opacity)),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.white.withOpacity(opacity)),
        elevation: 0,
      ),
      body: GestureDetector(
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: _handleVerticalDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragDistance),
          child: Stack(
            children: [
              PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: CachedNetworkImageProvider(
                  imagesToShow[index],
                ),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.contained,
                heroAttributes: PhotoViewHeroAttributes(tag: 'image_$index'),
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.black,
                    child: const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.broken_image, color: Colors.white, size: 64),
                          SizedBox(height: 16),
                          Text(
                            'Не удалось загрузить изображение',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
                itemCount: imagesToShow.length,
                loadingBuilder: (context, event) => Center(
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    value: event == null ? 0 : event.cumulativeBytesLoaded / (event.expectedTotalBytes ?? 1),
                  ),
                ),
                pageController: _photoController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPhotoIndex = index;
                  });
                },
                backgroundDecoration: BoxDecoration(color: Colors.transparent),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 