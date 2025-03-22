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
    
    return SearchResult(
      name: shortName,
      location: GeoLocation(
        latitude: lat,
        longitude: lng,
      ),
      placeName: shortName,
      placeAddress: address.isEmpty ? fullName : address,
    );
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