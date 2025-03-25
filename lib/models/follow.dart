import 'dart:convert';

/// Модель для хранения подписок пользователя
class Follow {
  final String followerId; // ID пользователя, который подписался
  final String followedId; // ID пользователя, на которого подписались
  final DateTime createdAt; // Дата подписки

  Follow({
    required this.followerId,
    required this.followedId,
    required this.createdAt,
  });

  // Сериализация в JSON
  Map<String, dynamic> toJson() {
    return {
      'followerId': followerId,
      'followedId': followedId,
      'createdAt': createdAt.millisecondsSinceEpoch,
    };
  }

  // Десериализация из JSON
  factory Follow.fromJson(Map<String, dynamic> json) {
    return Follow(
      followerId: json['followerId'] as String,
      followedId: json['followedId'] as String,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
    );
  }

  // Метод для конвертации объекта в строку JSON
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // Метод для создания объекта из строки JSON
  static Follow fromJsonString(String jsonString) {
    final json = jsonDecode(jsonString);
    return Follow.fromJson(json);
  }
} 