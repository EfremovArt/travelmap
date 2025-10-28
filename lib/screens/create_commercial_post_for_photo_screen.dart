import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../services/commercial_post_service.dart';
import '../utils/logger.dart';
import 'image_crop_screen.dart';

class CreateCommercialPostForPhotoScreen extends StatefulWidget {
  final int userId;
  final int photoId;

  const CreateCommercialPostForPhotoScreen({
    Key? key,
    required this.userId,
    required this.photoId,
  }) : super(key: key);

  @override
  State<CreateCommercialPostForPhotoScreen> createState() => _CreateCommercialPostForPhotoScreenState();
}

class _CreateCommercialPostForPhotoScreenState extends State<CreateCommercialPostForPhotoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _contactController = TextEditingController();
  
  String _selectedCurrency = 'USD';
  List<File> _selectedImages = [];
  File? _firstImageOriginal; // Original version of first image (before crop)
  bool _isLoading = false;

  final List<String> _currencies = ['USD', 'EUR', 'RUB', 'KZT'];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _contactController.dispose();
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

  Future<void> _pickImages() async {
    try {
      final ImagePicker picker = ImagePicker();
      final List<XFile> images = await picker.pickMultiImage();
      
      if (images.isNotEmpty) {
        // Показываем индикатор загрузки
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => Center(
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('Обработка фото...'),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        // Обрабатываем изображения: первое через crop, остальные без изменений
        List<File> processedImages = [];
        for (int i = 0; i < images.length; i++) {
          final xfile = images[i];
          
          // Только первое изображение проходит через crop
          if (i == 0) {
            final originalFile = File(xfile.path);
            final croppedFile = await _cropImage(originalFile);
            if (croppedFile != null) {
              processedImages.add(croppedFile);
              // Сохраняем оригинал для отправки на сервер
              _firstImageOriginal = originalFile;
            }
          } else {
            // Остальные изображения добавляем в исходном размере
            processedImages.add(File(xfile.path));
          }
        }

        // Закрываем индикатор загрузки
        if (mounted) {
          Navigator.of(context).pop();
        }

        if (processedImages.isNotEmpty) {
          setState(() {
            _selectedImages = processedImages;
          });
        }
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка выбора изображений: $e');
      
      // Закрываем индикатор если он открыт
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка выбора изображений'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _selectedImages.removeAt(index);
      // Если удалили первое фото, нужно сбросить оригинал
      if (index == 0) {
        _firstImageOriginal = null;
      }
    });
  }

  Future<void> _createPost() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final double? price = _priceController.text.isNotEmpty 
          ? double.tryParse(_priceController.text) 
          : null;

      Map<String, dynamic> result;

      if (_selectedImages.isNotEmpty) {
        // Создаем пост с изображениями
        result = await CommercialPostService.createCommercialPostForPhotoWithImages(
          userId: widget.userId,
          photoId: widget.photoId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty 
              ? _descriptionController.text.trim() 
              : null,
          images: _selectedImages,
          firstImageOriginal: _firstImageOriginal, // Передаем оригинал первого фото
          price: price,
          currency: _selectedCurrency,
          contactInfo: _contactController.text.trim().isNotEmpty 
              ? _contactController.text.trim() 
              : null,
        );
      } else {
        // Создаем пост без изображений
        final success = await CommercialPostService.createCommercialPostForPhoto(
          userId: widget.userId,
          photoId: widget.photoId,
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim().isNotEmpty 
              ? _descriptionController.text.trim() 
              : null,
          price: price,
          currency: _selectedCurrency,
          contactInfo: _contactController.text.trim().isNotEmpty 
              ? _contactController.text.trim() 
              : null,
        );
        
        result = {'success': success};
      }

      if (result['success'] == true) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Коммерческий пост для фото создан успешно!'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true); // Возвращаем true для обновления списка
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['error'] ?? 'Не удалось создать коммерческий пост'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка создания коммерческого поста для фото: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Создать предложение для фото',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
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
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.all(16),
          children: [
            // Информационный блок
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade600),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Создайте коммерческое предложение, связанное с этой фотографией',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            SizedBox(height: 24),

            // Заголовок
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Заголовок *',
                hintText: 'Например: Печать фото, Фотосессия',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Заголовок обязателен';
                }
                return null;
              },
              maxLength: 100,
            ),

            SizedBox(height: 16),

            // Описание
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Описание',
                hintText: 'Подробное описание вашего предложения',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 4,
              maxLength: 500,
            ),

            SizedBox(height: 16),

            // Цена и валюта
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _priceController,
                    decoration: InputDecoration(
                      labelText: 'Цена',
                      hintText: '0.00',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: Icon(Icons.attach_money),
                    ),
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    validator: (value) {
                      if (value != null && value.isNotEmpty) {
                        final price = double.tryParse(value);
                        if (price == null || price < 0) {
                          return 'Некорректная цена';
                        }
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCurrency,
                    decoration: InputDecoration(
                      labelText: 'Валюта',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: _currencies.map((currency) {
                      return DropdownMenuItem(
                        value: currency,
                        child: Text(currency),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCurrency = value!;
                      });
                    },
                  ),
                ),
              ],
            ),

            SizedBox(height: 16),

            // Контактная информация
            TextFormField(
              controller: _contactController,
              decoration: InputDecoration(
                labelText: 'Контактная информация',
                hintText: 'Телефон, email, ссылки',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: Icon(Icons.contact_phone),
              ),
              maxLines: 2,
              maxLength: 200,
            ),

            SizedBox(height: 24),

            // Изображения
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.photo_library, color: Colors.grey.shade600),
                      SizedBox(width: 8),
                      Text(
                        'Изображения предложения',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  // Кнопка добавления изображений
                  OutlinedButton.icon(
                    onPressed: _pickImages,
                    icon: Icon(Icons.add_photo_alternate),
                    label: Text('Добавить изображения'),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),

                  // Список выбранных изображений
                  if (_selectedImages.isNotEmpty) ...[
                    SizedBox(height: 16),
                    Text(
                      'Выбрано изображений: ${_selectedImages.length}',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _selectedImages.length,
                        itemBuilder: (context, index) {
                          return Container(
                            margin: EdgeInsets.only(right: 8),
                            child: Stack(
                              children: [
                                Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(8),
                                    image: DecorationImage(
                                      image: FileImage(_selectedImages[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  top: 4,
                                  right: 4,
                                  child: GestureDetector(
                                    onTap: () => _removeImage(index),
                                    child: Container(
                                      padding: EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
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
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            SizedBox(height: 32),

            // Кнопка создания
            ElevatedButton(
              onPressed: _isLoading ? null : _createPost,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade600,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isLoading
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        ),
                        SizedBox(width: 12),
                        Text('Создание...'),
                      ],
                    )
                  : Text(
                      'Создать коммерческий пост',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
