import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../config/mapbox_config.dart';
import '../models/location.dart';
import '../models/search_result.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../services/mapbox_service.dart';
import '../utils/logger.dart';
import '../widgets/enhanced_search_widget.dart';

class SelectLocationScreen extends StatefulWidget {
  const SelectLocationScreen({Key? key}) : super(key: key);

  @override
  _SelectLocationScreenState createState() => _SelectLocationScreenState();
}

class _SelectLocationScreenState extends State<SelectLocationScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Контроллеры и ключи
  final TextEditingController _searchController = TextEditingController();
  
  // Анимация для пульсирующей точки
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  // Переменные для работы с картой
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  
  // Состояние карты
  bool _isLoading = true;
  String? _error;
  
  // Местоположение и поиск
  GeoLocation? _currentLocation;
  GeoLocation? _selectedLocation;
  String _locationName = '';
  bool _isSearching = false;
  List<SearchResult> _searchResults = [];
  
  // Таймеры
  Timer? _mapLoadingTimer;
  Timer? _mapHealthCheckTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Инициализация анимации пульсирующей точки
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _pulseAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    
    // Инициализация компонентов
    _isLoading = true;
    _error = null;
    
    // Определяем текущее местоположение при загрузке экрана
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
      
      // Запускаем таймер для проверки загрузки карты
      _mapLoadingTimer?.cancel();
      _mapLoadingTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && _isLoading && _error == null) {
          setState(() {
            _error = "Превышено время ожидания загрузки карты. Попробуйте ещё раз.";
            _isLoading = false;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _pulseAnimationController.dispose();
    _mapLoadingTimer?.cancel();
    _mapHealthCheckTimer?.cancel();
    
    if (_mapboxMap != null) {
      try {
        AppLogger.log("Очистка ресурсов карты в select_location_screen");
        _pointAnnotationManager = null;
        _mapboxMap = null;
      } catch (e) {
        AppLogger.log("Ошибка при очистке ресурсов карты в select_location_screen: $e");
      }
    }
    
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Determine current location with extended error handling
  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    AppLogger.log("📍 Starting location determination");
    
    try {
      // First check if location service is enabled
      bool isLocationServiceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      AppLogger.log("🔍 Location service status: $isLocationServiceEnabled");
      
      if (!isLocationServiceEnabled) {
        AppLogger.log("❌ Location service is disabled");
        if (mounted) {
          setState(() {
            _currentLocation = GeoLocation(
              latitude: MapboxConfig.DEFAULT_LATITUDE,
              longitude: MapboxConfig.DEFAULT_LONGITUDE
            );
            _isLoading = false;
          });
        }
        return;
      }
      
      // Check and request necessary permissions
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      AppLogger.log("📱 Initial permission status: $permission");
      
      if (permission == geo.LocationPermission.denied) {
        permission = await geo.Geolocator.requestPermission();
        AppLogger.log("📱 After request permission status: $permission");
      }
      
      if (permission == geo.LocationPermission.denied || permission == geo.LocationPermission.deniedForever) {
        AppLogger.log("❌ Location permission denied");
        if (mounted) {
          setState(() {
            _currentLocation = GeoLocation(
              latitude: MapboxConfig.DEFAULT_LATITUDE,
              longitude: MapboxConfig.DEFAULT_LONGITUDE
            );
            _isLoading = false;
          });
        }
        return;
      }
      
      // Permission granted, get current position
      AppLogger.log("✅ Permission granted, getting position with timeout");
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20)
      );
      
      AppLogger.log("✅ Position obtained: ${position.latitude}, ${position.longitude}");
      
      if (mounted) {
        setState(() {
          _currentLocation = GeoLocation(
            latitude: position.latitude,
            longitude: position.longitude
          );
          _selectedLocation = _currentLocation;
          _locationName = "Current Location";
          _isLoading = false;
        });
        
        // Запускаем геокодинг для получения названия
        _reverseGeocode(position.latitude, position.longitude).then((name) {
          if (mounted && name != null && name.isNotEmpty) {
            setState(() {
              _locationName = name;
              AppLogger.log("✅ Current location name updated: $_locationName");
            });
          }
        });
      }
    } catch (e) {
      AppLogger.log("❌ Error determining location: $e");
      
      if (mounted) {
        setState(() {
          _currentLocation = GeoLocation(
            latitude: MapboxConfig.DEFAULT_LATITUDE,
            longitude: MapboxConfig.DEFAULT_LONGITUDE
          );
          _selectedLocation = _currentLocation;
          _locationName = "Default Location (New York)";
          _isLoading = false;
        });
      }
    }
  }

  /// Обработчик события создания карты
  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    AppLogger.log("🗺️ Карта создана успешно");
    
    if (!mounted) {
      AppLogger.log("⚠️ Widget не прикреплен к дереву, инициализация карты остановлена");
      return;
    }
    
    _mapboxMap = mapboxMap;
    
    // Отключаем шкалу зума
    try {
      await mapboxMap.scaleBar.updateSettings(
        ScaleBarSettings(
          enabled: false,
        )
      );
      AppLogger.log("✅ Scale bar disabled");
    } catch (e) {
      AppLogger.log("⚠️ Error disabling scale bar: $e");
    }
    
    if (mounted) {
      setState(() {
        // Оставляем _isLoading = true, но обновляем UI
      });
    }
    
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      
      try {
        await mapboxMap.style.setStyleURI(MapboxConfig.STREETS_STYLE_URI);
        AppLogger.log("🎨 Установлен стиль карты: ${MapboxConfig.STREETS_STYLE_URI}");
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        try {
          await MapboxConfig.registerMapboxMarkerImages(mapboxMap);
          AppLogger.log("🔹 Изображения маркеров зарегистрированы");
        } catch (e) {
          AppLogger.log("⚠️ Ошибка регистрации изображений маркеров: $e");
        }
      } catch (e) {
        AppLogger.log("⚠️ Ошибка установки стиля карты: $e");
      }
      
      try {
        AppLogger.log("📍 Создание менеджера аннотаций");
        _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
        AppLogger.log("✅ Менеджер аннотаций создан");
      } catch (e) {
        AppLogger.log("⚠️ Ошибка создания менеджера аннотаций: $e");
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
      
      // Отрисовываем маркер если уже выбрана локация
      if (_selectedLocation != null) {
        await _addMarkerAtPosition(
          lat: _selectedLocation!.latitude,
          lng: _selectedLocation!.longitude
        );
        
        await _moveCameraToLocation(
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude
        );
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      AppLogger.log("✅ Карта полностью инициализирована");
      
    } catch (e) {
      AppLogger.log("❌ Ошибка инициализации карты: $e");
      if (mounted) {
        setState(() {
          _error = "Ошибка инициализации карты. Попробуйте еще раз.";
          _isLoading = false;
        });
      }
    }
  }

  /// Handle map tap events to place markers
  void _onMapClick(MapContentGestureContext mapContext) {
    AppLogger.log("📌 Map tap received at ${DateTime.now()}");
    
    if (!mounted) {
      AppLogger.log("❌ Widget not mounted, ignoring tap");
      return;
    }

    try {
      AppLogger.log("🔍 MapContext details: point=${mapContext.point}");
      
      if (mapContext.point == null) {
        AppLogger.log("❌ Could not determine tap coordinates - mapContext.point is null");
        return;
      }
      
      final coordinates = mapContext.point.coordinates;
      
      if (coordinates == null || coordinates.isEmpty) {
        AppLogger.log("❌ Null or empty coordinates in tap event");
        return;
      }
      
      AppLogger.log("📊 Raw coordinates: $coordinates (type: ${coordinates.runtimeType})");
      
      double lat = MapboxConfig.DEFAULT_LATITUDE;
      double lng = MapboxConfig.DEFAULT_LONGITUDE;
      
      if (coordinates is List && coordinates.length >= 2) {
        final first = coordinates[0];
        final second = coordinates[1];
        
        if (first != null && second != null) {
          lng = first is double ? first : (first as num).toDouble();
          lat = second is double ? second : (second as num).toDouble();
          AppLogger.log("✅ Extracted coordinates from list: lng=$lng, lat=$lat");
        }
      } else if (coordinates is Position) {
        lng = coordinates.lng.toDouble();
        lat = coordinates.lat.toDouble();
        AppLogger.log("✅ Extracted coordinates from Position: lng=$lng, lat=$lat");
      } else {
        AppLogger.log("❌ Unsupported coordinate format: ${coordinates.runtimeType}");
        return;
      }
      
      // Basic coordinate validation
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        AppLogger.log("❌ Invalid coordinates: lat=$lat, lng=$lng");
        return;
      }
      
      // Update state with the selected location
      AppLogger.log("✅ Setting selected location to: lat=$lat, lng=$lng");
      if (mounted) {
        setState(() {
          _selectedLocation = GeoLocation(latitude: lat, longitude: lng);
          _locationName = "Выбранная точка";
        });
        
        // Сначала центрируем на локации, затем добавляем маркер
        _moveCameraToLocation(latitude: lat, longitude: lng, zoom: 15.0).then((_) {
        _addMarkerAtPosition(lat: lat, lng: lng, isCurrentLocation: false);
        });
        
        _reverseGeocode(lat, lng).then((name) {
          if (mounted && name != null && name.isNotEmpty) {
            setState(() {
              _locationName = name;
              AppLogger.log("✅ Location name updated: $_locationName");
            });
          }
        });
      }
    } catch (e) {
      AppLogger.log("❌ Error processing map tap: $e");
    }
  }

  /// Attempt to get location name from coordinates using reverse geocoding
  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      return await MapboxService.reverseGeocode(lat, lng);
    } catch (e) {
      AppLogger.log("❌ Error during reverse geocoding: $e");
      return null;
    }
  }

  // Выделяем перемещение камеры в отдельный метод
  Future<void> _moveCameraToLocation({
    required double latitude,
    required double longitude,
    double zoom = 14.0
  }) async {
    if (_mapboxMap == null || !mounted) {
      AppLogger.log("❌ Невозможно переместить камеру: карта не инициализирована или виджет отсоединен");
      return;
    }
    
    try {
      final point = Point(
        coordinates: Position(longitude, latitude)
      );
      
      final cameraOptions = CameraOptions(
        center: point,
        zoom: zoom
      );
      
      AppLogger.log("📍 Перемещение камеры к координатам: lat=$latitude, lng=$longitude, zoom=$zoom");
      
      try {
        await _mapboxMap!.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: 700)
        );
        AppLogger.log("✅ Камера перемещена с анимацией");
        return;
      } catch (e) {
        AppLogger.log("⚠️ Ошибка перемещения камеры с анимацией: $e");
      }
      
      try {
        await _mapboxMap!.setCamera(cameraOptions);
        AppLogger.log("✅ Камера перемещена без анимации");
      } catch (e) {
        AppLogger.log("❌ Ошибка перемещения камеры: $e");
      }
    } catch (e) {
      AppLogger.log("❌ Критическая ошибка перемещения камеры: $e");
    }
  }

  /// Добавляет маркер на карту по заданным координатам
  Future<void> _addMarkerAtPosition({
    required double lat, 
    required double lng,
    bool isCurrentLocation = false
  }) async {
    if (!mounted) {
      AppLogger.log("⚠️ Widget не прикреплен к дереву, отмена добавления маркера");
      return;
    }
    
    if (_mapboxMap == null) {
      AppLogger.log("⚠️ Карта не инициализирована, отмена добавления маркера");
      return;
    }
    
    try {
      if (_pointAnnotationManager == null) {
        try {
          AppLogger.log("📍 Создание менеджера маркеров");
          _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
        } catch (e) {
          AppLogger.log("❌ Ошибка создания менеджера маркеров: $e");
          return;
        }
      }
      
      if (_pointAnnotationManager == null) {
        AppLogger.log("❌ Менеджер маркеров не доступен");
        return;
      }
      
      try {
        await _pointAnnotationManager!.deleteAll();
        AppLogger.log("🧹 Удалены все существующие маркеры");
      } catch (e) {
        AppLogger.log("⚠️ Ошибка при удалении существующих маркеров: $e");
      }
      
      try {
        AppLogger.log("📍 Добавление маркера на координаты: lat=$lat, lng=$lng");
        
        // Попробуем несколько вариантов создания маркера
        PointAnnotation? createdMarker;
        
        // Вариант 1: Попробуем с кастомным изображением
        try {
          AppLogger.log("🎯 Попытка 1: Создание маркера с custom-marker");
          final markerOptions1 = PointAnnotationOptions(
            geometry: Point(coordinates: Position(lng, lat)),
            iconImage: "custom-marker",
            iconSize: 0.1, // Уменьшаем размер
            iconAnchor: IconAnchor.BOTTOM
          );
          createdMarker = await _pointAnnotationManager!.create(markerOptions1);
          if (createdMarker != null) {
            AppLogger.log("✅ Маркер создан с custom-marker, ID: ${createdMarker.id}");
          }
        } catch (e) {
          AppLogger.log("❌ Ошибка создания маркера с custom-marker: $e");
        }
        
        // Вариант 2: Если не получилось, попробуем встроенный маркер
        if (createdMarker == null) {
          try {
            AppLogger.log("🎯 Попытка 2: Создание маркера с marker-15");
            final markerOptions2 = PointAnnotationOptions(
              geometry: Point(coordinates: Position(lng, lat)),
              iconImage: "marker-15",
              iconSize: 0.1, // Уменьшаем размер
              iconAnchor: IconAnchor.BOTTOM
            );
            createdMarker = await _pointAnnotationManager!.create(markerOptions2);
            if (createdMarker != null) {
              AppLogger.log("✅ Маркер создан с marker-15, ID: ${createdMarker.id}");
            }
          } catch (e) {
            AppLogger.log("❌ Ошибка создания маркера с marker-15: $e");
          }
        }
        
        // Вариант 3: Попробуем с изображением из assets
        if (createdMarker == null) {
          try {
            AppLogger.log("🎯 Попытка 3: Создание маркера с изображением из assets");
            
            // Загружаем изображение из assets
            final ByteData byteData = await rootBundle.load('assets/Images/map-marker.png');
            final Uint8List bytes = byteData.buffer.asUint8List();
            
            final markerOptions3 = PointAnnotationOptions(
              geometry: Point(coordinates: Position(lng, lat)),
              image: bytes, // Используем прямое изображение
              iconSize: 0.1, // Еще больше уменьшаем размер
              iconAnchor: IconAnchor.BOTTOM
            );
            createdMarker = await _pointAnnotationManager!.create(markerOptions3);
            if (createdMarker != null) {
              AppLogger.log("✅ Маркер создан с прямым изображением, ID: ${createdMarker.id}");
            }
          } catch (e) {
            AppLogger.log("❌ Ошибка создания маркера с прямым изображением: $e");
          }
        }
        
        // Вариант 4: Простой маркер с минимальным размером
        if (createdMarker == null) {
          try {
            AppLogger.log("🎯 Попытка 4: Простой маркер с минимальным размером");
            final markerOptions4 = PointAnnotationOptions(
              geometry: Point(coordinates: Position(lng, lat)),
              iconSize: 0.05 // Супер маленький размер
            );
            createdMarker = await _pointAnnotationManager!.create(markerOptions4);
            if (createdMarker != null) {
              AppLogger.log("✅ Простой маркер создан, ID: ${createdMarker.id}");
            }
          } catch (e) {
            AppLogger.log("❌ Ошибка создания простого маркера: $e");
          }
        }
        
        if (createdMarker != null) {
          AppLogger.log("🎉 Маркер успешно добавлен с ID: ${createdMarker.id}");
          // Небольшая задержка для обеспечения отображения маркера
          await Future.delayed(const Duration(milliseconds: 300));
        } else {
          AppLogger.log("💥 Не удалось создать маркер ни одним из способов");
        }
        
      } catch (e) {
        AppLogger.log("❌ Ошибка при создании маркера: $e");
      }
    } catch (e) {
      AppLogger.log("❌ Общая ошибка при добавлении маркера: $e");
    }
  }

  void _onSearchResultSelected(SearchResult result) {
    AppLogger.log("🎯 Выбрана локация: ${result.placeName}");
    AppLogger.log("📍 Координаты: lat=${result.latitude}, lng=${result.longitude}");
    
    setState(() {
      _selectedLocation = GeoLocation(
        latitude: result.latitude, 
        longitude: result.longitude
      );
      _locationName = result.placeName;
      
      _isSearching = false;
      _searchResults = [];
    });
    
    if (_mapboxMap == null) {
      AppLogger.log("⚠️ Карта не инициализирована, маркер будет добавлен при инициализации карты");
      return;
    }
    
    // Сначала перемещаем камеру, затем добавляем маркер
    _moveCameraToLocation(
      latitude: result.latitude, 
      longitude: result.longitude,
      zoom: 15.0 // Увеличиваем зум для лучшей видимости
    ).then((_) {
      // После перемещения камеры добавляем маркер
    _addMarkerAtPosition(
      lat: result.latitude, 
      lng: result.longitude, 
      isCurrentLocation: false
    );
    });
  }

  void _confirmSelection() {
    if (_selectedLocation != null) {
      // Возвращаем выбранную локацию
      Navigator.of(context).pop({
        'location': _selectedLocation,
        'locationName': _locationName,
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Location'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Enhanced search widget
          EnhancedSearchWidget(
            hintText: 'Find a place or attraction...',
            onLocationSelected: _onSearchResultSelected,
            proximityLng: _currentLocation?.longitude,
            proximityLat: _currentLocation?.latitude,
          ),
          
          // Map display
          Expanded(
            child: Stack(
              children: [
                RepaintBoundary(
                  child: _buildMapWidget(),
                ),
                
                // Show selected location information
                if (_selectedLocation != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 16,
                    child: Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.place, color: Colors.red),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _locationName,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  Text(
                                    'Lat: ${_selectedLocation!.latitude.toStringAsFixed(5)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(5)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: _selectedLocation != null
                  ? _confirmSelection
                  : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: _selectedLocation != null 
                    ? Colors.blue.shade600 
                    : Colors.grey.shade400,
                disabledBackgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Text(
                'Continue',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: _selectedLocation != null 
                      ? Colors.white 
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the map widget
  Widget _buildMapWidget() {
    return Container(
      width: double.infinity,
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: MapWidget(
              key: const ValueKey('select_location_map'),
              styleUri: MapboxConfig.STREETS_STYLE_URI,
              onMapCreated: _onMapCreated,
              onTapListener: _onMapClick,
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(
                    _currentLocation?.longitude ?? MapboxConfig.DEFAULT_LONGITUDE,
                    _currentLocation?.latitude ?? MapboxConfig.DEFAULT_LATITUDE
                  )
                ),
                zoom: 12.0,
              ),
              // Включаем масштабирование и другие жесты карты
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<ScaleGestureRecognizer>(() => ScaleGestureRecognizer()),
                Factory<PanGestureRecognizer>(() => PanGestureRecognizer()),
                Factory<TapGestureRecognizer>(() => TapGestureRecognizer()),
              },
            ),
          ),
          
          if (_isLoading || _mapboxMap == null)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading map...',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            
          if (_error != null)
            Container(
              color: Colors.white.withOpacity(0.9),
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _getCurrentLocation(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Класс для дебаунса запросов поиска
class Debouncer {
  final int milliseconds;
  Timer? _timer;

  Debouncer({required this.milliseconds});

  void run(VoidCallback action) {
    _timer?.cancel();
    _timer = Timer(Duration(milliseconds: milliseconds), action);
  }
}
