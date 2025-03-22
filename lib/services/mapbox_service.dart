import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/mapbox_config.dart';
import '../models/search_result.dart';

/// Service class for interacting with the Mapbox API
class MapboxService {
  /// Searches for locations based on the query string
  static Future<List<SearchResult>> searchLocation(String query) async {
    try {
      // Escape special characters in the query
      final encodedQuery = Uri.encodeComponent(query);
      
      // Create the Mapbox Geocoding API URL
      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
          '?access_token=${MapboxConfig.ACCESS_TOKEN}'
          '&limit=5'; // Limit results to 5 items
      
      // Make the request
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        // Parse the response
        final data = json.decode(response.body);
        
        if (data['features'] != null && data['features'] is List) {
          // Convert each feature to a SearchResult
          return (data['features'] as List)
              .map((feature) => SearchResult.fromJson(feature))
              .toList();
        }
      }
      
      // Return empty list if something went wrong
      return [];
    } catch (e) {
      print('Error searching location: $e');
      return [];
    }
  }
} 