import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../utils/map_helper.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../services/social_service.dart';
import '../config/mapbox_config.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../screens/upload/upload_image_screen.dart';
import '../models/location.dart';
import '../utils/permissions_manager.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import 'dart:typed_data';
import '../widgets/post_card.dart';
import '../screens/edit/edit_post_screen.dart';
import '../screens/image_viewer/image_viewer_screen.dart';

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

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  // Состояние карты и маркеров
  MapboxMap? _mapboxMap;
  bool _isMapLoaded = false;
  bool _isMapLoading = true;
  bool _markersLoading = false;
  String? _error;
  GeoLocation? _currentPosition;
  StreamSubscription? _locationSubscription;
  String _activeView = 'map';
  Post? _selectedPost;
  // Основные данные карты
  Map<String, Post> _markerPostMap = {};
  PointAnnotationManager? _pointAnnotationManager;
  // Локальный список постов для обновления
  List<Post> _posts = [];
  // Таймер для периодического обновления постов
  Timer? _postsRefreshTimer;
  
  // Кэш для данных пользователя
  File? _userProfileImage;
  String _userFullName = 'Пользователь';
  String _userEmail = ''; // Добавляем поле для email пользователя
  bool _userDataLoaded = false;
  
  // Анимация для пульсирующей точки
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  // Контроллер для ListView в ленте
  final ScrollController _feedScrollController = ScrollController();
  
  // Переменная для хранения последнего просмотренного поста
  Post? _lastViewedPost;
  int _lastViewedPostIndex = -1;
  
  @override
  void initState() {
    super.initState();
    
    print("HomeTab: initialization");
    
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
    
    // Настройка слушателя для контроллера скролла, чтобы отслеживать видимые посты
    _feedScrollController.addListener(_onFeedScroll);
    
    // Initialize states
    _isMapLoading = true;
    _isMapLoaded = false;
    _markersLoading = false;
    _markerPostMap = {};
    _error = null;
    
    // Initialize posts list from widget if available
    if (widget.posts != null) {
      _posts = List.from(widget.posts!);
    }
    
    // Add lifecycle observer
    WidgetsBinding.instance.addObserver(this);
    
    // Загружаем данные пользователя
    _loadUserData();
    
    // Initialize location service
    _initializeLocationService().then((_) {
      // Initialize map after location service
      _initializeMap();
    });
    
    // Load all posts from service
    _loadAllPosts();
    
    // Запускаем таймер обновления постов каждые 60 секунд
    _startPostsRefreshTimer();
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
    print("HomeTab: dispose");
    
    // Останавливаем анимацию
    _pulseAnimationController.dispose();
    
    // Удаляем слушатель и освобождаем ресурсы контроллера скролла
    _feedScrollController.removeListener(_onFeedScroll);
    _feedScrollController.dispose();
    
    // Remove observer
    WidgetsBinding.instance.removeObserver(this);
    
    // Cancel location subscription first
    if (_locationSubscription != null) {
      _locationSubscription?.cancel();
      _locationSubscription = null;
      print("Location subscription canceled");
    }
    
    // Cancel posts refresh timer
    if (_postsRefreshTimer != null) {
      _postsRefreshTimer?.cancel();
      _postsRefreshTimer = null;
      print("Posts refresh timer canceled");
    }
    
    // Clean up map resources
    _cleanupMapResources();
    
    super.dispose();
  }
  
  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Обновляем локальный список постов, если изменился список постов
    if (widget.posts != oldWidget.posts) {
      if (widget.posts != null) {
        setState(() {
          _posts = List.from(widget.posts!);
        });
      }
      // В любом случае обновляем маркеры
      _loadPostMarkers();
    }
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    print("AppLifecycleState changed to: $state");
    
    if (state == AppLifecycleState.resumed) {
      // Когда приложение возвращается в активное состояние
      print("App resumed, refreshing posts and markers");
      
      // Reload posts and markers
      _loadAllPosts();
      
      // Restart timer
      _startPostsRefreshTimer();
    } else if (state == AppLifecycleState.paused) {
      // Когда приложение уходит в фоновый режим
      // Останавливаем таймер обновления
      _postsRefreshTimer?.cancel();
      _postsRefreshTimer = null;
    } else if (state == AppLifecycleState.inactive) {
      // App is inactive
      print("App inactive");
    } else if (state == AppLifecycleState.detached) {
      // App is detached
      print("App detached, cleaning up resources");
      // Ensure resources are properly cleaned up
      _cleanupMapResources();
    }
  }
  
  /// Check and request location permissions
  Future<bool> _checkLocationPermission() async {
    print("Checking location permissions");
    
    // Check location service
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("Location service is disabled");
      if (mounted) {
        setState(() {
          _error = "Location service is disabled. Please enable it in settings";
        });
      }
      return false;
    }
    
    // Check permissions
    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    
    if (permission == geo.LocationPermission.denied) {
      print("Location permission denied, requesting...");
      permission = await geo.Geolocator.requestPermission();
      
      if (permission == geo.LocationPermission.denied) {
        print("Location permission denied again");
        if (mounted) {
          setState(() {
            _error = "Location access denied. Some features will be unavailable";
          });
        }
        return false;
      }
    }
    
    if (permission == geo.LocationPermission.deniedForever) {
      print("Location permission denied forever");
      if (mounted) {
        setState(() {
          _error = "Location access permanently denied. Please change settings in system preferences";
        });
      }
      return false;
    }
    
    // Permissions granted
    print("Location permissions granted");
    return true;
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
  
  /// Called when map is created
  void _onMapCreated(MapboxMap mapboxMap) async {
    print("Map created");
    
    if (!mounted) {
      print("Widget not attached to tree, map initialization stopped");
      return;
    }
    
    try {
      // Save reference to map
      _mapboxMap = mapboxMap;
      
      // Set map style
      try {
        await mapboxMap.style.setStyleURI(MapboxConfig.STREETS_STYLE_URI);
        print("Applied map style: ${MapboxConfig.STREETS_STYLE_URI}");
        
        // Wait for style to load with timeout
        int attempts = 0;
        bool styleLoaded = false;
        while (!styleLoaded && attempts < 5) {
          try {
            styleLoaded = await mapboxMap.style.isStyleLoaded();
            if (styleLoaded) break;
          } catch (e) {
            print("Error checking style loading: $e");
          }
          attempts++;
          await Future.delayed(Duration(milliseconds: 200));
        }
        
        // Регистрируем изображения маркеров после загрузки стиля
        await MapboxConfig.registerMapboxMarkerImages(mapboxMap);
      } catch (e) {
        print("Error setting map style: $e");
        // Continue operation even with map style error
      }
      
      // Create annotation manager for markers
      try {
        _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
        print("Created annotation manager for markers");
      } catch (e) {
        print("Error creating annotation manager: $e");
        // Continue operation even with annotation manager error
      }
      
      // Update UI state in main thread
      if (mounted) {
        setState(() {
          _isMapLoaded = true;
          _isMapLoading = false;
          // Reset errors if any
          _error = null;
        });
      }
      
      // If there's a current position, move camera to it
      if (_currentPosition != null && mounted) {
        await _moveCamera(_currentPosition!);
      }
      
      // Load markers after map is initialized
      _loadPostMarkers();
      
      print("Map successfully initialized");
    } catch (e) {
      print("Critical error initializing map: $e");
      if (mounted) {
        setState(() {
          _error = "Map initialization error: $e";
          _isMapLoading = false;
        });
      }
    }
  }
  
  /// Loads all posts from PostService
  Future<void> _loadAllPosts() async {
    try {
      final allPosts = await PostService.getAllPosts();
      if (mounted) {
        setState(() {
          _posts = allPosts;
        });
        
        // If map is already loaded, update the markers
        if (_isMapLoaded && _mapboxMap != null) {
          _loadPostMarkers();
        }
      }
    } catch (e) {
      print("Error loading all posts: $e");
    }
  }
  
  /// Загружает маркеры постов на карту
  Future<void> _loadPostMarkers() async {
    if (_mapboxMap == null) {
      print("Map not initialized, marker loading stopped");
      return;
    }
    
    if (_pointAnnotationManager == null) {
      print("Annotation manager not initialized, trying to create it");
      try {
        _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
        if (_pointAnnotationManager == null) {
          print("Failed to create annotation manager");
          return;
        }
      } catch (e) {
        print("Error creating annotation manager: $e");
        return;
      }
    }
    
    setState(() {
      _markersLoading = true;
      _error = null;
    });
    
    try {
      // Вместо удаления всех маркеров, сохраним текущие и создадим/обновим только нужные
      Map<String, String> existingMarkers = {}; // postId -> markerId
      Map<String, Post> newMarkerPostMap = {};
      
      // Так как нам сложно получить текущие маркеры, будем работать с сохраненными данными
      // Копируем текущую карту маркеров, которую будем обновлять
      newMarkerPostMap = Map.from(_markerPostMap);
      
      // Создаем обратное отображение для быстрого поиска
      for (var entry in _markerPostMap.entries) {
        final markerId = entry.key;
        final post = entry.value;
        existingMarkers[post.id] = markerId;
      }
      
      // Logging post list details for diagnostics
      print("DIAGNOSTICS: _posts contains ${_posts.length} items");
      for (int i = 0; i < _posts.length; i++) {
        final post = _posts[i];
        print("DIAGNOSTICS: post $i - location: ${post.location?.latitude}, ${post.location?.longitude}");
      }
      
      // Собираем маркеры для удаления (те, которых больше нет в _posts)
      Set<String> postIdsToKeep = _posts.map((p) => p.id).toSet();
      Set<String> markerIdsToDelete = {};
      
      // Находим маркеры, которые нужно удалить
      for (var entry in _markerPostMap.entries) {
        final markerId = entry.key;
        final post = entry.value;
        
        if (!postIdsToKeep.contains(post.id)) {
          markerIdsToDelete.add(markerId);
          newMarkerPostMap.remove(markerId); // Удаляем из новой карты маркеров
        }
      }
      
      // Удаляем маркеры, которых больше нет в списке постов
      if (markerIdsToDelete.isNotEmpty) {
        // К сожалению, без прямого доступа к маркерам мы не можем их удалить по одному
        // Удалим все маркеры и пересоздадим только нужные
        try {
          await _pointAnnotationManager?.deleteAll();
          print("Cleared all markers to rebuild");
          
          // Сбрасываем все карты, так как маркеры были удалены
          newMarkerPostMap.clear();
          existingMarkers.clear();
        } catch (e) {
          print("Error clearing markers: $e");
        }
      }
      
      // Add or update markers from posts
      if (_posts.isNotEmpty) {
        print("Adding/updating ${_posts.length} post markers to the map");
        
        for (final post in _posts) {
          if (post.location == null) {
            print("DIAGNOSTICS: skipping post without location: ${post.id}");
            continue;
          }
          
          // Проверяем, существует ли уже маркер для этого поста
          final existingMarkerId = existingMarkers[post.id];
          
          // Если маркер уже существует и мы не удаляли все маркеры
          if (existingMarkerId != null && markerIdsToDelete.isEmpty) {
            // Маркер уже существует, он автоматически сохранен в newMarkerPostMap
            continue; // Пропускаем создание нового маркера
          }
          
          try {
            print("DIAGNOSTICS: adding marker for post ${post.id} at coordinates: ${post.location!.latitude}, ${post.location!.longitude}");
            
            // Check if map style is loaded before adding marker
            bool styleLoaded = false;
            try {
              styleLoaded = await _mapboxMap!.style.isStyleLoaded();
              print("DIAGNOSTICS: map style loaded status: $styleLoaded");
            } catch (e) {
              print("DIAGNOSTICS: error checking style loading: $e");
            }
            
            // Переменная для хранения ID изображения маркера
            String markerImageId = "custom-marker";
            
            // Если у поста есть изображения, используем первое как маркер
            if (post.images.isNotEmpty) {
              try {
                // Читаем данные изображения
                final File imageFile = post.images[0];
                final Uint8List imageBytes = await imageFile.readAsBytes();
                
                // Регистрируем изображение как маркер
                markerImageId = await MapboxConfig.registerPostImageAsMarker(
                  _mapboxMap!,
                  imageBytes,
                  post.id
                );
                
                print("DIAGNOSTICS: registered post image as marker with ID: $markerImageId");
              } catch (e) {
                print("DIAGNOSTICS: error creating image marker: $e, using default marker instead");
                markerImageId = "custom-marker";
              }
            }
            
            // Create marker options with improved visibility settings
            final options = PointAnnotationOptions(
              geometry: Point(
                coordinates: Position(
                  post.location!.longitude, 
                  post.location!.latitude
                )
              ),
              iconSize: 0.6, // Увеличиваем размер для лучшей видимости (было 0.1)
              iconImage: markerImageId, // Используем изображение поста или стандартный маркер
              textField: post.locationName,
              textSize: 12.0, // Уменьшаем размер текста для баланса
              textOffset: [0, 3.0], // Отодвигаем текст немного дальше от маркера
              textColor: 0xFF000000, // Черный текст
              textHaloColor: 0xFFFFFFFF, // Белая обводка
              textHaloWidth: 2.0, // Толщина обводки
              iconOffset: [0, 0], // Центрируем изображение маркера
            );
            
            print("DIAGNOSTICS: creating marker with iconImage='${options.iconImage}', iconSize=${options.iconSize}");
            
            // Add marker to map
            final pointAnnotation = await _pointAnnotationManager?.create(options);
            
            if (pointAnnotation != null) {
              // Store mapping between marker ID and post
              newMarkerPostMap[pointAnnotation.id] = post;
              print("DIAGNOSTICS: marker successfully added with ID: ${pointAnnotation.id}");
            } else {
              print("DIAGNOSTICS: failed to add marker, result is null");
            }
          } catch (e) {
            print("Error adding marker for post ${post.id}: $e");
          }
        }
        
        // Обновляем карту маркеров
        _markerPostMap = newMarkerPostMap;
        
        // Add click listener to markers
        if (_pointAnnotationManager != null) {
          try {
            // Add click listener
            _pointAnnotationManager!.addOnPointAnnotationClickListener(
              MyPointAnnotationClickListener((annotation) {
                final post = _markerPostMap[annotation.id];
                if (post != null) {
                  print("DIAGNOSTICS: click on marker with ID: ${annotation.id}, post: ${post.id}");
                  
                  // Вместо показа всплывающего окна, переключаемся на ленту и скроллим к нужному посту
                  setState(() {
                    _activeView = 'feed';
                    // Не устанавливаем _selectedPost, так как он используется для всплывающего окна
                    // _selectedPost = post;
                  });
                  
                  // Находим пост в ленте и прокручиваем к нему
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _scrollToPostInFeed(post);
                  });
                  
                } else {
                  print("DIAGNOSTICS: No post found for marker with ID: ${annotation.id}");
                }
                return true; // Возвращаем true, чтобы указать, что событие было обработано
              }),
            );
            print("Marker click listener added");
          } catch (e) {
            print("Error adding marker click listener: $e");
          }
        }
      }
    } catch (e) {
      print("Error loading post markers: $e");
      setState(() {
        _error = "Не удалось загрузить маркеры: $e";
      });
    } finally {
      if (mounted) {
        setState(() {
          _markersLoading = false;
        });
      }
    }
  }

  /// Перемещение камеры к указанной позиции
  Future<void> _moveCamera(GeoLocation location) async {
    if (_mapboxMap == null) return;
    
    try {
      final cameraOptions = CameraOptions(
        center: Point(
          coordinates: Position(
            location.longitude,
            location.latitude
          )
        ),
        zoom: 12.0
      );
      await _mapboxMap!.setCamera(cameraOptions);
      print("Камера перемещена к позиции: ${location.latitude}, ${location.longitude}");
    } catch (e) {
      print("Ошибка перемещения камеры: $e");
    }
  }

  /// Метод для обновления местоположения пользователя
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

  // Animation for new post marker appearance
  void _animateNewPostMarker(GeoLocation location) async {
    try {
      if (_mapboxMap == null) {
        print("⚠️ Cannot animate marker: map is not initialized");
        return;
      }
      
      print("🎉 Animating new marker at coordinates: ${location.latitude}, ${location.longitude}");
      
      // First make sure any existing markers are loaded
      await _loadPostMarkers();
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Your post has been published successfully!"),
            duration: Duration(seconds: 3),
          )
        );
      }
      
      // Calculate the camera position with an initial wide view
      final initialCamera = CameraOptions(
        center: Point(
          coordinates: Position(location.longitude, location.latitude)
        ),
        zoom: 10.0, // Start zoomed out
        bearing: 0.0,
        pitch: 0.0,
      );
      
      // First move to a wide view of the area
      if (mounted && _mapboxMap != null) {
        // Set camera position with animation
        await _mapboxMap!.flyTo(
          initialCamera,
          MapAnimationOptions(duration: 1000)
        );
        
        // Wait a moment for effect
        await Future.delayed(const Duration(milliseconds: 500));
      }
      
      // Then zoom in dramatically to the new post location
      final zoomInCamera = CameraOptions(
        center: Point(
          coordinates: Position(location.longitude, location.latitude)
        ),
        zoom: 15.0, // Zoomed in close
        bearing: 0.0,
        pitch: 30.0, // Tilt for dramatic effect
      );
      
      if (mounted && _mapboxMap != null) {
        // Zoom in dramatically to the location
        await _mapboxMap!.flyTo(
          zoomInCamera,
          MapAnimationOptions(duration: 1500)
        );
      }
      
      // Add a special highlight marker for the new post
      if (mounted && _pointAnnotationManager != null) {
        try {
          print("🎨 Creating animated highlight marker");
          
          // Создаем опции для анимированного маркера с миниатюрой
          // Попытаемся найти недавно созданный пост с этой локацией
          Post? recentPost;
          
          try {
            // Получаем все посты
            final allPosts = await PostService.getAllPosts();
            
            // Обновляем локальный список постов
            setState(() {
              _posts = allPosts;
            });
            
            // Ищем пост с этой локацией (созданный не более 10 секунд назад)
            final now = DateTime.now();
            for (final post in allPosts) {
              if (post.location.latitude == location.latitude && 
                  post.location.longitude == location.longitude &&
                  now.difference(post.createdAt).inSeconds < 10) {
                recentPost = post;
                print("📍 Found recent post for animation: ${post.id}");
                break;
              }
            }
          } catch (e) {
            print("⚠️ Error finding recent post: $e");
          }
          
          // Переменная для хранения ID изображения маркера
          String markerImageId = "custom-marker";
          
          // Если нашли недавний пост и у него есть изображения, используем первое изображение
          if (recentPost != null && recentPost.images.isNotEmpty) {
            try {
              // Читаем данные изображения
              final File imageFile = recentPost.images[0];
              final Uint8List imageBytes = await imageFile.readAsBytes();
              
              // Регистрируем изображение как маркер
              markerImageId = await MapboxConfig.registerPostImageAsMarker(
                _mapboxMap!,
                imageBytes,
                recentPost.id
              );
              
              print("DIAGNOSTICS: registered new post image as marker with ID: $markerImageId");
            } catch (e) {
              print("DIAGNOSTICS: error creating image marker for new post: $e, using default marker instead");
              markerImageId = "custom-marker";
            }
          }
          
          // Создаем опции для маркера с миниатюрой или стандартным маркером
          final options = PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(
                location.longitude, 
                location.latitude
              )
            ),
            iconSize: 0.6, // Увеличиваем размер для лучшей видимости (было 0.15)
            iconImage: markerImageId, // Используем изображение поста или стандартный маркер
            textField: "New Post!",
            textSize: 14.0, // Размер текста
            textOffset: [0, 3.0], // Отодвигаем текст немного дальше от маркера
            textColor: 0xFF000000, // Черный текст
            textHaloColor: 0xFFFFFFFF, // Белая обводка
            textHaloWidth: 2.0, // Толщина обводки
            iconOffset: [0, 0], // Центрируем изображение маркера
          );
          
          // Add highlighted marker
          final newMarker = await _pointAnnotationManager?.create(options);
          
          // Create a temporary post for this marker
          final tempPost = recentPost ?? Post(
            id: 'temp_new_post',
            user: 'You',
            description: 'Your new post',
            locationName: 'New Location',
            location: location,
            images: [], // Empty image list for temporary post
            createdAt: DateTime.now(),
          );
          
          // Save marker in marker map
          if (newMarker != null) {
            _markerPostMap[newMarker.id] = tempPost;
          }
          
          // Wait a few seconds to let user see the new marker
          await Future.delayed(Duration(seconds: 3));
          
          print("DIAGNOSTICS: animation completed, refreshing markers");
          
          // Final refresh to show all markers including the new one
          await _loadPostMarkers();
          
          print("✅ New post animation completed successfully");
        } catch (e) {
          print("❌ Error during marker animation: $e");
          // Ensure markers are refreshed even if animation fails
          await _loadPostMarkers();
        }
      }
    } catch (e) {
      print("❌ Error animating new post marker: $e");
      if (mounted) {
        // Make sure we still display the markers even if animation fails
        _loadPostMarkers();
      }
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
        print('Получены данные для анимации нового маркера: ${result.latitude}, ${result.longitude}');
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
      body: Stack(
        children: [
          // Основной контент (карта или список)
          Positioned.fill(
            child: _activeView == 'map' 
              ? _buildMapView() 
              : _buildFeedView(),
          ),
          
          // Переключатель видов (сдвоенные иконки внизу)
          Positioned(
            bottom: 25,
            left: 0,
            right: 0,
            child: Center(
              child: _buildViewToggle(),
            ),
          ),
        ],
      ),
      floatingActionButton: _activeView == 'map' ? Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Кнопка добавления фото
          FloatingActionButton(
            onPressed: _openUploadImageScreen,
            heroTag: 'addPhoto',
            backgroundColor: Colors.blue.shade700,
            child: Icon(Icons.add_a_photo),
          ),
          SizedBox(height: 16),
          // Кнопка перемещения к текущей позиции
          FloatingActionButton(
            onPressed: _moveToCurrentPosition,
            heroTag: 'myLocation',
            child: Icon(Icons.my_location),
          ),
        ],
      ) : null,
    );
  }

  // Сдвоенные иконки для переключения между картой и лентой
  Widget _buildViewToggle() {
    return Container(
      width: 120,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Иконка карты
          Expanded(
            child: _buildToggleIcon(
              icon: Icons.map,
              isActive: _activeView == 'map',
              view: 'map',
            ),
          ),
          // Вертикальный разделитель
          Container(
            width: 1,
            height: 24,
            color: Colors.grey.shade300,
          ),
          // Иконка ленты
          Expanded(
            child: _buildToggleIcon(
              icon: Icons.view_list,
              isActive: _activeView == 'feed',
              view: 'feed',
            ),
          ),
        ],
      ),
    );
  }

  // Одна иконка переключения
  Widget _buildToggleIcon({
    required IconData icon,
    required bool isActive,
    required String view,
  }) {
    return InkWell(
      onTap: () {
        setState(() {
          _activeView = view;
        });
        
        // Если переключаемся на ленту и есть информация о последнем просмотренном посте,
        // то прокручиваем к нему
        if (view == 'feed' && _lastViewedPost != null && _lastViewedPostIndex >= 0) {
          // Используем post-frame callback, чтобы прокрутка произошла после построения списка
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_feedScrollController.hasClients) {
              // Расчетная высота одного поста
              double approximatePostHeight = 350.0;
              
              // Прокручиваем к позиции поста
              _feedScrollController.animateTo(
                _lastViewedPostIndex * approximatePostHeight,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            }
          });
        }
      },
      borderRadius: BorderRadius.circular(25),
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          color: isActive ? Colors.blue.shade100.withOpacity(0.5) : Colors.transparent,
          borderRadius: BorderRadius.horizontal(
            left: view == 'map' ? Radius.circular(25) : Radius.zero,
            right: view == 'feed' ? Radius.circular(25) : Radius.zero,
          ),
        ),
        child: Icon(
          icon,
          color: isActive ? Colors.blue.shade700 : Colors.grey,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildMapView() {
    try {
      return Stack(
        children: [
          // Основной вид с картой или индикатором загрузки
          _currentPosition != null
              ? SizedBox(
                  width: double.infinity,
                  height: double.infinity,
                  child: MapWidget(
                    key: ValueKey('mapbox_map'),
                    // Используем базовый стиль для лучшей производительности
                    styleUri: MapboxConfig.BASIC_STYLE_URI,
                    // Обработчик создания карты
                    onMapCreated: _onMapCreated,
                    // Начальное положение камеры
                    cameraOptions: CameraOptions(
                      center: Point(
                        coordinates: Position(
                          _currentPosition!.longitude,
                          _currentPosition!.latitude,
                        ),
                      ),
                      zoom: 12.0,
                    ),
                    // Настройки рендеринга для лучшей совместимости
                    textureView: MapboxConfig.USE_TEXTURE_VIEW,
                  ),
                )
              : Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Определение местоположения...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                
          // Добавляем пульсирующую точку, если есть текущее местоположение и карта загружена
          if (_currentPosition != null && _mapboxMap != null && _isMapLoaded && !_isMapLoading)
            _buildPulsingUserLocationMarker(),
                
          // Индикатор загрузки при загрузке маркеров
          if (_markersLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
            
          // Информация о выбранном посте
          if (_selectedPost != null) 
            _buildPostDetails(),
            
          // Сообщение об ошибке, если есть
          if (_error != null)
            Container(
              color: Colors.black.withOpacity(0.7),
              padding: const EdgeInsets.all(16),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 40),
                    const SizedBox(height: 16),
                    Text(
                      'Ошибка: $_error',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          _error = null;
                          _isMapLoading = true;
                        });
                        _initializeMap();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Повторить'),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
    } catch (e) {
      print("Ошибка при построении карты: $e");
      return Center(
        child: Text("Не удалось загрузить карту: $e"),
      );
    }
  }

  /// Initialize map and related components
  Future<void> _initializeMap() async {
    if (!mounted) return;
    
    setState(() {
      _isMapLoading = true;
      _error = null;
    });
    
    try {
      // Check location permissions
      bool hasPermission = await _checkLocationPermission();
      
      if (!hasPermission) {
        return; // Exit if no permission
      }
      
      // Determine current location
      await _determinePosition().then((position) {
        if (mounted) {
          setState(() {
            _currentPosition = GeoLocation(
              latitude: position.latitude,
              longitude: position.longitude
            );
          });
        }
      }).catchError((e) {
        if (mounted) {
          setState(() {
            _error = "Error determining location: $e";
            _isMapLoading = false;
          });
        }
        print("Error determining location: $e");
      });
      
      // Reload markers if map is already initialized
      if (_mapboxMap != null) {
        _loadPostMarkers();
      }
      
      setState(() {
        _isMapLoading = false;
      });
    } catch (e) {
      print("Error initializing map: $e");
      if (mounted) {
        setState(() {
          _error = "Initialization error: $e";
          _isMapLoading = false;
        });
      }
    }
  }
  
  /// View post details
  Widget _buildPostDetails() {
    if (_selectedPost == null) return const SizedBox.shrink();
    
    try {
      return Positioned(
        bottom: 16,
        left: 16,
        right: 16,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Шапка с названием места и кнопкой удаления
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      _selectedPost!.locationName,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    tooltip: 'Удалить пост',
                    onPressed: () {
                      _deletePost(_selectedPost!);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Описание
              Text(
                _selectedPost!.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              
              // Кнопка просмотра
              ElevatedButton(
                onPressed: () => _openPostDetails(_selectedPost!),
                child: const Text('Подробнее'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print("Ошибка отображения деталей поста: $e");
      return const SizedBox.shrink();
    }
  }

  // Вид с лентой постов
  Widget _buildFeedView() {
    if (_posts.isEmpty) {
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
      controller: _feedScrollController,
      padding: EdgeInsets.only(top: 8, bottom: 70),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        // Проверяем, принадлежит ли пост текущему пользователю
        final isCurrentUserPost = _isCurrentUserPost(post);
        
        return FutureBuilder<bool>(
          future: _checkIsFollowing(post.user),
          builder: (context, snapshot) {
            final isFollowing = snapshot.data ?? false;
            
            return PostCard(
              post: post,
              userProfileImage: _userProfileImage,
              userFullName: _userFullName,
              isCurrentUserPost: isCurrentUserPost,
              onShowCommentsModal: _showCommentsModal,
              onShowOnMap: _showOnMap,
              onEditPost: _editPost,
              onDeletePost: _deletePost,
              onLikePost: _likePost,
              onFavoritePost: _favoritePost,
              onFollowUser: _followUser,
              isFollowing: isFollowing,
              onImageTap: _openImageViewer,
            );
          },
        );
      },
    );
  }

  /// Показать модальное окно с комментариями
  void _showCommentsModal(Post post) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          expand: false,
          builder: (_, controller) {
            return Container(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Комментарии',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  Divider(),
                  // Список комментариев (пример с демо-данными)
                  Expanded(
                    child: ListView.builder(
                      controller: controller,
                      itemCount: 5, // В будущем здесь будет реальное количество
                      itemBuilder: (context, index) {
                        return _buildCommentItem(
                          username: 'Пользователь ${index + 1}',
                          avatar: 'https://randomuser.me/api/portraits/men/${30 + index}.jpg',
                          text: 'Это комментарий к вашему посту. Очень интересное место!',
                          date: DateTime.now().subtract(Duration(hours: index)),
                        );
                      },
                    ),
                  ),
                  // Поле ввода нового комментария
                  Divider(),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Написать комментарий...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.send, color: Colors.blue),
                        onPressed: () {
                          // В будущем здесь будет логика отправки комментария
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Комментарий будет добавлен в следующем обновлении')),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
  
  // Построение элемента комментария
  Widget _buildCommentItem({
    required String username,
    required String avatar,
    required String text,
    required DateTime date,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundImage: NetworkImage(avatar),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(width: 8),
                    Text(
                      _formatCommentDate(date),
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Форматирование даты комментария
  String _formatCommentDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays} д.';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ч.';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} мин.';
    } else {
      return 'только что';
    }
  }
  
  // Форматирует количество подписчиков (1200 -> 1.2K)
  String _formatFollowers(int count) {
    if (count >= 1000000) {
      return "${(count / 1000000).toStringAsFixed(1)}M";
    } else if (count >= 1000) {
      return "${(count / 1000).toStringAsFixed(1)}K";
    } else {
      return count.toString();
    }
  }
  
  // Форматирует дату для отображения с временем
  String _formatDateDetailed(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return "${date.day}.${date.month}.${date.year}";
    } else {
      return "${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
    }
  }
  
  // Показать пост на карте
  void _showOnMap(Post post) {
    if (post.location != null) {
      // Сохраняем информацию о текущем посте перед переключением на карту
      _lastViewedPost = post;
      _lastViewedPostIndex = _posts.indexWhere((p) => p.id == post.id);
      
      // Перемещаем камеру к посту, если карта инициализирована
      if (_mapboxMap != null && _isMapLoaded) {
        // Сначала загружаем маркеры перед перемещением камеры
        _loadPostMarkers().then((_) {
          // После загрузки маркеров переключаемся на вкладку с картой
          setState(() {
            _activeView = 'map';
          });
          
          // Перемещаем камеру к локации поста
          _mapboxMap!.flyTo(
            CameraOptions(
              center: Point(
                coordinates: Position(
                  post.location!.longitude, 
                  post.location!.latitude
                )
              ),
              zoom: 14.0,
            ),
            MapAnimationOptions(duration: 1000)
          );
        });
      } else {
        // Если карта не инициализирована, просто переключаемся на вкладку с картой
        setState(() {
          _activeView = 'map';
        });
      }
    }
  }
  
  // Метод для редактирования поста (заглушка)
  void _editPost(Post post) {
    Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostScreen(post: post),
      ),
    ).then((result) {
      if (result == true) {
        // Если пост был успешно обновлен, обновляем UI
        _loadAllPosts();
      }
    });
  }

  /// View post details
  void _openPostDetails(Post post) {
    // Navigation to post details screen should be here
    print("Opening post details: ${post.id}");
    
    // Close details in current view
    setState(() {
      _selectedPost = null;
    });
    
    // Navigate to details screen (placeholder)
    // TODO: Add actual navigation to post details screen
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Viewing details for post ${post.locationName}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Удаляет пост из системы
  Future<void> _deletePost(Post post) async {
    // Показываем диалог подтверждения
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить пост?'),
        content: const Text('Этот пост будет удален навсегда. Продолжить?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    // Если пользователь подтвердил удаление
    if (shouldDelete == true) {
      try {
        // Показываем индикатор загрузки
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Удаление поста...'),
              duration: Duration(seconds: 1),
            ),
          );
        }
        
        // Удаляем пост через сервис
        await PostService.deletePost(post.id);
        
        // Обновляем список постов
        await _loadAllPosts();
        
        // Если открыт этот пост в деталях, закрываем детали
        if (_selectedPost?.id == post.id) {
          setState(() {
            _selectedPost = null;
          });
        }
        
        // Показываем сообщение об успешном удалении
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Пост успешно удален'),
            ),
          );
        }
      } catch (e) {
        print("Ошибка при удалении поста: $e");
        
        // Показываем сообщение об ошибке
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при удалении поста: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  /// Initialize location service
  Future<void> _initializeLocationService() async {
    print("Initializing location service");
    try {
      // Check location permissions
      bool hasPermission = await _checkLocationPermission();
      
      if (!hasPermission) {
        print("No permission to access location");
        return;
      }
      
      // Get current position
      geo.Position position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      
      print("Current position obtained: ${position.latitude}, ${position.longitude}");
      
      if (mounted) {
        setState(() {
          _currentPosition = GeoLocation(
            latitude: position.latitude,
            longitude: position.longitude
          );
        });
      }
    } catch (e) {
      print("Error initializing location service: $e");
      if (mounted) {
        setState(() {
          _error = "Error getting current position: $e";
        });
      }
    }
  }

  /// Properly cleans up all map-related resources
  void _cleanupMapResources() {
    if (_mapboxMap != null) {
      try {
        print("Cleaning up map resources");
        
        // Clean up point annotation manager first
        if (_pointAnnotationManager != null) {
          try {
            // Clear all markers to prevent memory leaks
            print("Clearing markers");
            _pointAnnotationManager = null;
          } catch (e) {
            print("Error while clearing markers: $e");
          }
        }
        
        // Release the map instance
        _mapboxMap = null;
        print("MapboxMap instance released");
        
      } catch (e) {
        print("Error while cleaning up map resources: $e");
      }
    }
  }

  /// Запускает таймер обновления постов
  void _startPostsRefreshTimer() {
    _postsRefreshTimer?.cancel();
    _postsRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      print("📱 Executing scheduled post refresh");
      _loadAllPosts();
    });
    
    // Начальное обновление
    _loadAllPosts();
    
    print("⏱️ Post refresh timer started: every 60 seconds");
  }

  // Загрузка данных пользователя
  Future<void> _loadUserData() async {
    try {
      final fullName = await UserService.getFullName();
      final profileImage = await UserService.getProfileImage();
      final email = await UserService.getEmail(); // Получаем email пользователя
      
      if (mounted) {
        setState(() {
          _userFullName = fullName;
          _userProfileImage = profileImage;
          _userEmail = email; // Сохраняем email пользователя
          _userDataLoaded = true;
        });
      }
    } catch (e) {
      print("Error loading user data: $e");
    }
  }

  /// Метод для построения основного контента в зависимости от активной вкладки
  Widget _buildMainContent() {
    // Если активна вкладка карты
    if (_activeView == 'map') {
      return _currentPosition != null
          ? Stack(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  height: MediaQuery.of(context).size.height,
                  child: MapWidget(
                    key: const ValueKey("mapWidget"),
                    onMapCreated: _onMapCreated,
                    styleUri: MapboxConfig.DEFAULT_STYLE_URI,
                    cameraOptions: CameraOptions(
                      center: Point(
                        coordinates: Position(
                          _currentPosition!.longitude, 
                          _currentPosition!.latitude
                        )
                      ),
                      zoom: 12.0
                    ),
                    onTapListener: (context) {
                      // Убираем выбранный пост при нажатии на пустое место карты
                      setState(() {
                        _selectedPost = null;
                      });
                    },
                  ),
                ),
                // Добавляем пульсирующую точку, если есть текущее местоположение
                if (_currentPosition != null && _mapboxMap != null && !_isMapLoading)
                  _buildPulsingUserLocationMarker(),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            );
    }
    
    // Если активна вкладка ленты
    return _buildFeedContent();
  }

  /// Создает пульсирующий маркер для отображения текущего местоположения пользователя
  Widget _buildPulsingUserLocationMarker() {
    return StreamBuilder<ScreenCoordinate?>(
      stream: Stream.periodic(const Duration(milliseconds: 100))
        .asyncMap((_) => _getScreenCoordinatesForLocation(_currentPosition!)),
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

  /// Строит содержимое ленты постов
  Widget _buildFeedContent() {
    if (_posts.isEmpty) {
      // Отображаем заглушку, если нет постов
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.photo_album,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Пока нет постов',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'Здесь будут отображаться посты от вас и людей, на которых вы подписаны',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[600],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Отображаем список постов
    return ListView.builder(
      padding: EdgeInsets.only(top: 8),
      itemCount: _posts.length,
      itemBuilder: (context, index) {
        final post = _posts[index];
        // Проверяем, принадлежит ли пост текущему пользователю
        final isCurrentUserPost = _isCurrentUserPost(post);
        
        return FutureBuilder<bool>(
          future: _checkIsFollowing(post.user),
          builder: (context, snapshot) {
            final isFollowing = snapshot.data ?? false;
            
            return PostCard(
              post: post,
              userProfileImage: _userProfileImage,
              userFullName: _userFullName,
              isCurrentUserPost: isCurrentUserPost,
              onShowCommentsModal: _showCommentsModal,
              onShowOnMap: _showOnMap,
              onEditPost: _editPost,
              onDeletePost: _deletePost,
              onLikePost: _likePost,
              onFavoritePost: _favoritePost,
              onFollowUser: _followUser,
              isFollowing: isFollowing,
            );
          },
        );
      },
    );
  }

  // Проверяем, является ли пост текущего пользователя
  bool _isCurrentUserPost(Post post) {
    // Получаем ID текущего пользователя (email)
    if (_userEmail.isEmpty) {
      return false;
    }
    
    // Проверяем, совпадает ли email с пользователем поста или это 'current_user'
    return post.user == _userEmail || post.user == 'current_user';
  }
  
  // Проверяем, подписан ли пользователь на автора поста
  Future<bool> _checkIsFollowing(String userId) async {
    try {
      if (_userEmail == userId || userId == 'current_user') {
        return false; // Нельзя подписаться на самого себя
      }
      return await SocialService.isFollowing(userId);
    } catch (e) {
      print("Error checking following status: $e");
      return false;
    }
  }
  
  // Обработчик лайка поста
  Future<void> _likePost(Post post) async {
    try {
      final isLiked = await SocialService.isLiked(post.id);
      
      if (isLiked) {
        await SocialService.unlikePost(post.id);
      } else {
        await SocialService.likePost(post.id);
      }
      
      // Обновляем UI
      setState(() {});
    } catch (e) {
      print("Error liking post: $e");
    }
  }
  
  // Обработчик добавления/удаления из избранного
  Future<void> _favoritePost(Post post) async {
    try {
      final isFavorite = await SocialService.isFavorite(post.id);
      
      if (isFavorite) {
        await SocialService.removeFromFavorites(post.id);
      } else {
        await SocialService.addToFavorites(post.id);
      }
      
      // Обновляем UI
      setState(() {});
    } catch (e) {
      print("Error favoriting post: $e");
    }
  }
  
  // Обработчик подписки на пользователя
  Future<void> _followUser(String userId) async {
    try {
      final isFollowing = await SocialService.isFollowing(userId);
      
      if (isFollowing) {
        await SocialService.unfollowUser(userId);
      } else {
        await SocialService.followUser(userId);
      }
      
      // Обновляем UI
      setState(() {});
    } catch (e) {
      print("Error following user: $e");
    }
  }

  // Метод для прокрутки к нужному посту в ленте
  void _scrollToPostInFeed(Post post) {
    // Находим индекс поста в списке
    int postIndex = _posts.indexWhere((p) => p.id == post.id);
    
    if (postIndex != -1 && _feedScrollController.hasClients) {
      // Расчетная высота одного поста (примерно)
      double approximatePostHeight = 350.0; // может потребоваться корректировка
      
      // Прокручиваем к позиции поста
      _feedScrollController.animateTo(
        postIndex * approximatePostHeight,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
      
      // Анимируем подсветку поста после прокрутки
      // (этот код можно будет реализовать позже)
    }
  }

  // Открытие просмотрщика изображений на весь экран
  void _openImageViewer(Post post, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageViewerScreen(
          images: post.images,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  // Метод для отслеживания скролла в ленте и определения текущего видимого поста
  void _onFeedScroll() {
    if (!_feedScrollController.hasClients || _posts.isEmpty) return;
    
    // Определяем текущую позицию скролла
    final double scrollOffset = _feedScrollController.offset;
    
    // Примерная высота поста (может потребоваться корректировка)
    double approximatePostHeight = 350.0;
    
    // Вычисляем примерный индекс видимого поста
    int visiblePostIndex = (scrollOffset / approximatePostHeight).floor();
    
    // Проверяем границы
    if (visiblePostIndex < 0) visiblePostIndex = 0;
    if (visiblePostIndex >= _posts.length) visiblePostIndex = _posts.length - 1;
    
    // Сохраняем информацию о текущем видимом посте
    _lastViewedPost = _posts[visiblePostIndex];
    _lastViewedPostIndex = visiblePostIndex;
  }
} 