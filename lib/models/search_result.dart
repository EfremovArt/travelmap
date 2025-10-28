import 'location.dart';

class SearchResult {
  final String name;
  final GeoLocation location;
  final String placeName;
  final String placeAddress;
  
  // Геттеры для совместимости с обновленным кодом
  double get latitude => location.latitude;
  double get longitude => location.longitude;

  SearchResult({
    required this.name,
    required this.location,
    required this.placeName,
    required this.placeAddress,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    final List<dynamic> coordinates = json['center'];
    final double lng = coordinates[0];
    final double lat = coordinates[1];
    
    final String fullName = json['place_name'] ?? 'Unknown location';
    final String shortName = json['text'] ?? 'Unknown';
    final String address = _formatAddress(json);
    
    // Определяем тип локации для лучшего отображения
    final List<dynamic> placeTypes = json['place_type'] ?? [];
    final String locationType = _getLocationType(placeTypes);
    
    // Формируем более информативное название
    String displayName = shortName;
    if (locationType.isNotEmpty) {
      displayName = '$shortName ($locationType)';
    }
    
    return SearchResult(
      name: displayName,
      location: GeoLocation(
        latitude: lat,
        longitude: lng,
      ),
      placeName: fullName, // Используем полное название для placeName
      placeAddress: address.isEmpty ? fullName : address,
    );
  }
  
  static String _getLocationType(List<dynamic> placeTypes) {
    if (placeTypes.isEmpty) return '';
    
    // Mapping location types to English
    final Map<String, String> typeMapping = {
      'poi': 'Attraction',
      'attraction': 'Attraction',
      'museum': 'Museum',
      'restaurant': 'Restaurant',
      'hotel': 'Hotel',
      'park': 'Park',
      'airport': 'Airport',
      'station': 'Station',
      'place': 'Place',
      'locality': 'Locality',
      'neighborhood': 'Neighborhood',
      'address': 'Address',
      'country': 'Country',
      'region': 'Region',
      'district': 'District',
      'postcode': 'Postcode',
    };
    
    // Find first known type
    for (final type in placeTypes) {
      if (type is String && typeMapping.containsKey(type)) {
        return typeMapping[type]!;
      }
    }
    
    return '';
  }
  
  static String _formatAddress(Map<String, dynamic> json) {
    String address = '';
    
    // Извлечение контекста (части адреса)
    if (json.containsKey('context') && json['context'] is List) {
      List<dynamic> context = json['context'];
      List<String> parts = [];
      
      for (var item in context) {
        if (item is Map && item.containsKey('text')) {
          parts.add(item['text']);
        }
      }
      
      address = parts.join(', ');
    }
    
    return address;
  }
} 