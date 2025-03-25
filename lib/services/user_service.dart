import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

class UserService {
  // Ключи для SharedPreferences
  static const String _firstNameKey = 'firstName';
  static const String _lastNameKey = 'lastName';
  static const String _profileImageKey = 'profileImage';
  static const String _emailKey = 'email';
  static const String _birthdayKey = 'birthday';

  // Получение полного имени пользователя
  static Future<String> getFullName() async {
    final prefs = await SharedPreferences.getInstance();
    final firstName = prefs.getString(_firstNameKey) ?? '';
    final lastName = prefs.getString(_lastNameKey) ?? '';
    
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

  // Получение имени пользователя
  static Future<String> getFirstName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_firstNameKey) ?? '';
  }

  // Получение фамилии пользователя
  static Future<String> getLastName() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_lastNameKey) ?? '';
  }

  // Получение изображения профиля
  static Future<File?> getProfileImage() async {
    final prefs = await SharedPreferences.getInstance();
    final imagePath = prefs.getString(_profileImageKey);
    
    if (imagePath != null && imagePath.isNotEmpty) {
      final file = File(imagePath);
      if (await file.exists()) {
        return file;
      }
    }
    
    return null;
  }

  // Получение email пользователя
  static Future<String> getEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_emailKey) ?? '';
  }

  // Сохранение данных пользователя в кэше приложения
  static Future<void> cacheUserData() async {
    // В будущем здесь можно добавить код для кэширования данных пользователя
    // для более быстрого доступа в приложении
  }
} 