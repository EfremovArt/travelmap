import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/mapbox_config.dart';
import '../models/search_result.dart';
import '../utils/logger.dart';
import 'enhanced_search_service.dart';
import 'mapbox_search_box_service.dart';

/// Service class for interacting with the Mapbox API
class MapboxService {
  /// Searches for locations based on the query string with enhanced support for attractions
  static Future<List<SearchResult>> searchLocation(String query) async {
    try {
      // Escape special characters in the query
      final encodedQuery = Uri.encodeComponent(query);
      
      // Create the Mapbox Geocoding API URL with enhanced parameters
      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
          '?access_token=${MapboxConfig.ACCESS_TOKEN}'
          '&limit=20' // Increased limit for more results
          '&language=en'; // English language only for better compatibility
      
      AppLogger.log('Searching for location: $query');
      AppLogger.log('Using URL: $url');
      
      // Make the request
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        // Parse the response
        final data = json.decode(response.body);
        
        if (data['features'] != null && data['features'] is List) {
          // Convert each feature to a SearchResult
          final results = (data['features'] as List)
              .map((feature) => SearchResult.fromJson(feature))
              .toList();
          
          AppLogger.log('Found ${results.length} locations');
          return results;
        }
      } else {
        AppLogger.log('Error searching location: ${response.statusCode}');
        AppLogger.log('Response: ${response.body}');
      }
      
      // Return empty list if something went wrong
      return [];
    } catch (e) {
      AppLogger.log('Error searching location: $e');
      return [];
    }
  }

  /// Специальный поиск только по достопримечательностям (POI)
  static Future<List<SearchResult>> searchAttractions(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      
      // Специальный запрос для поиска достопримечательностей
      // POI включает музеи, парки, памятники, туристические места и т.д.
      // Не ограничиваем страны и не используем proximity для глобального поиска
      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
          '?access_token=${MapboxConfig.ACCESS_TOKEN}'
          '&limit=10'
          '&types=poi' // Points of Interest - достопримечательности
          '&language=en'; // Только английский для корректного отображения
      
      AppLogger.log('Searching for attractions: $query');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['features'] != null && data['features'] is List) {
          // Преобразуем результаты без агрессивной фильтрации
          // Mapbox уже вернул POI, доверяем их результатам
          final results = (data['features'] as List)
              .map((feature) => SearchResult.fromJson(feature))
              .toList();
          
          AppLogger.log('Found ${results.length} POI/attractions');
          return results;
        }
      } else {
        AppLogger.log('Error searching attractions: ${response.statusCode}');
      }
      
      return [];
    } catch (e) {
      AppLogger.log('Error searching attractions: $e');
      return [];
    }
  }

  /// Combined search - finds all types of locations including attractions
  static Future<List<SearchResult>> searchLocationWithAttractions(
    String query, {
    double? proximityLng,
    double? proximityLat,
  }) async {
    try {
      AppLogger.log('🚀 Starting improved combined search for: $query');
      
      // Сначала проверяем доступность Search Box API
      final isSearchBoxAvailable = await MapboxSearchBoxService.isSearchBoxAPIAvailable();
      
      if (isSearchBoxAvailable) {
        AppLogger.log('✅ Search Box API is available, using it for attractions search');
        
        // Используем новый Search Box API с поддержкой proximity
        final searchBoxResults = await MapboxSearchBoxService.comprehensiveAttractionsSearch(
          query,
          proximityLng: proximityLng,
          proximityLat: proximityLat,
        );
        
        if (searchBoxResults.isNotEmpty) {
          AppLogger.log('✅ Search Box API found ${searchBoxResults.length} results');
          return searchBoxResults;
        }
        
        AppLogger.log('⚠️ Search Box API returned no results, trying fallback methods');
      } else {
        AppLogger.log('⚠️ Search Box API not available, using Geocoding API fallback');
      }
      
      // Fallback: Используем улучшенный поиск достопримечательностей через Geocoding API
      final attractionResults = await _searchAttractionsEnhanced(query);
      
      if (attractionResults.isNotEmpty) {
        AppLogger.log('✅ Enhanced attractions search found ${attractionResults.length} results');
        return attractionResults;
      }
      
      // Пробуем глобальный поиск для известных достопримечательностей
      final globalResults = await searchGlobalLandmarks(query);
      
      if (globalResults.isNotEmpty) {
        AppLogger.log('✅ Global landmarks search found ${globalResults.length} results');
        return globalResults;
      }
      
      // Если не нашли достопримечательности, используем универсальный поиск
      AppLogger.log('⚠️ No attractions found, using universal search');
      return await EnhancedSearchService.universalSearch(query);
    } catch (e) {
      AppLogger.log('❌ Error in combined search: $e');
      return [];
    }
  }

  /// Поиск по координатам (reverse geocoding)
  /// Приоритизирует POI (достопримечательности) при поиске
  static Future<String?> reverseGeocode(double lat, double lng) async {
    try {
      AppLogger.log("🔍 Attempting reverse geocoding for: $lat, $lng");
      
      // Шаг 1: Пробуем найти POI через Tilequery API (поиск в радиусе)
      AppLogger.log("🎯 Step 1: Searching for POI using Tilequery API");
      final tilequeryUrl = "https://api.mapbox.com/v4/mapbox.mapbox-streets-v8/tilequery/$lng,$lat.json"
          "?radius=50"  // Радиус поиска в метрах
          "&limit=5"
          "&dedupe"  // Удаляем дубликаты
          "&layers=poi_label"  // Слой с достопримечательностями
          "&access_token=${MapboxConfig.ACCESS_TOKEN}";
      
      AppLogger.log("🌐 Tilequery Request URL: $tilequeryUrl");
      
      try {
        final tilequeryResponse = await http.get(Uri.parse(tilequeryUrl));
        AppLogger.log("📡 Tilequery Response status: ${tilequeryResponse.statusCode}");
        
        if (tilequeryResponse.statusCode == 200) {
          final tilequeryData = jsonDecode(tilequeryResponse.body);
          final features = tilequeryData['features'] as List<dynamic>?;
          
          AppLogger.log("🔍 Tilequery features count: ${features?.length ?? 0}");
          
          if (features != null && features.isNotEmpty) {
            // Нашли POI через Tilequery! Берем первый (самый близкий)
            final poi = features[0];
            final properties = poi['properties'] as Map<String, dynamic>?;
            final poiName = properties?['name'] ?? properties?['name_en'] ?? properties?['class'];
            
            if (poiName != null && poiName.toString().isNotEmpty) {
              AppLogger.log("✅ Found POI via Tilequery: $poiName");
              return poiName.toString();
            }
          }
        }
      } catch (e) {
        AppLogger.log("⚠️ Tilequery API error (will try geocoding): $e");
      }
      
      // Шаг 2: Если Tilequery не сработал, пробуем стандартный Geocoding API
      AppLogger.log("🎯 Step 2: Searching for POI using Geocoding API");
      final poiUrl = "https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json"
          "?access_token=${MapboxConfig.ACCESS_TOKEN}"
          "&types=poi"  // Только достопримечательности
          "&limit=10"   // Увеличиваем лимит для большего охвата
          "&proximity=$lng,$lat"  // Приоритизируем результаты рядом с точкой клика
          "&language=en,ru";  // Поддержка русского и английского
      
      AppLogger.log("🌐 POI Request URL: $poiUrl");
      final poiResponse = await http.get(Uri.parse(poiUrl));
      
      AppLogger.log("📡 POI Response status: ${poiResponse.statusCode}");
      AppLogger.log("📦 POI Response body: ${poiResponse.body.substring(0, poiResponse.body.length > 500 ? 500 : poiResponse.body.length)}...");
      
      if (poiResponse.statusCode == 200) {
        final poiData = jsonDecode(poiResponse.body);
        final poiFeatures = poiData['features'] as List<dynamic>?;
        
        AppLogger.log("🔍 POI features count: ${poiFeatures?.length ?? 0}");
        
        if (poiFeatures != null && poiFeatures.isNotEmpty) {
          // Нашли POI! Берем первый (самый близкий)
          final poi = poiFeatures[0];
          final poiName = poi['text'] ?? poi['place_name'];
          AppLogger.log("✅ Found POI via Geocoding: $poiName");
          return poiName;
        } else {
          AppLogger.log("⚠️ No POI found in this location");
        }
      } else {
        AppLogger.log("❌ POI request failed with status: ${poiResponse.statusCode}");
      }
      
      // Шаг 3: Если POI не найден, ищем любые типы мест
      AppLogger.log("🔍 Step 3: Searching for any place type");
      final generalUrl = "https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json"
          "?access_token=${MapboxConfig.ACCESS_TOKEN}"
          "&types=poi,address,place,locality,neighborhood"
          // Не используем limit при reverse geocoding с несколькими типами (вызывает ошибку 422)
          "&language=en,ru";
      
      AppLogger.log("🌐 General Request URL: $generalUrl");
      final generalResponse = await http.get(Uri.parse(generalUrl));
      
      AppLogger.log("📡 General Response status: ${generalResponse.statusCode}");
      AppLogger.log("📦 General Response body: ${generalResponse.body.substring(0, generalResponse.body.length > 500 ? 500 : generalResponse.body.length)}...");
      
      if (generalResponse.statusCode == 200) {
        final generalData = jsonDecode(generalResponse.body);
        final generalFeatures = generalData['features'] as List<dynamic>?;
        
        AppLogger.log("🔍 General features count: ${generalFeatures?.length ?? 0}");
        
        if (generalFeatures != null && generalFeatures.isNotEmpty) {
          // Еще раз проверяем, может быть есть POI среди результатов
          for (var feature in generalFeatures) {
            final placeType = feature['place_type'] as List<dynamic>?;
            if (placeType != null && placeType.contains('poi')) {
              final name = feature['text'] ?? feature['place_name'];
              AppLogger.log("✅ Found POI in general search: $name");
              return name;
            }
          }
          
          // Если POI все равно не найден, возвращаем первый результат
          final name = generalFeatures[0]['place_name'];
          AppLogger.log("✅ Reverse geocoding successful (address/place): $name");
          return name;
        } else {
          AppLogger.log("⚠️ No features found in general search");
        }
      } else {
        AppLogger.log("❌ General request failed with status: ${generalResponse.statusCode}");
      }
      
      AppLogger.log("⚠️ Reverse geocoding returned no results");
      return null;
    } catch (e) {
      AppLogger.log("❌ Error during reverse geocoding: $e");
      return null;
    }
  }

  /// Улучшенный поиск достопримечательностей с несколькими стратегиями
  static Future<List<SearchResult>> _searchAttractionsEnhanced(String query) async {
    try {
      AppLogger.log('🏛️ Starting enhanced attractions search for: $query');
      
      final Map<String, SearchResult> uniqueResults = {};
      
      // Стратегия 1: Прямой поиск достопримечательностей
      final directResults = await _searchPOIWithAttractionFocus(query);
      for (final result in directResults) {
        final key = '${result.latitude}_${result.longitude}';
        uniqueResults[key] = result;
      }
      
      // Стратегия 2: Поиск с ключевыми словами достопримечательностей
      if (uniqueResults.length < 3) {
        final attractionKeywords = ['museum', 'palace', 'castle', 'cathedral', 'monument', 'square', 'tower'];
        
        for (final keyword in attractionKeywords) {
          final keywordResults = await _searchWithKeyword(query, keyword);
          for (final result in keywordResults) {
            final key = '${result.latitude}_${result.longitude}';
            if (!uniqueResults.containsKey(key)) {
              uniqueResults[key] = result;
            }
          }
          
          // Если нашли достаточно результатов, прерываем поиск
          if (uniqueResults.length >= 10) break;
        }
      }
      
      final finalResults = uniqueResults.values.toList();
      AppLogger.log('🎯 Enhanced attractions search completed: ${finalResults.length} unique results');
      
      return finalResults;
    } catch (e) {
      AppLogger.log('❌ Error in enhanced attractions search: $e');
      return [];
    }
  }
  
  /// Поиск POI с фокусом на достопримечательности
  static Future<List<SearchResult>> _searchPOIWithAttractionFocus(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      
      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
          '?access_token=${MapboxConfig.ACCESS_TOKEN}'
          '&limit=20'
          '&types=poi'
          '&language=ru,en'
          '&fuzzyMatch=true'
          '&bbox=-180,-85,180,85'; // Глобальный поиск
      
      AppLogger.log('🔍 POI search with attraction focus: $query');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['features'] != null && data['features'] is List) {
          final features = data['features'] as List;
          final results = <SearchResult>[];
          
          for (final feature in features) {
            final result = SearchResult.fromJson(feature);
            
            // Фильтруем и приоритизируем достопримечательности
            final placeName = result.placeName.toLowerCase();
            final context = feature['context']?.toString().toLowerCase() ?? '';
            final properties = feature['properties']?.toString().toLowerCase() ?? '';
            
            // Проверяем, является ли это достопримечательностью
            final isAttraction = _isAttractionResult(placeName, context, properties);
            
            if (isAttraction) {
              results.insert(0, result); // Добавляем в начало для приоритета
            } else {
              results.add(result);
            }
          }
          
          AppLogger.log('✅ Found ${results.length} POI results (attractions prioritized)');
          return results;
        }
      } else {
        AppLogger.log('❌ Error in POI search: ${response.statusCode}');
      }
      
      return [];
    } catch (e) {
      AppLogger.log('❌ Error in POI search: $e');
      return [];
    }
  }
  
  /// Поиск с дополнительным ключевым словом
  static Future<List<SearchResult>> _searchWithKeyword(String query, String keyword) async {
    try {
      final searchQuery = '$query $keyword';
      final encodedQuery = Uri.encodeComponent(searchQuery);
      
      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
          '?access_token=${MapboxConfig.ACCESS_TOKEN}'
          '&limit=5'
          '&types=poi'
          '&language=ru,en'
          '&fuzzyMatch=true'
          '&bbox=-180,-85,180,85';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['features'] != null && data['features'] is List) {
          final results = (data['features'] as List)
              .map((feature) => SearchResult.fromJson(feature))
              .toList();
          
          return results;
        }
      }
      
      return [];
    } catch (e) {
      AppLogger.log('❌ Error in keyword search: $e');
      return [];
    }
  }
  
  /// Проверяет, является ли результат поиска достопримечательностью
  static bool _isAttractionResult(String placeName, String context, String properties) {
    final attractionIndicators = [
      'museum', 'palace', 'castle', 'cathedral', 'church', 'temple', 'monastery',
      'monument', 'memorial', 'statue', 'tower', 'bridge', 'square', 'plaza',
      'park', 'garden', 'zoo', 'aquarium', 'gallery', 'theater', 'opera',
      'fortress', 'kremlin', 'abbey', 'basilica', 'shrine', 'tomb', 'mausoleum',
      'historic', 'heritage', 'landmark', 'attraction', 'tourist', 'unesco'
    ];
    
    final searchText = '$placeName $context $properties'.toLowerCase();
    
    return attractionIndicators.any((indicator) => searchText.contains(indicator));
  }

  /// Поиск популярных достопримечательностей в городе
  static Future<List<SearchResult>> searchPopularAttractions(String city) async {
    return await EnhancedSearchService.searchPopularAttractions(city);
  }
  
  /// Глобальный поиск известных достопримечательностей без ограничения по региону
  static Future<List<SearchResult>> searchGlobalLandmarks(String query) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      
      // Улучшенный поиск достопримечательностей с лучшими параметрами
      final url = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$encodedQuery.json'
          '?access_token=${MapboxConfig.ACCESS_TOKEN}'
          '&limit=15' // Увеличили лимит
          '&types=poi,place' // POI и места для достопримечательностей
          '&language=ru,en' // Поддержка русского и английского языков
          '&fuzzyMatch=true' // Нечеткий поиск для лучших результатов
          '&routing=false' // Не нужна маршрутизация
          '&bbox=-180,-85,180,85'; // Глобальный поиск без ограничений
      
      AppLogger.log('🌍 Global landmark search for: $query');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['features'] != null && data['features'] is List) {
          // Фильтруем и сортируем результаты
          final features = data['features'] as List;
          final results = <SearchResult>[];
          
          for (final feature in features) {
            final result = SearchResult.fromJson(feature);
            
            // Приоритизируем достопримечательности и известные места
            final placeName = result.placeName.toLowerCase();
            final isAttraction = placeName.contains('museum') || 
                               placeName.contains('palace') || 
                               placeName.contains('castle') || 
                               placeName.contains('cathedral') || 
                               placeName.contains('monument') || 
                               placeName.contains('temple') || 
                               placeName.contains('tower') ||
                               placeName.contains('square') ||
                               placeName.contains('park') ||
                               feature['properties']?['category']?.contains('landmark') == true;
            
            if (isAttraction) {
              results.insert(0, result); // Добавляем в начало для приоритета
            } else {
              results.add(result);
            }
          }
          
          AppLogger.log('✅ Found ${results.length} global landmarks (prioritized attractions)');
          return results;
        }
      } else {
        AppLogger.log('❌ Error searching global landmarks: ${response.statusCode}');
      }
      
      return [];
    } catch (e) {
      AppLogger.log('❌ Error searching global landmarks: $e');
      return [];
    }
  }
  
  /// Поиск ресторанов и кафе
  static Future<List<SearchResult>> searchRestaurants(String query) async {
    return await EnhancedSearchService.searchRestaurants(query);
  }

  /// Поиск отелей и размещения
  static Future<List<SearchResult>> searchHotels(String query) async {
    return await EnhancedSearchService.searchHotels(query);
  }

  /// Поиск по категориям
  static Future<List<SearchResult>> searchByCategory(String category, {String? location}) async {
    return await EnhancedSearchService.searchByCategory(category, location: location);
  }
} 