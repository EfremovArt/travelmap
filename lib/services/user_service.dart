import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/api_config.dart';
import 'auth_service.dart';
import '../utils/logger.dart';
class UserService {
  static final UserService _instance = UserService._internal();
  static final AuthService _authService = AuthService();
  
  factory UserService() {
    return _instance;
  }
  
  UserService._internal();

  // Ключи для SharedPreferences
  static const String _firstNameKey = 'firstName';
  static const String _lastNameKey = 'lastName';
  static const String _profileImageKey = 'profileImage';
  static const String _emailKey = 'email';
  static const String _birthdayKey = 'birthday';

  // In-memory кэш данных пользователя
  static Map<String, dynamic>? _cachedUserData;
  static DateTime? _cachedAt;
  static const Duration _cacheTtl = Duration(minutes: 10);

  static bool _isCacheFresh() {
    if (_cachedUserData == null || _cachedAt == null) return false;
    return DateTime.now().difference(_cachedAt!) < _cacheTtl;
  }

  /// Очистка кэша данных пользователя
  /// Используется для принудительного обновления данных
  static void clearCache() {
    _cachedUserData = null;
    _cachedAt = null;
    AppLogger.log('🗑️ Кэш данных пользователя очищен');
  }

  static Future<Map<String, dynamic>?> _getUserDataCached({bool forceRefresh = false}) async {
    // Возвращаем кэш, если он свежий
    if (!forceRefresh && _isCacheFresh()) {
      return _cachedUserData;
    }

    try {
      // Обновляем сессию и получаем userData один раз
      final result = await _authService.checkAuth();
      if (result['isAuthenticated'] == true && result['userData'] != null) {
        final data = Map<String, dynamic>.from(result['userData']);
        _cachedUserData = data;
        _cachedAt = DateTime.now();
        // AppLogger.log('📊 _getUserDataCached: обновили кэш пользовательских данных');
        return _cachedUserData;
      }

      // Если не аутентифицированы, отдаём то, что есть в кэше (если есть)
      if (_cachedUserData != null) {
        return _cachedUserData;
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при обновлении кэша пользовательских данных: $e');
      // Фолбэк на кэш, если он есть
      if (_cachedUserData != null) {
        return _cachedUserData;
      }
    }

    return null;
  }

  // Получение полного имени пользователя
  static Future<String> getFullName() async {
    try {
      final userData = await _getUserDataCached();
      if (userData != null) {
        final firstName = userData['firstName'] ?? '';
        final lastName = userData['lastName'] ?? '';
        
        if (firstName.isEmpty && lastName.isEmpty) {
          return 'Пользователь';
        } else if (firstName.isEmpty) {
          return lastName;
        } else if (lastName.isEmpty) {
          return firstName;
        } else {
          return '$firstName $lastName';
        }
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении имени пользователя: $e');
    }
    return 'Пользователь';
  }

  // Получение имени пользователя
  static Future<String> getFirstName() async {
    try {
      final userData = await _getUserDataCached();
      return userData?['firstName'] ?? '';
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении имени пользователя: $e');
      return '';
    }
  }

  // Получение фамилии пользователя
  static Future<String> getLastName() async {
    try {
      final userData = await _getUserDataCached();
      return userData?['lastName'] ?? '';
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении фамилии пользователя: $e');
      return '';
    }
  }

  // Получение URL изображения профиля
  static Future<String> getProfileImage() async {
    try {
      final userData = await _getUserDataCached();
      final rawProfileImageUrl = userData?['profileImageUrl'] ?? '';
      final profileImageUrl = ApiConfig.formatImageUrl(rawProfileImageUrl);
      
      // AppLogger.log('📸 getProfileImage: получен URL: $rawProfileImageUrl');
      // AppLogger.log('📸 getProfileImage: отформатированный URL: $profileImageUrl');
      
      return profileImageUrl;
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении изображения профиля: $e');
      return '';
    }
  }

  // Получение email пользователя
  static Future<String> getEmail() async {
    try {
      final userData = await _getUserDataCached();
      return userData?['email'] ?? '';
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении email пользователя: $e');
      return '';
    }
  }

  // Получение числового ID пользователя
  static Future<String> getUserId() async {
    try {
      final userData = await _getUserDataCached();
      // Получаем ID пользователя и конвертируем в строку для удобства сравнения
      final userId = userData?['id'] != null ? userData!['id'].toString() : '';
      
      // AppLogger.log('📊 Получен ID пользователя: $userId');
      return userId;
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении ID пользователя: $e');
      return '';
    }
  }

  // Получение данных пользователя с сервера (сырой вызов)
  static Future<Map<String, dynamic>?> _getUserDataFromServer() async {
    try {
      final result = await _authService.checkAuth();
      if (result['isAuthenticated'] == true && result['userData'] != null) {
        AppLogger.log('📊 _getUserDataFromServer: получены данные: ${result['userData']}');
        return result['userData'];
      } else {
        AppLogger.log('⚠️ _getUserDataFromServer: нет данных, isAuthenticated=${result['isAuthenticated']}');
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении данных пользователя с сервера: $e');
    }
    return null;
  }

  // Получение данных пользователя
  static Future<Map<String, dynamic>?> getUserData() async {
    return await _getUserDataCached();
  }

  // Получение данных текущего пользователя (используется для комментариев)
  static Future<Map<String, dynamic>> getCurrentUserData() async {
    try {
      final userData = await _getUserDataCached();
      if (userData != null) {
        return userData;
      }
      
      // Если не удалось получить данные с сервера, возвращаем базовые данные
      return {
        'id': 1,
        'firstName': await getFirstName(),
        'lastName': await getLastName(),
        'email': await getEmail(),
        'profileImageUrl': await getProfileImage(),
      };
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении данных текущего пользователя: $e');
      
      // Возвращаем данные по умолчанию в случае ошибки
      return {
        'id': 1,
        'firstName': 'Пользователь',
        'lastName': '',
        'email': '',
        'profileImageUrl': '',
      };
    }
  }

  // Проверка авторизации пользователя
  static Future<bool> isLoggedIn() async {
    try {
      final result = await _authService.checkAuth();
      return result['isAuthenticated'] == true;
    } catch (e) {
      AppLogger.log('❌ Ошибка при проверке авторизации: $e');
      return false;
    }
  }
  
  // Обновление статуса авторизации
  static Future<bool> checkAuth() async {
    try {
      final result = await _authService.refreshSession();
      return result['isAuthenticated'] == true;
    } catch (e) {
      AppLogger.log('❌ Ошибка при обновлении статуса авторизации: $e');
      return false;
    }
  }

  // Получение информации о пользователе по ID
  static Future<Map<String, dynamic>> getUserInfoById(String userId) async {
    try {
      final token = await AuthService.getToken();
      
      // Проверяем, не является ли это текущим пользователем
      final currentUserData = await _getUserDataCached();
      if (currentUserData != null && currentUserData['id'].toString() == userId) {
        // Форматируем URL изображения профиля
        if (currentUserData.containsKey('profileImageUrl')) {
          currentUserData['profileImageUrl'] = ApiConfig.formatImageUrl(currentUserData['profileImageUrl']);
        }
        return currentUserData;
      }
      
      // Получаем данные пользователя через API
      final response = await http.get(
        Uri.parse(ApiConfig.getUserByIdUrl(userId)),
        headers: {
          'Cookie': token,
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['userData'] != null) {
          // Форматируем URL изображения профиля
          final userData = data['userData'];
          if (userData.containsKey('profileImageUrl')) {
            userData['profileImageUrl'] = ApiConfig.formatImageUrl(userData['profileImageUrl']);
          }
          return userData;
        }
      }
      
      // Если API запрос не удался, возвращаем стандартные данные
      AppLogger.log('⚠️ Не удалось получить данные о пользователе $userId через API, возвращаем стандартные данные');
      return {
        'id': int.tryParse(userId) ?? 0,
        'firstName': 'User',
        'lastName': userId,
        'profileImageUrl': '',
        'email': '',
      };
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении информации о пользователе: $e');
      return {
        'id': 0,
        'firstName': 'Unknown',
        'lastName': 'User',
        'profileImageUrl': '',
        'email': '',
      };
    }
  }
  
  // Получение имени пользователя по email
  static Future<String> getFullNameByEmail(String email) async {
    try {
      AppLogger.log('🔍 UserService.getFullNameByEmail: Получаем имя для $email');
      
      // Если email совпадает с текущим пользователем, используем его данные
      final currentEmail = await getEmail();
      if (email == currentEmail) {
        final name = await getFullName();
        AppLogger.log('✅ UserService.getFullNameByEmail: Это текущий пользователь, имя: $name');
        return name;
      }
      
      // Пытаемся получить данные пользователя через API
      final response = await http.get(
        Uri.parse(ApiConfig.getUserByEmailUrl(email)),
        headers: _authService.sessionHeaders,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        AppLogger.log('📊 UserService.getFullNameByEmail: Ответ от сервера: $data');
        
        if (data['success'] == true && data['userData'] != null) {
          final userData = data['userData'];
          final firstName = userData['firstName'] ?? '';
          final lastName = userData['lastName'] ?? '';
          
          String result = '';
          if (firstName.isEmpty && lastName.isEmpty) {
            result = 'User';
          } else if (firstName.isEmpty) {
            result = lastName;
          } else if (lastName.isEmpty) {
            result = firstName;
          } else {
            result = '$firstName $lastName';
          }
          
          AppLogger.log('✅ UserService.getFullNameByEmail: Получено имя: $result');
          return result;
        }
      } else {
        AppLogger.log('❌ UserService.getFullNameByEmail: Ошибка запроса, код: ${response.statusCode}, тело: ${response.body}');
      }
      
      // Если не можем получить имя по API - используем первую часть email как имя
      String username = email.contains('@') ? email.split('@')[0] : email;
      AppLogger.log('⚠️ UserService.getFullNameByEmail: Используем запасной вариант: $username');
      
      // Обработка числовых user_id - возвращаем строку 'Пользователь'
      if (int.tryParse(email) != null) {
        return 'Пользователь ${int.parse(email)}';
      }
      
      return username;
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении имени пользователя по email: $e');
      return email.isNotEmpty ? email.split('@')[0] : 'User';
    }
  }
  
  // Получение фото профиля пользователя по email
  static Future<String?> getProfileImageByEmail(String email) async {
    try {
      // Если email совпадает с текущим пользователем, используем его данные
      final currentEmail = await getEmail();
      if (email == currentEmail) {
        return await getProfileImage();
      }
      
      // Пытаемся получить данные пользователя через API
      final response = await http.get(
        Uri.parse(ApiConfig.getUserByEmailUrl(email)),
        headers: _authService.sessionHeaders,
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['userData'] != null) {
          final rawProfileImageUrl = data['userData']['profileImageUrl'] ?? '';
          return ApiConfig.formatImageUrl(rawProfileImageUrl);
        }
      }
      
      return '';
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении фото пользователя по email: $e');
      return '';
    }
  }

  // Проверка и исправление URL фото профиля пользователя
  static Future<String> checkAndFixProfileImage() async {
    try {
      AppLogger.log('🔍 Проверка и исправление URL фото профиля');
      
      // Сначала попробуем получить URL из данных пользователя
      final userData = await _getUserDataFromServer();
      final rawProfileImageUrl = userData?['profileImageUrl'] ?? '';
      final profileImageUrl = ApiConfig.formatImageUrl(rawProfileImageUrl);
      
      AppLogger.log('📊 Оригинальный URL: $rawProfileImageUrl');
      AppLogger.log('📊 Отформатированный URL: $profileImageUrl');
      
      // Если URL не пустой, возвращаем его
      if (profileImageUrl.isNotEmpty) {
        AppLogger.log('✅ URL фото профиля найден в данных пользователя');
        return profileImageUrl;
      }
      
      // Если URL пустой, попробуем получить из SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedRawProfileImage = prefs.getString('profile_image_url') ?? '';
      final savedProfileImage = ApiConfig.formatImageUrl(savedRawProfileImage);
      
      AppLogger.log('📊 Сохраненный URL: $savedRawProfileImage');
      AppLogger.log('📊 Отформатированный сохраненный URL: $savedProfileImage');
      
      if (savedProfileImage.isNotEmpty) {
        AppLogger.log('✅ URL фото профиля найден в SharedPreferences');
        return savedProfileImage;
      }
      
      // Если и тут пусто, пробуем обновить данные авторизации
      AppLogger.log('🔄 Обновляем данные авторизации');
      await _authService.checkAuth();
      
      // Проверяем еще раз после обновления
      final updatedUserData = await _getUserDataFromServer();
      final updatedRawProfileImageUrl = updatedUserData?['profileImageUrl'] ?? '';
      final updatedProfileImageUrl = ApiConfig.formatImageUrl(updatedRawProfileImageUrl);
      
      AppLogger.log('📊 Обновленный URL: $updatedRawProfileImageUrl');
      AppLogger.log('📊 Отформатированный обновленный URL: $updatedProfileImageUrl');
      
      if (updatedProfileImageUrl.isNotEmpty) {
        AppLogger.log('✅ URL фото профиля найден после обновления');
        return updatedProfileImageUrl;
      }
      
      return '';
    } catch (e) {
      AppLogger.log('❌ Ошибка при проверке и исправлении URL фото профиля: $e');
      return '';
    }
  }
} 