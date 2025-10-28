import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../models/location.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';
import '../../utils/logger.dart';
import '../select_location_screen.dart';
import '../image_crop_screen.dart';

class UploadDescriptionScreen extends StatefulWidget {
  final int? userId;
  final List<File>? images;
  final GeoLocation? selectedLocation;
  final String? locationName;
  final int returnDepth;
  final File? firstImageOriginal;

  const UploadDescriptionScreen({
    Key? key,
    this.userId,
    this.images,
    this.selectedLocation,
    this.locationName,
    this.returnDepth = 3,
    this.firstImageOriginal,
  }) : super(key: key);

  @override
  State<UploadDescriptionScreen> createState() => _UploadDescriptionScreenState();
}

class _UploadDescriptionScreenState extends State<UploadDescriptionScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  bool _isPublishing = false;
  File? _selectedImage; // Keep for backward compatibility
  List<File> _selectedImages = [];
  File? _firstImageOriginal; // Оригинал первого изображения
  final ImagePicker _picker = ImagePicker();
  
  // Поля для локации
  GeoLocation? _selectedLocation;
  String _locationName = '';
  
  // User ID (получаем автоматически, если не передан)
  String _userId = '';

  @override
  void initState() {
    super.initState();
    // Инициализируем из переданных параметров, если они есть
    if (widget.images != null) {
      _selectedImages = List.from(widget.images!);
      if (_selectedImages.isNotEmpty) {
        _selectedImage = _selectedImages.first;
      }
    }
    if (widget.selectedLocation != null) {
      _selectedLocation = widget.selectedLocation;
    }
    if (widget.locationName != null) {
      _locationName = widget.locationName!;
    }
    if (widget.firstImageOriginal != null) {
      _firstImageOriginal = widget.firstImageOriginal;
    }
    // Загружаем ID пользователя
    _loadUserId();
  }
  
  Future<void> _loadUserId() async {
    if (widget.userId != null) {
      _userId = widget.userId.toString();
    } else {
      _userId = await UserService.getUserId();
      if (_userId.isEmpty) {
        _userId = await UserService.getEmail();
      }
    }
  }

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
          // Сохраняем оригинал ПЕРЕД обрезкой
          final originalFile = File(image.path);
          
          // Копируем оригинал во временную директорию
          final tempDir = await getTemporaryDirectory();
          final originalCopy = File('${tempDir.path}/original_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await originalFile.copy(originalCopy.path);
          _firstImageOriginal = originalCopy;
          print('📸 DESC SCREEN: Original saved: ${originalCopy.path}');
          
          // Первая фотография - открываем редактор для выбора квадратной области
          final croppedFile = await _cropImage(originalFile);
          
          if (croppedFile == null) {
            // Пользователь отменил обрезку, сбрасываем оригинал
            _firstImageOriginal = null;
            print('❌ DESC SCREEN: Crop cancelled');
            return;
          }
          imageFile = croppedFile;
          print('✂️ DESC SCREEN: Cropped image created');
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
              duration: const Duration(seconds: 1),
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.log('❌ Error selecting image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
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
        // Сохраняем оригинал ПЕРЕД обрезкой
        final originalFile = File(image.path);
        
        // Копируем оригинал во временную директорию
        final tempDir = await getTemporaryDirectory();
        final originalCopy = File('${tempDir.path}/original_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await originalFile.copy(originalCopy.path);
        _firstImageOriginal = originalCopy;
        print('📸 DESC SCREEN (camera): Original saved: ${originalCopy.path}');
        
        // Открываем редактор для масштабирования
        final croppedFile = await _cropImage(originalFile);
        
        if (croppedFile != null) {
          print('✂️ DESC SCREEN (camera): Cropped image created');
          setState(() {
            // Заменяем все фото одним новым обрезанным
            _selectedImages = [croppedFile];
            _selectedImage = _selectedImages.first;
          });
          
          // Показываем сообщение о замене
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
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
          const SnackBar(
            content: Text('Error selecting image'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _removeImage(int index) {
    setState(() {
      // Если удаляем первое фото, сбрасываем оригинал
      if (index == 0) {
        _firstImageOriginal = null;
        print('🗑️ DESC SCREEN: Removed first image, clearing original');
      }
      _selectedImages.removeAt(index);
      if (_selectedImages.isEmpty) {
        _selectedImage = null;
      } else {
        _selectedImage = _selectedImages.first;
      }
    });
  }

  void _removeAllImages() {
    setState(() {
      _selectedImages.clear();
      _selectedImage = null;
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

  Future<void> _publishPost() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isPublishing) return;

    // Проверяем обязательные поля
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one photo'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a location'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    setState(() {
      _isPublishing = true;
    });
    
    try {
      // Используем _userId, который был загружен в initState
      final userId = _userId.isNotEmpty ? _userId : 'current_user';
      
      AppLogger.log('📝 Creating new post with user ID: $userId');
      
      // Create new post
      final post = Post(
        id: const Uuid().v4(),
        images: _selectedImages,
        location: _selectedLocation!,
        locationName: _locationName.isNotEmpty ? _locationName : 'Selected Location',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        createdAt: DateTime.now(),
        user: userId,
      );
      
      print('🔍 UPLOAD DEBUG: _firstImageOriginal is ${_firstImageOriginal != null ? "NOT NULL" : "NULL"}');
      if (_firstImageOriginal != null) {
        print('🔍 Original path: ${_firstImageOriginal!.path}');
        print('🔍 File exists: ${await _firstImageOriginal!.exists()}');
      }
      
      // Save post (передаём оригинал первого изображения)
      final result = await PostService.savePost(post, firstImageOriginal: _firstImageOriginal);
      
      if (!mounted) return;
      
      if (result['success'] == true) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message'] ?? 'Post published successfully!'),
            backgroundColor: Colors.green,
          )
        );
        
        // Get result for return (location)
        final locationResult = _selectedLocation;
        
        AppLogger.log('Publication completed, returning location: ${locationResult!.latitude}, ${locationResult.longitude}');
        
        // Return result
        Navigator.of(context).pop(locationResult);
      } else {
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['error'] ?? 'Failed to publish post'),
            backgroundColor: Colors.red,
          )
        );
      }
    } catch (e) {
      AppLogger.log('Failed to publish post: $e');
      
      // Handle errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish post: $e'),
            backgroundColor: Colors.red,
          )
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
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
          'Create Post',
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
                      'Share Your Journey',
                      style: GoogleFonts.poppins(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Tell the world about your experience',
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
                  padding: const EdgeInsets.symmetric(horizontal: 24),
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
                            hintText: 'Give your post a title',
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
                            hintText: 'Write your impression here (optional)',
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
                      
                      const SizedBox(height: 40),
                    ],
                  ),
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
                    onPressed: _isPublishing ? null : _publishPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue.shade700,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: _isPublishing
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Publish Post',
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
                    'At least one photo required',
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
                              : 'Tap to select location for your post',
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
