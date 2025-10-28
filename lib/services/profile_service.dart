import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';
import 'auth_service.dart';
import '../utils/logger.dart';
class ProfileService {
  // Проверка наличия протокола в URL изображения
  String _normalizeImageUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }
    
    // Если URL уже начинается с http или https, возвращаем как есть
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    
    // Если URL начинается с /, это относительный путь
    if (url.startsWith('/')) {
      final fullUrl = 'https://bearded-fox.ru$url';
      return fullUrl;
    }
    
    // Добавляем базовый URL сервера
    final fullUrl = '${ApiConfig.baseUrl}/$url';
    return fullUrl;
  }

  // Обновление данных профиля
  Future<Map<String, dynamic>> updateProfile({
    required String firstName,
    String? lastName,
    String? birthday,
  }) async {
    try {
      // Получаем токен сессии для авторизации
      final token = await AuthService.getToken();
      
      // Форматируем дату рождения в формат, который ожидает сервер
      String? formattedBirthday;
      if (birthday != null && birthday.isNotEmpty) {
        try {
          // Преобразуем из MM/dd/yyyy в yyyy-MM-dd
          final parts = birthday.split('/');
          if (parts.length == 3) {
            formattedBirthday = "${parts[2]}-${parts[0].padLeft(2, '0')}-${parts[1].padLeft(2, '0')}";
          } else {
            // Проверяем, не в формате ли уже yyyy-MM-dd
            if (birthday.contains('-') && birthday.split('-').length == 3) {
              formattedBirthday = birthday; // Уже в нужном формате
            } else {
              formattedBirthday = birthday;
            }
          }
        } catch (e) {
          AppLogger.log('⚠️ Ошибка форматирования даты рождения: $e');
          formattedBirthday = birthday;
        }
      }
      
      // Создаем тело запроса
      final requestBody = {
        'firstName': firstName,
        if (lastName != null && lastName.isNotEmpty) 'lastName': lastName,
      };
      
      // Добавляем дату рождения, только если она задана
      if (formattedBirthday != null && formattedBirthday.isNotEmpty) {
        requestBody['birthday'] = formattedBirthday;
      }
      
      final response = await http.post(
        Uri.parse(ApiConfig.updateProfile),
        headers: {
          'Content-Type': 'application/json',
          'Cookie': token,
        },
        body: jsonEncode(requestBody),
      );

      AppLogger.log('📥 Код ответа обновления профиля: ${response.statusCode}');

      if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } catch (e) {
      AppLogger.log('❌ Ошибка при обновлении профиля: $e');
      return {
        'success': false,
        'error': 'Ошибка при обновлении профиля: $e',
      };
    }
  }

  // Загрузка изображения профиля
  Future<Map<String, dynamic>> uploadProfileImage(File imageFile) async {
    try {
      // Создаем multipart-запрос
      final uri = Uri.parse(ApiConfig.uploadProfileImage);
      
      // Получаем токен для авторизации
      final token = await AuthService.getToken();
      
      // Создаем запрос с multipart-данными
      final request = http.MultipartRequest('POST', uri);
      
      // Добавляем заголовки
      if (token.isNotEmpty) {
        request.headers['Cookie'] = token;
      } else {
        AppLogger.log('⚠️ Отсутствует токен сессии для авторизации запроса');
      }
      
      // Проверяем файл
      if (!imageFile.existsSync()) {
        AppLogger.log('❌ Файл не существует: ${imageFile.path}');
        return {
          'success': false,
          'error': 'Файл не существует',
        };
      }
      
      final fileSize = await imageFile.length();
      
      // Проверяем размер файла
      if (fileSize > 10 * 1024 * 1024) { // Ограничение 10MB
        AppLogger.log('❌ Файл слишком большой: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
        return {
          'success': false,
          'error': 'Файл слишком большой',
        };
      }
      
      // Добавляем файл к запросу
      final stream = http.ByteStream(imageFile.openRead());
      final length = await imageFile.length();
      
      final filename = imageFile.path.split('/').last;
      final extension = filename.split('.').last.toLowerCase();
      
      // Правильная настройка типа контента
      String contentType;
      if (extension == 'jpg' || extension == 'jpeg') {
        contentType = 'image/jpeg';
      } else if (extension == 'png') {
        contentType = 'image/png';
      } else if (extension == 'gif') {
        contentType = 'image/gif';
      } else {
        contentType = 'image/jpeg'; // По умолчанию используем jpeg
      }
      
      final multipartFile = http.MultipartFile(
        'profile_image', // имя поля должно соответствовать ожиданиям сервера
        stream,
        length,
        filename: filename,
        contentType: MediaType.parse(contentType),
      );
      
      request.files.add(multipartFile);
      
      // Отправляем запрос
      try {
        final streamedResponse = await request.send();
        
        // Получаем ответ как строку
        final response = await http.Response.fromStream(streamedResponse);
        
        AppLogger.log('📥 Код ответа: ${response.statusCode}');
        
        // Обрабатываем ошибки авторизации
        if (response.statusCode == 401) {
          AppLogger.log('❌ Ошибка авторизации при загрузке фото профиля');
          return {
            'success': false,
            'error': 'Требуется авторизация для загрузки изображения профиля',
          };
        }
        
        // Обрабатываем успешный ответ
        try {
          final Map<String, dynamic> data = jsonDecode(response.body);
          
          // Нормализуем URL изображения, если он есть
          if (data['success'] == true) {
            String? imageUrl = data['profileImageUrl'];
            
            // Проверяем разные варианты имени поля для URL изображения
            if (imageUrl == null || imageUrl.isEmpty) {
              imageUrl = data['imageUrl'];
            }
            if (imageUrl == null || imageUrl.isEmpty) {
              imageUrl = data['url'];
            }
            
            if (imageUrl != null && imageUrl.isNotEmpty) {
              final normalizedUrl = _normalizeImageUrl(imageUrl);
              data['profileImageUrl'] = normalizedUrl;
            } else {
              AppLogger.log('⚠️ В ответе сервера не найден URL изображения');
            }
          }
          
          return data;
        } catch (jsonError) {
          AppLogger.log('⚠️ Ошибка при разборе JSON-ответа: $jsonError');
          
          // Возвращаем простой объект с информацией об ошибке
          if (response.statusCode >= 200 && response.statusCode < 300) {
            return {
              'success': true,
              'message': 'Изображение загружено, но формат ответа не распознан',
              'statusCode': response.statusCode,
              'responseBody': response.body
            };
          } else {
            return {
              'success': false,
              'error': 'Ошибка при загрузке изображения: ${response.statusCode}',
              'responseBody': response.body
            };
          }
        }
      } catch (e) {
        AppLogger.log('❌ Ошибка при отправке запроса: $e');
        return {
          'success': false,
          'error': 'Ошибка при отправке запроса: $e',
        };
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при загрузке изображения профиля: $e');
      return {
        'success': false,
        'error': 'Ошибка при загрузке изображения: $e',
      };
    }
  }
} 