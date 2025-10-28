import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:path/path.dart' as path;

import '../config/api_config.dart';
import '../utils/logger.dart';
import 'auth_service.dart';

class AlbumCoverService {
  /// Загружает изображение обложки альбома без создания полноценного поста
  static Future<Map<String, dynamic>> uploadCover(File imageFile) async {
    try {
      final token = await AuthService.getToken();
      
      AppLogger.log('Uploading album cover image');
      
      // Создаем multipart request
      final request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.uploadAlbumCover),
      );
      
      // Добавляем заголовки авторизации в формате куки
      request.headers['Cookie'] = token;
      
      // Определяем MIME тип файла
      final extension = path.extension(imageFile.path).replaceAll('.', '');
      final mimeType = lookupMimeType(imageFile.path) ?? 'image/jpeg';
      
      // Добавляем файл
      final photoFile = await http.MultipartFile.fromPath(
        'cover_image',
        imageFile.path,
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(photoFile);
      
      AppLogger.log('Sending album cover upload request');
      
      // Отправляем запрос
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      AppLogger.log('Album cover upload response status: ${response.statusCode}');
      AppLogger.log('Album cover upload response body: ${response.body}');
      
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          AppLogger.log('Album cover uploaded successfully: $data');
          return {
            'success': true,
            'cover_id': data['id'],
            'cover_url': data['file_path'],
            'message': 'Album cover uploaded successfully'
          };
        } catch (e) {
          AppLogger.log('Error parsing album cover upload response: $e');
          AppLogger.log('Raw response body: ${response.body}');
          return {
            'success': false,
            'error': 'Invalid response format. Response: ${response.body.length > 200 ? response.body.substring(0, 200) + "..." : response.body}'
          };
        }
      } else {
        String errorMessage = 'Failed to upload album cover (Status: ${response.statusCode})';
        AppLogger.log('Raw error response: ${response.body}');
        try {
          final data = jsonDecode(response.body);
          errorMessage = data['message'] ?? errorMessage;
        } catch (e) {
          AppLogger.log('Error parsing error response: $e');
          // Если не удается распарсить JSON, используем raw body
          errorMessage = 'Server error: ${response.body.length > 100 ? response.body.substring(0, 100) + "..." : response.body}';
        }
        AppLogger.log('Album cover upload failed: $errorMessage');
        return {
          'success': false,
          'error': errorMessage
        };
      }
    } catch (e) {
      AppLogger.log('Error uploading album cover: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }
  
  /// Удаляет обложку альбома
  static Future<Map<String, dynamic>> deleteCover(String coverId) async {
    try {
      final token = await AuthService.getToken();
      
      final response = await http.post(
        Uri.parse(ApiConfig.deleteAlbumCover),
        headers: {
          'Cookie': token,
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'cover_id': coverId,
        }),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'success': true,
          'message': data['message'] ?? 'Cover deleted successfully'
        };
      } else {
        String errorMessage = 'Failed to delete cover';
        try {
          final data = jsonDecode(response.body);
          errorMessage = data['message'] ?? errorMessage;
        } catch (e) {
          AppLogger.log('Error parsing delete cover error response: $e');
        }
        return {
          'success': false,
          'error': errorMessage
        };
      }
    } catch (e) {
      AppLogger.log('Error deleting album cover: $e');
      return {
        'success': false,
        'error': e.toString()
      };
    }
  }
}
