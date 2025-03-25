import 'dart:convert';

/// Модель для хранения избранных постов пользователя
class Favorite {
  final String userId; // ID пользователя, который добавил пост в избранное
  final String postId; // ID поста, который добавлен в избранное
  final DateTime createdAt; // Дата добавления в избранное

  Favorite({
    required this.userId,
    required this.postId,
    required this.createdAt,
  });

  // Сериализация в JSON
  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'postId': postId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  // Десериализация из JSON
  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      userId: json['userId'] as String,
      postId: json['postId'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    );
  }

  // Метод для конвертации объекта в строку JSON
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // Метод для создания объекта из строки JSON
  static Favorite fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString);
    return Favorite.fromJson(json);
  }
} 