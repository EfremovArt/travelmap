class CommercialPost {
  final int id;
  final int userId;
  final int? albumId; // Nullable для standalone и photo постов
  final int? photoId; // Новое поле для привязки к фото
  final String type; // 'album', 'photo', 'standalone'
  final String title;
  final String? description;
  final String? imageUrl; // Deprecated - use imageUrls instead
  final List<String> imageUrls; // Multiple images support (cropped for feed)
  final List<String> originalImageUrls; // Original images for gallery view
  final double? price;
  final String currency;
  final String? contactInfo;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  // Поля локации
  final double? latitude;
  final double? longitude;
  final String? locationName;
  
  // Дополнительные поля для отображения
  final String? userName;
  final String? userProfileImage;
  final String? albumTitle;
  final String? photoTitle;
  final String? photoUrl;

  CommercialPost({
    required this.id,
    required this.userId,
    this.albumId,
    this.photoId,
    required this.type,
    required this.title,
    this.description,
    this.imageUrl,
    this.imageUrls = const [],
    this.originalImageUrls = const [],
    this.price,
    this.currency = 'USD',
    this.contactInfo,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.latitude,
    this.longitude,
    this.locationName,
    this.userName,
    this.userProfileImage,
    this.albumTitle,
    this.photoTitle,
    this.photoUrl,
  });

  factory CommercialPost.fromJson(Map<String, dynamic> json) {
    try {
      // Обработка множественных изображений (cropped для ленты)
      List<String> imageUrls = [];
      if (json['images'] != null && json['images'] is List) {
        imageUrls = (json['images'] as List)
            .where((img) => img != null)
            .map((img) => img.toString())
            .toList();
      } else if (json['image_url'] != null && json['image_url'].toString().isNotEmpty) {
        // Fallback для старых постов с одним изображением
        imageUrls = [json['image_url'].toString()];
      }
      
      // Обработка оригинальных изображений (для галереи)
      List<String> originalImageUrls = [];
      if (json['original_images'] != null && json['original_images'] is List) {
        originalImageUrls = (json['original_images'] as List)
            .where((img) => img != null)
            .map((img) => img.toString())
            .toList();
      } else {
        // Если нет оригинальных изображений, используем cropped (обратная совместимость)
        originalImageUrls = imageUrls;
      }

      final latitude = json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null;
      final longitude = json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null;
      final locationName = json['location_name']?.toString();

      // Безопасное получение ID
      final id = json['id'] != null ? (int.tryParse(json['id'].toString()) ?? 0) : 0;
      final userId = json['user_id'] != null ? (int.tryParse(json['user_id'].toString()) ?? 0) : 0;

      return CommercialPost(
        id: id,
        userId: userId,
        albumId: json['album_id'] != null ? int.tryParse(json['album_id'].toString()) : null,
        photoId: json['photo_id'] != null ? int.tryParse(json['photo_id'].toString()) : null,
        type: json['type']?.toString() ?? 'standalone',
        title: json['title']?.toString() ?? '',
        description: json['description']?.toString(),
        imageUrl: json['image_url']?.toString(), // Keep for backward compatibility
        imageUrls: imageUrls,
        originalImageUrls: originalImageUrls,
        price: json['price'] != null ? double.tryParse(json['price'].toString()) : null,
        currency: json['currency']?.toString() ?? 'USD',
        contactInfo: json['contact_info']?.toString(),
        isActive: json['is_active'] == 1 || json['is_active'] == true || json['is_active']?.toString() == '1',
        createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
        updatedAt: DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? DateTime.now(),
        latitude: latitude,
        longitude: longitude,
        locationName: locationName,
        userName: json['user_name']?.toString(),
        userProfileImage: json['user_profile_image']?.toString(),
        albumTitle: json['album_title']?.toString(),
        photoTitle: json['photo_title']?.toString(),
        photoUrl: json['photo_url']?.toString(),
      );
    } catch (e) {
      throw Exception('Ошибка парсинга CommercialPost: $e. JSON: $json');
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'album_id': albumId,
      'photo_id': photoId,
      'type': type,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'images': imageUrls,
      'original_images': originalImageUrls,
      'price': price,
      'currency': currency,
      'contact_info': contactInfo,
      'is_active': isActive ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'location_name': locationName,
    };
  }

  String get formattedPrice {
    if (price == null) return '';
    return '${price!.toStringAsFixed(2)} $currency';
  }

  String get shortDescription {
    if (description == null || description!.isEmpty) return '';
    if (description!.length <= 100) return description!;
    return '${description!.substring(0, 100)}...';
  }

  // Удобные геттеры для работы с изображениями
  bool get hasImages => imageUrls.isNotEmpty;
  
  String? get firstImageUrl => imageUrls.isNotEmpty ? imageUrls.first : imageUrl;
  
  int get imagesCount => imageUrls.length;
  
  // Удобный геттер для проверки наличия локации
  bool get hasLocation => latitude != null && longitude != null;
  
  // Геттеры для типов коммерческих постов (основаны на связях, а не на типе)
  bool get isAlbumPost => albumId != null;
  bool get isPhotoPost => photoId != null;
  bool get isStandalonePost => albumId == null && photoId == null;
  
  // Удобный геттер для получения связанного контента
  String get contextTitle {
    if (isAlbumPost && albumTitle != null) return albumTitle!;
    if (isPhotoPost && photoTitle != null) return photoTitle!;
    return title;
  }
}
