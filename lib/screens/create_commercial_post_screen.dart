import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/commercial_post.dart';
import '../services/commercial_post_service.dart';
import '../services/album_service.dart';
import '../utils/logger.dart';
import '../models/location.dart';
import '../screens/select_location_screen.dart';
import '../screens/image_crop_screen.dart';

class CreateCommercialPostScreen extends StatefulWidget {
  final int userId;
  final int? albumId; // Optional - если передан, пост будет создан в альбоме

  const CreateCommercialPostScreen({
    Key? key,
    required this.userId,
    this.albumId,
  }) : super(key: key);

  @override
  State<CreateCommercialPostScreen> createState() => _CreateCommercialPostScreenState();
}

class _CreateCommercialPostScreenState extends State<CreateCommercialPostScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  bool _isLoading = false;
  File? _selectedImage; // Keep for backward compatibility
  List<File> _selectedImages = []; // Multiple images support (cropped versions)
  File? _firstImageOriginal; // Original version of first image (before crop)
  final ImagePicker _picker = ImagePicker();
  
  // Поля для локации
  GeoLocation? _selectedLocation;
  String _locationName = '';


  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
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

  Future<void> _pickMultipleImages() async {
    try {
      // В старых версиях image_picker нет множественного выбора
      // Поэтому делаем альтернативный подход - позволяем добавлять по одному
      
      // Для первой фотографии загружаем в исходном размере (для качественной обрезки)
      // Для остальных используем сжатие
      final XFile? image;
      if (_selectedImages.isEmpty) {
        // Первая фотография - исходный размер
        image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 100, // Максимальное качество
          // Без maxWidth и maxHeight - исходный размер
        );
      } else {
        // Последующие фотографии - со сжатием
        image = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 80,
          maxWidth: 1024,
          maxHeight: 1024,
        );
      }
      
      if (image != null) {
        File imageFile;
        
        // Обрезаем только первую фотографию
        if (_selectedImages.isEmpty) {
          // Первая фотография - сохраняем оригинал и создаем обрезанную версию
          final originalFile = File(image.path);
          
          // Открываем редактор для выбора квадратной области
          final croppedFile = await _cropImage(originalFile);
          
          if (croppedFile == null) {
            // Пользователь отменил обрезку
            return;
          }
          
          // Сохраняем оригинал для отправки на сервер
          _firstImageOriginal = originalFile;
          imageFile = croppedFile;
        } else {
          // Последующие фотографии добавляем в исходном размере
          imageFile = File(image.path);
        }
        
        setState(() {
          // Добавляем фото к существующему списку
          _selectedImages.add(imageFile);
          // Ограничиваем до 10 фото
          if (_selectedImages.length > 10) {
            _selectedImages.removeLast();
          }
          // Keep first image for backward compatibility
          if (_selectedImage == null && _selectedImages.isNotEmpty) {
            _selectedImage = _selectedImages.first;
          }
        });
        
        // Показываем сообщение о добавлении фото
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Photo added (${_selectedImages.length}/10)'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.log('❌ Error selecting image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickSingleImage() async {
    try {
      // Загружаем в исходном размере для качественной обрезки
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 100, // Максимальное качество
        // Без maxWidth и maxHeight - исходный размер
      );
      
      if (image != null) {
        final originalFile = File(image.path);
        
        // Открываем редактор для масштабирования
        final croppedFile = await _cropImage(originalFile);
        
        if (croppedFile != null) {
          setState(() {
            // Заменяем все фото одним новым обрезанным
            _selectedImages = [croppedFile];
            _selectedImage = _selectedImages.first;
            // Сохраняем оригинал для отправки на сервер
            _firstImageOriginal = originalFile;
          });
          
          // Показываем сообщение о замене
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Single photo selected'),
                backgroundColor: Colors.blue,
                duration: Duration(seconds: 1),
              ),
            );
          }
        }
      }
    } catch (e) {
      AppLogger.log('❌ Error selecting image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      _selectedImages.removeAt(index);
      if (_selectedImages.isEmpty) {
        _selectedImage = null;
        _firstImageOriginal = null;
      } else {
        _selectedImage = _selectedImages.first;
        // Если удалили первое фото, нужно сбросить оригинал
        if (index == 0) {
          _firstImageOriginal = null;
        }
      }
    });
  }

  void _removeAllImages() {
    setState(() {
      _selectedImages.clear();
      _selectedImage = null;
      _firstImageOriginal = null;
    });
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const SelectLocationScreen(),
      ),
    );
    
    if (result is Map<String, dynamic>) {
      final location = result['location'] as GeoLocation?;
      final locationName = result['locationName'] as String?;
      
      if (location != null) {
        setState(() {
          _selectedLocation = location;
          _locationName = locationName ?? "Selected Location";
        });
      }
    }
  }

  Widget _buildInputSection({required String label, required Widget child}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
        child,
        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic> result;
      
      if (widget.albumId != null) {
        // Создаем коммерческий пост для конкретного альбома
        result = await CommercialPostService.createCommercialPostWithImages(
          userId: widget.userId,
          albumId: widget.albumId!,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          images: _selectedImages.isNotEmpty ? _selectedImages : null,
          firstImageOriginal: _firstImageOriginal, // Передаем оригинал первого фото
          latitude: _selectedLocation?.latitude,
          longitude: _selectedLocation?.longitude,
          locationName: _locationName.isNotEmpty ? _locationName : null,
        );
      } else {
        // Создаем standalone коммерческий пост
        result = await CommercialPostService.createStandaloneCommercialPost(
          userId: widget.userId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isEmpty 
              ? null 
              : _descriptionController.text.trim(),
          images: _selectedImages.isNotEmpty ? _selectedImages : null,
          firstImageOriginal: _firstImageOriginal, // Передаем оригинал первого фото
          latitude: _selectedLocation?.latitude,
          longitude: _selectedLocation?.longitude,
          locationName: _locationName.isNotEmpty ? _locationName : null,
        );
      }

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Commercial post created successfully! ${result['images_count'] ?? 0} images uploaded'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating post: ${result['error'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.log('❌ Error creating commercial post: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAFAFA),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Create Commercial Post',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Заголовок
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.albumId != null ? 'Add to Album' : 'Add Commercial Post',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.albumId != null 
                          ? 'Create a commercial post for this album'
                          : 'Create a post to promote your business',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
              // Выбор фото
              _buildPhotoSection(),

              // Заголовок
              _buildInputSection(
                label: 'Title *',
                child: TextFormField(
                  controller: _titleController,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Enter your business title',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade400,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Title is required';
                    }
                    if (value.trim().length < 3) {
                      return 'Title must be at least 3 characters';
                    }
                    return null;
                  },
                ),
              ),

              // Описание
              _buildInputSection(
                label: 'Description',
                child: TextFormField(
                  controller: _descriptionController,
                  maxLines: 4,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Describe your business (optional)',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade400,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.grey.shade200),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: Colors.blue.shade600, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(20),
                  ),
                ),
              ),

              // Секция выбора локации
              _buildLocationSection(),

              // Убираю поля цены и валюты
              
              const SizedBox(height: 40),
            ]),
                ),
              ),
              
              // Кнопка создания (фиксированная внизу)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _createPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isLoading
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            widget.albumId != null 
                                ? 'Add to Album' 
                                : 'Create Commercial Post',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhotoSection() {
    return _buildInputSection(
      label: 'Photos (${_selectedImages.length}/10)',
      child: Column(
        children: [
              // Информационный блок
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.grey.shade600, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'First photo will be cropped to square • Other photos keep original size',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 12),

              // Кнопки выбора фото
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickSingleImage,
                      icon: const Icon(Icons.photo_camera_outlined, size: 20),
                      label: Text(
                        'Single Photo',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade50,
                        foregroundColor: Colors.blue.shade700,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.blue.shade200),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _pickMultipleImages,
                      icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
                      label: Text(
                        'Add Photo',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade50,
                        foregroundColor: Colors.green.shade700,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(color: Colors.green.shade200),
                        ),
                      ),
                    ),
                  ),
                ],
              ),

          if (_selectedImages.isEmpty) ...[
            const SizedBox(height: 16),
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.grey.shade200,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.photo_outlined,
                    size: 32,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No photos selected',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Photos are optional',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            const SizedBox(height: 16),
            // Сетка выбранных изображений
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${_selectedImages.length} photo${_selectedImages.length > 1 ? 's' : ''} selected',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: _removeAllImages,
                        child: Text(
                          'Remove All',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: _selectedImages.length,
                    itemBuilder: (context, index) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              _selectedImages[index],
                              width: double.infinity,
                              height: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () => _removeImage(index),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.close,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ),
                          if (index == 0)
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade600,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'Main',
                                  style: GoogleFonts.poppins(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return _buildInputSection(
      label: 'Location',
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _pickLocation,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _selectedLocation != null ? Colors.green.shade50 : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _selectedLocation != null ? Icons.location_on : Icons.add_location_outlined,
                      color: _selectedLocation != null ? Colors.green.shade600 : Colors.grey.shade500,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedLocation != null ? 'Location Selected' : 'Add Location',
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: _selectedLocation != null ? Colors.green.shade700 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _selectedLocation != null 
                              ? (_locationName.isNotEmpty ? _locationName : 'Custom location')
                              : 'Tap to select location for your commercial post',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        if (_selectedLocation != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Lat: ${_selectedLocation!.latitude.toStringAsFixed(4)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(4)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    color: Colors.grey.shade400,
                    size: 16,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }


}
