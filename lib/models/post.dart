import 'dart:io';
import 'dart:convert';
import 'location.dart';

class Post {
  final String id;
  final String user;
  final String title;
  final String description;
  final String locationName;
  final GeoLocation location;
  final List<File> images;
  final List<String> imageUrls;
  final List<String> originalImageUrls; // Original images for gallery view
  final List<String> photoIds; // IDs of all photos in this post/location
  final DateTime createdAt;
  
  Post({
    required this.id,
    required this.user,
    this.title = '',
    required this.description,
    required this.locationName,
    required this.location,
    required this.images,
    this.imageUrls = const [],
    this.originalImageUrls = const [],
    this.photoIds = const [],
    required this.createdAt,
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
      'user': user,
      'title': title,
      'description': description,
      'locationName': locationName,
      'location': {
        'latitude': location.latitude,
        'longitude': location.longitude,
      },
      'imageUrls': imageUrls,
      'originalImageUrls': originalImageUrls,
      'photoIds': photoIds,
      'createdAt': createdAt.toIso8601String(),
    };
  }
  
  factory Post.fromJson(Map<String, dynamic> json) {
    final imageUrls = List<String>.from(json['imageUrls'] ?? []);
    final originalImageUrls = json['originalImageUrls'] != null 
        ? List<String>.from(json['originalImageUrls'])
        : imageUrls; // Fallback to cropped if no originals
    final photoIds = json['photoIds'] != null
        ? List<String>.from(json['photoIds'])
        : [json['id'].toString()]; // Fallback to main ID if no photoIds
    
    return Post(
      id: json['id'].toString(),
      user: json['user'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      locationName: json['locationName'] ?? '',
      location: GeoLocation(
        latitude: json['location']['latitude'],
        longitude: json['location']['longitude'],
      ),
      images: [],
      imageUrls: imageUrls,
      originalImageUrls: originalImageUrls,
      photoIds: photoIds,
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
} 