import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../config/mapbox_config.dart';
import '../screens/upload/upload_image_screen.dart';
import '../models/post.dart';
import '../models/location.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../services/social_service.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import '../widgets/post_card.dart';
import '../screens/edit/edit_post_screen.dart';

class MyMapTab extends StatefulWidget {
  const MyMapTab({Key? key}) : super(key: key);

  @override
  State<MyMapTab> createState() => _MyMapTabState();
}

// Вспомогательный класс для обработки нажатий на маркеры
class MyPointAnnotationClickListener extends OnPointAnnotationClickListener {
  final Function(PointAnnotation) callback;

  MyPointAnnotationClickListener(this.callback);

  @override
  bool onPointAnnotationClick(PointAnnotation annotation) {
    return callback(annotation);
  }
}

class _MyMapTabState extends State<MyMapTab> with SingleTickerProviderStateMixin {
  MapboxMap? _mapboxMap;
  bool _mapInitialized = false;
  geo.Position? _currentPosition;
  PointAnnotationManager? _pointAnnotationManager;
  
  // Анимация для пульсирующей точки
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;
  
  // Новые поля для обработки пользовательских постов
  List<Post> _userPosts = [];
  Map<String, Post> _markerPostMap = {};
  bool _isLoading = true;
  String _activeView = 'map'; // 'map' или 'feed'
  Post? _selectedPost;
  Timer? _postsRefreshTimer;
  
  // Кэш для данных пользователя
  File? _userProfileImage;
  String _userFullName = 'Пользователь';
  String _userEmail = ''; // Добавляем поле для email пользователя
  bool _userDataLoaded = false;
  
  @override
  void initState() {
    super.initState();
    
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
    
    _determinePosition();
    _loadUserData();
    _loadUserPosts();
    _startPostsRefreshTimer();
  }
  
  @override
  void dispose() {
    // Останавливаем анимацию
    _pulseAnimationController.dispose();
    
    if (_postsRefreshTimer != null) {
      _postsRefreshTimer?.cancel();
      _postsRefreshTimer = null;
    }
    super.dispose();
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
  
  // Загрузка постов текущего пользователя
  Future<void> _loadUserPosts() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      // Получаем ID текущего пользователя (временно используем email)
      final userEmail = await UserService.getEmail();
      final userId = userEmail.isNotEmpty ? userEmail : 'current_user';
      
      print("🔍 MY MAP TAB: Loading posts for user: $userId");
      
      // Сначала загружаем все посты, чтобы убедиться, что данные обновлены
      final allPosts = await PostService.getAllPosts();
      print("🔍 MY MAP TAB: Total posts loaded: ${allPosts.length}");
      
      // Вывести все ID пользователей для диагностики
      final userIds = allPosts.map((post) => post.user).toSet().toList();
      print("🔍 MY MAP TAB: Available user IDs in posts: $userIds");
      
      print("🔍 MY MAP TAB: Current user ID: $userId");
      
      // Выводим подробную информацию о каждом посте для отладки
      for (int i = 0; i < allPosts.length; i++) {
        final post = allPosts[i];
        print("🔍 MY MAP TAB: Post #$i - User ID: '${post.user}', Location: ${post.locationName}, Created: ${post.createdAt}");
      }
      
      // Фильтруем посты с обоими возможными идентификаторами (email и 'current_user')
      final userPosts = allPosts.where((post) => 
        post.user == userId || post.user == 'current_user'
      ).toList();
      
      print("🔍 MY MAP TAB: User posts found: ${userPosts.length}");
      
      if (mounted) {
        setState(() {
          _userPosts = userPosts;
          _isLoading = false;
        });
        
        // Если карта уже инициализирована, обновляем маркеры
        if (_mapInitialized && _mapboxMap != null) {
          _loadPostMarkers();
        }
      }
    } catch (e) {
      print("🔍 MY MAP TAB: Error loading user posts: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Запуск таймера для периодического обновления постов
  void _startPostsRefreshTimer() {
    _postsRefreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _loadUserPosts();
    });
  }
  
  // Загрузка маркеров постов на карту
  Future<void> _loadPostMarkers() async {
    if (_mapboxMap == null || !mounted) return;
    
    try {
      print("Loading post markers for MY MAP tab");
      
      // Очищаем существующие маркеры
      if (_pointAnnotationManager != null) {
        await _pointAnnotationManager!.deleteAll();
      } else {
        _pointAnnotationManager = await _mapboxMap!.annotations.createPointAnnotationManager();
      }
      
      // Очищаем соответствие маркер -> пост
      _markerPostMap = {};
      
      // Сначала регистрируем стандартный маркер, если его еще нет
      await MapboxConfig.registerMapboxMarkerImages(_mapboxMap!);
      
      // Добавляем маркеры для всех постов пользователя
      if (_userPosts.isNotEmpty) {
        print("Adding ${_userPosts.length} markers to MY MAP");
        
        // Создаем опции для всех маркеров
        for (final post in _userPosts) {
          if (post.location != null) {
            try {
              final point = Point(
                coordinates: Position(
                  post.location.longitude,
                  post.location.latitude
                )
              );
              
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
                  
                  print("Registered post image as marker with ID: $markerImageId");
                } catch (e) {
                  print("Error creating image marker: $e, using default marker instead");
                  markerImageId = "custom-marker";
                }
              }
              
              // Создаем маркер с улучшенными настройками видимости
              final options = PointAnnotationOptions(
                geometry: point,
                iconSize: 0.6, // Увеличиваем размер для лучшей видимости
                iconOffset: [0.0, 0.0], // Центрируем изображение маркера
                iconImage: markerImageId, // Используем изображение поста или стандартный маркер
                textField: post.locationName,
                textSize: 12.0,
                textOffset: [0.0, 3.0], // Отодвигаем текст немного дальше от маркера
                textColor: 0xFF000000, // Черный текст
                textHaloColor: 0xFFFFFFFF, // Белая обводка
                textHaloWidth: 2.0, // Толщина обводки
              );
              
              print("Creating marker with iconImage='${options.iconImage}', iconSize=${options.iconSize}");
              
              // Добавляем маркер на карту
              final pointAnnotation = await _pointAnnotationManager?.create(options);
              
              if (pointAnnotation != null) {
                // Сохраняем связь маркер -> пост
                _markerPostMap[pointAnnotation.id] = post;
                print("Marker successfully added with ID: ${pointAnnotation.id}");
              } else {
                print("Failed to add marker, result is null");
              }
            } catch (e) {
              print("Error adding marker for post ${post.id}: $e");
            }
          }
        }
        
        // Добавляем обработчик клика по маркеру
        if (_pointAnnotationManager != null) {
          _pointAnnotationManager!.addOnPointAnnotationClickListener(
            MyPointAnnotationClickListener((annotation) {
              final post = _markerPostMap[annotation.id];
              if (post != null) {
                setState(() {
                  _selectedPost = post;
                });
                
                // Если карта доступна, увеличиваем к выбранному маркеру
                if (_mapboxMap != null) {
                  _mapboxMap!.flyTo(
                    CameraOptions(
                      center: Point(
                        coordinates: Position(
                          post.location.longitude, 
                          post.location.latitude
                        )
                      ),
                      zoom: 14.0,
                    ),
                    MapAnimationOptions(duration: 1000)
                  );
                }
                
                return true;
              }
              return false;
            })
          );
        }
      }
    } catch (e) {
      print("Error loading post markers: $e");
    }
  }
  
  // Метод для определения текущего положения пользователя
  Future<void> _determinePosition() async {
    bool serviceEnabled;
    geo.LocationPermission permission;

    // Проверяем, включены ли службы геолокации
    serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Службы геолокации недоступны, показываем сообщение пользователю
      return;
    }

    // Проверяем разрешения на доступ к местоположению
    permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        // Пользователь отклонил запрос на разрешение
        return;
      }
    }
    
    if (permission == geo.LocationPermission.deniedForever) {
      // Пользователь навсегда отклонил запрос на разрешение
      return;
    } 

    // Получаем текущее положение
    try {
      final position = await geo.Geolocator.getCurrentPosition();
      setState(() {
        _currentPosition = position;
      });
      
      // Если карта уже инициализирована, перемещаем камеру к текущему положению
      if (_mapInitialized && _mapboxMap != null) {
        final cameraOptions = CameraOptions(
          center: Point(
            coordinates: Position(
              _currentPosition!.longitude, 
              _currentPosition!.latitude
            )
          ),
          zoom: 12.0
        );
        // Второй параметр - это продолжительность анимации в миллисекундах
        _mapboxMap!.flyTo(cameraOptions, MapAnimationOptions(duration: 1000));
      }
    } catch (e) {
      print('Error getting location: $e');
    }
  }
  
  // Обработчик события инициализации карты
  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;
    _mapInitialized = true;
    
    // Регистрируем стандартные изображения маркеров
    await MapboxConfig.registerMapboxMarkerImages(mapboxMap);
    
    // Создаем менеджер точечных аннотаций
    _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    
    // Если местоположение уже определено, перемещаем камеру к нему
    if (_currentPosition != null) {
      final cameraOptions = CameraOptions(
        center: Point(
          coordinates: Position(
            _currentPosition!.longitude, 
            _currentPosition!.latitude
          )
        ),
        zoom: 12.0
      );
      // Второй параметр - это продолжительность анимации в миллисекундах
      _mapboxMap!.flyTo(cameraOptions, MapAnimationOptions(duration: 1000));
    }
    
    // Загружаем маркеры постов пользователя
    _loadPostMarkers();
    
    setState(() {});
  }
  
  // Добавление маркера на карту
  void _addMarker(Point point) async {
    if (_mapboxMap == null || _pointAnnotationManager == null) return;
    
    // Выводим координаты точки
    print("Adding marker at Point: ${point.coordinates.lng}, ${point.coordinates.lat}");
    
    // Создаем точечную аннотацию на карте с минимальными настройками для точности
    final options = PointAnnotationOptions(
      geometry: point,
      iconSize: 0.1,
      iconImage: "custom-marker",
      // Минимум дополнительных настроек, которые могут влиять на смещение
      textField: "точка",
      textSize: 12.0,
      textOffset: [0.0, 2.0], // Текст под маркером
    );
    
    final marker = await _pointAnnotationManager!.create(options);
    
    // Логируем результат для отладки
    if (marker != null) {
      print("Marker created successfully with ID: ${marker.id}");
    } else {
      print("Failed to create marker");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Основной контент: карта или лента
          _buildMainContent(),
          
          // Плавающий переключатель между картой и лентой
          Positioned(
            bottom: 25,
            left: 0,
            right: 0,
            child: Center(
              child: _buildViewToggle(),
            ),
          ),
          
          // Информация о выбранном посте
          if (_selectedPost != null && _activeView == 'map')
            Positioned(
              bottom: 100,
              left: 16,
              right: 16,
              child: GestureDetector(
                onTap: () {
                  // При нажатии на карточку поста можно перейти в детальный просмотр
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: _buildSelectedPostCard(),
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Переход на экран загрузки
          _openUploadImageScreen();
        },
        backgroundColor: Theme.of(context).primaryColor,
        child: const Icon(
          Icons.add_photo_alternate,
          color: Colors.white,
          size: 28,
        ),
      ),
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
  
  // Метод для построения основного контента в зависимости от активной вкладки
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
                // Добавляем пульсирующую точку текущего местоположения
                if (_currentPosition != null && _mapboxMap != null && _mapInitialized && !_isLoading)
                  _buildPulsingUserLocationMarker(),
              ],
            )
          : const Center(
              child: CircularProgressIndicator(),
            );
    } else {
      // Лента с постами
      return _buildUserPostsList();
    }
  }
  
  // Открываем экран загрузки изображений и получаем результат
  void _openUploadImageScreen() async {
    try {
      print("🔍 MY MAP TAB: Opening upload screen from My Map Tab");
      
      // Получаем email пользователя для диагностики перед открытием экрана загрузки
      final userEmail = await UserService.getEmail();
      print("🔍 MY MAP TAB: Current user email before upload: $userEmail");
      
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const UploadImageScreen()),
      );
      
      // Логгируем результат
      print("🔍 MY MAP TAB: Upload screen result: $result");
      
      // Если пост был опубликован и получена локация
      if (result != null && result is GeoLocation) {
        print('🔍 MY MAP TAB: Got location data for new marker animation: ${result.latitude}, ${result.longitude}');
        // Анимируем появление нового маркера
        _animateNewPostMarker(result);
      } else {
        // Просто обновляем данные
        print('🔍 MY MAP TAB: No location data returned, refreshing posts');
        _loadUserPosts();
      }
    } catch (e) {
      print('🔍 MY MAP TAB: Error opening upload screen: $e');
    }
  }
  
  // Анимация появления нового маркера
  Future<void> _animateNewPostMarker(GeoLocation location) async {
    if (_mapboxMap == null || !mounted) return;
    
    try {
      print("🎨 Анимируем появление нового маркера");
      setState(() {
        _activeView = 'map'; // Переключаемся на вид карты
      });
      
      // Перемещаем камеру к новой точке
      _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(
            coordinates: Position(location.longitude, location.latitude)
          ),
          zoom: 14.0,
        ),
        MapAnimationOptions(duration: 1000)
      );
      
      if (mounted && _pointAnnotationManager != null) {
        try {
          print("🎨 Создаем анимированный маркер");
          
          // Пытаемся найти недавно созданный пост с этой локацией
          Post? recentPost;
          
          try {
            // Обновляем посты
            await _loadUserPosts();
            
            // Ищем пост с этой локацией (созданный не более 10 секунд назад)
            final now = DateTime.now();
            for (final post in _userPosts) {
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
              
              print("Registered new post image as marker with ID: $markerImageId");
            } catch (e) {
              print("Error creating image marker for new post: $e, using default marker instead");
              markerImageId = "custom-marker";
            }
          }
          
          // Создаем опции для маркера
          final options = PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(
                location.longitude, 
                location.latitude
              )
            ),
            iconSize: 0.6,
            iconImage: markerImageId, // Используем изображение поста или стандартный маркер
            textField: "New Post!",
            textSize: 14.0,
            textOffset: [0, 3.0],
            textColor: 0xFF000000, // Черный текст
            textHaloColor: 0xFFFFFFFF, // Белая обводка
            textHaloWidth: 2.0, // Толщина обводки
            iconOffset: [0, 0],
          );
          
          // Добавляем подсвеченный маркер
          final newMarker = await _pointAnnotationManager?.create(options);
          
          // Создаем временный пост для этого маркера, если не нашли настоящий
          final tempPost = recentPost ?? Post(
            id: 'temp_new_post',
            user: 'You',
            description: 'Your new post',
            locationName: 'New Location',
            location: location,
            images: [], // Пустой список изображений для временного поста
            createdAt: DateTime.now(),
          );
          
          // Сохраняем маркер в карте маркеров
          if (newMarker != null) {
            _markerPostMap[newMarker.id] = tempPost;
          }
          
          // Ждем несколько секунд, чтобы пользователь увидел новый маркер
          await Future.delayed(Duration(seconds: 3));
          
          print("Анимация завершена, обновляем маркеры");
          
          // Финальное обновление, чтобы показать все маркеры, включая новый
          await _loadPostMarkers();
          
          print("✅ Анимация нового поста успешно завершена");
        } catch (e) {
          print("❌ Ошибка во время анимации маркера: $e");
          // Обновляем маркеры, даже если анимация не удалась
          await _loadPostMarkers();
        }
      }
    } catch (e) {
      print("❌ Ошибка при анимации нового маркера поста: $e");
      if (mounted) {
        // Убеждаемся, что маркеры отображаются, даже если анимация не удалась
        _loadPostMarkers();
      }
    }
  }
  
  // Диалоговое окно для добавления новой точки
  void _showAddLocationDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add New Location',
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Location Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Notes (optional)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                minLines: 3,
                maxLines: 5,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Здесь будет код сохранения новой точки
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Location added')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Add',
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // Показать пост на карте
  void _showOnMap(Post post) {
    if (post.location != null) {
      // Переключаемся на вкладку с картой
      setState(() {
        _activeView = 'map';
        _selectedPost = post;
      });
      
      // Перемещаем камеру к посту, если карта инициализирована
      if (_mapboxMap != null && _mapInitialized) {
        _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(
                post.location.longitude, 
                post.location.latitude
              )
            ),
            zoom: 14.0,
          ),
          MapAnimationOptions(duration: 1000)
        );
      }
    }
  }
  
  // Показать модальное окно с комментариями
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
        _loadUserPosts();
      }
    });
  }
  
  // Метод для удаления поста
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
        await _loadUserPosts();
        
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

  /// Создает пульсирующий маркер для отображения текущего местоположения пользователя
  Widget _buildPulsingUserLocationMarker() {
    return StreamBuilder<ScreenCoordinate?>(
      stream: Stream.periodic(const Duration(milliseconds: 100))
        .asyncMap((_) => _getScreenCoordinatesForLocation()),
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
  Future<ScreenCoordinate?> _getScreenCoordinatesForLocation() async {
    if (_mapboxMap == null || _currentPosition == null) return null;
    
    try {
      final coordinate = await _mapboxMap!.pixelForCoordinate(
        Point(
          coordinates: Position(
            _currentPosition!.longitude,
            _currentPosition!.latitude,
          ),
        ),
      );
      return coordinate;
    } catch (e) {
      print('Error converting geo coordinates to screen coordinates: $e');
      return null;
    }
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
  
  // Отображение выбранного поста (когда отображается на карте)
  Widget _buildSelectedPostCard() {
    if (_selectedPost == null) return SizedBox.shrink();
    
    // Проверяем, принадлежит ли пост текущему пользователю
    final isCurrentUserPost = _isCurrentUserPost(_selectedPost!);
    
    return FutureBuilder<bool>(
      future: _checkIsFollowing(_selectedPost!.user),
      builder: (context, snapshot) {
        final isFollowing = snapshot.data ?? false;
        
        return PostCard(
          post: _selectedPost!,
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
  }
  
  // Обновить метод для отображения списка постов
  Widget _buildUserPostsList() {
    if (_userPosts.isEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isLoading)
            const CircularProgressIndicator()
          else
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.photo_album,
                  size: 80,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'Нет постов',
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
                    'Добавьте свои первые фотографии на карту мест',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                  ),
                ),
              ],
            ),
        ],
      );
    }
    
    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: _userPosts.length,
      itemBuilder: (context, index) {
        final post = _userPosts[index];
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
} 