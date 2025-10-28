import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../models/commercial_post.dart';
import '../services/commercial_post_service.dart';
import '../utils/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../config/api_config.dart';

class EditCommercialPostScreen extends StatefulWidget {
  final CommercialPost post;

  const EditCommercialPostScreen({
    Key? key,
    required this.post,
  }) : super(key: key);

  @override
  State<EditCommercialPostScreen> createState() => _EditCommercialPostScreenState();
}

class _EditCommercialPostScreenState extends State<EditCommercialPostScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isUpdating = false;
  List<File> _newImages = [];
  List<String> _existingImageUrls = [];

  @override
  void initState() {
    super.initState();
    // Инициализируем значения из существующего коммерческого поста
    _titleController.text = widget.post.title;
    _descriptionController.text = widget.post.description ?? '';
    
    // Инициализируем существующие изображения
    if (widget.post.hasImages) {
      _existingImageUrls = List<String>.from(widget.post.imageUrls);
    } else if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty) {
      _existingImageUrls = [widget.post.imageUrl!];
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _updateCommercialPost() async {
    if (_isUpdating) return;
    
    setState(() {
      _isUpdating = true;
    });
    
    try {
      // Проверяем что есть изображения
      if (_newImages.isEmpty && _existingImageUrls.isEmpty) {
        throw Exception('No images selected');
      }
      
      // Проверяем что есть заголовок
      if (_titleController.text.trim().isEmpty) {
        throw Exception('Title is required');
      }
      
      AppLogger.log('Updating commercial post with ${_newImages.length} new images and ${_existingImageUrls.length} existing images');
      
      // Обновляем коммерческий пост
      final result = await CommercialPostService.updateCommercialPost(
        postId: widget.post.id,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        newImages: _newImages,
        existingImageUrls: _existingImageUrls,
      );
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        // Показываем сообщение об успехе
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Commercial post updated successfully!'))
        );
        
        // Возвращаемся на предыдущий экран
        Navigator.of(context).pop(true);
      } else {
        // Показываем сообщение об ошибке
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to update commercial post'),
            backgroundColor: Colors.red,
          )
        );
      }
    } catch (e) {
      AppLogger.log('Failed to update commercial post: $e');
      
      // Обрабатываем ошибки
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update commercial post: $e'),
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

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> pickedImages = await picker.pickMultiImage();
    
    if (pickedImages.isNotEmpty) {
      setState(() {
        // Добавляем новые изображения к существующим
        _newImages.addAll(pickedImages.map((xFile) => File(xFile.path)).toList());
      });
    }
  }

  // Метод для удаления изображения
  void _removeImage(int index) {
    setState(() {
      if (index < _existingImageUrls.length) {
        // Удаляем существующее изображение
        _existingImageUrls.removeAt(index);
      } else {
        // Удаляем новое изображение
        _newImages.removeAt(index - _existingImageUrls.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Edit Commercial Post",
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: Colors.black87),
          onPressed: () => Navigator.of(context).pop(),
        ),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Container(
            height: 1,
            color: Colors.grey.shade200,
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Предпросмотр изображений
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
                ..._existingImageUrls.asMap().entries.map((entry) {
                  final index = entry.key;
                  final imageUrl = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: CachedNetworkImage(
                              imageUrl: ApiConfig.formatImageUrl(imageUrl),
                              fit: BoxFit.cover,
                              width: 100,
                              height: 120,
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
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
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
                  );
                }),
                
                // Новые изображения
                ..._newImages.asMap().entries.map((entry) {
                  final index = entry.key + _existingImageUrls.length;
                  final image = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0),
                    child: Stack(
                      children: [
                        Container(
                          width: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              image,
                              fit: BoxFit.cover,
                              width: 100,
                              height: 120,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 4,
                          right: 4,
                          child: GestureDetector(
                            onTap: () => _removeImage(index),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.red,
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
                  );
                }),
              ],
            ),
          ),
          
          // Поля ввода
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Поле заголовка
                  TextField(
                    controller: _titleController,
                    decoration: InputDecoration(
                      labelText: 'Title *',
                      hintText: 'Enter commercial post title...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 1,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Поле описания
                  TextField(
                    controller: _descriptionController,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: 'Enter description...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 3,
                  ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          // Кнопка "Обновить"
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isUpdating ? null : _updateCommercialPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade600,
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
                      'Update Commercial Post',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
