import 'dart:io';
import 'location.dart';

class Post {
  final String id;
  final List<File> images;
  final GeoLocation location;
  final String locationName;
  final String description;
  final DateTime createdAt;
  final String user;
  
  Post({
    required this.id,
    required this.images,
    required this.location,
    required this.locationName,
    required this.description,
    required this.createdAt,
    required this.user,
  });
  
  // Метод для извлечения широты
  double get latitude {
    return location.latitude;
  }
  
  // Метод для извлечения долготы
  double get longitude {
    return location.longitude;
  }
  
  // В будущем можно добавить методы для сериализации/десериализации
  // для сохранения постов в локальном хранилище или отправки на сервер
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'location': location.toJson(),
      'locationName': locationName,
      'description': description,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'user': user,
      // Для изображений понадобится отдельная логика загрузки на сервер
      // Здесь мы только сохраняем пути к файлам
      'imagePaths': images.map((file) => file.path).toList(),
    };
  }
  
  factory Post.fromJson(Map<String, dynamic> json) {
    return Post(
      id: json['id'] as String,
      images: (json['imagePaths'] as List<dynamic>)
          .map((path) => File(path as String))
          .toList(),
      location: GeoLocation.fromJson(json['location'] as Map<String, dynamic>),
      locationName: json['locationName'] as String,
      description: json['description'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      user: json['user'] as String,
    );
  }
} 