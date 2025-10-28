import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/mapbox_config.dart';
import '../models/search_result.dart';
import '../utils/logger.dart';

/// Расширенный сервис поиска с поддержкой различных типов локаций
class EnhancedSearchService {
  
  /// Поиск по категориям достопримечательностей
  static Future<List<SearchResult>> searchByCategory(String category, {String? location}) async {
    try {
      final query = location != null ? '$category near $location' : category;
      final encodedQuery = Uri.encodeComponent(query);
      
      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
          '?access_token=${MapboxConfig.ACCESS_TOKEN}'
          '&limit=20'
          '&types=poi'
          '&language=ru,en' // Поддержка русского и английского
          '&fuzzyMatch=true' // Нечеткий поиск
          '&bbox=-180,-85,180,85'; // Глобальный поиск
      
      AppLogger.log('Searching by category: $category');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['features'] != null && data['features'] is List) {
          final results = (data['features'] as List)
              .map((feature) => SearchResult.fromJson(feature))
              .toList();
          
          AppLogger.log('Found ${results.length} results for category: $category');
          return results;
        }
      } else {
        AppLogger.log('Error searching by category: ${response.statusCode}');
      }
      
      return [];
    } catch (e) {
      AppLogger.log('Error searching by category: $e');
      return [];
    }
  }
  
  /// Поиск популярных достопримечательностей в городе
  static Future<List<SearchResult>> searchPopularAttractions(String city) async {
    try {
      final popularCategories = [
        'museum',
        'attraction',
        'monument',
        'park',
        'gallery',
        'castle',
        'cathedral',
        'temple',
        'palace',
        'tower'
      ];
      
      final List<SearchResult> allResults = [];
      
      // Ищем по каждой категории
      for (final category in popularCategories) {
        final results = await searchByCategory(category, location: city);
        allResults.addAll(results);
      }
      
      // Убираем дубликаты
      final Map<String, SearchResult> uniqueResults = {};
      for (final result in allResults) {
        final key = '${result.latitude}_${result.longitude}';
        uniqueResults[key] = result;
      }
      
      final uniqueList = uniqueResults.values.toList();
      AppLogger.log('Found ${uniqueList.length} unique popular attractions in $city');
      
      return uniqueList;
    } catch (e) {
      AppLogger.log('Error searching popular attractions: $e');
      return [];
    }
  }
  
  /// Поиск ресторанов и кафе
  static Future<List<SearchResult>> searchRestaurants(String query) async {
    try {
      final restaurantCategories = [
        'restaurant',
        'cafe',
        'bar',
        'food',
        'dining'
      ];
      
      final List<SearchResult> allResults = [];
      
      for (final category in restaurantCategories) {
        final searchQuery = '$query $category';
        final encodedQuery = Uri.encodeComponent(searchQuery);
        
        final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
            '?access_token=${MapboxConfig.ACCESS_TOKEN}'
            '&limit=10'
            '&types=poi'
            '&language=ru,en'
            '&country=RU,US,GB,DE,FR,IT,ES,CN,JP,KR'
            '&proximity=ip';
        
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          if (data['features'] != null && data['features'] is List) {
            final results = (data['features'] as List)
                .map((feature) => SearchResult.fromJson(feature))
                .toList();
            
            allResults.addAll(results);
          }
        }
      }
      
      // Убираем дубликаты
      final Map<String, SearchResult> uniqueResults = {};
      for (final result in allResults) {
        final key = '${result.latitude}_${result.longitude}';
        uniqueResults[key] = result;
      }
      
      final uniqueList = uniqueResults.values.toList();
      AppLogger.log('Found ${uniqueList.length} unique restaurants for: $query');
      
      return uniqueList;
    } catch (e) {
      AppLogger.log('Error searching restaurants: $e');
      return [];
    }
  }
  
  /// Поиск отелей и размещения
  static Future<List<SearchResult>> searchHotels(String query) async {
    try {
      final hotelCategories = [
        'hotel',
        'lodging',
        'hostel',
        'resort',
        'accommodation'
      ];
      
      final List<SearchResult> allResults = [];
      
      for (final category in hotelCategories) {
        final searchQuery = '$query $category';
        final encodedQuery = Uri.encodeComponent(searchQuery);
        
        final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
            '?access_token=${MapboxConfig.ACCESS_TOKEN}'
            '&limit=10'
            '&types=poi'
            '&language=ru,en'
            '&country=RU,US,GB,DE,FR,IT,ES,CN,JP,KR'
            '&proximity=ip';
        
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          
          if (data['features'] != null && data['features'] is List) {
            final results = (data['features'] as List)
                .map((feature) => SearchResult.fromJson(feature))
                .toList();
            
            allResults.addAll(results);
          }
        }
      }
      
      // Убираем дубликаты
      final Map<String, SearchResult> uniqueResults = {};
      for (final result in allResults) {
        final key = '${result.latitude}_${result.longitude}';
        uniqueResults[key] = result;
      }
      
      final uniqueList = uniqueResults.values.toList();
      AppLogger.log('Found ${uniqueList.length} unique hotels for: $query');
      
      return uniqueList;
    } catch (e) {
      AppLogger.log('Error searching hotels: $e');
      return [];
    }
  }
  
  /// Универсальный поиск с поддержкой всех типов локаций
  static Future<List<SearchResult>> universalSearch(String query) async {
    try {
      AppLogger.log('Starting universal search for: $query');
      
      // Выполняем несколько типов поиска параллельно
      final futures = await Future.wait([
        _searchGeneral(query),
        _searchPOI(query),
        _searchPlaces(query),
        _searchAddresses(query),
      ]);
      
      final generalResults = futures[0];
      final poiResults = futures[1];
      final placesResults = futures[2];
      final addressesResults = futures[3];
      
      // Объединяем результаты, убираем дубликаты
      final Map<String, SearchResult> uniqueResults = {};
      
      // Добавляем результаты в порядке приоритета
      final allResults = [
        ...poiResults,      // Достопримечательности имеют высший приоритет
        ...placesResults,   // Места
        ...addressesResults, // Адреса
        ...generalResults,  // Общие результаты
      ];
      
      for (final result in allResults) {
        final key = '${result.latitude}_${result.longitude}';
        if (!uniqueResults.containsKey(key)) {
          uniqueResults[key] = result;
        }
      }
      
      final combinedResults = uniqueResults.values.toList();
      AppLogger.log('Universal search found ${combinedResults.length} unique locations');
      
      return combinedResults;
    } catch (e) {
      AppLogger.log('Error in universal search: $e');
      return [];
    }
  }
  
  /// Вспомогательный метод для общего поиска
  static Future<List<SearchResult>> _searchGeneral(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
        '?access_token=${MapboxConfig.ACCESS_TOKEN}'
        '&limit=10'
        '&language=ru,en'
        '&country=RU,US,GB,DE,FR,IT,ES,CN,JP,KR'
        '&proximity=ip';
    
    return _performSearch(url);
  }
  
  /// Вспомогательный метод для поиска POI
  static Future<List<SearchResult>> _searchPOI(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
        '?access_token=${MapboxConfig.ACCESS_TOKEN}'
        '&limit=15'
        '&types=poi'
        '&language=ru,en'
        '&country=RU,US,GB,DE,FR,IT,ES,CN,JP,KR'
        '&proximity=ip';
    
    return _performSearch(url);
  }
  
  /// Вспомогательный метод для поиска мест
  static Future<List<SearchResult>> _searchPlaces(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
        '?access_token=${MapboxConfig.ACCESS_TOKEN}'
        '&limit=10'
        '&types=place,locality,neighborhood'
        '&language=ru,en'
        '&country=RU,US,GB,DE,FR,IT,ES,CN,JP,KR'
        '&proximity=ip';
    
    return _performSearch(url);
  }
  
  /// Вспомогательный метод для поиска адресов
  static Future<List<SearchResult>> _searchAddresses(String query) async {
    final encodedQuery = Uri.encodeComponent(query);
    final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
        '?access_token=${MapboxConfig.ACCESS_TOKEN}'
        '&limit=10'
        '&types=address'
        '&language=ru,en'
        '&country=RU,US,GB,DE,FR,IT,ES,CN,JP,KR'
        '&proximity=ip';
    
    return _performSearch(url);
  }
  
  /// Вспомогательный метод для выполнения HTTP запроса
  static Future<List<SearchResult>> _performSearch(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['features'] != null && data['features'] is List) {
          final results = (data['features'] as List)
              .map((feature) => SearchResult.fromJson(feature))
              .toList();
          
          return results;
        }
      } else {
        AppLogger.log('Error in search request: ${response.statusCode}');
      }
      
      return [];
    } catch (e) {
      AppLogger.log('Error performing search: $e');
      return [];
    }
  }
}

