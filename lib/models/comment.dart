import 'dart:convert';

class Comment {
  final int id;
  final int userId;
  final String photoId;
  final String text;
  final DateTime createdAt;
  // Дополнительные данные о пользователе для отображения
  final String? userFirstName;
  final String? userLastName;
  final String? userProfileImageUrl;

  Comment({
    required this.id,
    required this.userId,
    required this.photoId,
    required this.text,
    required this.createdAt,
    this.userFirstName,
    this.userLastName,
    this.userProfileImageUrl,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    // Преобразуем id и userId из любого типа (строка или число) в int
    int parseId(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    
    return Comment(
      id: parseId(json['id']),
      userId: parseId(json['userId']),
      photoId: json['photoId'].toString(),
      text: json['text'],
      createdAt: DateTime.parse(json['createdAt']),
      userFirstName: json['userFirstName'],
      userLastName: json['userLastName'],
      userProfileImageUrl: json['userProfileImageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'photoId': photoId,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'userFirstName': userFirstName,
      'userLastName': userLastName,
      'userProfileImageUrl': userProfileImageUrl,
    };
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  factory Comment.fromJsonString(String jsonString) {
    final Map<String, dynamic> json = jsonDecode(jsonString);
    return Comment.fromJson(json);
  }
} 