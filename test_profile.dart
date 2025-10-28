import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'lib/services/auth_service.dart';
import 'lib/services/profile_service.dart';

void main() {
  runApp(const TestProfileApp());
}

class TestProfileApp extends StatelessWidget {
  const TestProfileApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Тест Профиля',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TestProfileScreen(),
    );
  }
}

class TestProfileScreen extends StatefulWidget {
  const TestProfileScreen({Key? key}) : super(key: key);

  @override
  State<TestProfileScreen> createState() => _TestProfileScreenState();
}

class _TestProfileScreenState extends State<TestProfileScreen> {
  final ProfileService _profileService = ProfileService();
  final AuthService _authService = AuthService();
  final TextEditingController _birthdayController = TextEditingController();

  String _token = '';
  String _responseLog = '';
  DateTime? _selectedDate;
  File? _profileImage;
  String? _profileImageUrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  Future<void> _initializeTest() async {
    setState(() {
      _responseLog = 'Инициализация...\n';
      _isLoading = true;
    });

    try {
      // Инициализация сервиса авторизации
      await _authService.initialize();
      
      // Получение токена
      _token = await AuthService.getToken();
      _addToLog('Получен токен: ${_token.isNotEmpty ? "токен получен" : "токен отсутствует"}');
      
      // Проверка авторизации
      final authResult = await _authService.checkAuth();
      _addToLog('Результат проверки авторизации: $authResult');
      
      if (authResult['success'] == true && authResult['isAuthenticated'] == true) {
        final userData = authResult['userData'];
        _addToLog('Данные пользователя: $userData');
        
        if (userData != null && userData['birthday'] != null) {
          _addToLog('Дата рождения из профиля: ${userData['birthday']}');
          
          try {
            // Преобразуем из формата yyyy-MM-dd в MM/dd/yyyy
            final dateStr = userData['birthday'].toString();
            
            if (dateStr.contains('-')) {
              final parts = dateStr.split('-');
              if (parts.length == 3) {
                _birthdayController.text = "${parts[1]}/${parts[2]}/${parts[0]}";
                _selectedDate = DateTime.parse(dateStr);
              } else {
                _birthdayController.text = dateStr;
              }
            } else {
              _birthdayController.text = dateStr;
            }
            
            _addToLog('Преобразованная дата: ${_birthdayController.text}');
          } catch (e) {
            _addToLog('Ошибка при преобразовании даты: $e');
            _birthdayController.text = userData['birthday'].toString();
          }
        }
        
        _profileImageUrl = userData?['profileImageUrl'];
        _addToLog('URL изображения профиля: $_profileImageUrl');
      } else {
        _addToLog('⚠️ Пользователь не авторизован!');
      }
    } catch (e) {
      _addToLog('❌ Ошибка при инициализации: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _addToLog(String message) {
    setState(() {
      _responseLog += '$message\n';
    });
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthdayController.text = DateFormat('MM/dd/yyyy').format(picked);
        _addToLog('Выбрана дата: ${_birthdayController.text}');
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 800,
      );

      if (pickedImage != null) {
        _addToLog('Выбрано изображение: ${pickedImage.path}');
        
        setState(() {
          _profileImage = File(pickedImage.path);
        });
      }
    } catch (e) {
      _addToLog('❌ Ошибка при выборе изображения: $e');
    }
  }

  Future<void> _uploadImage() async {
    if (_profileImage == null) {
      _addToLog('⚠️ Изображение не выбрано!');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      _addToLog('Загрузка изображения...');
      
      final result = await _profileService.uploadProfileImage(_profileImage!);
      
      _addToLog('Результат загрузки: $result');
      
      if (result['success'] == true) {
        setState(() {
          _profileImageUrl = result['profileImageUrl'];
        });
        _addToLog('✅ Изображение загружено успешно');
      } else {
        _addToLog('⚠️ Ошибка загрузки: ${result['error']}');
      }
    } catch (e) {
      _addToLog('❌ Ошибка: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveProfile() async {
    setState(() {
      _isLoading = true;
    });

    try {
      _addToLog('Сохранение профиля...');
      _addToLog('Дата рождения: ${_birthdayController.text}');
      
      final result = await _profileService.updateProfile(
        firstName: 'Тестовое Имя',
        lastName: 'Тестовая Фамилия',
        birthday: _birthdayController.text.isNotEmpty ? _birthdayController.text : null,
      );
      
      _addToLog('Результат сохранения: $result');
      
      if (result['success'] == true) {
        _addToLog('✅ Профиль сохранен успешно');
      } else {
        _addToLog('⚠️ Ошибка сохранения: ${result['error']}');
      }
    } catch (e) {
      _addToLog('❌ Ошибка: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Тест Профиля'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _initializeTest,
          ),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Информация о токене
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Токен: ${_token.isNotEmpty ? "✅" : "❌"}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(_token.isNotEmpty ? _token.substring(0, _token.length > 20 ? 20 : _token.length) + '...' : 'Токен отсутствует'),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Изображение профиля
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Изображение профиля',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        
                        Center(
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              shape: BoxShape.circle,
                            ),
                            child: _profileImage != null
                              ? ClipOval(
                                  child: Image.file(
                                    _profileImage!,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              : _profileImageUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      _profileImageUrl!,
                                      fit: BoxFit.cover,
                                      loadingBuilder: (context, child, loadingProgress) {
                                        if (loadingProgress == null) return child;
                                        return Center(
                                          child: CircularProgressIndicator(
                                            value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / 
                                                  loadingProgress.expectedTotalBytes!
                                              : null,
                                          ),
                                        );
                                      },
                                      errorBuilder: (context, error, stackTrace) {
                                        _addToLog('❌ Ошибка загрузки изображения: $error');
                                        return const Icon(
                                          Icons.error_outline,
                                          size: 50,
                                          color: Colors.red,
                                        );
                                      },
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    size: 80,
                                    color: Colors.grey,
                                  ),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            ElevatedButton.icon(
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Выбрать'),
                              onPressed: _pickImage,
                            ),
                            ElevatedButton.icon(
                              icon: const Icon(Icons.upload_file),
                              label: const Text('Загрузить'),
                              onPressed: _profileImage != null ? _uploadImage : null,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Дата рождения
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Дата рождения',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        
                        TextField(
                          controller: _birthdayController,
                          readOnly: true,
                          onTap: _selectDate,
                          decoration: InputDecoration(
                            hintText: 'Дата рождения',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            suffixIcon: const Icon(Icons.calendar_month),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _saveProfile,
                            child: const Text('Сохранить профиль'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Лог ответов
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Лог операций',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        
                        Container(
                          height: 300,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: SingleChildScrollView(
                            child: Text(
                              _responseLog,
                              style: const TextStyle(
                                color: Colors.green,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }
} 