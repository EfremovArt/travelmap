import 'dart:io';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
// Добавлено: кэширование сетевых изображений
import 'package:cached_network_image/cached_network_image.dart';

/// Виджет для отображения коллажа из фотографий разных размеров
class PhotoGrid extends StatelessWidget {
  final List<String> imageUrls;
  final List<File> images;
  final Function(int) onImageTap;

  const PhotoGrid({
    Key? key,
    this.imageUrls = const [],
    this.images = const [],
    required this.onImageTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool hasUrls = imageUrls.isNotEmpty;
    final bool hasImages = images.isNotEmpty;
    final int totalImages = hasUrls ? imageUrls.length : images.length;

    if (totalImages == 0) {
      return const SizedBox();
    }

    // Убираем фиксированную высоту, чтобы фото определяло свою высоту пропорционально
    return _buildGridLayout(totalImages, hasUrls);
  }

  /// Построение разных типов сеток в зависимости от количества изображений
  Widget _buildGridLayout(int totalImages, bool hasUrls) {
    if (totalImages == 1) {
      // Для одного изображения - показываем на всю ширину
      return _buildSingleImage(0, hasUrls);
    } else {
      // Для 2+ изображений в превью показываем только первое изображение
      // Полистать остальные можно по нажатию, т.к. onImageTap(index) открывает вьювер
      return _buildSingleImage(0, hasUrls);
    }
  }

  /// Строит отдельное изображение для коллажа
  Widget _buildSingleImage(int index, bool hasUrls) {
    return GestureDetector(
      onTap: () => onImageTap(index),
      child: AspectRatio(
        aspectRatio: 1.0, // Квадратное соотношение сторон
        child: hasUrls
            ? _buildNetworkImage(index)
            : Image.file(
                images[index],
                fit: BoxFit.cover, // Заполняем весь контейнер
                width: double.infinity,
                height: double.infinity,
              ),
      ),
    );
  }

  /// Построение сетевого изображения с обработкой ошибок и индикатором загрузки
  Widget _buildNetworkImage(int index) {
    String photoUrl = imageUrls[index];

    // Более надежное форматирование URL
    if (!photoUrl.startsWith('http')) {
      // Если URL начинается с /travel/, убираем его, так как он будет в baseUrl
      if (photoUrl.startsWith('/travel/')) {
        photoUrl = photoUrl.replaceFirst('/travel/', '');
      } else if (photoUrl.startsWith('travel/')) {
        photoUrl = photoUrl.replaceFirst('travel/', '');
      } else if (photoUrl.startsWith('/')) {
        photoUrl = photoUrl.substring(1); // Убираем начальный слеш
      }

      // Формируем полный URL без дублирования /travel/
      if (photoUrl.startsWith('uploads/')) {
        photoUrl = '${ApiConfig.baseUrl}/$photoUrl';
      } else {
        photoUrl = '${ApiConfig.baseUrl}/uploads/$photoUrl';
      }
    }

    // Кэшируем изображения для экономии памяти
    return CachedNetworkImage(
      imageUrl: photoUrl,
      fit: BoxFit.cover, // Заполняем весь контейнер
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: 800, // Увеличиваем для лучшего качества
      memCacheHeight: 800,
      placeholder: (context, url) => Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(
            Icons.broken_image,
            size: 32,
            color: Colors.grey,
          ),
        ),
      ),
    );
  }

  /// Построение блока "Ещё N фото" для случаев, когда изображений больше пяти
  Widget _buildMoreImagesOverlay(int index, bool hasUrls, int moreCount) {
    return GestureDetector(
      onTap: () => onImageTap(index),
      child: AspectRatio(
        aspectRatio: 1.0, // Квадратное соотношение сторон
        child: Stack(
          fit: StackFit.expand,
          children: [
            hasUrls 
              ? _buildNetworkImage(index) 
              : Image.file(
                  images[index],
                  fit: BoxFit.cover, // Заполняем весь контейнер
                  width: double.infinity,
                  height: double.infinity,
                ),
            // Накладываем затемнение и текст с количеством оставшихся фото
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
              ),
              child: Center(
                child: Text(
                  '+$moreCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 