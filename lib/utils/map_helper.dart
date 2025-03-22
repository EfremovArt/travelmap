import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../config/mapbox_config.dart';
import '../models/location.dart';

/// Результат создания менеджера аннотаций
class AnnotationManagerResult {
  final PointAnnotationManager? manager;
  final String? error;

  AnnotationManagerResult({this.manager, this.error});
}

/// Класс для обработки кликов на аннотации
class MyPointAnnotationClickListener implements OnPointAnnotationClickListener {
  final bool Function(PointAnnotation) _onClickCallback;

  MyPointAnnotationClickListener(this._onClickCallback);

  @override
  bool onPointAnnotationClick(PointAnnotation annotation) {
    return _onClickCallback(annotation);
  }
}

/// Вспомогательный класс для работы с Mapbox картой
class MapHelper {
  // Кэшированный менеджер аннотаций для повторного использования
  static PointAnnotationManager? _cachedManager;
  
  /// Инициализирует компоненты карты (локация, аннотации)
  static Future<bool> initializeMapComponents(
    MapboxMap mapboxMap, 
    {
      Function(PointAnnotationManager)? onPointManagerCreated,
      Function(dynamic)? onError,
    }
  ) async {
    try {
      print("Initializing map components");
      
      // Более надежное ожидание инициализации стиля
      bool styleLoaded = false;
      int styleRetryCount = 0;
      const int maxStyleRetries = 5;
      
      while (!styleLoaded && styleRetryCount < maxStyleRetries) {
        try {
          styleLoaded = await mapboxMap.style.isStyleLoaded();
          if (styleLoaded) {
            print("Стиль карты загружен успешно");
            break;
          }
        } catch (e) {
          print("Error checking if style is loaded (attempt ${styleRetryCount + 1}): $e");
        }
        
        // Увеличиваем задержку с каждой попыткой
        await Future.delayed(Duration(milliseconds: 500 + 500 * styleRetryCount));
        styleRetryCount++;
      }
      
      // Даже если не смогли проверить стиль, продолжаем работу
      // с паузой для загрузки ресурсов карты
      if (!styleLoaded) {
        print("Не удалось подтвердить загрузку стиля, даем карте дополнительное время");
        await Future.delayed(Duration(milliseconds: 2000)); 
      }
      
      // Несколько попыток создания менеджера аннотаций
      PointAnnotationManager? pointAnnotationManager;
      int retryCount = 0;
      const int maxRetries = 5;
      Exception? lastException;
      
      while (pointAnnotationManager == null && retryCount < maxRetries) {
        try {
          // Перед созданием менеджера делаем дополнительную паузу на случай
          // медленной инициализации плагина аннотаций
          await Future.delayed(Duration(milliseconds: 300 * (retryCount + 1)));
          
          // Создаем менеджер аннотаций
          pointAnnotationManager = await _createAnnotationManagerSafe(mapboxMap);
          
          if (pointAnnotationManager != null) {
            break; // Успешно создали менеджер
          }
        } catch (e) {
          lastException = e is Exception ? e : Exception(e.toString());
          print("Attempt $retryCount to create annotation manager failed: $e");
        }
        
        retryCount++;
        // Увеличиваем задержку с каждой попыткой
        await Future.delayed(Duration(milliseconds: 500 + 300 * retryCount));
      }
      
      if (pointAnnotationManager != null) {
        print("Point annotation manager created successfully");
        if (onPointManagerCreated != null) {
          onPointManagerCreated(pointAnnotationManager);
        }
        return true;
      } else {
        final errorMessage = lastException != null 
            ? "Failed to create annotation manager: ${lastException}"
            : "Failed to create annotation manager after $maxRetries attempts";
            
        print(errorMessage);
        if (onError != null) {
          onError(errorMessage);
        }
        return false;
      }
    } catch (e) {
      print("Error initializing map components: $e");
      if (onError != null) {
        onError(e);
      }
      return false;
    }
  }

  /// Безопасный метод создания менеджера аннотаций с дополнительными проверками
  static Future<PointAnnotationManager?> _createAnnotationManagerSafe(MapboxMap mapboxMap) async {
    try {
      // Проверяем стиль еще раз перед созданием менеджера
      bool styleLoaded = false;
      try {
        styleLoaded = await mapboxMap.style.isStyleLoaded();
      } catch (e) {
        print("Style check failed before creating annotation manager: $e");
        // Продолжаем, даже если проверка не удалась
      }
      
      if (!styleLoaded) {
        // Даем дополнительное время на загрузку стиля
        await Future.delayed(Duration(milliseconds: 500));
      }
      
      // Пробуем создать менеджер аннотаций
      try {
        final annotationsPlugin = mapboxMap.annotations;
        final manager = await annotationsPlugin.createPointAnnotationManager();
        return manager;
      } catch (apiError) {
        print("API error creating annotation manager: $apiError");
        
        // Пробуем еще раз с дополнительной задержкой
        await Future.delayed(Duration(milliseconds: 800));
        return await mapboxMap.annotations.createPointAnnotationManager();
      }
    } catch (e) {
      print("Error creating annotation manager: $e");
      return null;
    }
  }

  /// Создает точку из координат
  static Point createPoint(double longitude, double latitude) {
    return Point(
      coordinates: Position(longitude, latitude),
    );
  }

  /// Создает объект точки из GeoLocation
  static Point createPointFromLocation(GeoLocation location) {
    return createPoint(location.longitude, location.latitude);
  }
  
  /// Перемещает камеру к указанной локации с упрощенной обработкой ошибок
  static Future<void> moveCamera({
    required MapboxMap mapboxMap,
    required double latitude,
    required double longitude,
    double zoom = 13.0,
    bool animate = false, // Отключаем анимацию для большей стабильности
  }) async {
    try {
      // Создаем точку из координат
      final point = Point(
        coordinates: Position(longitude, latitude),
      );
      
      // Используем простое перемещение без анимации для стабильности
      final cameraOptions = CameraOptions(
        center: point,
        zoom: zoom,
      );
      
      if (animate) {
        // Используем более быстрые анимации для меньшей нагрузки
        await mapboxMap.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: 300), // Короткая анимация
        );
      } else {
        // Мгновенное перемещение камеры
        await mapboxMap.setCamera(cameraOptions);
      }
    } catch (e) {
      print("Ошибка при перемещении камеры: $e");
    }
  }

  /// Безопасно очищает все маркеры с карты
  static Future<bool> clearMarkers(PointAnnotationManager? manager) async {
    if (manager == null) {
      print("Cannot clear markers: manager is null");
      return false;
    }

    try {
      // Проверяем, что менеджер валиден и доступен
      // Пробуем получить идентификатор менеджера, если вызов не выбрасывает исключение, 
      // считаем менеджер валидным
      try {
        final id = manager.id;
        print("Attempting to clear markers for manager with id: $id");
      } catch (e) {
        print("Manager appears to be invalid: $e");
        return false;
      }
      
      try {
        // Пробуем удалить все маркеры
        await manager.deleteAll();
        print("Successfully cleared all markers");
        return true;
      } catch (e) {
        if (e.toString().contains("No manager found with id")) {
          // Наиболее частая ошибка - менеджер был уничтожен
          print("Manager was already destroyed: $e");
          return false;
        } else {
          // Другие ошибки
          print("Error during marker deletion: $e");
          return false;
        }
      }
    } catch (e) {
      print("General error clearing markers: $e");
      return false;
    }
  }

  /// Безопасно создает менеджер аннотаций для точек с повторными попытками и кэшированием
  static Future<PointAnnotationManager?> createAnnotationManager(MapboxMap map) async {
    // Если у нас уже есть кэшированный менеджер, проверяем его валидность перед возвратом
    if (_cachedManager != null) {
      try {
        // Проверяем, что менеджер валиден путем доступа к его ID
        final id = _cachedManager!.id;
        print("Using cached annotation manager with id: $id");
        return _cachedManager;
      } catch (e) {
        print("Cached annotation manager is invalid: $e");
        _cachedManager = null;
      }
    }
    
    int retryCount = 0;
    final maxRetries = 3;
    
    while (retryCount < maxRetries) {
      try {
        // Проверяем, загружен ли стиль карты
        bool styleLoaded = false;
        try {
          styleLoaded = await map.style.isStyleLoaded();
        } catch (e) {
          print("Error checking if style is loaded (attempt ${retryCount + 1}): $e");
          styleLoaded = false;
        }

        if (!styleLoaded) {
          // Если стиль не загружен, ждем и пробуем снова
          print("Style not loaded, waiting (attempt ${retryCount + 1})");
          await Future.delayed(Duration(milliseconds: 1000));
          retryCount++;
          continue;
        }

        // Пытаемся создать менеджер аннотаций
        print("Creating new annotation manager...");
        final annotationApi = map.annotations;
        if (annotationApi == null) {
          print("Annotation API is null, retrying...");
          await Future.delayed(Duration(milliseconds: 1000));
          retryCount++;
          continue;
        }
        
        final manager = await annotationApi.createPointAnnotationManager();
        
        // Проверяем, что менеджер валиден и кэшируем его для последующего использования
        if (manager != null) {
          try {
            // Проверяем, что менеджер работоспособен, доступаясь к его ID
            final id = manager.id;
            print("Annotation manager created successfully with id: $id");
            
            // Кэшируем менеджер для повторного использования
            _cachedManager = manager;
            
            return manager;
          } catch (e) {
            print("Manager was created but appears to be invalid: $e");
          }
        } else {
          print("Manager creation returned null");
        }
      } catch (e) {
        print("Error creating annotation manager (attempt ${retryCount + 1}): $e");
      }

      // Ждем перед следующей попыткой
      await Future.delayed(Duration(milliseconds: 1000));
      retryCount++;
    }

    print("Failed to create annotation manager after $maxRetries attempts");
    return null;
  }

  /// Добавляет обработчик клика на точечные аннотации
  static Future<bool> addClickListenerToAnnotation(
    PointAnnotationManager manager,
    Function(String annotationId) onAnnotationClick
  ) async {
    try {
      // Проверяем, что менеджер действительно существует
      try {
        final id = manager.id;
        print("Adding click listener to manager with ID: $id");
      } catch (e) {
        print("Cannot add click listener to invalid manager: $e");
        return false;
      }
      
      // Создаем обработчик кликов
      manager.addOnPointAnnotationClickListener(MyPointAnnotationClickListener(
        (PointAnnotation annotation) {
          try {
            print("Marker clicked: ${annotation.id}");
            onAnnotationClick(annotation.id);
            return true;
          } catch (e) {
            print("Error in marker click handler: $e");
            return false;
          }
        }
      ));
      
      return true;
    } catch (e) {
      print("Error adding click listener: $e");
      return false;
    }
  }

  /// Безопасная проверка загрузки стиля карты
  static Future<bool> isStyleLoaded(MapboxMap map) async {
    try {
      return await map.style.isStyleLoaded();
    } catch (e) {
      print("Error checking if style is loaded: $e");
      return false;
    }
  }
} 