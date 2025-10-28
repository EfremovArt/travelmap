import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';
import 'user_service.dart';
/// Сервис для авторизации пользователя
class AuthService {
  // Статический экземпляр для реализации синглтона
  static final AuthService _instance = AuthService._internal();
  
  // HTTP-клиент для сохранения сессии между запросами
  static final http.Client _httpClient = http.Client();
  
  // Хранение куки сессии
  String? _sessionCookie;
  
  // Синглтон
  factory AuthService() {
    return _instance;
  }
  
  AuthService._internal();
  
  // Ключи для хранения данных
  static const String _userDataKey = 'user_data';
  static const String _sessionCookieKey = 'session_cookie';
  
  /// Инициализация сервиса - загрузка сохраненной куки сессии
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _sessionCookie = prefs.getString(_sessionCookieKey);
    } catch (e) {
      AppLogger.log('❌ Ошибка при инициализации AuthService: $e');
    }
  }
  
  /// Получить текущие заголовки с куками сессии
  Map<String, String> get sessionHeaders {
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    if (_sessionCookie != null && _sessionCookie!.isNotEmpty) {
      // Санитизируем сохраненное значение, чтобы отправлять ровно пару PHPSESSID=...
      final sanitized = _extractPhpSessPair(_sessionCookie!);
      if (sanitized.isNotEmpty) {
        headers['Cookie'] = sanitized;
      } else {
        headers['Cookie'] = _sessionCookie!;
      }
    } else {
      AppLogger.log('⚠️ Кука сессии отсутствует!');
    }
    
    return headers;
  }
  
  /// Обновление и сохранение куки сессии из ответа сервера
  Future<void> _updateSessionCookie(http.Response response) async {
    // Ищем куку во всех возможных вариантах заголовков
    String? cookieHeader = response.headers['set-cookie'];
    
    // В некоторых случаях заголовок может быть в разных регистрах
    if (cookieHeader == null || cookieHeader.isEmpty) {
      cookieHeader = response.headers['Set-Cookie'];
    }
    
    if (cookieHeader == null || cookieHeader.isEmpty) {
      // Проверяем все заголовки ответа
      for (var key in response.headers.keys) {
        if (key.toLowerCase().contains('set-cookie')) {
          cookieHeader = response.headers[key];
          break;
        }
      }
    }
    
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      // Извлекаем только пару PHPSESSID=...
      final phpSess = _extractPhpSessPair(cookieHeader);
      if (phpSess.isNotEmpty) {
        _sessionCookie = phpSess;
      } else {
        // Фолбэк: берем первую пару до ';'
        final firstPair = cookieHeader.split(';').first.trim();
        _sessionCookie = firstPair;
      }
      
      // Сохраняем куку в SharedPreferences
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionCookieKey, _sessionCookie!);
      } catch (e) {
        AppLogger.log('❌ Ошибка при сохранении куки сессии: $e');
      }
      return;
    }
    
    // Проверяем тело ответа - иногда сервер возвращает куку в теле JSON
    try {
      final Map<String, dynamic> body = jsonDecode(response.body);
      if (body.containsKey('cookie')) {
        final raw = body['cookie']?.toString() ?? '';
        final phpSess = _extractPhpSessPair(raw);
        _sessionCookie = phpSess.isNotEmpty ? phpSess : raw;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_sessionCookieKey, _sessionCookie!);
      }
    } catch (_) {}
  }

  // Вспомогательная функция: извлечь из Set-Cookie ровно пару PHPSESSID=...
  String _extractPhpSessPair(String cookieHeader) {
    try {
      final lower = cookieHeader;
      final regex = RegExp(r'PHPSESSID=([^;\s,]+)');
      final match = regex.firstMatch(lower);
      if (match != null) {
        final value = match.group(1) ?? '';
        if (value.isNotEmpty) {
          return 'PHPSESSID=' + value;
        }
      }
      // Если PHPSESSID не найден, возможно сервер отдает уже корректную пару без атрибутов
      if (cookieHeader.startsWith('PHPSESSID=')) {
        final pair = cookieHeader.split(';').first.trim();
        return pair;
      }
    } catch (_) {}
    return '';
  }
  
  /// Авторизация через Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Инициализируем GoogleSignIn
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email'],
      );
      
      // Очищаем предыдущую сессию Google
      await googleSignIn.signOut();
      
      // Запускаем процесс входа
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      // Если пользователь не выбран (закрыл окно входа)
      if (googleUser == null) {
        return {
          'success': false,
          'message': 'Вход отменен пользователем'
        };
      }
      
      AppLogger.log('✅ Успешный вход через Google: ${googleUser.email}');
      
      // Получаем данные аутентификации
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      // Извлекаем токены
      final String? idToken = googleAuth.idToken;
      final String? accessToken = googleAuth.accessToken;
      
      AppLogger.log('📝 ID токен: ${idToken != null ? 'получен' : 'отсутствует'}');
      AppLogger.log('📝 Access токен: ${accessToken != null ? 'получен' : 'отсутствует'}');
      
      // Проверяем токены
      if (idToken == null && accessToken == null) {
        return {
          'success': false,
          'message': 'Не удалось получить токены авторизации'
        };
      }
      
      // Данные для отправки на сервер
      final Map<String, dynamic> requestData = {
        'email': googleUser.email,
        'name': googleUser.displayName ?? '',
        'photo_url': googleUser.photoUrl ?? '',
      };
      
      // Добавляем доступные токены
      if (idToken != null) {
        requestData['id_token'] = idToken;
      }
      
      if (accessToken != null) {
        requestData['access_token'] = accessToken;
      }
      
      AppLogger.log('📤 Отправляемые данные: $requestData');
      
      // Отправляем токены на сервер для верификации и получения или создания учетной записи
      final response = await _httpClient.post(
        Uri.parse(ApiConfig.googleAuth),
        headers: sessionHeaders,
        body: jsonEncode(requestData),
      );
      
      AppLogger.log('🔄 Отправка токенов на сервер: ${response.statusCode}');
      
      // Обрабатываем куки из ответа
      await _updateSessionCookie(response);
      
      // Проверяем ответ
      AppLogger.log('📡 Ответ сервера: ${response.statusCode}');
      AppLogger.log('📡 Тело ответа: ${response.body}');
      
      if (response.statusCode == 200) {
        try {
          Map<String, dynamic> responseData = jsonDecode(response.body);
          
          if (responseData['success'] == true) {
            // Очищаем кэш UserService перед сохранением новых данных
            // Это важно для правильной работы проверки прав доступа
            UserService.clearCache();
            AppLogger.log('🧹 Кэш UserService очищен после успешного входа');
            
            // Сохраняем данные пользователя
            await _saveUserData(responseData['userData']);
            
            return {
              'success': true,
              'message': 'Успешная авторизация',
              'userData': responseData['userData'],
            };
          } else {
            return {
              'success': false,
              'message': responseData['message'] ?? 'Неизвестная ошибка при авторизации'
            };
          }
        } catch (e) {
          AppLogger.log('❌ Ошибка при парсинге ответа: $e');
          AppLogger.log('❌ Сырой ответ сервера: ${response.body}');
          return {
            'success': false,
            'message': 'Ошибка при обработке ответа сервера: $e'
          };
        }
      } else {
        AppLogger.log('❌ Ошибка сервера: ${response.statusCode}');
        return {
          'success': false,
          'message': 'Ошибка сервера: ${response.statusCode}'
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при авторизации через Google: $e');
      return {
        'success': false,
        'message': 'Ошибка при авторизации: $e'
      };
    }
  }
  
  /// Обновление сессии авторизации
  Future<Map<String, dynamic>> refreshSession() async {
    try {
      // Добавляем локальные данные пользователя, если доступны
      final prefs = await SharedPreferences.getInstance();
      final email = prefs.getString('email');
      
      final Map<String, dynamic> requestData = {
        'auto_reauth': true,
      };
      
      // Если есть сохраненный email, используем его для восстановления сессии
      if (email != null && email.isNotEmpty) {
        requestData['email'] = email;
      }
      
      // Выполняем запрос на обновление сессии
      final response = await _httpClient.post(
        Uri.parse(ApiConfig.googleAuth),
        headers: sessionHeaders,
        body: jsonEncode(requestData),
      );
      
      // Обрабатываем куки из ответа
      await _updateSessionCookie(response);
      
      // Проверяем ответ
      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true) {
          if (responseData['userData'] != null) {
            // Обновляем сохраненные данные пользователя
            await _saveUserData(responseData['userData']);
          }
          
          return {
            'success': true,
            'message': 'Сессия обновлена успешно',
            'isAuthenticated': true,
          };
        } else {
          return {
            'success': false,
            'message': responseData['message'] ?? 'Не удалось обновить сессию',
            'isAuthenticated': false,
          };
        }
      } else {
        return {
          'success': false,
          'message': 'Ошибка сервера: ${response.statusCode}',
          'isAuthenticated': false,
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при обновлении сессии: $e');
      return {
        'success': false,
        'message': 'Ошибка при обновлении сессии: $e',
        'isAuthenticated': false,
      };
    }
  }
  
  /// Проверка авторизации пользователя
  Future<Map<String, dynamic>> checkAuth() async {
    try {
      // Если сессионной куки нет, проверяем сохраненные данные пользователя
      if (_sessionCookie == null || _sessionCookie!.isEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('user_id');
        final email = prefs.getString('email');
        
        if (userId != null && email != null) {
          AppLogger.log('🔍 Найдены локальные данные пользователя, пытаемся обновить сессию');
          return await refreshSession();
        }
        
        AppLogger.log('🔍 Нет локальных данных пользователя');
        return {
          'success': false,
          'isAuthenticated': false,
          'message': 'Локальная сессия отсутствует'
        };
      }
      
      final response = await _httpClient.get(
        Uri.parse(ApiConfig.checkAuth),
        headers: sessionHeaders,
      );
      
      // Обрабатываем куки из ответа
      await _updateSessionCookie(response);
      
      if (response.statusCode == 200) {
        Map<String, dynamic> responseData = jsonDecode(response.body);
        
        if (responseData['success'] == true && responseData['isAuthenticated'] == true) {
          // Обновляем сохраненные данные
          if (responseData['userData'] != null) {
            await _saveUserData(responseData['userData']);
          }
          
          return {
            'success': true,
            'isAuthenticated': true,
            'userData': responseData['userData'],
          };
        } else {
          // Если не авторизован, пытаемся обновить сессию
          return await refreshSession();
        }
      } else if (response.statusCode == 401) {
        // Если получен код 401, пытаемся обновить сессию
        return await refreshSession();
      } else {
        return {
          'success': false,
          'isAuthenticated': false,
          'message': 'Ошибка сервера: ${response.statusCode}',
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при проверке авторизации: $e');
      return {
        'success': false,
        'isAuthenticated': false,
        'message': 'Ошибка при проверке авторизации: $e',
      };
    }
  }
  
  /// Выход из аккаунта
  Future<Map<String, dynamic>> signOut() async {
    try {
      // Очищаем данные пользователя сначала локально
      await _clearUserData();
      
      // Очищаем куку сессии локально
      _sessionCookie = null;
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_sessionCookieKey);
      
      // Выход из Google в отдельном try-catch блоке
      try {
        final GoogleSignIn googleSignIn = GoogleSignIn();
        await googleSignIn.signOut();
      } catch (googleError) {
        AppLogger.log('Ошибка при выходе из Google: $googleError');
        // Игнорируем ошибку Google и продолжаем с локальным выходом
      }
      
      // Отправляем запрос на выход на сервер в отдельном try-catch
      try {
        final response = await _httpClient.post(
          Uri.parse(ApiConfig.logout),
          headers: sessionHeaders,
        ).timeout(const Duration(seconds: 5)); // Добавляем таймаут
        
        if (response.statusCode == 200) {
          return {
            'success': true,
            'message': 'Выход выполнен успешно',
          };
        }
      } catch (serverError) {
        AppLogger.log('Ошибка сервера при выходе: $serverError');
        // Игнорируем ошибку сервера и считаем выход успешным,
        // так как локальные данные уже очищены
      }
      
      // Считаем выход успешным, даже если были проблемы с сервером
      return {
        'success': true,
        'message': 'Локальный выход выполнен успешно',
      };
    } catch (e) {
      AppLogger.log('❌ Общая ошибка при выходе из аккаунта: $e');
      // Возвращаем успех=true чтобы UI мог продолжить работу
      return {
        'success': true,
        'message': 'Выход с ошибками: $e',
      };
    }
  }
  
  /// Сохранение данных пользователя в локальное хранилище
  Future<void> _saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Сводный лог вместо множества подробных
      // AppLogger.log('🔄 Сохраняем пользователя id=${userData['id']} email=${userData['email']}');
      
      String rawProfileImageUrl = userData['profileImageUrl']?.toString() ?? '';
      String formattedProfileImageUrl = ApiConfig.formatImageUrl(rawProfileImageUrl);
      
      // Сохраняем данные сессии и базовую информацию о пользователе
      await prefs.setString(_sessionCookieKey, _sessionCookie ?? '');
      await prefs.setString('user_id', userData['id']?.toString() ?? '');
      await prefs.setString('email', userData['email']?.toString() ?? '');
      
      // Дополнительно сохраняем URL фото
      if (formattedProfileImageUrl.isNotEmpty) {
        await prefs.setString('profile_image_url', formattedProfileImageUrl);
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при сохранении данных сессии: $e');
    }
  }
  
  /// Очистка данных пользователя
  Future<void> _clearUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Очищаем все ключи, связанные с пользователем
      await prefs.remove(_userDataKey);
      await prefs.remove('user_id');
      await prefs.remove('user_email');
      await prefs.remove('email'); // Добавлено - этот ключ используется в коде
      await prefs.remove('user_name');
      await prefs.remove('user_photo');
    } catch (e) {
      AppLogger.log('❌ Ошибка при очистке данных пользователя: $e');
    }
  }
  
  /// Получение сохраненных данных пользователя
  Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userDataString = prefs.getString(_userDataKey);
      
      if (userDataString != null) {
        return jsonDecode(userDataString);
      }
      
      return null;
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении данных пользователя: $e');
      return null;
    }
  }
  
  /// Получить текущий токен (куку) сессии для использования в запросах
  static Future<String> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cookie = prefs.getString(_sessionCookieKey);
      
      if (cookie != null && cookie.isNotEmpty) {
        return cookie;
      } else {
        AppLogger.log('⚠️ Токен сессии не найден в SharedPreferences');
        // Попробуем обновить сессию и вернуть новый токен
        final result = await _instance.checkAuth();
        if (result['success'] == true && _instance._sessionCookie != null) {
          return _instance._sessionCookie!;
        }
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при получении токена сессии: $e');
    }
    
    // Если не удалось получить токен, возвращаем пустую строку
    return '';
  }
} 