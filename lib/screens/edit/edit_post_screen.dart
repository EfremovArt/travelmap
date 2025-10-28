import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/location.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../upload/upload_location_screen.dart';
import '../../utils/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../image_crop_screen.dart';

class EditPostScreen extends StatefulWidget {
  final Post post;

  const EditPostScreen({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  State<EditPostScreen> createState() => _EditPostScreenState();
}

class _EditPostScreenState extends State<EditPostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isUpdating = false;
  List<File> _images = [];
  List<String> _imageUrls = [];
  GeoLocation _selectedLocation = GeoLocation(latitude: 0, longitude: 0);
  String _locationName = '';

  @override
  void initState() {
    super.initState();
    // Инициализируем значения из существующего поста
    _titleController.text = widget.post.title;
    _descriptionController.text = widget.post.description;
    _images = List<File>.from(widget.post.images);
    _imageUrls = List<String>.from(widget.post.imageUrls);
    _selectedLocation = widget.post.location;
    _locationName = widget.post.locationName;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updatePost() async {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
    });
    
    try {
      // Check that we have all required data
      if (_images.isEmpty && _imageUrls.isEmpty) {
        throw Exception('No images selected');
      }
      
      // Создаем обновленный пост, сохраняя оригинальный ID и user, и дату создания
      final updatedPost = Post(
        id: widget.post.id,
        images: _images,
        imageUrls: _imageUrls,
        location: _selectedLocation,
        locationName: _locationName,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        createdAt: widget.post.createdAt,
        user: widget.post.user,
      );
      
      AppLogger.log('Updating post with ${_images.length} new images and ${_imageUrls.length} existing images');
      
      // Update post
      final result = await PostService.updatePost(updatedPost);
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Post updated successfully!'))
        );
        
        // После успешного обновления получаем актуальные данные поста не по старому photoId,
        // который мог измениться из-за пересоздания записей фото, а по locationId
        Post updatedPostToReturn = widget.post;
        try {
          final String? locationId = await PostService.getLocationIdByPhotoId(widget.post.id);
          if (locationId != null) {
            final postsInLocation = await PostService.getPostsByLocationId(locationId);
            if (postsInLocation.isNotEmpty) {
              updatedPostToReturn = postsInLocation.first; // Первая фотография в локации — основной пост
            }
          } else {
            // Фоллбэк: обновим список постов пользователя и попробуем найти наиболее подходящий
            final updatedPosts = await PostService.getUserPosts(userId: widget.post.user);
            if (updatedPosts.isNotEmpty) {
              // Пытаемся найти по названию локации, иначе берём первый
              final candidate = updatedPosts.where((p) => p.locationName == _locationName);
              updatedPostToReturn = candidate.isNotEmpty ? candidate.first : updatedPosts.first;
            }
          }
        } catch (_) {}
        
        // Return to previous screen with updated post data
        Navigator.of(context).pop(updatedPostToReturn);
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to update post'),
            backgroundColor: Colors.red,
          )
        );
      }
    } catch (e) {
      AppLogger.log('Failed to update post: $e');
      
      // Handle errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update post: $e'),
            backgroundColor: Colors.red,
          )
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    }
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
      AppLogger.log('❌ Error cropping image: $e');
      return null;
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> pickedImages = await picker.pickMultiImage();
    
    if (pickedImages.isNotEmpty) {
      // Обрабатываем изображения: первое через crop только если нет существующих изображений
      List<File> processedImages = [];
      bool hasExistingImages = _images.isNotEmpty || _imageUrls.isNotEmpty;
      
      for (int i = 0; i < pickedImages.length; i++) {
        final pickedImage = pickedImages[i];
        
        // Только первое изображение проходит через crop, и только если это первое изображение поста
        if (!hasExistingImages && i == 0) {
          final croppedFile = await _cropImage(File(pickedImage.path));
          if (croppedFile != null) {
            processedImages.add(croppedFile);
          }
        } else {
          // Остальные изображения добавляем в исходном размере
          processedImages.add(File(pickedImage.path));
        }
      }
      
      if (processedImages.isNotEmpty) {
        setState(() {
          // Добавляем новые изображения к существующим
          _images.addAll(processedImages);
        });
      }
    }
  }

  // Метод для удаления конкретного изображения
  void _removeImage(int index) {
    setState(() {
      if (index < _images.length) {
        _images.removeAt(index);
      } else {
        _imageUrls.removeAt(index - _images.length);
      }
    });
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadLocationScreen(
          images: _images,
        ),
      ),
    );
    
    if (result is GeoLocation) {
      setState(() {
        _selectedLocation = result;
        _locationName = "Selected Location"; // Простое название, в реальном приложении здесь получали бы название по координатам
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Edit your post",
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Предпросмотр изображений с возможностью выбора новых
          Container(
            height: 120,
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                // Контейнер для выбора новых изображений
                GestureDetector(
                  onTap: _pickImages,
                  child: Container(
                    width: 100,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_photo_alternate, color: Colors.grey.shade600, size: 32),
                        const SizedBox(height: 4),
                        Text('Add More', style: TextStyle(color: Colors.grey.shade700, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
                
                // Существующие изображения
                ..._images.map((image) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          image,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(_images.indexOf(image)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
                
                // Существующие URL изображения
                ..._imageUrls.map((imageUrl) => Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          progressIndicatorBuilder: (context, url, progress) => Center(
                            child: CircularProgressIndicator(value: progress.progress),
                          ),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.error_outline,
                            size: 40,
                            color: Colors.red,
                          ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeImage(_images.length + _imageUrls.indexOf(imageUrl)),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ),
          
          // Поле для выбора локации
          GestureDetector(
            onTap: _pickLocation,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.place, color: Colors.red),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _locationName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Icon(Icons.edit, color: Colors.grey[600]),
                ],
              ),
            ),
          ),
          
          // Поле для ввода заголовка
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: TextField(
              controller: _titleController,
              maxLines: 1,
              decoration: InputDecoration(
                hintText: 'Edit title...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(16),
                prefixIcon: const Icon(Icons.title),
              ),
            ),
          ),
          
          // Поле для ввода описания
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _descriptionController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Write your impression here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),
          
          // Кнопка "Обновить"
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _updatePost,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isUpdating
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Update',
                      style: TextStyle(fontSize: 16),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 