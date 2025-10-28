import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/mapbox_config.dart';
import '../models/search_result.dart';
import '../utils/logger.dart';

/// Правильная реализация Mapbox Search Box API для поиска достопримечательностей
class MapboxSearchBoxService {
  
  /// Поиск достопримечательностей с использованием Search Box API suggest endpoint
  /// Добавлена поддержка приоритета по близости через proximity
  static Future<List<SearchResult>> searchAttractions(
    String query, {
    double? proximityLng,
    double? proximityLat,
  }) async {
    try {
      AppLogger.log('🌍 Starting multilingual attractions search for: $query');
      
      // Минимальная длина запроса для Search Box (меньше — сразу fallback)
      if (query.trim().length < 2) {
        AppLogger.log('⚠️ Query too short for Search Box, returning empty to trigger fallback');
        return [];
      }
      
      final Map<String, SearchResult> uniqueResults = {};
      
      // Сначала пробуем поиск на русском языке
      final russianResults = await _performAttractionsSearch(
        query,
        'ru',
        proximityLng: proximityLng,
        proximityLat: proximityLat,
      );
      for (final result in russianResults) {
        final key = '${result.latitude}_${result.longitude}';
        uniqueResults[key] = result;
      }
      
      // Если недостаточно результатов, пробуем на английском
      if (uniqueResults.length < 3) {
        AppLogger.log('🔍 Not enough results in Russian, trying English translation');
        final englishQuery = _translateToEnglish(query);
        if (englishQuery != query) {
          final englishResults = await _performAttractionsSearch(
            englishQuery,
            'en',
            proximityLng: proximityLng,
            proximityLat: proximityLat,
          );
          for (final result in englishResults) {
            final key = '${result.latitude}_${result.longitude}';
            if (!uniqueResults.containsKey(key)) {
              uniqueResults[key] = result;
            }
          }
        }
      }
      
      // Если все еще мало результатов, пробуем оригинальный запрос на английском
      if (uniqueResults.length < 3 && query.toLowerCase() != _translateToEnglish(query).toLowerCase()) {
        AppLogger.log('🔍 Trying original query in English');
        final originalEnglishResults = await _performAttractionsSearch(
          query,
          'en',
          proximityLng: proximityLng,
          proximityLat: proximityLat,
        );
        for (final result in originalEnglishResults) {
          final key = '${result.latitude}_${result.longitude}';
          if (!uniqueResults.containsKey(key)) {
            uniqueResults[key] = result;
          }
        }
      }
      
      final finalResults = uniqueResults.values.toList();
      AppLogger.log('✅ Multilingual search found ${finalResults.length} attractions');
      return finalResults;
    } catch (e) {
      AppLogger.log('❌ Error in multilingual attractions search: $e');
      return [];
    }
  }
  
  /// Выполняет поиск достопримечательностей на конкретном языке
  static Future<List<SearchResult>> _performAttractionsSearch(
    String query,
    String language, {
    double? proximityLng,
    double? proximityLat,
  }) async {
    try {
      final encodedQuery = Uri.encodeComponent(query);
      final sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
      
      // Формируем proximity
      final hasProximity = proximityLng != null && proximityLat != null;
      final proximityParam = hasProximity ? '&proximity=${proximityLng!.toStringAsFixed(6)},${proximityLat!.toStringAsFixed(6)}' : '';
      
      // Запрос с приоритетом POI; без origin; limit=10
      final url = 'https://api.mapbox.com/search/searchbox/v1/suggest'
          '?q=$encodedQuery'
          '&access_token=${MapboxConfig.ACCESS_TOKEN}'
          '&session_token=$sessionToken'
          '&language=$language'
          '&limit=10'
          '&types=poi'
          '$proximityParam';
      
      AppLogger.log('🏛️ Search Box API $language request: $query${hasProximity ? ' with proximity' : ''}');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['suggestions'] != null && data['suggestions'] is List) {
          final suggestions = List<Map<String, dynamic>>.from(data['suggestions']);
          AppLogger.log('📊 Found ${suggestions.length} suggestions in $language');
          
          // Сортируем: 1) feature_type=poi вперед; 2) по distance если есть
          suggestions.sort((a, b) {
            final aIsPoi = (a['feature_type'] ?? '') == 'poi';
            final bIsPoi = (b['feature_type'] ?? '') == 'poi';
            if (aIsPoi != bIsPoi) return aIsPoi ? -1 : 1;
            final aDist = (a['distance'] is num) ? (a['distance'] as num).toDouble() : double.infinity;
            final bDist = (b['distance'] is num) ? (b['distance'] as num).toDouble() : double.infinity;
            return aDist.compareTo(bDist);
          });
          
          final results = <SearchResult>[];
          
          for (int i = 0; i < suggestions.length; i++) {
            final suggestion = suggestions[i];
            
            if (suggestion['mapbox_id'] != null) {
              final originalName = suggestion['name']?.toString();
              final retrieveResult = await _retrievePOIDetails(
                suggestion['mapbox_id'], 
                sessionToken, 
                originalName: originalName
              );
              if (retrieveResult != null) {
                results.add(retrieveResult);
                AppLogger.log('✅ Retrieved $language result $i: ${suggestion['name']}');
              }
            }
          }
          
          return results;
        }
      } else {
        AppLogger.log('❌ Search Box API $language error: ${response.statusCode}');
      }
      
      return [];
    } catch (e) {
      AppLogger.log('❌ Error in $language attractions search: $e');
      return [];
    }
  }
  
  /// Переводит популярные достопримечательности с русского на английский
  static String _translateToEnglish(String query) {
    final translations = {
      // Популярные достопримечательности
      'колизей': 'colosseum',
      'эйфелева башня': 'eiffel tower',
      'эйфелева': 'eiffel tower',
      'башня': 'tower',
      'биг бен': 'big ben',
      'лувр': 'louvre',
      'эрмитаж': 'hermitage',
      'кремль': 'kremlin',
      'красная площадь': 'red square',
      'тадж махал': 'taj mahal',
      'тадж-махал': 'taj mahal',
      'пирамиды': 'pyramids',
      'пирамида': 'pyramid',
      'сфинкс': 'sphinx',
      'статуя свободы': 'statue of liberty',
      'статуя': 'statue',
      'акрополь': 'acropolis',
      'парфенон': 'parthenon',
      'нотр дам': 'notre dame',
      'нотр-дам': 'notre dame',
      'сиднейская опера': 'sydney opera house',
      'опера': 'opera house',
      'мачу пикчу': 'machu picchu',
      'мачу-пикчу': 'machu picchu',
      'стоунхендж': 'stonehenge',
      'петра': 'petra',
      'великая стена': 'great wall',
      'великая китайская стена': 'great wall of china',
      'запретный город': 'forbidden city',
      'ангкор': 'angkor',
      'ангкор ват': 'angkor wat',
      'чичен ица': 'chichen itza',
      'христос спаситель': 'christ the redeemer',
      'христос-спаситель': 'christ the redeemer',
      'мост': 'bridge',
      'собор': 'cathedral',
      'церковь': 'church',
      'музей': 'museum',
      'дворец': 'palace',
      'замок': 'castle',
      'крепость': 'fortress',
      'памятник': 'monument',
      'парк': 'park',
      'фонтан': 'fountain',
      'театр': 'theater',
      'галерея': 'gallery',
      'храм': 'temple',
      'площадь': 'square',
      'улица': 'street',
      'бульвар': 'boulevard',
      'проспект': 'avenue',
    };
    
    final lowerQuery = query.toLowerCase().trim();
    
    if (translations.containsKey(lowerQuery)) {
      AppLogger.log('🔄 Translated "$query" to "${translations[lowerQuery]}"');
      return translations[lowerQuery]!;
    }
    
    for (final entry in translations.entries) {
      if (lowerQuery.contains(entry.key)) {
        final translated = lowerQuery.replaceAll(entry.key, entry.value);
        AppLogger.log('🔄 Partial translation "$query" to "$translated"');
        return translated;
      }
    }
    
    return query;
  }
  
  /// Получение подробной информации о POI через retrieve endpoint
  static Future<SearchResult?> _retrievePOIDetails(String mapboxId, String sessionToken, {String? originalName}) async {
    try {
      final url = 'https://api.mapbox.com/search/searchbox/v1/retrieve/$mapboxId'
          '?access_token=${MapboxConfig.ACCESS_TOKEN}'
          '&session_token=$sessionToken';
      
      AppLogger.log('🔍 Retrieving POI details for ID: $mapboxId');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        AppLogger.log('📊 Retrieve response keys: ${data.keys.toList()}');
        
        if (data['features'] != null && data['features'] is List) {
          final features = data['features'] as List;
          AppLogger.log('📊 Retrieve found ${features.length} features');
          
          if (features.isNotEmpty) {
            final feature = features[0];
            AppLogger.log('📊 Feature structure: ${feature.keys.toList()}');
            
            if (feature['geometry'] != null && feature['properties'] != null) {
              final adaptedFeature = _adaptFeatureForSearchResult(feature, originalName: originalName);
              return SearchResult.fromJson(adaptedFeature);
            } else {
              AppLogger.log('❌ Invalid GeoJSON feature structure');
            }
          }
        } else {
          AppLogger.log('⚠️ No features in retrieve response for ID: $mapboxId');
        }
      } else {
        AppLogger.log('❌ Retrieve API error ${response.statusCode}: ${response.body}');
      }
      
      return null;
    } catch (e) {
      AppLogger.log('❌ Error retrieving POI details: $e');
      return null;
    }
  }
  
  /// Адаптирует feature из Search Box API для SearchResult
  static Map<String, dynamic> _adaptFeatureForSearchResult(Map<String, dynamic> feature, {String? originalName}) {
    try {
      final properties = feature['properties'] ?? {};
      final geometry = feature['geometry'] ?? {};
      final coordinates = geometry['coordinates'] ?? [];
      
      AppLogger.log('📊 Properties keys: ${properties.keys.toList()}');
      AppLogger.log('📊 Available names - original: $originalName, properties[name]: ${properties['name']}, full_address: ${properties['full_address']}');
      
      // Приоритет для названия: оригинальное из suggestion > name из properties > сокращенный адрес
      String placeName = originalName ?? properties['name'] ?? 'Unknown POI';
      
      if (placeName == 'Unknown POI' && properties['full_address'] != null) {
        final fullAddress = properties['full_address'].toString();
        final addressParts = fullAddress.split(',');
        if (addressParts.isNotEmpty) {
          placeName = addressParts[0].trim();
        }
      }
      
      if (coordinates.length >= 2) {
        AppLogger.log('📊 Coordinates: ${coordinates[0]}, ${coordinates[1]}');
      } else {
        AppLogger.log('⚠️ Invalid coordinates: $coordinates');
      }
      
      final adaptedFeature = {
        'type': 'Feature',
        'geometry': geometry,
        'properties': properties,
        'place_name': placeName,
        'text': originalName ?? properties['name'] ?? placeName,
        'center': coordinates.length >= 2 ? coordinates : [0.0, 0.0],
        'context': properties['context'] ?? [],
      };
      
      AppLogger.log('✅ Final adapted feature: "$placeName" at ${coordinates.length >= 2 ? coordinates : 'invalid coords'}');
      return adaptedFeature;
    } catch (e) {
      AppLogger.log('❌ Error adapting feature: $e');
      return feature;
    }
  }
  
  /// Поиск с категориями достопримечательностей с многоязычной поддержкой
  static Future<List<SearchResult>> searchByCategory(
    String query,
    List<String> categories, {
    double? proximityLng,
    double? proximityLat,
  }) async {
    try {
      AppLogger.log('🔍 Starting multilingual category search: $query with categories: ${categories.join(',')}');
      
      // Минимальная длина запроса для Search Box
      if (query.trim().length < 2) {
        AppLogger.log('⚠️ Query too short for Search Box (category), returning empty');
        return [];
      }
      
      final Map<String, SearchResult> uniqueResults = {};
      
      // Поиск на русском языке
      final russianResults = await _performCategorySearch(
        query,
        categories,
        'ru',
        proximityLng: proximityLng,
        proximityLat: proximityLat,
      );
      for (final result in russianResults) {
        final key = '${result.latitude}_${result.longitude}';
        uniqueResults[key] = result;
      }
      
      // Если недостаточно результатов, пробуем на английском с переводом
      if (uniqueResults.length < 2) {
        final englishQuery = _translateToEnglish(query);
        if (englishQuery != query) {
          final englishResults = await _performCategorySearch(
            englishQuery,
            categories,
            'en',
            proximityLng: proximityLng,
            proximityLat: proximityLat,
          );
          for (final result in englishResults) {
            final key = '${result.latitude}_${result.longitude}';
            if (!uniqueResults.containsKey(key)) {
              uniqueResults[key] = result;
            }
          }
        }
      }
      
      final finalResults = uniqueResults.values.toList();
      AppLogger.log('✅ Multilingual category search found ${finalResults.length} results');
      return finalResults;
    } catch (e) {
      AppLogger.log('❌ Error in multilingual category search: $e');
      return [];
    }
  }
  
  /// Выполняет поиск по категориям на конкретном языке
  static Future<List<SearchResult>> _performCategorySearch(
    String query,
    List<String> categories,
    String language, {
    double? proximityLng,
    double? proximityLat,
  }) async {
    try {
      final sessionToken = DateTime.now().millisecondsSinceEpoch.toString();
      // Добавляем ключевые слова категорий прямо в запрос (вместо poi_category)
      final combinedQuery = (query + ' ' + categories.join(' ')).trim();
      final encodedQuery = Uri.encodeComponent(combinedQuery);
      
      final hasProximity = proximityLng != null && proximityLat != null;
      final proximityParam = hasProximity ? '&proximity=${proximityLng!.toStringAsFixed(6)},${proximityLat!.toStringAsFixed(6)}' : '';
      
      // Запрос только с types=poi и ограничением limit=10
      final url = 'https://api.mapbox.com/search/searchbox/v1/suggest'
          '?q=$encodedQuery'
          '&access_token=${MapboxConfig.ACCESS_TOKEN}'
          '&session_token=$sessionToken'
          '&language=$language'
          '&limit=10'
          '&types=poi'
          '$proximityParam';
      
      AppLogger.log('🔍 Search Box API $language category search (q augmented): $combinedQuery${hasProximity ? ' and proximity' : ''}');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['suggestions'] != null && data['suggestions'] is List) {
          final suggestions = List<Map<String, dynamic>>.from(data['suggestions']);
          AppLogger.log('📊 Category search found ${suggestions.length} suggestions in $language');
          
          // Сортировка: POI первыми, затем по distance
          suggestions.sort((a, b) {
            final aIsPoi = (a['feature_type'] ?? '') == 'poi';
            final bIsPoi = (b['feature_type'] ?? '') == 'poi';
            if (aIsPoi != bIsPoi) return aIsPoi ? -1 : 1;
            final aDist = (a['distance'] is num) ? (a['distance'] as num).toDouble() : double.infinity;
            final bDist = (b['distance'] is num) ? (b['distance'] as num).toDouble() : double.infinity;
            return aDist.compareTo(bDist);
          });
          
          final results = <SearchResult>[];
          
          for (int i = 0; i < suggestions.length; i++) {
            final suggestion = suggestions[i];
            
            if (suggestion['mapbox_id'] != null) {
              final originalName = suggestion['name']?.toString();
              final retrieveResult = await _retrievePOIDetails(
                suggestion['mapbox_id'], 
                sessionToken, 
                originalName: originalName
              );
              if (retrieveResult != null) {
                results.add(retrieveResult);
                AppLogger.log('✅ Retrieved $language category result $i: ${suggestion['name']}');
              }
            }
          }
          
          return results;
        }
      } else {
        AppLogger.log('❌ Category search $language error: ${response.statusCode}');
      }
      
      return [];
    } catch (e) {
      AppLogger.log('❌ Error in $language category search: $e');
      return [];
    }
  }
  
  /// Комплексный поиск достопримечательностей с несколькими стратегиями
  static Future<List<SearchResult>> comprehensiveAttractionsSearch(
    String query, {
    double? proximityLng,
    double? proximityLat,
  }) async {
    try {
      AppLogger.log('🚀 Starting comprehensive attractions search for: $query');
      
      final Map<String, SearchResult> uniqueResults = {};
      
      // Стратегия 1: Общий поиск достопримечательностей
      final generalResults = await searchAttractions(
        query,
        proximityLng: proximityLng,
        proximityLat: proximityLat,
      );
      for (final result in generalResults) {
        final key = '${result.latitude}_${result.longitude}';
        uniqueResults[key] = result;
      }
      
      // Стратегия 2: Если недостаточно результатов, пробуем более специфические категории
      if (uniqueResults.length < 3) {
        AppLogger.log('🔍 Not enough results, trying specific categories');
        
        final specificCategories = [
          ['museum'],
          ['castle', 'palace'],
          ['cathedral', 'church'],
          ['monument'],
          ['park']
        ];
        
        for (final categoryGroup in specificCategories) {
          AppLogger.log('🔍 Trying category group: ${categoryGroup.join(', ')}');
          final categoryResults = await searchByCategory(
            query,
            categoryGroup,
            proximityLng: proximityLng,
            proximityLat: proximityLat,
          );
          
          for (final result in categoryResults) {
            final key = '${result.latitude}_${result.longitude}';
            if (!uniqueResults.containsKey(key)) {
              uniqueResults[key] = result;
            }
          }
          
          if (uniqueResults.length >= 8) {
            AppLogger.log('✅ Found enough results, stopping category search');
            break;
          }
        }
      }
      
      final finalResults = uniqueResults.values.toList();
      AppLogger.log('🎯 Comprehensive search completed: ${finalResults.length} unique attractions');
      
      return finalResults;
    } catch (e) {
      AppLogger.log('❌ Error in comprehensive search: $e');
      return [];
    }
  }
  
  /// Проверка доступности Search Box API
  static Future<bool> isSearchBoxAPIAvailable() async {
    try {
      final testUrl = 'https://api.mapbox.com/search/searchbox/v1/suggest'
          '?q=test'
          '&access_token=${MapboxConfig.ACCESS_TOKEN}'
          '&session_token=test_${DateTime.now().millisecondsSinceEpoch}'
          '&limit=1';
      
      final response = await http.get(Uri.parse(testUrl));
      
      // Если получили 200 или любой другой код, кроме 404/403, значит API доступен
      final isAvailable = response.statusCode != 404 && response.statusCode != 403;
      
      AppLogger.log(isAvailable 
          ? '✅ Search Box API is available' 
          : '❌ Search Box API is not available (${response.statusCode})');
      
      return isAvailable;
    } catch (e) {
      AppLogger.log('❌ Error checking Search Box API availability: $e');
      return false;
    }
  }
}
