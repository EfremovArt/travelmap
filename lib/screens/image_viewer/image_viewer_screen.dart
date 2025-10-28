import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// Экран для просмотра изображений на весь экран с возможностью листать и масштабировать
class ImageViewerScreen extends StatefulWidget {
  final List<File> images;
  final int initialIndex;

  const ImageViewerScreen({
    Key? key,
    required this.images,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  _ImageViewerScreenState createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late PageController _pageController;
  late int _currentIndex;
  double _dragDistance = 0;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    
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
    _pageController.dispose();
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
        automaticallyImplyLeading: true,
        title: Text(
          '${_currentIndex + 1}/${widget.images.length}',
          style: TextStyle(
            color: Colors.white.withOpacity(opacity),
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: GestureDetector(
        onVerticalDragUpdate: _handleVerticalDragUpdate,
        onVerticalDragEnd: _handleVerticalDragEnd,
        child: Transform.translate(
          offset: Offset(0, _dragDistance),
          child: Stack(
            children: [
              // Основная галерея изображений
              PhotoViewGallery.builder(
            scrollPhysics: const BouncingScrollPhysics(),
            builder: (BuildContext context, int index) {
              return PhotoViewGalleryPageOptions(
                imageProvider: FileImage(widget.images[index]),
                initialScale: PhotoViewComputedScale.contained,
                minScale: PhotoViewComputedScale.contained,
                maxScale: PhotoViewComputedScale.contained,
                heroAttributes: PhotoViewHeroAttributes(tag: 'image_$index'),
              );
            },
            itemCount: widget.images.length,
            loadingBuilder: (context, event) => Center(
              child: CircularProgressIndicator(
                value: event == null ? 0 : event.cumulativeBytesLoaded / event.expectedTotalBytes!,
              ),
            ),
                pageController: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
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