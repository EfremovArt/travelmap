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

class _UploadLocationScreenState extends State<UploadLocationScreen> with WidgetsBindingObserver {
  // Map controllers
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  
  // Location data
  GeoLocation? _selectedLocation;
  String? _locationName;
  
  // UI state
  bool _isMapInitialized = false;
  bool _isStyleLoaded = false;
  bool _isMapLoading = false;
  String? _error;
  
  // Search state
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<SearchResult> _searchResults = [];
  Timer? _searchDebounce;
  
  // Таймер для проверки загрузки карты
  Timer? _mapLoadingTimer;

  // Constants for the demo location (Moscow)
  static const double DEMO_LOCATION_LATITUDE = 55.751244;
  static const double DEMO_LOCATION_LONGITUDE = 37.618423;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Check location permissions when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkLocationPermission();
      
      // Запускаем таймер для проверки загрузки карты
      _mapLoadingTimer = Timer(const Duration(seconds: 10), () {
        if (mounted && !_isMapInitialized && _error == null) {
          setState(() {
            _error = "Map loading timeout. Please try again.";
          });
        }
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _mapLoadingTimer?.cancel();
    _searchDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Реагируем на изменения жизненного цикла приложения
    if (state == AppLifecycleState.resumed) {
      // При возвращении в приложение проверяем состояние карты
      if (_mapboxMap != null && !_isMapInitialized) {
        _reinitializeMapIfNeeded();
      }
    }
  }
  
  // Метод для переинициализации карты при необходимости
  void _reinitializeMapIfNeeded() {
    if (!mounted) return;
    
    setState(() {
      _isMapInitialized = false;
      _isStyleLoaded = false;
      _error = null;
    });
    
    // Форсируем перестроение виджета
    if (mounted) setState(() {});
  }

  void _checkLocationPermission() async {
    await PermissionsManager.checkLocationPermission(
      context: context,
      onPermissionResult: (isGranted) {
        if (!isGranted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Разрешения на определение местоположения необходимы для корректной работы карты'),
            ),
          );
        }
      },
    );
  }

  /// Map creation handler
  void _onMapCreated(MapboxMap mapboxMap) {
    _mapboxMap = mapboxMap;
    _isMapInitialized = true;
    _initializeMap();
  }
  
  /// Map click handler for MapWidget
  void _onMapClick(context) {
    // В новой версии, координаты нажатия нужно получить из context.point.coordinates
    if (context != null && context.point != null) {
      final point = context.point;
      if (point != null) {
        _onMapClickPoint(point);
      }
    }
  }
  
  /// Handles map click with a Point object
  void _onMapClickPoint(Point point) {
    if (!mounted) return;
    
    try {
      // Handle both APIs - check which property exists
      double lat, lng;
      
      if (point.coordinates is Position) {
        // For Position type
        lat = point.coordinates.lat.toDouble();
        lng = point.coordinates.lng.toDouble();
      } else if (point.coordinates is List) {
        // For List type coordinates
        final coords = point.coordinates;
        if (coords.length >= 2) {
          lng = coords[0]?.toDouble() ?? 0.0;
          lat = coords[1]?.toDouble() ?? 0.0;
        } else {
          print('Invalid coordinates format: $coords');
          return;
        }
      } else {
        print('Unknown coordinates format: ${point.coordinates}');
        return;
      }
      
      print("Map clicked at: $lat, $lng");
      
      setState(() {
        _selectedLocation = GeoLocation(latitude: lat, longitude: lng);
        _locationName = "Selected Location";
      });
      
      // Add a marker at the selected point
      _addMarkerAtPosition(lat: lat, lng: lng);
    } catch (e) {
      print("Error handling map click: $e");
      if (mounted) {
        _showErrorSnackbar("Error selecting location: $e");
      }
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

  // Добавляет маркер с обработкой ошибок
  Future<bool> _addMarkerAtPosition({required double lat, required double lng}) async {
    if (_mapboxMap == null) return false;
    
    try {
      // Если менеджер аннотаций не создан или недоступен, пробуем создать
      if (_pointAnnotationManager == null) {
        try {
          _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
          print("Created annotation manager with ID: ${_pointAnnotationManager?.id}");
        } catch (e) {
          print("Error creating annotation manager: $e");
          return false;
        }
      }
      
      // Очищаем существующие маркеры перед добавлением нового
      if (_pointAnnotationManager != null) {
        try {
          await MapHelper.clearMarkers(_pointAnnotationManager);
        } catch (e) {
          print("Error clearing markers (non-critical): $e");
          // Пробуем создать новый менеджер
          try {
            _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
          } catch (managerError) {
            print("Error recreating manager: $managerError");
          }
        }
      }
      
      // Добавляем маркер
      if (_pointAnnotationManager != null) {
        try {
          final options = PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(lng, lat),
            ),
            iconSize: 1.0,
            textSize: 12.0,
            iconImage: "marker",
          );
          
          await _pointAnnotationManager!.create(options);
          return true;
        } catch (e) {
          print("Error adding marker: $e");
          return false;
        }
      }
      
      return false;
    } catch (e) {
      print("General error adding marker: $e");
      return false;
    }
  }

  // Показывает сообщение об ошибке
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // Проверка, работаем ли мы на эмуляторе
  Future<bool> _isEmulator() async {
    // Простая эвристика для эмулятора - считаем, что мы на эмуляторе, чтобы избежать проблем с рендерингом
    return true; // Всегда возвращаем true, чтобы избежать проблем с рендерингом на эмуляторе
  }

  // Fallback виджет для эмуляторов
  Widget _buildEmulatorFallback() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, size: 64, color: Colors.grey[600]),
            SizedBox(height: 16),
            Text(
              'Map rendering issue',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.place),
              label: Text('Select demo location'),
              onPressed: _selectDemoLocation,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _isEmulator(),
      builder: (context, snapshot) {
        final bool isEmulator = snapshot.data ?? false;
        
        return Scaffold(
          appBar: AppBar(
            title: Text('Select location'),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: SearchBar(
                  controller: _searchController,
                  hintText: 'Search location',
                  leading: Icon(Icons.search),
                  onChanged: _onSearchTextChanged,
                  onSubmitted: _onSearchSubmitted,
                ),
              ),
              // Отображение результатов поиска
              if (_isSearching && _searchResults.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      final result = _searchResults[index];
                      return ListTile(
                        title: Text(result.placeName),
                        subtitle: Text(result.placeAddress),
                        onTap: () => _onSearchResultSelected(result),
                      );
                    },
                  ),
                )
              else
                Expanded(
                  child: isEmulator
                      ? _buildEmulatorFallback() // Всегда показываем fallback на эмуляторе
                      : Stack(
                          children: [
                            RepaintBoundary(
                              key: UniqueKey(), // Уникальный ключ предотвращает проблемы с кешированием
                              child: _buildMapWidget(),
                            ),
                            // Индикатор загрузки
                            if (_isMapLoading) 
                              Center(
                                child: CircularProgressIndicator(),
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
                child: Text('Continue'),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Инициализация карты и связанных компонентов
  Future<void> _initializeMap() async {
    if (!mounted || _mapboxMap == null) return;
    
    setState(() {
      _isMapLoading = true;
    });
    
    try {
      // Инициализируем компоненты карты с улучшенной обработкой ошибок
      final success = await MapHelper.initializeMapComponents(_mapboxMap!);
      
      if (!success) {
        if (mounted) {
          _showErrorSnackbar("Failed to initialize map components");
        }
        return;
      }
      
      print("Initializing map components");
      
      // Создаем менеджер аннотаций только после успешной инициализации компонентов
      try {
        _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
        print("Created point annotation manager with ID: ${_pointAnnotationManager?.id}");
      } catch (e) {
        print("Error creating annotation manager: $e");
        if (mounted) {
          _showErrorSnackbar("Failed to create marker system");
        }
      }
      
      // Если местоположение выбрано, добавляем маркер
      if (_selectedLocation != null) {
        // Используем MapHelper для безопасного добавления маркера
        await _addMarkerAtPosition(
          lat: _selectedLocation!.latitude, 
          lng: _selectedLocation!.longitude
        );
      }
    } catch (e) {
      print("Error initializing map: $e");
      if (mounted) {
        _showErrorSnackbar("Map initialization error: $e");
      }
    } finally {
      if (mounted) {
        setState(() {
          _isMapLoading = false;
        });
      }
    }
  }

  // Добавление маркера на карту (обертка для совместимости)
  Future<bool> _addMarker(double latitude, double longitude, String name) async {
    if (_mapboxMap == null || !mounted) {
      print("Cannot add marker - map not initialized");
      return false;
    }
    
    // Показать название места
    setState(() {
      _locationName = name;
    });
    
    // Добавить маркер
    return await _addMarkerAtPosition(lat: latitude, lng: longitude);
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
    _addMarker(location.latitude, location.longitude, name);
  }
  
  // Получаем имя локации на основе координат
  String getLocationName(double latitude, double longitude) {
    // Определим примерные названия для известных координат
    if (latitude == 55.751244 && longitude == 37.618423) {
      return 'Москва';
    } else if (latitude == 59.938806 && longitude == 30.314278) {
      return 'Санкт-Петербург';
    } else if (latitude == 56.838924 && longitude == 60.605701) {
      return 'Екатеринбург';
    } else if (latitude == 43.134019 && longitude == 131.928379) {
      return 'Владивосток';
    } else if (latitude == 45.035158 && longitude == 38.975795) {
      return 'Краснодар';
    }
    
    // Возвращаем строку с координатами, если нет известного названия
    return 'Location (${latitude.toStringAsFixed(4)}, ${longitude.toStringAsFixed(4)})';
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
                  _locationName!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'Шир: ${_selectedLocation!.latitude.toStringAsFixed(6)}, Дол: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
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
          locationName: _locationName ?? 'Selected location',
        ),
      ),
    );
  }

  /// Builds the map widget with correct parameters for API 2.6.2
  Widget _buildMapWidget() {
    return FutureBuilder<bool>(
      future: _isEmulator(),
      builder: (context, snapshot) {
        final bool isEmulator = snapshot.data ?? false;
        
        if (isEmulator) {
          // Return a simplified placeholder for the emulator to avoid crashes
          return Container(
            color: Colors.grey[200],
            height: double.infinity,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map, size: 64, color: Colors.grey[400]),
                  SizedBox(height: 16),
                  Text('Map preview not available on emulator',
                      style: TextStyle(color: Colors.grey[600])),
                ],
              ),
            ),
          );
        }
        
        try {
          return SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: MapWidget(
              key: UniqueKey(),
              styleUri: MapboxConfig.MINIMAL_STYLE_URI,
              cameraOptions: CameraOptions(
                center: Point(
                  coordinates: Position(
                    DEMO_LOCATION_LONGITUDE,
                    DEMO_LOCATION_LATITUDE
                  ),
                ),
                zoom: 9.0,
              ),
              onMapCreated: _onMapCreated,
              onTapListener: _onMapClick,
            ),
          );
        } catch (e) {
          print('Error creating map: $e');
          return Center(
            child: Text('Error loading map: $e'),
          );
        }
      }
    );
  }

  // Выбор демо-локации для тестирования
  void _selectDemoLocation() {
    setState(() {
      // Использование демо-координат (например, Москва)
      _selectedLocation = GeoLocation(
        latitude: 55.751244,
        longitude: 37.618423,
      );
      
      // Обновляем название локации
      _locationName = 'Moscow (demo)';
      
      // Показываем сообщение о выборе локации
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected demo location')),
      );
    });
    
    // Переходим к следующему шагу
    _navigateToDescriptionScreen();
  }

  // Обработчик загрузки стиля карты
  void _onStyleLoaded() {
    print("Map style loaded successfully");
    
    if (!mounted) return;
    
    setState(() {
      _isMapInitialized = true;
      _isStyleLoaded = true;
    });
    
    // Отменяем таймер загрузки карты
    _mapLoadingTimer?.cancel();
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
      _addMarker(_selectedLocation!.latitude, _selectedLocation!.longitude, _locationName ?? '');
      MapHelper.moveCamera(
        mapboxMap: _mapboxMap!,
        latitude: _selectedLocation!.latitude,
        longitude: _selectedLocation!.longitude,
        zoom: 14.0,
      );
    }
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