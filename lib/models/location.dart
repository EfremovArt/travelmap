class GeoLocation {
  final double latitude;
  final double longitude;

  const GeoLocation({
    required this.latitude, 
    required this.longitude
  });

  // Преобразование в Mapbox Point, когда нужно
  // Используется в методах, где требуется объект типа Point из Mapbox
  Map<String, dynamic> toMapbox() {
    return {
      'type': 'Point',
      'coordinates': [longitude, latitude]
    };
  }

  // Преобразование в карту для сериализации JSON
  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Создание из JSON
  factory GeoLocation.fromJson(Map<String, dynamic> json) {
    return GeoLocation(
      latitude: json['latitude'] as double,
      longitude: json['longitude'] as double,
    );
  }

  @override
  String toString() {
    return 'GeoLocation(lat: $latitude, lng: $longitude)';
  }
} 