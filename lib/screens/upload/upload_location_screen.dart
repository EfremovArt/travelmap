import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../../config/mapbox_config.dart';
import 'upload_description_screen.dart';
import '../../models/location.dart';
import 'dart:async';
import '../../models/search_result.dart';
import '../../utils/permissions_manager.dart';
import '../../utils/map_helper.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../../services/mapbox_service.dart';

class UploadLocationScreen extends StatefulWidget {
  final List<File> images;

  const UploadLocationScreen({
    Key? key,
    required this.images,
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
  
  // Таймер для проверки загрузки карты
  Timer? _mapLoadingTimer;

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
      _mapLoadingTimer = Timer(const Duration(seconds: 15), () {
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
    
    // Очистка всех ресурсов карты
    if (_mapboxMap != null) {
      try {
        print("Очистка ресурсов карты в upload_location_screen");
        // В новых версиях SDK нужно явно освобождать ресурсы
        _pointAnnotationManager = null;
        _mapboxMap = null;
      } catch (e) {
        print("Ошибка при очистке ресурсов карты в upload_location_screen: $e");
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
    
    print("📍 Starting location determination");
    
    try {
      // First check if location service is enabled
      bool isLocationServiceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      print("🔍 Location service status: $isLocationServiceEnabled");
      
      if (!isLocationServiceEnabled) {
        print("❌ Location service is disabled");
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
      print("📱 Initial permission status: $permission");
      
      if (permission == geo.LocationPermission.denied) {
        // Explicitly request permission
        permission = await geo.Geolocator.requestPermission();
        print("📱 After request permission status: $permission");
      }
      
      // Handle all permission cases
      if (permission == geo.LocationPermission.denied) {
        print("❌ Location permission denied");
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
        print("❌ Location permission permanently denied");
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
      print("✅ Permission granted, getting position with timeout");
      final position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 20) // Increase timeout for better chance of success
      );
      
      print("✅ Position obtained: ${position.latitude}, ${position.longitude}");
      
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
              print("✅ Current location name updated: $_locationName");
            });
          }
        });
      }
    } catch (e) {
      print("❌ Error determining location: $e");
      
      // Try using last known position as fallback before using Moscow
      try {
        print("🔄 Trying to get last known position as fallback");
        final lastPosition = await geo.Geolocator.getLastKnownPosition();
        
        if (lastPosition != null) {
          print("✅ Last known position found: ${lastPosition.latitude}, ${lastPosition.longitude}");
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
                  print("✅ Last known location name updated: $_locationName");
                });
              }
            });
            
            return;
          }
        } else {
          print("⚠️ No last known position available");
        }
      } catch (secondError) {
        print("⚠️ Error getting last known position: $secondError");
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
          _locationName = "Default Location (Moscow)";
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
  void _onMapCreated(MapboxMap mapboxMap) async {
    print("🗺️ Карта создана успешно");
    
    if (!mounted) {
      print("⚠️ Widget не прикреплен к дереву, инициализация карты остановлена");
      return;
    }
    
    try {
      // Сохраняем ссылку на карту
      _mapboxMap = mapboxMap;
      
      // Устанавливаем стиль карты
      try {
        await mapboxMap.style.setStyleURI(MapboxConfig.STREETS_STYLE_URI);
        print("🎨 Устанавливаем стиль карты: ${MapboxConfig.STREETS_STYLE_URI}");
        
        // Ждем загрузки стиля с таймаутом
        int attempts = 0;
        bool styleLoaded = false;
        while (!styleLoaded && attempts < 5) {
          try {
            styleLoaded = await mapboxMap.style.isStyleLoaded();
            if (styleLoaded) break;
          } catch (e) {
            print("⚠️ Ошибка проверки загрузки стиля: $e");
          }
          attempts++;
          await Future.delayed(Duration(milliseconds: 200));
        }
        
        // Регистрируем изображения маркеров после загрузки стиля
        await MapboxConfig.registerMapboxMarkerImages(mapboxMap);
      } catch (e) {
        print("⚠️ Ошибка установки стиля карты: $e");
      }
      
      // Создаем менеджер аннотаций для маркеров с повторными попытками
      int annotationAttempts = 0;
      const maxAnnotationAttempts = 3;
      
      while (annotationAttempts < maxAnnotationAttempts) {
        try {
          print("📍 Инициализация менеджера маркеров (попытка ${annotationAttempts + 1})");
          _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
          
          if (_pointAnnotationManager != null) {
            print("✅ Менеджер маркеров успешно создан");
            break;
          }
        } catch (e) {
          print("⚠️ Ошибка создания менеджера маркеров (попытка ${annotationAttempts + 1}): $e");
        }
        
        annotationAttempts++;
        if (annotationAttempts < maxAnnotationAttempts) {
          await Future.delayed(Duration(milliseconds: 500));
        }
      }
      
      // Обновляем состояние UI в главном потоке
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
      
      // Если есть текущая позиция, перемещаем камеру к ней
      if (_currentLocation != null) {
        try {
          await mapboxMap.setCamera(
            CameraOptions(
              center: Point(
                coordinates: Position(
                  _currentLocation!.longitude,
                  _currentLocation!.latitude
                )
              ),
              zoom: 12.0,
            ),
          );
          print("✅ Камера перемещена к текущей позиции");
        } catch (e) {
          print("⚠️ Ошибка перемещения камеры: $e");
        }
      }
      
      print("✅ Карта полностью инициализирована");
    } catch (e) {
      print("❌ Критическая ошибка при инициализации карты: $e");
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
    print("📌 Map tap received at ${DateTime.now()}");
    
    if (!mounted) {
      print("❌ Widget not mounted, ignoring tap");
      return;
    }

    try {
      print("🔍 MapContext details: point=${mapContext.point}");
      
      // Check if tap point exists
      if (mapContext.point == null) {
        print("❌ Could not determine tap coordinates - mapContext.point is null");
        
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
        print("❌ Null or empty coordinates in tap event");
        
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
      
      print("📊 Raw coordinates: $coordinates (type: ${coordinates.runtimeType})");
      
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
          print("✅ Extracted coordinates from list: lng=$lng, lat=$lat");
        }
      } else if (coordinates is Position) {
        // Position из Mapbox SDK
        lng = coordinates.lng.toDouble(); // Преобразуем num в double
        lat = coordinates.lat.toDouble(); // Преобразуем num в double
        print("✅ Extracted coordinates from Position: lng=$lng, lat=$lat");
      } else {
        print("❌ Unsupported coordinate format: ${coordinates.runtimeType}");
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
        print("❌ Invalid coordinates: lat=$lat, lng=$lng");
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
      print("✅ Setting selected location to: lat=$lat, lng=$lng");
      if (mounted) {
        setState(() {
          _selectedLocation = GeoLocation(latitude: lat, longitude: lng);
          
          // Используем простое имя локации пока не получим более точное через геокодинг
          _locationName = "Выбранная точка";
        });
        
        // Отображаем маркер ТОЧНО в месте тапа
        _addMarkerAtPosition(lat: lat, lng: lng, isCurrentLocation: false);
        
        // Запускаем геокодинг асинхронно - уже после размещения маркера
        _reverseGeocode(lat, lng).then((name) {
          if (mounted && name != null && name.isNotEmpty) {
            setState(() {
              _locationName = name;
              print("✅ Location name updated: $_locationName");
            });
          }
        });
      }
    } catch (e) {
      print("❌ Error processing map tap: $e");
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
      print("🔍 Attempting reverse geocoding for: $lat, $lng");
      final response = await http.get(
        Uri.parse(
          "https://api.mapbox.com/geocoding/v5/mapbox.places/$lng,$lat.json?access_token=${MapboxConfig.ACCESS_TOKEN}&language=en"
        )
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final features = data['features'] as List<dynamic>;
        
        if (features.isNotEmpty) {
          // Get the first feature's place_name as the location name
          final name = features[0]['place_name'];
          print("✅ Reverse geocoding successful: $name");
          return name;
        }
      }
      
      print("⚠️ Reverse geocoding returned no results");
      return null;
    } catch (e) {
      print("❌ Error during reverse geocoding: $e");
      return null;
    }
  }

  // Выделяем перемещение камеры в отдельный метод
  Future<void> _moveCameraToLocation(Point point) async {
    if (_mapboxMap == null || !mounted) return;
    
    try {
      // Упрощаем перемещение камеры для снижения нагрузки
      await _mapboxMap!.setCamera(
        CameraOptions(
          center: point,
          zoom: 13.0,
        ),
      );
    } catch (e) {
      print("Error moving camera: $e");
    }
  }

  /// Добавляет маркер на карту по заданным координатам
  Future<void> _addMarkerAtPosition({
    required double lat, 
    required double lng,
    bool isCurrentLocation = false
  }) async {
    if (!mounted) {
      print("⚠️ Widget не прикреплен к дереву, отмена добавления маркера");
      return;
    }
    
    if (_mapboxMap == null) {
      print("⚠️ Карта не инициализирована, отмена добавления маркера");
      return;
    }
    
    // Если менеджер аннотаций не существует или был уничтожен, пытаемся его пересоздать
    if (_pointAnnotationManager == null) {
      try {
        print("🔄 Пересоздание менеджера маркеров");
        _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
        if (_pointAnnotationManager == null) {
          print("❌ Не удалось создать менеджер маркеров");
          return;
        }
      } catch (e) {
        print("❌ Критическая ошибка при создании менеджера маркеров: $e");
        return;
      }
    }

    try {
      // Очищаем существующие маркеры безопасно
      if (_pointAnnotationManager != null) {
        print("🧹 Удаление существующих маркеров");
        try {
          await _pointAnnotationManager!.deleteAll();
        } catch (e) {
          print("⚠️ Ошибка удаления существующих маркеров: $e");
          // Пробуем пересоздать менеджер
          try {
            _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
            if (_pointAnnotationManager == null) {
              print("❌ Не удалось пересоздать менеджер маркеров");
              return;
            }
          } catch (secondError) {
            print("❌ Не удалось пересоздать менеджер маркеров: $secondError");
            return;
          }
        }
      }
      
      // Выводим точные координаты для отладки
      print("📍 Добавление маркера по координатам: lat=$lat, lng=$lng");
      
      // Создаем маркер с минимальными настройками
      final markerOptions = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(lng, lat)
        ),
        iconImage: isCurrentLocation ? "current-location-marker" : "custom-marker",
        iconSize: 0.1
      );
      
      // Добавляем маркер на карту
      final marker = await _pointAnnotationManager!.create(markerOptions);
      
      if (marker != null) {
        print("✅ Маркер успешно создан по координатам: lat=$lat, lng=$lng");
      } else {
        print("❌ Не удалось создать маркер");
      }
    } catch (e) {
      print("❌ Ошибка при добавлении маркера: $e");
    }
  }

  // Показывает сообщение об ошибке
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Location'),
      ),
      body: Column(
        children: [
          // Search field
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SearchBar(
              controller: _searchController,
              hintText: 'Find a place',
              leading: const Icon(Icons.search),
              onChanged: _onSearchTextChanged,
              onSubmitted: _onSearchSubmitted,
            ),
          ),
          
          // Display search results or map
          Expanded(
            child: _isSearching && _searchResults.isNotEmpty
                ? ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return ListTile(
                        title: Text(result.placeName),
                        subtitle: Text(result.placeAddress),
                        onTap: () => _onSearchResultSelected(result),
                      );
                    },
                  )
                : Stack(
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
    
    print("🔄 Reinitializing map");
    
    // Update state
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      // Cancel existing timer
      _mapLoadingTimer?.cancel();
      
      // Set a new timer to track loading
      _mapLoadingTimer = Timer(const Duration(seconds: 15), () {
        if (mounted && _isLoading) {
          print("⏱️ Map loading timeout exceeded");
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
        print("⏳ Map not initialized, waiting for creation");
        // Don't update _isLoading since it's already set to true
        return;
      }
      
      // If map is initialized - update style
      print("🎨 Updating map style");
      try {
        await _mapboxMap!.style.setStyleURI(MapboxConfig.STREETS_STYLE_URI);
      } catch (e) {
        print("⚠️ Error updating map style: $e");
        // Continue even if there's an error
      }
      
      // Check and recreate annotation manager if needed
      if (_pointAnnotationManager == null && _mapboxMap != null) {
        try {
          print("🔄 Recreating annotation manager");
          _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
        } catch (e) {
          print("⚠️ Error creating annotation manager: $e");
        }
      }
      
      // If there's a selected location - add marker
      if (_selectedLocation != null && _pointAnnotationManager != null) {
        await _addMarkerAtPosition(
          lat: _selectedLocation!.latitude, 
          lng: _selectedLocation!.longitude
        );
      } 
      // If no selected location but current location exists - show it
      else if (_currentLocation != null && _mapboxMap != null) {
        try {
          print("🎥 Moving camera to current location");
          await _mapboxMap!.setCamera(
            CameraOptions(
              center: Point(
                coordinates: Position(
                  _currentLocation!.longitude,
                  _currentLocation!.latitude
                )
              ),
              zoom: 12.0,
            ),
          );
        } catch (e) {
          print("⚠️ Error moving camera: $e");
        }
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
      
      print("✅ Map successfully reinitialized");
    } catch (e) {
      print("❌ Error reinitializing map: $e");
      
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
                final String endpoint = 'https://api.mapbox.com/geocoding/v5/mapbox.places/$query.json';
                final Uri uri = Uri.parse('$endpoint?access_token=${MapboxConfig.ACCESS_TOKEN}&limit=5');
                
                final response = await http.get(uri);
                
                if (response.statusCode == 200) {
                  final Map<String, dynamic> data = json.decode(response.body);
                  final List<dynamic> features = data['features'];
                  
                  setModalState(() {
                    results = features.map<Map<String, dynamic>>((feature) {
                      final List<dynamic> coordinates = feature['center'];
                      final double lng = coordinates[0];
                      final double lat = coordinates[1];
                      final String name = feature['place_name'] ?? 'Unknown location';
                      
                      return {
                        'name': name,
                        'location': GeoLocation(
                          latitude: lat,
                          longitude: lng
                        )
                      };
                    }).toList();
                    isSearching = false;
                  });
                } else {
                  print('Error searching locations: ${response.statusCode}');
                  setModalState(() {
                    results = [];
                    isSearching = false;
                  });
                }
              } catch (e) {
                print('Exception searching locations: $e');
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
    setState(() {
      _selectedLocation = location;
      _locationName = name;
    });
    
    // Создаем точку для центрирования карты
    final point = Point(
      coordinates: Position(
        location.longitude,
        location.latitude,
      ),
    );
    
    // Перемещаем карту на выбранную локацию
    _moveCameraToLocation(point);
    
    // Добавляем маркер на карту
    _addMarkerAtPosition(lat: location.latitude, lng: location.longitude, isCurrentLocation: false);
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search location...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _isSearching 
            ? const SizedBox(
                width: 24, 
                height: 24, 
                child: CircularProgressIndicator(strokeWidth: 2)
              )
            : IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  setState(() {
                    _searchResults = [];
                  });
                },
              ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onSubmitted: (_) => _showNewSearchDialog(),
        onTap: _showNewSearchDialog,
      ),
    );
  }

  Widget _buildSelectedLocationInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(Icons.place, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _locationName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}, Lng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        color: Colors.black.withOpacity(0.5),
        child: LimitedBox(
          maxHeight: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final result = _searchResults[index];
              return ListTile(
                leading: const Icon(Icons.place, color: Colors.red),
                title: Text(
                  result.name,
                  style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  result.name,
                  style: GoogleFonts.poppins(fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () {
                  _selectLocation(result.location, result.name);
                },
              );
            },
          ),
        ),
      ),
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
          ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: MapWidget(
              // Используем простой стабильный ключ
              key: const ValueKey('location_map'),
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
          if (_isLoading || _mapboxMap == null)
            const Center(
              child: CircularProgressIndicator(),
            ),
          if (_error != null)
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  Text(
                    'Ошибка загрузки карты: $_error',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initializeMap,
                    child: const Text('Повторить'),
                  ),
                ],
              ),
            ),
          // Добавляем пульсирующую точку, если есть текущее местоположение
          if (_currentLocation != null && _mapboxMap != null && !_isLoading)
            _buildPulsingUserLocationMarker(),
        ],
      ),
    );
  }

  /// Создает пульсирующий маркер для отображения текущего местоположения пользователя
  Widget _buildPulsingUserLocationMarker() {
    return StreamBuilder<ScreenCoordinate?>(
      stream: Stream.periodic(const Duration(milliseconds: 100))
        .asyncMap((_) => _getScreenCoordinatesForLocation(_currentLocation!)),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data == null) {
          return const SizedBox.shrink(); // Если координаты еще не готовы, ничего не отображаем
        }
        
        final screenCoordinate = snapshot.data!;
        
        return Positioned(
          left: screenCoordinate.x.toDouble() - 15,
          top: screenCoordinate.y.toDouble() - 15,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  // Внешний пульсирующий круг
                  Container(
                    width: 30 + (10 * _pulseAnimation.value),
                    height: 30 + (10 * _pulseAnimation.value),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withOpacity(0.3 * (1 - _pulseAnimation.value)),
                    ),
                  ),
                  // Средний круг
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue.withOpacity(0.5),
                    ),
                  ),
                  // Внутренний круг
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.blue,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
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
      print('Error converting geo coordinates to screen coordinates: $e');
      return null;
    }
  }

  // Методы обработки поиска
  void _onSearchTextChanged(String value) {
    setState(() {
      _isSearching = value.isNotEmpty;
      if (!_isSearching) {
        _searchResults = [];
      }
    });
    
    if (value.isNotEmpty) {
      _performSearch(value);
    }
  }
  
  void _onSearchSubmitted(String value) {
    if (value.isNotEmpty) {
      _performSearch(value);
    }
  }
  
  Future<void> _performSearch(String query) async {
    try {
      final results = await MapboxService.searchLocation(query);
      setState(() {
        _searchResults = results;
      });
    } catch (e) {
      print('Error searching locations: $e');
      setState(() {
        _searchResults = [];
      });
    }
  }
  
  void _onSearchResultSelected(SearchResult result) {
    setState(() {
      _isSearching = false;
      _searchResults = [];
      _searchController.text = result.placeName;
      
      _selectedLocation = GeoLocation(
        latitude: result.latitude, 
        longitude: result.longitude
      );
      _locationName = result.placeName;
    });
    
    // Update map
    if (_selectedLocation != null && _mapboxMap != null) {
      _addMarkerAtPosition(lat: _selectedLocation!.latitude, lng: _selectedLocation!.longitude, isCurrentLocation: false);
      MapHelper.moveCamera(
        mapboxMap: _mapboxMap!,
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        zoom: 14.0,
      );
    }
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
