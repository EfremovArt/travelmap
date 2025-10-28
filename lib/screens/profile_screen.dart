import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/social_service.dart';
import '../utils/logger.dart';
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  final AuthService _authService = AuthService();
  final ProfileService _profileService = ProfileService();
  final SocialService _socialService = SocialService();

  File? _profileImage;
  String? _profileImageUrl; // Для изображения из Google-аккаунта
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isGoogleAccount = false;
  
  // Данные о социальных связях
  int _followersCount = 0;
  int _followingCount = 0;
  int _favoritesCount = 0;
  bool _loadingSocialData = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadSocialData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  // Load user data from SharedPreferences and API
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Проверяем данные авторизации через API
      final authResult = await _authService.checkAuth();
      
      AppLogger.log('🔍 Результат проверки авторизации: $authResult');
      
      if (authResult['success'] == true && authResult['isAuthenticated'] == true) {
        final userData = authResult['userData'];
        
        setState(() {
          _firstNameController.text = userData['firstName'] ?? '';
          _lastNameController.text = userData['lastName'] ?? '';
          _emailController.text = userData['email'] ?? '';
          
          // Process profile image URL - ensure it has base URL if it's a relative path
          String? profileImageUrl = userData['profileImageUrl'];
          if (profileImageUrl != null && profileImageUrl.isNotEmpty) {
            AppLogger.log('🖼️ Загружаем URL изображения профиля: "$profileImageUrl"');
            
            if (profileImageUrl.startsWith('/')) {
              // It's a relative URL, add the base URL
              profileImageUrl = 'https://bearded-fox.ru${profileImageUrl}';
              AppLogger.log('📸 Нормализованный URL изображения: $profileImageUrl');
            } else if (!profileImageUrl.startsWith('http://') && !profileImageUrl.startsWith('https://')) {
              // Если URL не содержит протокол и не начинается с /, добавляем базовый URL
              profileImageUrl = 'https://bearded-fox.ru/$profileImageUrl';
              AppLogger.log('📸 Добавлен базовый URL к изображению: $profileImageUrl');
            }
            
            // Проверяем, что URL действительно имеет смысл
            if (Uri.tryParse(profileImageUrl)?.hasScheme == true) {
              _profileImageUrl = profileImageUrl;
              AppLogger.log('✅ Установлен URL изображения профиля: $_profileImageUrl');
            } else {
              AppLogger.log('⚠️ Некорректный URL изображения профиля: $profileImageUrl');
              _profileImageUrl = null;
            }
          } else {
            AppLogger.log('⚠️ Пустой URL изображения профиля');
            _profileImageUrl = null;
          }
          
          // Обрабатываем дату рождения, если она есть
          if (userData['birthday'] != null && userData['birthday'].toString().isNotEmpty) {
            try {
              // Преобразуем из формата yyyy-MM-dd в MM/dd/yyyy
              final dateStr = userData['birthday'].toString();
              AppLogger.log('📅 Получена дата рождения: $dateStr');
              
              if (dateStr.contains('-')) {
                final parts = dateStr.split('-');
                if (parts.length == 3) {
                  // Формат сервера: yyyy-MM-dd -> MM/dd/yyyy
                  _birthdayController.text = "${parts[1]}/${parts[2]}/${parts[0]}";
                  _selectedDate = DateTime.parse(dateStr);
                } else {
                  _birthdayController.text = dateStr;
                }
              } else {
                _birthdayController.text = dateStr;
              }
              
              AppLogger.log('📅 Дата в контроллере: ${_birthdayController.text}');
            } catch (dateError) {
              AppLogger.log('⚠️ Ошибка при форматировании даты рождения: $dateError');
              _birthdayController.text = userData['birthday'].toString();
            }
          } else {
            AppLogger.log('📅 Дата рождения не указана в данных пользователя');
            _birthdayController.text = '';
          }
          
          // Определяем тип аутентификации
          _isGoogleAccount = userData['googleId'] != null;
        });
      } else {
        // Если API вернул ошибку авторизации, перенаправляем на страницу входа
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session expired. Please log in again.'))
          );
          
          // Немного задержки перед переходом
          Future.delayed(Duration(seconds: 2), () {
            Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
          });
        }
      }
    } catch (e) {
      AppLogger.log('❌ Error loading user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'))
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Save user data via API
  Future<void> _saveUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_formKey.currentState?.validate() ?? false) {
        // Check that the data has changed
        final String firstName = _firstNameController.text.trim();
        final String lastName = _lastNameController.text.trim();
        final String birthday = _birthdayController.text.trim();
        
        if (firstName.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('First name cannot be empty'))
            );
          }
          setState(() {
            _isLoading = false;
          });
          return;
        }
        
        // Log values before saving
        AppLogger.log('📋 Saving profile:');
        AppLogger.log('👤 First name: $firstName');
        AppLogger.log('👤 Last name: $lastName');
        AppLogger.log('📅 Date of birth: $birthday');
        
        // Дополнительная проверка формата даты
        String formattedBirthday = birthday;
        if (birthday.isNotEmpty) {
          try {
            final parts = birthday.split('/');
            if (parts.length == 3) {
              AppLogger.log('📅 Валидная дата в формате MM/DD/YYYY: месяц=${parts[0]}, день=${parts[1]}, год=${parts[2]}');
              
              // Проверяем, что это действительно дата
              final month = int.parse(parts[0]);
              final day = int.parse(parts[1]);
              final year = int.parse(parts[2]);
              
              if (month < 1 || month > 12) {
                AppLogger.log('⚠️ Некорректный месяц: $month');
              }
              
              if (day < 1 || day > 31) {
                AppLogger.log('⚠️ Некорректный день: $day');
              }
              
              if (year < 1900 || year > DateTime.now().year) {
                AppLogger.log('⚠️ Некорректный год: $year');
              }
            } else {
              AppLogger.log('⚠️ Некорректный формат даты: $birthday');
            }
          } catch (e) {
            AppLogger.log('⚠️ Ошибка при проверке даты: $e');
          }
        }
        
        // Сохраняем данные на сервер
        final result = await _profileService.updateProfile(
          firstName: firstName,
          lastName: lastName,
          birthday: formattedBirthday,
        );
        
        AppLogger.log('📤 Результат обновления профиля: $result');
        
        if (result['success'] == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile successfully saved'))
            );
            setState(() {
              _isEditing = false;
            });
            
            // Перезагружаем данные профиля
            await _loadUserData();
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(result['error'] ?? 'Error saving profile'))
            );
          }
        }
      }
    } catch (e) {
      AppLogger.log('❌ Error saving user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e'))
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Pick an image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(
        source: source,
        imageQuality: 85, // Уменьшаем качество для быстрой загрузки
        maxWidth: 800,   // Ограничиваем размер
      );

      if (pickedImage != null) {
        AppLogger.log('📸 Выбрано изображение: ${pickedImage.path}');
        final fileExtension = pickedImage.path.split('.').last.toLowerCase();
        
        // Проверяем, поддерживается ли формат изображения
        if (fileExtension != 'jpg' && fileExtension != 'jpeg' && fileExtension != 'png' && fileExtension != 'gif') {
          AppLogger.log('⚠️ Неподдерживаемый формат изображения: $fileExtension. Поддерживаются только JPG, PNG и GIF');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Выберите изображение в формате JPG, PNG или GIF'))
            );
          }
          return;
        }
        
        setState(() {
          _profileImage = File(pickedImage.path);
          _profileImageUrl = null; // Сбрасываем URL, если выбрано локальное изображение
        });
        
        // Сразу загружаем изображение на сервер
        _uploadProfileImage(_profileImage!);
      } else {
        AppLogger.log('⚠️ Выбор изображения был отменен пользователем');
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при выборе изображения: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось выбрать изображение: $e'))
        );
      }
    }
  }
  
  // Загрузка фото профиля на сервер
  Future<void> _uploadProfileImage(File imageFile) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      AppLogger.log('📤 Начинаем загрузку изображения: ${imageFile.path}');
      AppLogger.log('📁 Размер файла: ${(await imageFile.length() / 1024).toStringAsFixed(2)} KB');
      
      // Проверяем наличие файла
      if (!await imageFile.exists()) {
        AppLogger.log('❌ Файл не существует: ${imageFile.path}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Файл изображения не существует'))
          );
        }
        setState(() {
          _isLoading = false;
          _profileImage = null;
        });
        return;
      }
      
      // Проверяем тип файла
      final fileExtension = imageFile.path.split('.').last.toLowerCase();
      if (fileExtension != 'jpg' && fileExtension != 'jpeg' && fileExtension != 'png' && fileExtension != 'gif') {
        AppLogger.log('⚠️ Неподдерживаемый формат изображения: $fileExtension');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Неподдерживаемый формат изображения. Используйте JPG, PNG или GIF'))
          );
        }
        setState(() {
          _isLoading = false;
          _profileImage = null;
        });
        return;
      }
      
      // Загружаем изображение на сервер
      final result = await _profileService.uploadProfileImage(imageFile);
      
      AppLogger.log('📤 Результат загрузки изображения: $result');
      
      if (result['success'] == true) {
        // Обновляем URL изображения
        final String? newImageUrl = result['profileImageUrl'] ?? result['imageUrl'] ?? result['absoluteUrl'];
        
        setState(() {
          if (newImageUrl != null && newImageUrl.isNotEmpty) {
            _profileImageUrl = newImageUrl;
            AppLogger.log('✅ Установлен новый URL изображения: $_profileImageUrl');
          } else {
            AppLogger.log('⚠️ Сервер не вернул URL изображения');
            
            // Если сервер не вернул URL, но загрузка успешна, попробуем использовать возвращенное имя файла
            if (result['fileName'] != null && result['fileName'].isNotEmpty) {
              _profileImageUrl = 'https://bearded-fox.ru/travel/uploads/profile_images/${result['fileName']}';
              AppLogger.log('✅ Сформирован URL изображения из имени файла: $_profileImageUrl');
            }
          }
          _profileImage = null; // Сбрасываем локальный файл, так как загрузка прошла успешно
        });
        
        // Перезагружаем данные пользователя
        await _loadUserData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Изображение профиля обновлено'))
          );
        }
      } else {
        String errorMessage = result['error'] ?? result['message'] ?? 'Ошибка при загрузке изображения';
        AppLogger.log('❌ Ошибка при загрузке: $errorMessage');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage))
          );
        }
        
        // Сбрасываем локальный файл, так как загрузка не удалась
        setState(() {
          _profileImage = null;
        });
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при загрузке изображения: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading profile image: $e'))
        );
      }
      
      // Сбрасываем локальный файл, так как произошла ошибка
      setState(() {
        _profileImage = null;
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show dialog to choose image source
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Choose Image Source',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                'Gallery',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(
                'Camera',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Select birthday date
  Future<void> _selectDate() async {
    AppLogger.log('📅 Открываем выбор даты рождения');
    
    try {
      // По умолчанию 18 лет назад, или текущая выбранная дата
      final DateTime initialDate = _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18));
      
      AppLogger.log('📅 Начальная дата: $initialDate');
      
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(1900),
        lastDate: DateTime.now(),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: ColorScheme.light(
                primary: Colors.blue.shade700,
                onPrimary: Colors.white,
                onSurface: Colors.black,
              ),
            ),
            child: child!,
          );
        },
      );
  
      if (picked != null) {
        AppLogger.log('📅 Выбрана дата: $picked');
        
        // Форматируем дату в строку в формате MM/dd/yyyy для отображения
        final String formattedDate = DateFormat('MM/dd/yyyy').format(picked);
        AppLogger.log('📅 Отформатированная дата: $formattedDate');
        
        setState(() {
          _selectedDate = picked;
          if (_birthdayController != null) {
            _birthdayController.text = formattedDate;
          }
        });
        
        AppLogger.log('📅 Дата в контроллере: ${_birthdayController.text}');
      } else {
        AppLogger.log('📅 Выбор даты отменен');
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при выборе даты: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error selecting date: $e'))
        );
      }
    }
  }

  // Выход из аккаунта
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sign Out?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to sign out of your account?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              'Sign Out',
              style: GoogleFonts.poppins(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    ) ?? false;

    if (confirmed) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Сначала очищаем SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
        
        try {
          // Выходим из аккаунта через API в отдельном try-catch блоке
          // чтобы предотвратить крах, если API не ответит
          await _authService.signOut();
        } catch (apiError) {
          AppLogger.log('API error during sign out: $apiError');
          // Игнорируем ошибку API, продолжаем локальный выход
        }
        
        // Переходим на экран входа
        if (mounted) {
          await Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        AppLogger.log('Error signing out: $e');
        // В случае общей ошибки, показываем сообщение пользователю
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error while signing out: $e'))
          );
          
          // И все равно пытаемся перейти на экран входа
          await Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // Toggle edit mode
  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  // Загрузка социальных данных пользователя
  Future<void> _loadSocialData() async {
    if (mounted) {
      setState(() {
        _loadingSocialData = true;
      });
    }
    
    try {
      // Загружаем данные о подписчиках
      final followersResult = await _socialService.getFollows(
        type: 'followers',
      );
      
      if (followersResult['success'] == true && followersResult['follows'] != null) {
        setState(() {
          _followersCount = followersResult['totalCount'] ?? 0;
        });
      }
      
      // Загружаем данные о подписках
      final followingResult = await _socialService.getFollows(
        type: 'following',
      );
      
      if (followingResult['success'] == true && followingResult['follows'] != null) {
        setState(() {
          _followingCount = followingResult['totalCount'] ?? 0;
        });
      }
      
      // Загружаем данные об избранных фотографиях
      final favoritesResult = await _socialService.getFavorites();
      
      if (favoritesResult['success'] == true && favoritesResult['favorites'] != null) {
        setState(() {
          _favoritesCount = favoritesResult['totalCount'] ?? 0;
        });
      }
    } catch (e) {
      AppLogger.log('Ошибка загрузки социальных данных: $e');
    } finally {
      if (mounted) {
        setState(() {
          _loadingSocialData = false;
        });
      }
    }
  }

  // Переход к списку подписчиков
  void _showFollowers() {
    AppLogger.log('Показать подписчиков');
    // Здесь будет переход к экрану подписчиков
    // Navigator.push(context, MaterialPageRoute(builder: (context) => FollowersScreen()));
  }
  
  // Переход к списку подписок
  void _showFollowing() {
    AppLogger.log('Показать подписки');
    // Здесь будет переход к экрану подписок
    // Navigator.push(context, MaterialPageRoute(builder: (context) => FollowingScreen()));
  }
  
  // Переход к избранным фотографиям
  void _showFavorites() {
    AppLogger.log('Показать избранное');
    // Здесь будет переход к экрану избранных фотографий
    // Navigator.push(context, MaterialPageRoute(builder: (context) => FavoritesScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        title: Text(
          'Profile',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _isEditing
              ? IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _saveUserData,
          )
              : IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _toggleEditMode,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Profile header with image
          _buildProfileHeader(),

          // Profile information
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User information
                    if (_isEditing)
                      _buildEditForm()
                    else
                      _buildProfileInfo(),

                    const SizedBox(height: 32),

                    // Sign out button
                    ElevatedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.white,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: Text(
                        'Sign Out',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Delete account button (only in edit mode)
                    if (_isEditing)
                      TextButton.icon(
                        onPressed: _deleteAccount,
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        label: Text(
                          'Delete Account',
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build profile header with big image
  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                // Profile image with border
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 4.0,
                    ),
                  ),
                  child: _profileImageUrl != null && _profileImage == null && _profileImageUrl!.isNotEmpty
                      ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: _profileImageUrl!,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => const CircularProgressIndicator(),
                      errorWidget: (context, url, error) {
                        AppLogger.log('⚠️ Ошибка загрузки изображения: $url - $error');
                        // Если возникла ошибка при загрузке изображения, очищаем URL
                        if (mounted) {
                          Future.microtask(() {
                            setState(() {
                              _profileImageUrl = null;
                            });
                          });
                        }
                        return const Icon(
                          Icons.person,
                          size: 80,
                          color: Colors.grey,
                        );
                      },
                    ),
                  )
                      : _profileImage != null
                      ? ClipOval(
                    child: Image.file(
                      _profileImage!,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  )
                      : const CircleAvatar(
                    radius: 80,
                    backgroundColor: Colors.grey,
                    child: Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Camera icon for editing profile image
                if (_isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.blue.shade700,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _isEditing ? "Edit Profile" : "Profile",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build profile information in view mode
  Widget _buildProfileInfo() {
    final TextStyle labelStyle = GoogleFonts.poppins(
      fontSize: 14,
      color: Colors.grey.shade600,
    );

    final TextStyle valueStyle = GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );

    return Column(
      children: [
        // Отступ вместо карточки социальной статистики
        SizedBox(height: 16),
        
        // Личная информация
        Card(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Personal Information',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
                const SizedBox(height: 16),
                _buildInfoItem('First Name', _firstNameController.text),
                const Divider(),
                _buildInfoItem('Last Name', _lastNameController.text),
                const Divider(),
                _buildInfoItem('Email', _emailController.text),
                const Divider(),
                _buildInfoItem('Date of Birth', _birthdayController.text),

                if (_isGoogleAccount) ...[
                  const Divider(),
                  _buildInfoItem('Account', 'Google'),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  // Build single info item for view mode
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Text(
            value.isNotEmpty ? value : 'Not specified',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Build edit form in edit mode
  Widget _buildEditForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Edit Profile',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                hintText: 'First Name',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your first name';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                hintText: 'Last Name',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Поле даты рождения
            GestureDetector(
              onTap: _selectDate,
              child: AbsorbPointer(
                child: TextFormField(
                  controller: _birthdayController,
                  decoration: InputDecoration(
                    hintText: 'Date of Birth',
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    suffixIcon: const Icon(Icons.calendar_month),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Delete account
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              'Delete',
              style: GoogleFonts.poppins(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() {
          _isLoading = true;
        });

        // Если это Google-аккаунт, выходим через сервис
        if (_isGoogleAccount) {
          await _authService.signOut();
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // Удаляем все данные пользователя

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Account successfully deleted'))
          );

          // Перенаправляем на экран входа - используем простой подход
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        AppLogger.log('Ошибка при удалении аккаунта: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error deleting account'))
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
}