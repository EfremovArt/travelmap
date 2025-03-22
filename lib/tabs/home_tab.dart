import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../utils/map_helper.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../config/mapbox_config.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../screens/upload/upload_image_screen.dart';
import '../models/location.dart';
import '../utils/permissions_manager.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import 'package:flutter_svg/flutter_svg.dart';

/// Вкладка с картой и лентой постов
class HomeTab extends StatefulWidget {
  final List<Post>? posts;
  final Function(Post)? onPostSelected;

  const HomeTab({
    Key? key,
    this.posts,
    this.onPostSelected,
  }) : super(key: key);

  @override
  _HomeTabState createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  // Состояние карты и маркеров
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  bool _isMapLoaded = false;
  bool _isMapLoading = false;
  bool _markersLoading = false;
  String? _error;
  GeoLocation? _currentPosition;
  StreamSubscription? _locationSubscription;
  String _activeView = 'map';
  Post? _selectedPost;
  
  @override
  void initState() {
    super.initState();
    _isMapLoading = true;
    _checkLocationPermission();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Обновляем маркеры при возвращении на экран
    if (_mapboxMap != null && _isMapLoaded) {
      _loadPostMarkers();
    }
  }
  
  @override
  void dispose() {
    // Сначала вызываем родительский метод dispose
    super.dispose();
    
    // Проверяем, что виджет все еще в состоянии монтирования
    if (!mounted) return;
    
    // Безопасно освобождаем ресурсы
    try {
      // Останавливаем обновление местоположения
      _locationSubscription?.cancel();
      
      // Безопасно очищаем маркеры неблокирующим способом
      if (_pointAnnotationManager != null) {
        print("Safely cleaning up map resources");
        // Используем неблокирующий подход для предотвращения проблем жизненного цикла
        MapHelper.clearMarkers(_pointAnnotationManager)
          .then((success) {
            print("Markers cleaned up: $success");
          })
          .catchError((error) {
            print("Error during marker cleanup: $error");
          })
          .whenComplete(() {
            // После очистки или ошибки, освобождаем ссылки
            _pointAnnotationManager = null;
          });
      }
    } catch (e) {
      print("Error during dispose: $e");
    } finally {
      // Всегда освобождаем ссылки на ресурсы
      _mapboxMap = null;
      _pointAnnotationManager = null;
    }
  }
  
  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Обновляем маркеры, если изменился список постов
    if (widget.posts != oldWidget.posts) {
      _loadPostMarkers();
    }
  }
  
  void _checkLocationPermission() async {
    final permissionGranted = await PermissionsManager.checkLocationPermission(
      context: context,
      onPermissionResult: (isGranted) {
        if (!isGranted && mounted) {
          setState(() {
            _error = 'Location permission is required for this app to function properly.';
            _isMapLoading = false;
          });
        }
      },
    );
    
    if (permissionGranted) {
      _determinePosition().then((position) {
        if (mounted) {
          setState(() {
            // Convert geo.Position to GeoLocation
            _currentPosition = GeoLocation(
              latitude: position.latitude,
              longitude: position.longitude
            );
            _isMapLoading = false;
          });
        }
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _error = e.toString();
            _isMapLoading = false;
          });
        }
        print("Error determining position: $e");
      });
    }
  }
  
  Future<geo.Position> _determinePosition() async {
    bool serviceEnabled;
    geo.LocationPermission permission;

    // Test if location services are enabled
    serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      return Future.error('Location services are disabled. Please enable location services to continue.');
    }

    permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        // Permissions are denied
        return Future.error('Location permissions are denied. Please grant location permissions to continue.');
      }
    }
    
    if (permission == geo.LocationPermission.deniedForever) {
      // Permissions are denied forever
      return Future.error(
        'Location permissions are permanently denied. Please enable location permissions in your device settings.'
      );
    } 

    // When permissions are granted
    return await geo.Geolocator.getCurrentPosition();
  }
  
  // Move camera to current position
  Future<void> _moveToCurrentPosition() async {
    if (_mapboxMap == null) {
      print("Map is not initialized");
      return;
    }

    try {
      setState(() {
        _isMapLoading = true;
      });

      // Получаем текущую позицию
      geo.Position position = await geo.Geolocator.getCurrentPosition();
      
      _currentPosition = GeoLocation(
        latitude: position.latitude,
        longitude: position.longitude
      );
      
      // Перемещаем камеру к позиции
      _moveCamera(_currentPosition!);
      
      setState(() {
        _isMapLoading = false;
      });
    } catch (e) {
      print("Error getting current position: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
      setState(() {
        _isMapLoading = false;
      });
    }
  }
  
  // Обработчик события инициализации карты
  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    // Сохраняем ссылку на карту и обновляем состояние
    _mapboxMap = mapboxMap;
    
    // Отображаем индикатор загрузки
    if (mounted) {
      setState(() {
        _isMapLoading = true;
      });
    }
    
    try {
      // Ждем, чтобы дать карте время полностью инициализироваться
      await Future.delayed(Duration(milliseconds: 1000));
      
      // Инициализируем компоненты карты с безопасным подходом и множественными попытками
      final success = await MapHelper.initializeMapComponents(
        mapboxMap,
        onPointManagerCreated: (manager) async {
          // Сохраняем менеджер аннотаций
          _pointAnnotationManager = manager;
          
          // Обновляем состояние UI
          if (mounted) {
            setState(() {
              _isMapLoading = false;
              _isMapLoaded = true;
              _error = '';
            });
          }
          
          // Даем дополнительное время для полной инициализации менеджера аннотаций
          await Future.delayed(Duration(milliseconds: 500));
          
          // Загружаем маркеры постов после успешной инициализации
          await _loadPostMarkers();
        },
        onError: (error) {
          // Логируем ошибку
          print("Map initialization error: $error");
          
          // Обновляем UI и сохраняем сообщение об ошибке
          if (mounted) {
            setState(() {
              _isMapLoading = false;
              _error = error.toString();
            });
          }
        },
      );
      
      // Если инициализация не удалась, а UI не обновился через callback
      if (!success && mounted && _isMapLoading) {
        setState(() {
          _isMapLoading = false;
          _error = 'Failed to initialize map components.';
        });
      }
    } catch (e) {
      // Ловим любые необработанные исключения
      print("Global error in map initialization: $e");
      
      if (mounted) {
        setState(() {
          _isMapLoading = false;
          _error = e.toString();
        });
      }
    }
  }
  
  /// Загружает маркеры постов на карту
  Future<void> _loadPostMarkers() async {
    if (!mounted) return;

    if (_mapboxMap == null) {
      print("Cannot load post markers: map is null");
      return;
    }

    try {
      setState(() {
        _isMapLoading = true;
      });

      // Более агрессивная задержка перед добавлением маркеров, 
      // чтобы дать карте время полностью загрузиться
      print("Waiting for map to be fully initialized before loading markers");
      await Future.delayed(Duration(milliseconds: 2000));

      // Создаем менеджер аннотаций, если он еще не создан
      if (_pointAnnotationManager == null) {
        try {
          print("Creating new point annotation manager");
          // Используем вспомогательный метод для создания менеджера
          if (_mapboxMap != null) {
            final manager = await _mapboxMap!.annotations.createPointAnnotationManager();
            if (manager != null) {
              setState(() {
                _pointAnnotationManager = manager;
              });
              print("Point annotation manager created successfully with ID: ${_pointAnnotationManager?.id}");
            } else {
              print("Failed to create point annotation manager: API returned null");
              setState(() {
                _isMapLoading = false;
              });
              return;
            }
          } else {
            print("Map is null, cannot create annotation manager");
            setState(() {
              _isMapLoading = false;
            });
            return;
          }
        } catch (e) {
          print("Error creating point annotation manager: $e");
          setState(() {
            _isMapLoading = false;
          });
          return;
        }
      }

      // Проверяем, что менеджер существует
      if (_pointAnnotationManager == null) {
        print("Point annotation manager is still null, cannot add markers");
        setState(() {
          _isMapLoading = false;
        });
        return;
      }

      // Загружаем маркеры
      await _addPostMarkers();

      setState(() {
        _isMapLoading = false;
      });
    } catch (e) {
      print("Error loading post markers: $e");
      if (mounted) {
        setState(() {
          _isMapLoading = false;
        });
      }
    }
  }

  /// Перемещает камеру к указанным координатам
  void _moveCamera(GeoLocation position, {double zoom = 12.0}) {
    if (_mapboxMap == null) return;
    
    try {
      final cameraOptions = CameraOptions(
        center: Point(
          coordinates: Position(
            position.longitude, 
            position.latitude,
          ),
        ),
        zoom: zoom,
      );
      _mapboxMap!.flyTo(
        cameraOptions,
        MapAnimationOptions(duration: 1000),
      );
    } catch (e) {
      print("Error moving camera: $e");
    }
  }

  /// Добавляет маркеры для постов на карту
  Future<void> _addPostMarkers() async {
    if (!mounted) return;
    
    if (_mapboxMap == null) {
      print("Cannot add post markers: map is null");
      return;
    }

    // Перед добавлением маркеров убедимся, что менеджер аннотаций создан
    if (_pointAnnotationManager == null) {
      print("Point annotation manager is null, cannot add markers");
      return;
    }

    try {
      // Безопасно очищаем существующие маркеры
      print("Attempting to clear markers for manager with id: ${_pointAnnotationManager?.id}");
      bool clearedMarkers = false;
      
      try {
        clearedMarkers = await MapHelper.clearMarkers(_pointAnnotationManager);
      } catch (e) {
        print("Error during marker deletion: $e");
      }
      print("Cleared existing markers: $clearedMarkers");

      // Дополнительно дадим карте время полностью подготовиться
      await Future.delayed(Duration(milliseconds: 500));

      // Загрузка постов
      List<Post> postsToShow;
      if (widget.posts != null && widget.posts!.isNotEmpty) {
        postsToShow = widget.posts!;
      } else {
        // Загружаем посты из сервиса, если они не переданы
        try {
          postsToShow = await PostService.getAllPosts();
        } catch (e) {
          print("Error fetching posts: $e");
          postsToShow = [];
        }
      }

      if (postsToShow.isEmpty) {
        print("No posts to show");
        return;
      }

      print("Adding ${postsToShow.length} markers to the map");
      int successCount = 0;

      // Добавляем маркер для каждого поста
      for (var post in postsToShow) {
        if (post.location != null) {
          try {
            bool added = await _safeAddPostMarker(post);
            if (added) successCount++;
          } catch (e) {
            print("Error adding marker for post ${post.id}: $e");
          }
        }
      }

      print("Successfully added $successCount markers out of ${postsToShow.length}");

      // Перемещаем карту на текущее положение, если доступно
      if (_currentPosition != null) {
        _moveCamera(_currentPosition!);
      } else if (postsToShow.isNotEmpty && postsToShow[0].location != null) {
        // Или на место первого поста, если текущее положение недоступно
        _moveCamera(postsToShow[0].location!);
      }

      // Инициализируем обработчики событий для маркеров
      await _initializeMarkerListeners();

    } catch (e) {
      print("Error adding post markers: $e");
    }
  }

  /// Безопасно добавляет маркер для поста с повторными попытками
  Future<bool> _safeAddPostMarker(Post post) async {
    if (_pointAnnotationManager == null) {
      print("Cannot add marker: point annotation manager is null");
      return false;
    }

    // Проверяем, что локация доступна
    if (post.location == null) {
      print("Post location is null");
      return false;
    }

    // Максимальное количество попыток
    const maxRetries = 3;
    
    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        final options = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              post.location!.longitude,
              post.location!.latitude,
            ),
          ),
          iconSize: 1.0,
          textField: post.locationName,
          textSize: 12.0,
          textOffset: [0.0, 1.5],
          iconImage: "marker",
        );

        // Пытаемся добавить маркер
        await _pointAnnotationManager?.create(options);
        return true;
      } catch (e) {
        print("Error adding marker (attempt $attempt): $e");
        
        if (attempt < maxRetries) {
          // Ждем перед следующей попыткой
          await Future.delayed(Duration(milliseconds: 500));
          
          // Если менеджер был уничтожен, пытаемся создать новый
          if (e.toString().contains("No manager found with id") || 
              _pointAnnotationManager == null) {
            print("Manager was destroyed, attempting to recreate");
            try {
              if (_mapboxMap != null) {
                final manager = await _mapboxMap!.annotations.createPointAnnotationManager();
                if (manager != null) {
                  setState(() {
                    _pointAnnotationManager = manager;
                  });
                  print("Recreated point annotation manager with ID: ${_pointAnnotationManager?.id}");
                } else {
                  print("Failed to recreate manager: API returned null");
                  return false;
                }
              } else {
                print("Map is null, cannot recreate manager");
                return false;
              }
            } catch (managerError) {
              print("Error recreating manager: $managerError");
              return false;
            }
          }
        }
      }
    }

    // Если все попытки не удались, используем прямой способ
    try {
      print("Attempting to add marker using direct method");
      if (_mapboxMap != null && post.location != null) {
        // Создаем новый менеджер
        try {
          final newManager = await _mapboxMap!.annotations.createPointAnnotationManager();
          if (newManager != null) {
            // Добавляем маркер через новый менеджер
            final options = PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(
                  post.location!.longitude,
                  post.location!.latitude,
                ),
              ),
              iconSize: 1.0,
              textField: post.locationName,
              textSize: 12.0,
              textOffset: [0.0, 1.5],
              iconImage: "marker",
            );
            
            await newManager.create(options);
            print("Successfully added marker using direct method");
            return true;
          }
        } catch (e) {
          print("Direct method failed to add marker: $e");
        }
      }
      return false;
    } catch (e) {
      print("Helper method failed to add marker: $e");
      return false;
    }
  }

  // Обработчик нажатия на маркер
  void _onMarkerTapped(Post post) {
    if (mounted) {
      setState(() {
        _selectedPost = post;
      });
    }
  }

  // Анимация для появления нового маркера поста
  void _animateNewPostMarker(GeoLocation location) async {
    try {
      if (_mapboxMap == null) return;
      
      // Перемещаем камеру к местоположению нового поста
      final cameraOptions = CameraOptions(
        center: Point(
          coordinates: Position(location.longitude, location.latitude)
        ),
        zoom: 14.0
      );
      
      // Анимированное перемещение камеры
      _mapboxMap!.flyTo(cameraOptions, MapAnimationOptions(duration: 1500));
      
      // Обновляем маркеры
      await Future.delayed(const Duration(milliseconds: 500));
      _loadPostMarkers();
      
      // Показываем анимацию появления маркера
      await Future.delayed(const Duration(milliseconds: 1000));
      
      // Можно добавить дополнительные анимации, если требуется
    } catch (e) {
      print('Error animating new post marker: $e');
    }
  }
  
  // Открываем экран загрузки изображений и получаем результат
  void _openUploadImageScreen() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UploadImageScreen(),
        ),
      );
      
      // Если пост был опубликован и получена локация
      if (result != null && result is GeoLocation) {
        // Анимируем появление нового маркера
        _animateNewPostMarker(result);
      }
    } catch (e) {
      print('Error opening upload screen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Верхняя панель с переключателем вида
          _buildViewSelector(),
          
          // Основной контент (карта или список)
          Expanded(
            child: _activeView == 'map' 
              ? _buildMapView() 
              : _buildFeedView(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _moveToCurrentPosition,
        child: Icon(Icons.my_location),
      ),
    );
  }

  // Виджет переключения вида (карта/лента)
  Widget _buildViewSelector() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildTabButton('Map', 'map'),
          _buildTabButton('Feed', 'feed'),
        ],
      ),
    );
  }

  // Строит кнопку для переключения вида
  Widget _buildTabButton(String title, String view) {
    final isActive = _activeView == view;
    
    return GestureDetector(
      onTap: () {
        setState(() {
          _activeView = view;
        });
      },
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
        decoration: BoxDecoration(
          color: isActive ? Theme.of(context).primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isActive ? Colors.white : Colors.black54,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildMapView() {
    return Stack(
      children: [
        // Карта
        SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: MapWidget(
            key: ValueKey('mapbox'),
            styleUri: 'mapbox://styles/mapbox/streets-v11',
            onMapCreated: _onMapCreated,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(
                  37.61922359771423, // Москва
                  55.75695375116516,
                ),
              ),
              zoom: 10.0,
            ),
          ),
        ),
        
        // Индикатор загрузки
        if (_isMapLoading || _markersLoading)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
            
        // Сообщение об ошибке, если есть
        if (_error != null && _error!.isNotEmpty)
          Container(
            color: Colors.black.withOpacity(0.7),
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.white, size: 48.0),
                  SizedBox(height: 16.0),
                  Text(
                    _error!,
                    style: TextStyle(color: Colors.white, fontSize: 16.0),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 24.0),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _error = null;
                        _loadPostMarkers();
                      });
                    },
                    child: Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPostDetails() {
    if (_selectedPost == null) return SizedBox.shrink();
    
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 8,
              offset: Offset(0, -2),
            ),
          ],
        ),
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedPost!.images.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      _selectedPost!.images.first,
                      width: 80,
                      height: 80,
                      fit: BoxFit.cover,
                    ),
                  ),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _selectedPost!.locationName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        DateFormat('dd.MM.yyyy HH:mm').format(_selectedPost!.createdAt),
                        style: TextStyle(
                          color: Colors.grey[600],
                        ),
                      ),
                      if (_selectedPost!.description != null && _selectedPost!.description!.isNotEmpty) ...[
                        SizedBox(height: 8),
                        Text(_selectedPost!.description!),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    setState(() {
                      _selectedPost = null;
                    });
                  },
                  child: Text('Закрыть'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  bool _handleMapTap(ScreenCoordinate coordinate) {
    if (_mapboxMap != null) {
      _mapboxMap!.coordinateForPixel(coordinate).then((point) {
        _onMapTap(point);
      }).catchError((e) {
        print("Error converting tap coordinates: $e");
      });
    }
    return true;
  }

  void _onMapTap(Point point) {
    print("Нажатие на карту: ${point.coordinates.lat}, ${point.coordinates.lng}");
    
    // Если выбран пост, закрываем его детали
    if (_selectedPost != null) {
      setState(() {
        _selectedPost = null;
      });
      return;
    }
    
    // Можно добавить дополнительную логику при нажатии на карту
  }

  /// Инициализирует обработчики событий для маркеров
  Future<void> _initializeMarkerListeners() async {
    if (_mapboxMap == null || _pointAnnotationManager == null) {
      print("Cannot initialize marker listeners: map or manager is null");
      return;
    }

    try {
      print("Initializing marker click listeners");
      
      // Добавляем обработчик клика на маркер используя вспомогательный класс
      _pointAnnotationManager!.addOnPointAnnotationClickListener(
        MyPointAnnotationClickListener((PointAnnotation annotation) {
          try {
            print("Marker clicked: ${annotation.id}");
            
            // Получаем координаты маркера из аннотации
            final coordinates = annotation.geometry.coordinates;
            final latitude = coordinates.lat;
            final longitude = coordinates.lng;
            
            // Ищем пост с этими координатами
            if (widget.posts != null && widget.posts!.isNotEmpty) {
              for (Post post in widget.posts!) {
                if (post.location != null && 
                    post.location!.latitude == latitude && 
                    post.location!.longitude == longitude) {
                  _onMarkerTapped(post);
                  break;
                }
              }
            }
            
            return true;
          } catch (e) {
            print("Error handling marker click: $e");
            return false;
          }
        })
      );
    } catch (e) {
      print("Error initializing marker listeners: $e");
    }
  }

  // Метод для обновления местоположения пользователя
  void _updateUserLocation(geo.Position position) {
    if (mounted) {
      setState(() {
        _currentPosition = GeoLocation(
          latitude: position.latitude,
          longitude: position.longitude
        );
      });
      
      if (_mapboxMap != null && _isMapLoaded) {
        // Обновляем маркеры после обновления позиции
        _loadPostMarkers();
      }
    }
  }

  // Вид с лентой постов
  Widget _buildFeedView() {
    if (widget.posts == null || widget.posts!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.photo_album, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No posts yet',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Posts from you and people you follow will appear here',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.only(top: 8),
      itemCount: widget.posts!.length,
      itemBuilder: (context, index) {
        final post = widget.posts![index];
        return _buildPostCard(post);
      },
    );
  }

  // Карточка поста в ленте
  Widget _buildPostCard(Post post) {
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка с именем и аватаром пользователя
          ListTile(
            leading: CircleAvatar(
              child: Icon(Icons.person),
            ),
            title: Text(
              post.user,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: post.locationName.isNotEmpty 
              ? Row(
                  children: [
                    Icon(Icons.location_on, size: 14, color: Colors.grey),
                    SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        post.locationName,
                        style: TextStyle(fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                )
              : null,
          ),
          
          // Изображения поста
          if (post.images.isNotEmpty)
            Container(
              height: 250,
              width: double.infinity,
              child: Image.file(
                post.images[0],
                fit: BoxFit.cover,
              ),
            ),
          
          // Описание поста
          if (post.description.isNotEmpty)
            Padding(
              padding: EdgeInsets.all(16),
              child: Text(post.description),
            ),
          
          // Кнопки лайка, комментирования
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.favorite_border),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: Icon(Icons.comment_outlined),
                      onPressed: () {},
                    ),
                  ],
                ),
                IconButton(
                  icon: Icon(Icons.bookmark_border),
                  onPressed: () {},
                ),
              ],
            ),
          ),
          
          // Дата публикации
          Padding(
            padding: EdgeInsets.only(left: 16, right: 16, bottom: 16),
            child: Text(
              _formatDate(post.createdAt),
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Форматирует дату для отображения
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} years ago';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} months ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'Just now';
    }
  }
}

// Класс-обработчик для клика по маркеру
class OnPointAnnotationClickListenerImp extends OnPointAnnotationClickListener {
  final bool Function(PointAnnotation) onPointAnnotationClickCb;
  
  OnPointAnnotationClickListenerImp({required this.onPointAnnotationClickCb});
  
  @override
  bool onPointAnnotationClick(PointAnnotation annotation) {
    return onPointAnnotationClickCb(annotation);
  }
} 