import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';

class LocationService {
  // Добавление новой локации
  Future<Map<String, dynamic>> addLocation({
    required String title,
    String? description,
    required double latitude,
    required double longitude,
    String? address,
    String? city,
    String? country,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.addLocation),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'title': title,
          'description': description,
          'latitude': latitude,
          'longitude': longitude,
          'address': address,
          'city': city,
          'country': country,
        }),
      );

      if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при добавлении локации: $e',
      };
    }
  }

  // Получение локаций пользователя
  Future<Map<String, dynamic>> getUserLocations({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.getUserLocations}?page=$page&per_page=$perPage'),
      );

      if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при получении локаций: $e',
      };
    }
  }

  // Загрузка фотографии для локации
  Future<Map<String, dynamic>> uploadPhoto({
    required File photoFile,
    int? locationId,
    String? title,
    String? description,
  }) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(ApiConfig.uploadPhoto),
      );

      request.files.add(
        await http.MultipartFile.fromPath(
          'photo',
          photoFile.path,
        ),
      );

      if (locationId != null) {
        request.fields['location_id'] = locationId.toString();
      }
      
      if (title != null) {
        request.fields['title'] = title;
      }
      
      if (description != null) {
        request.fields['description'] = description;
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 401) {
        return {
          'success': false,
          'error': 'Требуется авторизация',
        };
      }

      final Map<String, dynamic> data = jsonDecode(response.body);
      return data;
    } catch (e) {
      return {
        'success': false,
        'error': 'Ошибка при загрузке фотографии: $e',
      };
    }
  }
} 