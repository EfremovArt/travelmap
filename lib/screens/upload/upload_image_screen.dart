import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

import 'upload_location_screen.dart';
import '../image_crop_screen.dart';

class UploadImageScreen extends StatefulWidget {
  const UploadImageScreen({Key? key}) : super(key: key);

  @override
  State<UploadImageScreen> createState() => _UploadImageScreenState();
}

class _UploadImageScreenState extends State<UploadImageScreen> {
  final List<File> _selectedImages = [];
  File? _firstImageOriginal; // Сохраняем оригинал первого изображения
  bool _isLoading = false;

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
      return null;
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      setState(() {
        _isLoading = true;
      });

      final picker = ImagePicker();
      
      if (source == ImageSource.camera) {
        final pickedImage = await picker.pickImage(source: source);
        if (pickedImage != null) {
          // Сохраняем оригинал перед обрезкой (если это первое фото)
          final originalFile = File(pickedImage.path);
          if (_selectedImages.isEmpty) {
            // Копируем оригинал во временную директорию
            final tempDir = await getTemporaryDirectory();
            final originalCopy = File('${tempDir.path}/original_${DateTime.now().millisecondsSinceEpoch}.jpg');
            await originalFile.copy(originalCopy.path);
            _firstImageOriginal = originalCopy;
            print('📸 Camera ORIGINAL IMAGE SAVED (copy): ${originalCopy.path}');
          }
          
          // Открываем редактор масштабирования
          final croppedFile = await _cropImage(originalFile);
          if (croppedFile != null) {
            setState(() {
              _selectedImages.add(croppedFile);
            });
          } else {
            // Если пользователь отменил обрезку, сбрасываем оригинал
            if (_selectedImages.isEmpty) {
              _firstImageOriginal = null;
            }
          }
        }
      } else {
        final pickedImages = await picker.pickMultiImage();
        if (pickedImages.isNotEmpty) {
          // Обрабатываем изображения: первое через crop, остальные без изменений
          List<File> processedImages = [];
          
          for (int i = 0; i < pickedImages.length; i++) {
            final pickedImage = pickedImages[i];
            
            // Только первое изображение проходит через crop
            if (_selectedImages.isEmpty && i == 0) {
              final originalFile = File(pickedImage.path);
              
              // Копируем оригинал во временную директорию чтобы сохранить доступ к файлу
              final tempDir = await getTemporaryDirectory();
              final originalCopy = File('${tempDir.path}/original_${DateTime.now().millisecondsSinceEpoch}.jpg');
              await originalFile.copy(originalCopy.path);
              
              // Сохраняем копию оригинала первого изображения
              _firstImageOriginal = originalCopy;
              print('📸 ORIGINAL IMAGE SAVED (copy): ${originalCopy.path}');
              print('📸 File exists: ${await originalCopy.exists()}');
              
              final croppedFile = await _cropImage(originalFile);
              if (croppedFile != null) {
                processedImages.add(croppedFile);
                print('✂️ CROPPED IMAGE: ${croppedFile.path}');
              } else {
                // Если пользователь отменил обрезку, сбрасываем оригинал
                _firstImageOriginal = null;
                print('❌ Crop cancelled, original reset');
              }
            } else {
              // Остальные изображения добавляем в исходном размере
              processedImages.add(File(pickedImage.path));
            }
          }
          
          if (processedImages.isNotEmpty) {
            setState(() {
              _selectedImages.addAll(processedImages);
            });
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e'))
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _removeImage(int index) {
    setState(() {
      // Если удаляем первое изображение, сбрасываем оригинал
      if (index == 0) {
        _firstImageOriginal = null;
        print('🗑️ Removed first image, clearing _firstImageOriginal');
      }
      _selectedImages.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Заголовок
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: Text(
                'Share your impressions',
                style: GoogleFonts.poppins(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
            ),
            
            // Контейнер для изображений
            Expanded(
              child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _selectedImages.isEmpty
                  ? _buildEmptyImagesContainer()
                  : _buildSelectedImagesGrid(),
            ),
            
            // Кнопка Next
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _selectedImages.isNotEmpty
                    ? () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => UploadLocationScreen(
                              images: _selectedImages,
                              firstImageOriginal: _firstImageOriginal,
                            ),
                          ),
                        )
                    : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                    disabledBackgroundColor: Colors.grey.shade300,
                  ),
                  child: Text(
                    'Next',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyImagesContainer() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.grey.shade300,
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library,
              size: 64,
              color: Colors.blue.shade700,
            ),
            const SizedBox(height: 16),
            Text(
              'Upload Images',
              style: GoogleFonts.poppins(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.blue.shade800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Select photos to share',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Gallery'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.blue.shade700,
                    elevation: 0,
                    side: BorderSide(
                      color: Colors.blue.shade700,
                      width: 1,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _pickImage(ImageSource.camera),
                  icon: const Icon(Icons.camera_alt),
                  label: const Text('Camera'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    elevation: 0,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImagesGrid() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedImages.length} ${_selectedImages.length == 1 ? 'image' : 'images'} selected',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.add),
                label: const Text('Add More'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue.shade700,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: _selectedImages.length,
            itemBuilder: (context, index) {
              return Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedImages[index],
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
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
    );
  }
} 