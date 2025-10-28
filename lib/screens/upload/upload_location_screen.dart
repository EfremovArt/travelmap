import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../../config/mapbox_config.dart';
import 'upload_description_screen.dart';
import '../../models/location.dart';
import 'dart:async';
import '../../models/search_result.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../services/mapbox_service.dart';
import '../../utils/logger.dart';
import '../../widgets/enhanced_search_widget.dart';
class UploadLocationScreen extends StatefulWidget {
  final List<File> images;
  final File? firstImageOriginal;

  const UploadLocationScreen({
    Key? key,
    required this.images,
    this.firstImageOriginal,
  }) : super(key: key);

  @override
  _UploadLocationScreenState createState() => _UploadLocationScreenState();
}

class _UploadLocationScreenState extends State<UploadLocationScreen> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
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
      _mapLoadingTimer?.cancel(); // Сначала отменяем предыдущий таймер если был
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
    
    // Останавливаем анимацию
    _pulseAnimationController.dispose();
    
    // Отменяем все таймеры и подписки
    _mapLoadingTimer?.cancel();
    _mapHealthCheckTimer?.cancel();
    
    // Очистка всех ресурсов карты
    if (_mapboxMap != null) {
      try {
        AppLogger.log("Очистка ресурсов карты в upload_location_screen");
        // В новых версиях SDK нужно явно освобождать ресурсы
        _pointAnnotationManager = null;
        _mapboxMap = null;
      } catch (e) {
        AppLogger.log("Ошибка при очистке ресурсов карты в upload_location_screen: $e");
      }
    }
    
    // Отменяем подписку на жизненный цикл
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Реагируем на изменения жизненного цикла приложения
    if (state == AppLifecycleState.resumed) {
      // При возвращении в приложение проверяем состояние карты
      if (_mapboxMap != null && !_isLoading) {
        _reinitializeMapIfNeeded();
      }
    }
  }
  
  // Метод для переинициализации карты при необходимости
  void _reinitializeMapIfNeeded() {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    // Форсируем перестроение виджета
    if (mounted) setState(() {});
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
        _showLocationServiceDisabledDialog();
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
      
      // Check and request necessary permissions with improved handling
      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      AppLogger.log("📱 Initial permission status: $permission");
      
      if (permission == geo.LocationPermission.denied) {
        // Explicitly request permission
        permission = await geo.Geolocator.requestPermission();
        AppLogger.log("📱 After request permission status: $permission");
      }
      
      // Handle all permission cases
      if (permission == geo.LocationPermission.denied) {
        AppLogger.log("❌ Location permission denied");
        _showPermissionDeniedDialog(isPermanent: false);
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
      } else if (permission == geo.LocationPermission.deniedForever) {
        AppLogger.log("❌ Location permission permanently denied");
        _showPermissionDeniedDialog(isPermanent: true);
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
      
      // Permission granted, get current position with improved timeout
      AppLogger.log("✅ Permission granted, getting position with timeout");
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20) // Increase timeout for better chance of success
      );
      
      AppLogger.log("✅ Position obtained: ${position.latitude}, ${position.longitude}");
      
      if (mounted) {
        setState(() {
          _currentLocation = GeoLocation(
            latitude: position.latitude,
            longitude: position.longitude
          );
          // Автоматически выбираем текущую локацию
          _selectedLocation = _currentLocation;
          _locationName = "Current Location";
          _isLoading = false;
        });
        
        // Добавляем маркер текущей позиции, если карта инициализирована
        if (_mapboxMap != null && _pointAnnotationManager != null) {
          _addMarkerAtPosition(
            lat: position.latitude,
            lng: position.longitude,
            isCurrentLocation: true
          );
          
          // Перемещаем камеру к текущему местоположению
          _mapboxMap!.setCamera(
            CameraOptions(
              center: Point(
                coordinates: Position(
                  position.longitude,
                  position.latitude
                )
              ),
              zoom: 13.0,
            ),
          );
        }
        
        // Запускаем геокодинг для получения названия текущего местоположения
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
      
      // Try using last known position as fallback before using Moscow
      try {
        AppLogger.log("🔄 Trying to get last known position as fallback");
        final lastPosition = await geo.Geolocator.getLastKnownPosition();
        
        if (lastPosition != null) {
          AppLogger.log("✅ Last known position found: ${lastPosition.latitude}, ${lastPosition.longitude}");
          if (mounted) {
            setState(() {
              _currentLocation = GeoLocation(
                latitude: lastPosition.latitude,
                longitude: lastPosition.longitude
              );
              _selectedLocation = _currentLocation;
              _locationName = "Last Known Location";
              _isLoading = false;
            });
            
            // Add marker
            if (_mapboxMap != null && _pointAnnotationManager != null) {
              _addMarkerAtPosition(
                lat: lastPosition.latitude,
                lng: lastPosition.longitude,
                isCurrentLocation: true
              );
              
              // Перемещаем камеру к последнему известному местоположению
              _mapboxMap!.setCamera(
                CameraOptions(
                  center: Point(
                    coordinates: Position(
                      lastPosition.longitude,
                      lastPosition.latitude
                    )
                  ),
                  zoom: 13.0,
                ),
              );
            }
            
            // Запускаем геокодинг для получения названия текущего местоположения
            _reverseGeocode(lastPosition.latitude, lastPosition.longitude).then((name) {
              if (mounted && name != null && name.isNotEmpty) {
                setState(() {
                  _locationName = name;
                  AppLogger.log("✅ Last known location name updated: $_locationName");
                });
              }
            });
            
            return;
          }
        } else {
          AppLogger.log("⚠️ No last known position available");
        }
      } catch (secondError) {
        AppLogger.log("⚠️ Error getting last known position: $secondError");
      }
      
      // Finally fall back to default coordinates
      if (mounted) {
        setState(() {
          _currentLocation = GeoLocation(
            latitude: MapboxConfig.DEFAULT_LATITUDE,
            longitude: MapboxConfig.DEFAULT_LONGITUDE
          );
          // Также устанавливаем значение по умолчанию как выбранное
          _selectedLocation = _currentLocation;
          _locationName = "Default Location (New York)";
          _isLoading = false;
          
          // Если карта уже инициализирована, перемещаем камеру к координатам по умолчанию
          if (_mapboxMap != null) {
            _mapboxMap!.setCamera(
              CameraOptions(
                center: Point(
                  coordinates: Position(
                    MapboxConfig.DEFAULT_LONGITUDE,
                    MapboxConfig.DEFAULT_LATITUDE
                  )
                ),
                zoom: 10.0,
              ),
            );
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Could not determine your location. Using default location.'),
              duration: const Duration(seconds: 3),
            ),
          );
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
    
    // Сначала сохраняем ссылку на карту, чтобы она была доступна
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
    
    // Сразу вызываем обновление состояния, чтобы отобразить изменения
    if (mounted) {
      setState(() {
        // Оставляем _isLoading = true, но обновляем UI
      });
    }
    
    try {
      // Небольшая пауза после создания карты для стабильности
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Устанавливаем стиль карты
      try {
        await mapboxMap.style.setStyleURI(MapboxConfig.STREETS_STYLE_URI);
        AppLogger.log("🎨 Установлен стиль карты: ${MapboxConfig.STREETS_STYLE_URI}");
        
        // Минимальная задержка для загрузки стиля
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Регистрируем изображения маркеров
        try {
          await MapboxConfig.registerMapboxMarkerImages(mapboxMap);
          AppLogger.log("🔹 Изображения маркеров зарегистрированы");
        } catch (e) {
          AppLogger.log("⚠️ Ошибка регистрации изображений маркеров: $e");
        }
      } catch (e) {
        AppLogger.log("⚠️ Ошибка установки стиля карты: $e");
      }
      
      // Создаем менеджер аннотаций для маркеров
      try {
        AppLogger.log("📍 Создание менеджера аннотаций");
        _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
        AppLogger.log("✅ Менеджер аннотаций создан");
      } catch (e) {
        AppLogger.log("⚠️ Ошибка создания менеджера аннотаций: $e");
      }
      
      // Устанавливаем _isLoading = false, чтобы скрыть индикатор загрузки
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
      
      // Отрисовываем маркер и перемещаем камеру, если уже выбрана локация
      if (_selectedLocation != null) {
        await _addMarkerAtPosition(
          lat: _selectedLocation!.latitude,
          lng: _selectedLocation!.longitude
        );
        
        // Перемещаем камеру к выбранной локации
        await _moveCameraToLocation(
          latitude: _selectedLocation!.latitude,
          longitude: _selectedLocation!.longitude
        );
      } 
      // Если нет выбранной локации, но есть текущая, показываем ее
      else if (_currentLocation != null) {
        // Добавляем маркер геолокации пользователя
        await _addUserLocationMarker();
        
        // Перемещаем камеру к текущей локации
        await _moveCameraToLocation(
          latitude: _currentLocation!.latitude,
          longitude: _currentLocation!.longitude,
          zoom: 12.0
        );
      }
      
      // Запускаем таймер проверки здоровья карты
      _startMapHealthCheckTimer();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      AppLogger.log("✅ Карта полностью инициализирована");
      
      // Включаем все жесты для карты, включая масштабирование
      await mapboxMap.gestures.updateSettings(
        GesturesSettings(
          pinchToZoomEnabled: true,  // Включаем масштабирование двумя пальцами
          doubleTapToZoomInEnabled: true,  // Включаем зум двойным тапом
          doubleTouchToZoomOutEnabled: true,  // Включаем уменьшение двумя пальцами
          quickZoomEnabled: true,  // Включаем быстрое масштабирование
          scrollEnabled: true,  // Оставляем возможность перемещать карту
          rotateEnabled: true,  // Оставляем возможность поворачивать карту
        )
      );
      AppLogger.log("✅ All map gestures enabled including zoom");
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
      
      // Check if tap point exists
      if (mapContext.point == null) {
        AppLogger.log("❌ Could not determine tap coordinates - mapContext.point is null");
        
        // Показываем визуальный индикатор проблемы
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Не удалось определить координаты нажатия"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      // Get coordinates from gesture context
      final coordinates = mapContext.point.coordinates;
      
      if (coordinates == null || coordinates.isEmpty) {
        AppLogger.log("❌ Null or empty coordinates in tap event");
        
        // Показываем визуальный индикатор проблемы
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Координаты нажатия отсутствуют"),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }
      
      AppLogger.log("📊 Raw coordinates: $coordinates (type: ${coordinates.runtimeType})");
      
      // Default values
      double lat = MapboxConfig.DEFAULT_LATITUDE;
      double lng = MapboxConfig.DEFAULT_LONGITUDE;
      
      // Упрощенная и более надежная обработка координат
      if (coordinates is List && coordinates.length >= 2) {
        // Mapbox обычно дает координаты в формате [lng, lat]
        final first = coordinates[0];
        final second = coordinates[1];
        
        if (first != null && second != null) {
          lng = first is double ? first : (first as num).toDouble();
          lat = second is double ? second : (second as num).toDouble();
          AppLogger.log("✅ Extracted coordinates from list: lng=$lng, lat=$lat");
        }
      } else if (coordinates is Position) {
        // Position из Mapbox SDK
        lng = coordinates.lng.toDouble(); // Преобразуем num в double
        lat = coordinates.lat.toDouble(); // Преобразуем num в double
        AppLogger.log("✅ Extracted coordinates from Position: lng=$lng, lat=$lat");
      } else {
        AppLogger.log("❌ Unsupported coordinate format: ${coordinates.runtimeType}");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Неподдерживаемый формат координат"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Basic coordinate validation
      if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
        AppLogger.log("❌ Invalid coordinates: lat=$lat, lng=$lng");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Некорректные координаты"),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
      
      // Update state with the selected location
      AppLogger.log("✅ Setting selected location to: lat=$lat, lng=$lng");
      if (mounted) {
        setState(() {
          _selectedLocation = GeoLocation(latitude: lat, longitude: lng);
          
          // Используем простое имя локации пока не получим более точное через геокодинг
          _locationName = "Выбранная точка";
        });
        
        // Отображаем маркер ТОЧНО в месте тапа
        _addMarkerAtPosition(lat: lat, lng: lng, isCurrentLocation: false);
        
        // Перемещаем камеру к новой точке
        _moveCameraToLocation(latitude: lat, longitude: lng);
        
        // Запускаем геокодинг асинхронно - уже после размещения маркера
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Ошибка при обработке нажатия"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Attempt to get location name from coordinates using reverse geocoding
  Future<String?> _reverseGeocode(double lat, double lng) async {
    try {
      // Используем новый метод из MapboxService
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
    // Проверяем доступность карты
    if (_mapboxMap == null || !mounted) {
      AppLogger.log("❌ Невозможно переместить камеру: карта не инициализирована или виджет отсоединен");
      return;
    }
    
    try {
      // Создаем точку с координатами (lng, lat)
      final point = Point(
        coordinates: Position(longitude, latitude)
      );
      
      // Создаем опции камеры
      final cameraOptions = CameraOptions(
        center: point,
        zoom: zoom
      );
      
      AppLogger.log("📍 Перемещение камеры к координатам: lat=$latitude, lng=$longitude, zoom=$zoom");
      
      // Сначала пробуем с анимацией
      try {
        await _mapboxMap!.flyTo(
          cameraOptions,
          MapAnimationOptions(duration: 700) // Уменьшаем время анимации для стабильности
        );
        AppLogger.log("✅ Камера перемещена с анимацией");
        return;
      } catch (e) {
        AppLogger.log("⚠️ Ошибка перемещения камеры с анимацией: $e");
      }
      
      // Если анимация не сработала, пробуем без анимации
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
    // Базовые проверки
    if (!mounted) {
      AppLogger.log("⚠️ Widget не прикреплен к дереву, отмена добавления маркера");
      return;
    }
    
    if (_mapboxMap == null) {
      AppLogger.log("⚠️ Карта не инициализирована, отмена добавления маркера");
      return;
    }
    
    try {
      // Если менеджер маркеров не был создан, создаем его
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


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Location'),
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
                // Map in RepaintBoundary for rendering optimization
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
      bottomNavigationBar: BottomAppBar(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: ElevatedButton(
            onPressed: _selectedLocation != null
                ? _navigateToDescriptionScreen
                : null,
            child: const Text('Continue'),
          ),
        ),
      ),
    );
  }

  /// Initialization of map and related components
  Future<void> _initializeMap() async {
    if (!mounted) return;
    
    AppLogger.log("🔄 Reinitializing map");
    
    // Update state
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Cancel existing timer
      _mapLoadingTimer?.cancel();
      
      // Set a new timer to track loading
      _mapLoadingTimer = Timer(const Duration(seconds: 20), () {
        if (mounted && _isLoading) {
          AppLogger.log("⏱️ Map loading timeout exceeded");
          setState(() {
            _error = "Map loading timed out. Please try again.";
            _isLoading = false;
          });
        }
      });
      
      // Get current location
      await _getCurrentLocation();
      
      // If map is not initialized - wait for _onMapCreated to be called
      if (_mapboxMap == null) {
        AppLogger.log("⏳ Map not initialized, waiting for creation");
        return;
      }
      
      // Проверяем состояние карты перед использованием
      bool isMapValid = false;
      try {
        isMapValid = await _mapboxMap!.style.isStyleLoaded();
        AppLogger.log("🔍 Проверка стиля карты: ${isMapValid ? "загружен" : "не загружен"}");
      } catch (e) {
        AppLogger.log("⚠️ Ошибка при проверке состояния карты: $e");
        // Предполагаем, что карта не в порядке
        isMapValid = false;
      }
      
      // Если карта недействительна, пробуем пересоздать или восстановить карту
      if (!isMapValid) {
        AppLogger.log("⚠️ Карта в недействительном состоянии, пытаемся восстановить");
        
        // Попытка 1: Просто переустановить стиль
        try {
          await _mapboxMap!.style.setStyleURI(MapboxConfig.STREETS_STYLE_URI);
          AppLogger.log("🔄 Стиль карты переустановлен");
          
          // Проверяем, помогло ли
          await Future.delayed(Duration(milliseconds: 500));
          isMapValid = await _mapboxMap!.style.isStyleLoaded();
          AppLogger.log("🔍 Повторная проверка стиля: ${isMapValid ? "загружен" : "не загружен"}");
        } catch (e) {
          AppLogger.log("⚠️ Ошибка при переустановке стиля: $e");
        }
      }
      
      // Если карта все еще недействительна, показываем ошибку и просим пользователя перезагрузить
      if (!isMapValid) {
        AppLogger.log("❌ Не удалось восстановить карту");
        if (mounted) {
          setState(() {
            _error = "Ошибка загрузки карты. Пожалуйста, нажмите 'Повторить'.";
            _isLoading = false;
          });
        }
        return;
      }
      
      // При перезагрузке проверяем и пересоздаем менеджер аннотаций
      if (_pointAnnotationManager == null) {
        try {
          AppLogger.log("🔄 Создание менеджера аннотаций");
          
          // Несколько попыток создать менеджер
          int attempts = 0;
          while (attempts < 3 && _pointAnnotationManager == null) {
            try {
              _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
              if (_pointAnnotationManager != null) {
                AppLogger.log("✅ Менеджер аннотаций успешно создан");
                break;
              }
            } catch (e) {
              AppLogger.log("⚠️ Ошибка создания менеджера аннотаций (попытка ${attempts + 1}): $e");
            }
            attempts++;
            await Future.delayed(Duration(milliseconds: 300));
          }
        } catch (e) {
          AppLogger.log("❌ Критическая ошибка создания менеджера аннотаций: $e");
        }
      }
      
      // Если менеджер аннотаций все еще не создан - выводим предупреждение
      if (_pointAnnotationManager == null) {
        AppLogger.log("⚠️ Менеджер аннотаций не создан, маркеры могут не отображаться");
      }
      
      // If there's a selected location - add marker
      if (_selectedLocation != null && _mapboxMap != null) {
        try {
          // Добавляем задержку перед операциями
          await Future.delayed(Duration(milliseconds: 300));
          
          await _addMarkerAtPosition(
            lat: _selectedLocation!.latitude, 
            lng: _selectedLocation!.longitude
          );
          
          // Перемещаем камеру к выбранной локации
          await _moveCameraToLocation(
            latitude: _selectedLocation!.latitude,
            longitude: _selectedLocation!.longitude
          );
        } catch (e) {
          AppLogger.log("⚠️ Ошибка при отображении выбранной локации: $e");
        }
      } 
      // If no selected location but current location exists - show it
      else if (_currentLocation != null && _mapboxMap != null) {
        try {
          AppLogger.log("🎥 Moving camera to current location");
          
          // Добавляем задержку перед операциями
          await Future.delayed(Duration(milliseconds: 300));
          
          // Перемещаем камеру к текущей локации с меньшим зумом
          await _moveCameraToLocation(
            latitude: _currentLocation!.latitude,
            longitude: _currentLocation!.longitude,
            zoom: 12.0 // Меньший зум для текущего местоположения
          );
        } catch (e) {
          AppLogger.log("⚠️ Ошибка при перемещении камеры к текущему местоположению: $e");
        }
      }
      
      // Запускаем таймер проверки здоровья карты
      _startMapHealthCheckTimer();
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      AppLogger.log("✅ Map successfully reinitialized");
    } catch (e) {
      AppLogger.log("❌ Error reinitializing map: $e");
      
      if (mounted) {
        setState(() {
          _error = "Error reloading map: $e";
          _isLoading = false;
        });
      }
    }
  }

  // Показать диалог поиска с улучшенным интерфейсом
  void _showNewSearchDialog() async {
    setState(() {
      _isSearching = false;
      _searchResults = [];
    });
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        // Используем StatefulBuilder для управления состоянием внутри диалога
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Локальные переменные для хранения состояния диалога
            final TextEditingController dialogSearchController = TextEditingController();
            bool isSearching = false;
            List<Map<String, dynamic>> results = [];
            
            // Функция для выполнения поиска
            void performSearch(String query) async {
              if (query.isEmpty) {
                setModalState(() {
                  results = [];
                  isSearching = false;
                });
                return;
              }
              
              setModalState(() {
                isSearching = true;
              });
              
              try {
                // Используем новый комбинированный поиск
                final searchResults = await MapboxService.searchLocationWithAttractions(
                  query,
                  proximityLng: _currentLocation?.longitude,
                  proximityLat: _currentLocation?.latitude,
                );
                
                setModalState(() {
                  results = searchResults.map<Map<String, dynamic>>((result) {
                    return {
                      'name': result.placeName,
                      'location': result.location
                    };
                  }).toList();
                  isSearching = false;
                });
              } catch (e) {
                AppLogger.log('Exception searching locations: $e');
                setModalState(() {
                  results = [];
                  isSearching = false;
                });
              }
            }
            
            // Настраиваем дебаунс для поиска
            final debounce = Debouncer(milliseconds: 500);
            
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 16,
                left: 16,
                right: 16
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Заголовок
                  Padding(
                    padding: const EdgeInsets.only(left: 8.0, bottom: 16.0),
                    child: Text(
                      'Find location',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  
                  // Поле поиска
                  TextField(
                    controller: dialogSearchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search location...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: isSearching 
                        ? const SizedBox(
                            width: 24, 
                            height: 24, 
                            child: CircularProgressIndicator(strokeWidth: 2)
                          )
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              dialogSearchController.clear();
                              setModalState(() {
                                results = [];
                              });
                            },
                          ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onChanged: (query) {
                      debounce.run(() {
                        performSearch(query);
                      });
                    },
                  ),
                  
                  // Результаты поиска
                  const SizedBox(height: 16),
                  if (isSearching)
                    const Center(
                      child: CircularProgressIndicator(),
                    )
                  else if (results.isEmpty)
                    Container(
                      alignment: Alignment.center,
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      child: Column(
                        children: [
                          Icon(
                            Icons.search,
                            size: 48,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            dialogSearchController.text.isEmpty
                                ? 'Find location'
                                : 'No results found',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    LimitedBox(
                      maxHeight: 300,
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: results.length,
                        itemBuilder: (context, index) {
                          final result = results[index];
                          return ListTile(
                            leading: const Icon(Icons.place, color: Colors.red),
                            title: Text(
                              result['name'],
                              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              result['name'],
                              style: GoogleFonts.poppins(fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onTap: () {
                              // Закрыть диалог и выбрать локацию
                              Navigator.pop(context);
                              
                              final location = result['location'] as GeoLocation;
                              _selectLocation(location, result['name']);
                            },
                          );
                        },
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  // Выбор локации из результатов поиска
  void _selectLocation(GeoLocation location, String name) {
    AppLogger.log("Выбрана локация: $name, координаты: ${location.latitude}, ${location.longitude}");
    
    // Сначала сохраняем выбранную локацию
    setState(() {
      _selectedLocation = location;
      _locationName = name;
      
      // Очищаем поисковый интерфейс
      _isSearching = false;
      _searchResults = [];
      _searchController.text = name;
    });
    
    // Если карта не инициализирована, просто выходим
    if (_mapboxMap == null) {
      AppLogger.log("⚠️ Карта не инициализирована, маркер будет добавлен при инициализации карты");
      return;
    }
    
    // Добавляем маркер и перемещаем камеру
    _addMarkerAtPosition(
      lat: location.latitude, 
      lng: location.longitude, 
      isCurrentLocation: false
    );
    
    _moveCameraToLocation(
      latitude: location.latitude, 
      longitude: location.longitude
    );
  }


  void _navigateToDescriptionScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadDescriptionScreen(
          images: widget.images,
          selectedLocation: _selectedLocation!,
          locationName: _locationName,
          firstImageOriginal: widget.firstImageOriginal,
        ),
      ),
    );
  }

  /// Builds the map widget
  Widget _buildMapWidget() {
    return Container(
      width: double.infinity,
      // Адаптивная высота вместо фиксированной
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Stack(
        children: [
          // Всегда показываем MapWidget, независимо от состояния _mapboxMap
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: MapWidget(
              // Используем постоянный ключ для стабильности
              key: const ValueKey('upload_location_map'),
              // Используем самый простой стиль для максимальной совместимости
              styleUri: MapboxConfig.STREETS_STYLE_URI,
              onMapCreated: _onMapCreated,
              // Настраиваем обработчик тапов по карте
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
            ),
          ),
          
          // Если карта загружается или еще не инициализирована, показываем загрузочный индикатор
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
            
          // Если есть ошибка, показываем сообщение об ошибке и кнопку повтора
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
                    const SizedBox(height: 8),
                    Text(
                      'Пожалуйста, повторите попытку или перезапустите приложение.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _initializeMap, // Вызываем прямо _initializeMap вместо _reinitializeMapIfNeeded
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
          // Маркер геолокации теперь добавляется непосредственно на карту через annotations
        ],
      ),
    );
  }

  PointAnnotation? _userLocationAnnotation;
  
  /// Добавляет или обновляет маркер текущей геолокации пользователя на карте
  Future<void> _addUserLocationMarker() async {
    if (_mapboxMap == null || _pointAnnotationManager == null || _currentLocation == null) {
      return;
    }
    
    try {
      // Сначала удаляем старый маркер геолокации, если он есть
      if (_userLocationAnnotation != null) {
        try {
          await _pointAnnotationManager!.delete(_userLocationAnnotation!);
        } catch (e) {
          AppLogger.log("⚠️ Ошибка при удалении старого маркера геолокации: $e");
        }
      }
      
      // Регистрируем изображение маркера геолокации, если еще не зарегистрировано
      final userLocationMarkerId = "user-location-marker";
      bool hasUserMarker = await _mapboxMap!.style.hasStyleImage(userLocationMarkerId);
      
      if (!hasUserMarker) {
        try {
          // Загружаем изображение маркера из assets
          final ByteData data = await rootBundle.load('assets/Images/map-marker.png');
          final Uint8List bytes = data.buffer.asUint8List();
          
          // Декодируем изображение
          final ui.Codec codec = await ui.instantiateImageCodec(bytes);
          final ui.FrameInfo frameInfo = await codec.getNextFrame();
          final ui.Image image = frameInfo.image;
          
          // Конвертируем в ByteData
          final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData == null) {
            AppLogger.log("❌ Не удалось преобразовать изображение маркера в байты");
            image.dispose();
            return;
          }
          
          final Uint8List imageData = byteData.buffer.asUint8List();
          
          // Создаем MbxImage для Mapbox
          final MbxImage mbxImage = MbxImage(
            width: image.width,
            height: image.height,
            data: imageData,
          );
          
          // Освобождаем ресурсы
          image.dispose();
          
          // Регистрируем изображение на карте
          await _mapboxMap!.style.addStyleImage(
            userLocationMarkerId,
            1.0, // scale
            mbxImage,
            false, // sdf
            [], // stretchX
            [], // stretchY
            null, // content
          );
          AppLogger.log("✅ Зарегистрировано изображение маркера геолокации");
        } catch (e) {
          AppLogger.log("❌ Ошибка регистрации изображения маркера геолокации: $e");
          return;
        }
      }
      
      // Создаем новый маркер геолокации
      final point = Point(
        coordinates: Position(
          _currentLocation!.longitude,
          _currentLocation!.latitude,
        ),
      );
      
      final options = PointAnnotationOptions(
        geometry: point,
        iconImage: userLocationMarkerId,
        iconSize: 0.2,
        iconAnchor: IconAnchor.BOTTOM,
      );
      
      _userLocationAnnotation = await _pointAnnotationManager!.create(options);
      AppLogger.log("✅ Маркер геолокации добавлен на карту");
      
    } catch (e) {
      AppLogger.log("❌ Ошибка при добавлении маркера геолокации: $e");
    }
  }
  
  /// Преобразует геокоординаты в координаты экрана
  Future<ScreenCoordinate?> _getScreenCoordinatesForLocation(GeoLocation location) async {
    if (_mapboxMap == null) return null;
    
    try {
      final coordinate = await _mapboxMap!.pixelForCoordinate(
        Point(
          coordinates: Position(
            location.longitude,
            location.latitude,
          ),
        ),
      );
      return coordinate;
    } catch (e) {
      AppLogger.log('Error converting geo coordinates to screen coordinates: $e');
      return null;
    }
  }
  
  void _onSearchResultSelected(SearchResult result) {
    AppLogger.log("🎯 Выбрана локация: ${result.placeName}");
    AppLogger.log("📍 Координаты: lat=${result.latitude}, lng=${result.longitude}");
    
    // Сохраняем выбранную локацию
    setState(() {
      _selectedLocation = GeoLocation(
        latitude: result.latitude, 
        longitude: result.longitude
      );
      _locationName = result.placeName;
      
      // Очищаем поисковый интерфейс
      _isSearching = false;
      _searchResults = [];
      _searchController.text = result.placeName;
    });
    
    // Если карта не инициализирована, просто выходим
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

  // Helper method to show location service disabled dialog
  void _showLocationServiceDisabledDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Services Disabled'),
        content: Text('Please enable location services in your device settings to use your current location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  // Helper method to show permission denied dialog
  void _showPermissionDeniedDialog({required bool isPermanent}) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Location Permission Required'),
        content: Text(isPermanent 
          ? 'Location permission is permanently denied. Please enable it in app settings.'
          : 'Location permission is required to use your current location.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('OK'),
          ),
          if (isPermanent)
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                geo.Geolocator.openAppSettings();
              },
              child: Text('Open Settings'),
            ),
        ],
      ),
    );
  }

  // Таймер для проверки состояния карты
  void _startMapHealthCheckTimer() {
    _mapHealthCheckTimer?.cancel();
    
    // Проверяем состояние карты каждые 3 секунды
    _mapHealthCheckTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      if (!mounted || _mapboxMap == null) {
        timer.cancel();
        return;
      }
      
      try {
        // Проверяем состояние стиля карты
        final isStyleLoaded = await _mapboxMap!.style.isStyleLoaded();
        
        if (!isStyleLoaded) {
          AppLogger.log("⚠️ Обнаружена проблема со стилем карты, пытаемся восстановить");
          
          // Пробуем переустановить стиль карты
          try {
            await _mapboxMap!.style.setStyleURI(MapboxConfig.STREETS_STYLE_URI);
            AppLogger.log("🔄 Стиль карты переустановлен");
          } catch (e) {
            AppLogger.log("❌ Не удалось переустановить стиль карты: $e");
          }
        }
      } catch (e) {
        AppLogger.log("⚠️ Ошибка при проверке состояния карты: $e");
      }
    });
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
