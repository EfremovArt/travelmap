import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/location.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../upload/upload_location_screen.dart';

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
  final TextEditingController _descriptionController = TextEditingController();
  bool _isUpdating = false;
  List<File> _images = [];
  GeoLocation _selectedLocation = GeoLocation(latitude: 0, longitude: 0);
  String _locationName = '';

  @override
  void initState() {
    super.initState();
    // Инициализируем значения из существующего поста
    _descriptionController.text = widget.post.description;
    _images = List<File>.from(widget.post.images);
    _selectedLocation = widget.post.location;
    _locationName = widget.post.locationName;
  }

  @override
  void dispose() {
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
      if (_images.isEmpty) {
        throw Exception('No images selected');
      }
      
      // Создаем обновленный пост, сохраняя оригинальный ID и user, и дату создания
      final updatedPost = Post(
        id: widget.post.id,
        images: _images,
        location: _selectedLocation,
        locationName: _locationName,
        description: _descriptionController.text.trim(),
        createdAt: widget.post.createdAt,
        user: widget.post.user,
      );
      
      // Update post
      await PostService.updatePost(updatedPost);
      
      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post updated successfully!'))
      );
      
      // Return to previous screen
      Navigator.of(context).pop(true); // Возвращаем true для обновления UI
    } catch (e) {
      print('Failed to update post: $e');
      
      // Handle errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update post: $e'))
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

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> pickedImages = await picker.pickMultiImage();
    
    if (pickedImages.isNotEmpty) {
      setState(() {
        // Добавляем новые изображения к существующим, а не заменяем их
        _images.addAll(pickedImages.map((xFile) => File(xFile.path)).toList());
      });
    }
  }

  // Метод для удаления конкретного изображения
  void _removeImage(int index) {
    setState(() {
      _images.removeAt(index);
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
            child: Row(
              children: [
                // Контейнер для выбора новых изображений
                Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: GestureDetector(
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
                ),
                
                // Существующие изображения
                Expanded(
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          Container(
                            width: 100,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              image: DecorationImage(
                                image: FileImage(_images[index]),
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                          // Кнопка удаления изображения
                          Positioned(
                            top: 4,
                            right: 12,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
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
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          
          // Отображение выбранной локации с возможностью изменения
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