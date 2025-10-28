import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:http/http.dart' as http;
import '../utils/map_helper.dart';
import '../config/mapbox_config.dart';
import '../config/api_config.dart';
import '../models/post.dart';
import '../services/post_service.dart';
import '../services/user_service.dart';
import '../services/social_service.dart';
import '../services/location_service.dart';
import '../config/mapbox_config.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../screens/upload/upload_description_screen.dart';
import '../models/location.dart';
import '../utils/permissions_manager.dart';
import 'package:intl/intl.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:io';
import 'dart:typed_data';
import '../widgets/post_card.dart';
import '../screens/edit/edit_post_screen.dart';
import '../screens/image_viewer/image_viewer_screen.dart';
import '../screens/comments_screen.dart';
import '../screens/image_viewer/network_image_viewer_screen.dart';
import '../screens/image_viewer/vertical_photo_gallery_screen.dart';
import '../widgets/location_posts_viewer.dart';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/map_filter_service.dart';
import '../utils/logger.dart';
import 'package:flutter/services.dart';
import '../screens/main_screen.dart';
import '../screens/location_posts_screen.dart';
/// Tab with map and post feed
class HomeTab extends StatefulWidget {
  final List<Post>? posts;
  final Function(Post)? onPostSelected;
  final GlobalKey<_HomeTabState>? homeStateKey;

  const HomeTab({
    super.key,
    this.posts,
    this.onPostSelected,
    this.homeStateKey,
  });

  @override
  _HomeTabState createState() => _HomeTabState();
}

// Создаем публичный тип HomeTabState для доступа к нему извне
typedef HomeTabState = _HomeTabState;

class _HomeTabState extends State<HomeTab> with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  final UserService _userService = UserService();
  final GlobalKey<RefreshIndicatorState> _refreshIndicatorKey = GlobalKey<RefreshIndicatorState>();
  final ScrollController _feedScrollController = ScrollController();
  final TextEditingController _commentController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  // Map and marker states
  MapboxMap? _mapboxMap;
  bool _isMapLoaded = false;
  bool _isMapLoading = false;
  bool _markersLoading = false;
  String _error = '';
  GeoLocation? _currentPosition;
  StreamSubscription? _locationSubscription;
  String _activeView = 'map';
  Post? _selectedPost;
  // Main map data
  Map<String, Post> _markerPostMap = {};
  PointAnnotationManager? _pointAnnotationManager;
  // Маппинг post.id -> текущая аннотация (для точечного обновления размеров)
  final Map<String, PointAnnotation> _postIdToAnnotation = {};
  // Local list of posts for updating
  List<Post> _posts = [];
  // Keys for precise scrolling to a specific post in the feed
  // final Map<String, GlobalKey> _postItemKeys = {}; // Удалено - теперь используем ScrollController
  // Mapping from post.id to its actual index in the feed UI (after grouping and sorting)
  final Map<String, int> _postIdToFeedIndex = {};
  // Timer for periodic post updates
  Timer? _postsRefreshTimer;

  // Cache for user data
  String? _userProfileImage;
  String _userFullName = 'User';
  String _userEmail = ''; // Add field for user email
  String _userId = ''; // Добавляем ID пользователя
  bool _userDataLoaded = false;
  String _searchQuery = ''; // Текст поиска по заголовкам постов

  // Animation for pulsating point
  late AnimationController _pulseAnimationController;
  late Animation<double> _pulseAnimation;

  // Variable to store last viewed post
  Post? _lastViewedPost;
  int _lastViewedPostIndex = -1;

  // Состояние клика по маркеру: какой маркер выделен и стадия клика (0/1)
  String? _highlightedPostId;
  int _markerClickStage = 0;
  // Версионный счётчик для отмены/завершения долгих операций подсветки
  int _highlightOperationVersion = 0;
  // Флаг отмены текущей операции подсветки
  bool _cancelHighlightInProgress = false;
  
  // Флаг для подавления сброса по тапу карты сразу после клика по маркеру
  bool _suppressMapTapReset = false;
  // Отметка времени последнего клика по маркеру
  DateTime? _lastMarkerTapAt;

  // Listener for marker clicks to avoid recreating it every time
  late final MyPointAnnotationClickListener _markerClickListener = MyPointAnnotationClickListener((annotation) {
    final post = _markerPostMap[annotation.id];
    if (post == null) {
      return true;
    }

    // Коротко подавляем onTap карты, чтобы не сбрасывать выделение в этот же кадр
    _suppressMapTapReset = true;
    Future.delayed(const Duration(milliseconds: 250), () {
      _suppressMapTapReset = false;
    });


    // Логика переключения по post.id, а не по ID аннотации (которая меняется при пересоздании)
    // Фикс порядка событий: запоминаем время клика по маркеру
    _lastMarkerTapAt = DateTime.now();
    if (_highlightedPostId == post.id && _markerClickStage == 1) {
      final sourceView = _mapFilterService.sourceView;

      // Сбросим стадию до перехода
      _highlightedPostId = null;
      _markerClickStage = 0;
      // Поднимаем версию операций подсветки и выставляем флаг отмены,
      // чтобы любые отложенные/тяжёлые действия немедленно завершились
      _cancelHighlightInProgress = true;
      _highlightOperationVersion++;

      if (sourceView == 'favorites') {
        if (mainScreenKey.currentState != null) {
          mainScreenKey.currentState?.switchToTab(2);
        }
      } else if (sourceView == 'followings') {
        // Сохраняем ID поста для прокрутки при возврате в followings
        AppLogger.log('📌 Сохраняем ID поста для прокрутки в followings: ${post.id}');
        _mapFilterService.setScrollToPostId(post.id);
        if (mainScreenKey.currentState != null) {
          // Вкладка followings — индекс 1
          AppLogger.log('🔄 Переключаемся на вкладку followings (индекс 1)');
          mainScreenKey.currentState?.switchToTab(1);
        }
      } else if (sourceView == 'profile') {
        // Сохраняем ID поста для прокрутки при возврате в профиль
        AppLogger.log('📌 Сохраняем ID поста для прокрутки: ${post.id}');
        _mapFilterService.setScrollToPostId(post.id);
        if (mainScreenKey.currentState != null) {
          // Вкладка профиля (MyMapTab) — индекс 3
          AppLogger.log('🔄 Переключаемся на вкладку профиля (индекс 3)');
          mainScreenKey.currentState?.switchToTab(3);
        }
      } else {
        setState(() {
          _activeView = 'feed';
        });
        // ИСПРАВЛЕНИЕ: Вызываем сразу, т.к. теперь используем ScrollController вместо GlobalKey
        _selectPostInGroupInFeed(post);
      }

      return true;
    }

    // 2) Первый клик по маркеру или клик по другому маркеру -> выделить (увеличить)
    _highlightedPostId = post.id;
    _markerClickStage = 1;
    // Сбрасываем флаг отмены для новой операции и фиксируем версию
    _cancelHighlightInProgress = false;
    final int opVersion = ++_highlightOperationVersion;
    // Выделяем маркер (пересоздание с увеличенным размером)
    _highlightClickedMarker(post.id, opVersion: opVersion);

    return true; // событие обработано
  });

  // Добавляем переменную для хранения текущих настроек камеры
  CameraOptions? _lastCameraOptions;

  // Map filter service
  final MapFilterService _mapFilterService = MapFilterService();
  bool _showOnlyFavorites = false;
  bool _showOnlyFollowings = false;
  String? _filterTitle;
  StreamSubscription? _mapFilterSubscription;
  StreamSubscription? _followingsFilterSubscription;
  StreamSubscription? _highlightPostSubscription;
  StreamSubscription? _filterTitleSubscription;
  // Контроллеры для групповых виджетов (по ключу — имя локации)
  final Map<String, LocationPostsViewerController> _groupControllers = {};
  // Маппинг от post.id к ключу группы для правильного поиска контроллера
  final Map<String, String> _postIdToGroupKey = {};
  
  // Таймер для мониторинга состояния камеры
  Timer? _cameraMonitorTimer;

  // Добавляем флаг для отслеживания специального отображения маркеров
  bool _showingSpecificPost = false;
  bool _isProcessingAnnotations = false; // <<< Add lock flag here
  // Вспомогательный метод для создания единого ключа группы по локации
  String _createLocationGroupKey(String locationName, double latitude, double longitude) {
    // Округляем координаты до 5 знаков после запятой для группировки близких постов
    final roundedLat = latitude.toStringAsFixed(5);
    final roundedLon = longitude.toStringAsFixed(5);
    return '${locationName.toLowerCase().trim()}|$roundedLat|$roundedLon';
  }

  LocationPostsViewerController _getOrCreateViewerControllerForGroup(List<Post> postsInLocation) {
    // Используем единый метод для создания ключа
    final key = _createLocationGroupKey(
      postsInLocation.first.locationName,
      postsInLocation.first.location.latitude,
      postsInLocation.first.location.longitude
    );
    return _groupControllers.putIfAbsent(key, () => LocationPostsViewerController());
  }

  void _selectPostInGroupInFeed(Post post) {
    AppLogger.log('🎯 КЛИК НА МАРКЕР: post.id=${post.id}');
    
    // Обновляем состояние
    if (mounted) {
      setState(() {
        _selectedPost = post;
        _lastViewedPost = post;
        _lastViewedPostIndex = _posts.indexWhere((p) => p.id == post.id);
      });
    }
    
    // ИСПРАВЛЕНИЕ: Используем ScrollController + offset вместо GlobalKey
    // (GlobalKey не работает, т.к. Container внутри FutureBuilder и создается асинхронно)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToPostByIdWithController(post.id);
    });
  }
  
  // Новый метод: прокрутка через ScrollController
  Future<void> _scrollToPostByIdWithController(String postId) async {
    if (!mounted || !_feedScrollController.hasClients) {
      AppLogger.log('⚠️ ScrollController не готов');
      return;
    }
    
    final feedIndex = _postIdToFeedIndex[postId];
    if (feedIndex == null) {
      AppLogger.log('⚠️ Пост $postId не найден в _postIdToFeedIndex');
      return;
    }
    
    // Вычисляем примерный offset (высота PostCard ≈ 500px + margin 16px)
    const double itemHeight = 516.0; // 500 + 8 + 8 margin
    final double targetOffset = feedIndex * itemHeight;
    
    // Ограничиваем offset максимальной позицией
    final double maxOffset = _feedScrollController.position.maxScrollExtent;
    final double safeOffset = targetOffset > maxOffset ? maxOffset : targetOffset;
    
    AppLogger.log('✅ Прокручиваем к посту $postId (index=$feedIndex, offset=$safeOffset)');
    
    await _feedScrollController.animateTo(
      safeOffset,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOut,
    );
  }

  // Анимация появления маркеров
  Future<void> _animateMarkerAppearance(PointAnnotation annotation, double targetIconSize, {int durationMs = 220}) async {
    try {
      const int steps = 5; // быстро и плавно
      final int stepDuration = (durationMs / steps).round();
      for (int i = 1; i <= steps; i++) {
        final double t = i / steps;
        // Обновляем размер и непрозрачность
        annotation.iconSize = targetIconSize * t;
        annotation.iconOpacity = t;
        await _pointAnnotationManager?.update(annotation);
        await Future.delayed(Duration(milliseconds: stepDuration));
      }
    } catch (e) {
      AppLogger.log("⚠️ Ошибка анимации маркера: $e");
    }
  }

  Future<void> _animateMarkersAppearance(List<PointAnnotation> annotations, double targetIconSize, {int durationMs = 220}) async {
    try {
      const int steps = 5;
      final int stepDuration = (durationMs / steps).round();
      for (int i = 1; i <= steps; i++) {
        final double t = i / steps;
        for (final annotation in annotations) {
          annotation.iconSize = targetIconSize * t;
          annotation.iconOpacity = t;
          // Обновляем по одному, чтобы избежать больших пакетов
          await _pointAnnotationManager?.update(annotation);
        }
        await Future.delayed(Duration(milliseconds: stepDuration));
      }
    } catch (e) {
      AppLogger.log("⚠️ Ошибка групповой анимации маркеров: $e");
    }
  }

  // Переменные для хранения отложенных действий
  GeoLocation? _pendingLocation;
  String? _pendingLocationName;
  Post? _pendingPost;
  bool _hasPendingAction = false;
  
  // Метод для установки отложенного действия с локацией
  void setPendingLocationToShow(GeoLocation location, String locationName) {
    _pendingLocation = location;
    _pendingLocationName = locationName;
    _pendingPost = null;
    _hasPendingAction = true;
  }
  
  // Метод для установки отложенного действия с постом
  void setPendingPostToShow(Post post) {
    _pendingPost = post;
    _pendingLocation = null;
    _pendingLocationName = null;
    _hasPendingAction = true;
  }
  
  // Выполнить отложенные действия если они есть
  void _processPendingActions() {
    if (!_hasPendingAction) {
      return;
    }
    
    
    if (_pendingLocation != null && _pendingLocationName != null) {
      
      if (_mapboxMap != null && _isMapLoaded) {
        // Убедимся, что мы находимся в режиме карты
        setState(() {
          _activeView = 'map';
        });
        
        // Отложенное выполнение для гарантии обновления UI
        Future.delayed(Duration(milliseconds: 300), () async {
          if (!mounted || _mapboxMap == null) return;
          
          // Сначала очищаем все существующие поисковые маркеры
          try {
            await _clearSearchMarkers();
          } catch (e) {
            AppLogger.log('⚠️ Ошибка при очистке поисковых маркеров: $e');
          }
          
          // Перемещаем камеру к локации с анимацией
          try {
            await _flyToLocation(_pendingLocation!);
          } catch (e) {
            AppLogger.log('⚠️ Ошибка при перемещении камеры: $e');
            // Пробуем обычное перемещение камеры
            await _moveCamera(_pendingLocation!);
          }
          
          // Добавляем маркер
          try {
            await _addCustomMarker(_pendingLocation!, _pendingLocationName!);
          } catch (e) {
            AppLogger.log('⚠️ Ошибка при добавлении маркера: $e');
          }
        });
      } else {
      }
    } else if (_pendingPost != null) {
      
      // Проверяем, есть ли пост в списке постов
      int postIndex = _posts.indexWhere((p) => p.id == _pendingPost!.id);
      if (postIndex == -1) {
        
        // Обновляем список постов
        _loadAllPosts().then((_) {
          // Проверяем еще раз после обновления
          postIndex = _posts.indexWhere((p) => p.id == _pendingPost!.id);
          if (postIndex == -1) {
            AppLogger.log('❌ Пост всё еще не найден после обновления списка');
            return;
          }
          
          _processSelectedPost(postIndex);
        });
      } else {
        _processSelectedPost(postIndex);
      }
    }
    
    // Сбрасываем флаги отложенных действий
    _pendingLocation = null;
    _pendingLocationName = null;
    _pendingPost = null;
    _hasPendingAction = false;
  }
  
  // Вспомогательный метод для обработки выбранного поста
  void _processSelectedPost(int postIndex) {
    
    // Устанавливаем выбранный пост
    Post post = _posts[postIndex];
    setState(() {
      _selectedPost = post;
      _lastViewedPost = post;
      _lastViewedPostIndex = postIndex;
      _activeView = 'feed';
    });
    
    // Отложенное выполнение для гарантии обновления UI
    Future.delayed(Duration(milliseconds: 300), () {
      if (!mounted) return;
      
      // Прокручиваем к посту
      _scrollToPostById(post.id);
    });
  }
  
  // Метод для очистки поисковых маркеров
  Future<void> _clearSearchMarkers() async {
    if (_mapboxMap == null || !_isMapLoaded || _pointAnnotationManager == null) return;
    
    try {
      
      // Получаем список поисковых маркеров
      List<String> searchMarkerIds = _markerPostMap.entries
          .where((entry) => entry.value.id.startsWith('search_'))
          .map((entry) => entry.key)
          .toList();
      
      // Удаляем маркеры
      if (searchMarkerIds.isNotEmpty) {
        
        // Пытаемся удалить маркеры через создание нового менеджера аннотаций
        try {
          // Создаем новый менеджер аннотаций, это автоматически очистит все предыдущие маркеры
          final annotations = await _mapboxMap!.annotations;
          _pointAnnotationManager = await annotations.createPointAnnotationManager();
          
          // Добавляем обработчик нажатия на новый менеджер
          _pointAnnotationManager!.addOnPointAnnotationClickListener(_markerClickListener);
          
          // Удаляем поисковые маркеры из кэша
          for (String markerId in searchMarkerIds) {
            _markerPostMap.remove(markerId);
          }
          
          
          // Перезагружаем маркеры постов
          await _loadPostMarkers();
        } catch (e) {
          AppLogger.log('❌ Ошибка при создании нового менеджера аннотаций: $e');
        }
      } else {
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при очистке поисковых маркеров: $e');
    }
  }
  
  // Метод для прокрутки к посту по его ID
  void _scrollToPostById(String postId) {
    if (!_feedScrollController.hasClients) {
      return;
    }
    
    // ИСПРАВЛЕНИЕ: Используем реальный индекс поста в UI, а не индекс в массиве _posts
    // так как посты в UI сгруппированы и отсортированы по другим правилам
    int? feedIndex = _postIdToFeedIndex[postId];
    
    if (feedIndex != null) {
      
      // Более точный расчет положения поста в списке UI
      // Учитываем: margin (vertical: 8) = 16px + separator (height: 4) = 4px = 20px на элемент
      // Плюс примерная высота PostCard
      double approximatePostHeight = 350.0; // Базовая высота PostCard
      double marginsAndSeparator = 20.0; // 16 (margin) + 4 (separator)
      double totalItemHeight = approximatePostHeight + marginsAndSeparator;
      
      double offset = feedIndex * totalItemHeight;
      
      // Вычитаем padding контейнера (padding: EdgeInsets.symmetric(vertical: 4))
      offset = offset > 4 ? offset - 4 : 0;
      
      // Прокручиваем к позиции поста
      _feedScrollController.animateTo(
        offset,
        duration: Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      );
      
      // Добавляем визуальное выделение поста по индексу из _posts (для обратной совместимости с подсветкой)
      setState(() {
        _lastViewedPostIndex = _posts.indexWhere((p) => p.id == postId);
      });
      
      // Сбрасываем выделение через некоторое время
      Future.delayed(Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _lastViewedPostIndex = -1;
          });
        }
      });
    } else {
      AppLogger.log('❌ Пост с ID $postId не найден в UI ленты (feedIndex == null)');
    }
  }

  // Метод удален - теперь используем _scrollToPostByIdWithController
  
  // Метод для добавления кастомного маркера на карту
  Future<void> _addCustomMarker(GeoLocation location, String name) async {
    if (_mapboxMap == null || !_isMapLoaded || _pointAnnotationManager == null) {
      return;
    }
    
    try {
      
      // Загружаем изображение маркера
      Uint8List bytes;
      try {
        final ByteData byteData = await rootBundle.load('assets/Images/map-marker.png');
        bytes = byteData.buffer.asUint8List();
      } catch (e) {
        AppLogger.log('❌ Ошибка при загрузке изображения маркера: $e. Создаем изображение программно...');
        
        // Создаем простой красный квадрат как маркер
        final ui.PictureRecorder recorder = ui.PictureRecorder();
        final ui.Canvas canvas = ui.Canvas(recorder);
        final ui.Paint paint = ui.Paint()..color = Colors.red;
        canvas.drawRect(Rect.fromLTWH(0, 0, 50, 50), paint);
        final ui.Image image = await recorder.endRecording().toImage(50, 50);
        final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
        
        if (byteData == null) {
          throw Exception('Failed to create marker image');
        }
        bytes = byteData.buffer.asUint8List();
      }
      
      // Создаем опции для маркера
          final pointAnnotationOptions = PointAnnotationOptions(
        geometry: Point(
          coordinates: Position(
            location.longitude,
            location.latitude,
          ),
        ),
            image: bytes,
            iconSize: 0.01,
            iconAnchor: IconAnchor.BOTTOM,
      );
      
      // Добавляем маркер на карту
      final annotation = await _pointAnnotationManager!.create(pointAnnotationOptions);
          if (annotation != null) {
            await _animateMarkerAppearance(annotation, 0.5, durationMs: 160);
          }
      
      // Создаем временный пост для маркера
      final post = Post(
        id: 'search_${DateTime.now().millisecondsSinceEpoch}',
        user: 'current_user',
        description: 'Search result',
        locationName: name,
        location: location,
        images: [],
        createdAt: DateTime.now(),
      );
      
      // Сохраняем маркер и связываем его с постом
      _markerPostMap[annotation.id] = post;
      
    } catch (e) {
      AppLogger.log('❌ Ошибка при добавлении маркера: $e');
    }
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Проверяем, нужно ли перезагрузить маркеры из-за изменения фильтра
    if (_isMapLoaded && _mapboxMap != null) {
      // Если мы на вкладке карты и установлен фильтр, перезагружаем маркеры
      if (_activeView == 'map' && _showOnlyFavorites) {
         // Ensure the flag is checked before reloading
         if (!_showingSpecificPost) { // Double check flag just before call
           _reloadMarkers();
         }
      }
    }

    // При возвращении на экран карты проверяем и восстанавливаем маркеры
    if (_activeView == 'map' && _isMapLoaded && _mapboxMap != null && _posts.isNotEmpty) {
       // Небольшая задержка для завершения lifecycle операций
       Future.delayed(Duration(milliseconds: 500), () {
         if (mounted && _activeView == 'map' && _isMapLoaded && _mapboxMap != null) {
           // Принудительно пересоздаем менеджер аннотаций
           _pointAnnotationManager = null;
           _markerPostMap.clear();
           _loadPostMarkers();
         }
       });
    }
  }

  @override
  void initState() {
    super.initState();
    
    // Register with the widget binding observer to catch app lifecycle events
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize pulse animation
    _pulseAnimationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut)
    )..addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _pulseAnimationController.reverse();
      } else if (status == AnimationStatus.dismissed) {
        _pulseAnimationController.forward();
      }
    });
    
    _pulseAnimationController.forward();
    
    // Загружаем данные пользователя
    _loadUserData();
    
    // Получаем текущую позицию и запускаем слушатель
    _determinePosition();
    
    // Запускаем таймер для периодического обновления постов
    _postsRefreshTimer = Timer.periodic(const Duration(minutes: 5), (timer) {
      if (mounted) {
        _loadAllPosts();
      }
    });
    
    // Запускаем мониторинг камеры
    _startCameraMonitor();
    
    // Подписка на изменения фильтра избранных постов
    _mapFilterSubscription = _mapFilterService.showOnlyFavoritesStream.listen((showOnlyFavorites) {
      _handleFilterChange(showOnlyFavorites);
    });
    
    // Подписка на изменения фильтра постов из followings
    _followingsFilterSubscription = _mapFilterService.showOnlyFollowingsStream.listen((showOnlyFollowings) {
      _handleFollowingsFilterChange(showOnlyFollowings);
    });
    
    // Подписка на выделение поста
    _highlightPostSubscription = _mapFilterService.highlightPostStream.listen((highlightedPost) {
      AppLogger.log('📡 HomeTab: Получен highlightedPost из stream: ${highlightedPost?.id}');
      _handleHighlightPost(highlightedPost);
    });
    
    // Подписка на изменение заголовка фильтра
    _filterTitleSubscription = _mapFilterService.filterTitleStream.listen((title) {
      if (mounted) {
        setState(() {
          _filterTitle = title;
        });
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Важно: восстанавливаем маркеры при возвращении из фонового режима
    if (state == AppLifecycleState.resumed) {
      // Очищаем кэш данных пользователя для обновления прав доступа
      UserService.clearCache();
      // Перезагружаем данные пользователя
      _loadUserData();
      
      if (_mapboxMap != null && _isMapLoaded) {
        // Восстанавливаем кэшированные изображения маркеров
        MapboxConfig.reinstallCachedMarkerImages(_mapboxMap!).then((_) {
          // После восстановления изображений загружаем маркеры
          if (mounted) {
            _loadPostMarkers();
          }
        });
      }
    }
  }

  @override
  void dispose() {
    // Отписываемся от наблюдателя жизненного цикла
    WidgetsBinding.instance.removeObserver(this);
    
    // Останавливаем анимацию
    _pulseAnimationController.dispose();
    
    // Останавливаем таймеры
    _postsRefreshTimer?.cancel();
    _cameraMonitorTimer?.cancel();
    
    // Отписываемся от подписки на местоположение
    _locationSubscription?.cancel();
    
    // Отписываемся от фильтров
    _mapFilterSubscription?.cancel();
    _followingsFilterSubscription?.cancel();
    _highlightPostSubscription?.cancel();
    _filterTitleSubscription?.cancel();
    
    super.dispose();
  }

  @override
  void didUpdateWidget(HomeTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (_mapboxMap != null && _isMapLoaded && _activeView == 'map') {
      // Важно: сбрасываем флаг выделения маркера при переключении экранов
      _showingSpecificPost = false;
      _lastViewedPost = null;
      
      // Принудительное восстановление маркеров с небольшой задержкой
      Future.delayed(Duration(milliseconds: 400), () async {
        if (mounted && _activeView == 'map' && _isMapLoaded && _mapboxMap != null) {
          try {
            // Безопасно пересоздаем менеджер аннотаций вместо deleteAll
            try {
              final annotations = await _mapboxMap!.annotations;
              _pointAnnotationManager = await annotations.createPointAnnotationManager();
              _pointAnnotationManager!.addOnPointAnnotationClickListener(_markerClickListener);
              _markerPostMap.clear();
            } catch (e) {
              AppLogger.log('❌ didUpdateWidget: Ошибка создания менеджера аннотаций: $e');
              _pointAnnotationManager = null;
              _markerPostMap.clear();
            }
            
            // Восстанавливаем изображения маркеров
            await MapboxConfig.reinstallCachedMarkerImages(_mapboxMap!);
            
            // Загружаем маркеры
            await _loadPostMarkers();
          } catch (e) {
            AppLogger.log('❌ didUpdateWidget: Ошибка восстановления маркеров: $e');
            // Fallback - полная перезагрузка
            _pointAnnotationManager = null;
            _markerPostMap.clear();
            await _loadPostMarkers();
          }
        }
      });
    }
  }

  /// Мягкое восстановление менеджера аннотаций при необходимости  
  Future<void> _ensureAnnotationManager() async {
    if (_mapboxMap == null || !_isMapLoaded) return;
    
    try {
      // Проверяем, нужно ли создать менеджер аннотаций
      if (_pointAnnotationManager == null) {
        
        final annotations = await _mapboxMap!.annotations;
        _pointAnnotationManager = await annotations.createPointAnnotationManager();
        _pointAnnotationManager!.addOnPointAnnotationClickListener(_markerClickListener);
      }
      
    } catch (e) {
      AppLogger.log("❌ Ошибка создания менеджера аннотаций: $e");
    }
  }

  /// Check and request location permissions
  Future<bool> _checkLocationPermission() async {

    // Check location service
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
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
      permission = await geo.Geolocator.requestPermission();

      if (permission == geo.LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _error = "Location access denied. Some features will be unavailable";
          });
        }
        return false;
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      if (mounted) {
        setState(() {
          _error = "Location access permanently denied. Please change settings in system preferences";
        });
      }
      return false;
    }

    // Permissions granted
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

      // Обновляем настройки камеры перед перемещением
      await _updateCameraOptions();

      // Сохраняем текущий зум перед перемещением
      double currentZoom = _lastCameraOptions?.zoom ?? 12.0;

      // Перемещаем камеру к позиции с сохранением зума
      await _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(
                coordinates: Position(
                    _currentPosition!.longitude,
                    _currentPosition!.latitude
                )
            ),
            zoom: currentZoom, // Используем сохраненный зум
          ),
          MapAnimationOptions(duration: 1000)
      );

      // Добавляем маркер геолокации пользователя
      await _addUserLocationMarker();

      setState(() {
        _isMapLoading = false;
      });
    } catch (e) {
      AppLogger.log("Error getting current position: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e")),
      );
      setState(() {
        _isMapLoading = false;
      });
    }
  }

  /// Called when map is created
  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    
    try {
      _mapboxMap = mapboxMap;
      
      // Сбрасываем старый менеджер аннотаций при пересоздании карты
      _pointAnnotationManager = null;
      _markerPostMap.clear();
      
      // Настраиваем жесты карты (ВКЛЮЧАЕМ все жесты для нормального взаимодействия)
      await mapboxMap.gestures.updateSettings(
        GesturesSettings(
          pinchToZoomEnabled: true,    // Включаем масштабирование щипком
          doubleTapToZoomInEnabled: true,  // Включаем увеличение двойным тапом
          doubleTouchToZoomOutEnabled: true, // Включаем уменьшение двумя пальцами
          quickZoomEnabled: true,      // Включаем быстрое масштабирование
          scrollEnabled: true,         // Включаем прокрутку
          rotateEnabled: false,        // Отключаем поворот для простоты
          pitchEnabled: false,         // Отключаем наклон (tilt) двумя пальцами
        )
      );
      
      // Отключаем шкалу зума
      try {
        await mapboxMap.scaleBar.updateSettings(
          ScaleBarSettings(
            enabled: false,
          )
        );
      } catch (e) {
        AppLogger.log("⚠️ Error disabling scale bar: $e");
      }
      
      // Создаем новый менеджер аннотаций
      final annotations = await mapboxMap.annotations;
      _pointAnnotationManager = await annotations.createPointAnnotationManager();
      _pointAnnotationManager?.addOnPointAnnotationClickListener(_markerClickListener);
      
      // Устанавливаем флаг готовности карты
      setState(() {
        _isMapLoaded = true;
      });
      
      // Гарантируем регистрацию дефолтных иконок до создания любых маркеров
      try {
        await MapboxConfig.registerMapboxMarkerImages(_mapboxMap!);
      } catch (e) {
        AppLogger.log("⚠️ Error registering default markers on map creation: $e");
      }
      
      // При пересоздании карты загружаем маркеры сразу, если посты уже есть
      if (_posts.isNotEmpty) {
        await _loadPostMarkers();
      }
      
      // Загружаем посты и их маркеры асинхронно, не блокируя карту
      _loadDataAsync();
      
      // Устанавливаем начальную позицию камеры
      if (_currentPosition != null) {
        _moveCamera(_currentPosition!);
        // Добавляем маркер геолокации пользователя
        _addUserLocationMarker();
      } else {
        _determinePosition();
      }
      
      // Запускаем мониторинг камеры
      _startCameraMonitor();
      
      
    } catch (e) {
      AppLogger.log("Error in onMapCreated: $e");
      setState(() {
        _error = "Ошибка инициализации карты: $e";
      });
    }
  }

  /// Асинхронная загрузка данных без блокировки UI
  Future<void> _loadDataAsync() async {
    try {
      // Сначала загружаем посты
      await _loadAllPosts();
      
      // Потом загружаем маркеры
      await _loadPostMarkers();
      
    } catch (error) {
      AppLogger.log("⚠️ Error loading data: $error");
    }
  }

  /// Обработчик события StyleImageMissing - восстанавливает пропавшие изображения
  // Removing this method as addStyleImageMissingListener is not supported in the current SDK version
  // bool _onStyleImageMissing(StyleImageMissingEventData imageData) {
  //   // implementation removed
  //   return false;
  // }

  /// Загружает и регистрирует изображение маркера для одного поста
  Future<void> _loadMarkerImageForPost(Post post) async {
    try {
      final String cacheId = "post-marker-${post.id}";
      
      // Проверяем кэш
      if (MapboxConfig.markerImageBytesCache.containsKey(cacheId)) {
        return;
      }
      
      String imageUrl = post.imageUrls.first;
      if (!imageUrl.startsWith("http")) {
        if (imageUrl.startsWith("/")) imageUrl = imageUrl.substring(1);
        imageUrl = "${ApiConfig.baseUrl}/${imageUrl}";
      }
      
      final http.Response response = await http.get(Uri.parse(imageUrl));
      if (response.statusCode == 200) {
        final Uint8List imageBytes = response.bodyBytes;
        
        // Регистрируем изображение как маркер
        await MapboxConfig.registerPostImageAsMarker(
          _mapboxMap!,
          imageBytes,
          post.id
        );
      }
    } catch (e) {
      // Игнорируем ошибки - будет использован стандартный маркер
    }
  }
  
  /// Загружает изображение маркера в фоне без блокировки UI
  void _loadMarkerImageInBackground(Post post) {
    // Запускаем загрузку асинхронно без await
    Future.microtask(() async {
      await _loadMarkerImageForPost(post);
    });
  }

  /// Загружает изображение маркера для поста, если оно отсутствует
  Future<void> _loadMissingMarkerImage(String postId) async {
    try {
      // Находим пост по ID
      Post? post = _posts.firstWhere((p) => p.id == postId, orElse: () {
        return null as Post; // This will throw an error and be caught by the try-catch
      });
      
      if (post != null && post.imageUrls.isNotEmpty && _mapboxMap != null) {
        try {
          String imageUrl = post.imageUrls.first;
          
          // Корректируем URL если нужно
          if (!imageUrl.startsWith("http")) {
            if (imageUrl.startsWith("/")) {
              imageUrl = imageUrl.substring(1);
            }
            imageUrl = "${ApiConfig.baseUrl}/${imageUrl}";
          }
          
          
          // Загружаем изображение
          final http.Response response = await http.get(Uri.parse(imageUrl));
          
          if (response.statusCode == 200) {
            final Uint8List imageBytes = response.bodyBytes;
            
            // Регистрируем изображение как маркер
            await MapboxConfig.registerPostImageAsMarker(
              _mapboxMap!,
              imageBytes,
              postId
            );
            
          } else {
            AppLogger.log("❌ Failed to load image, status: ${response.statusCode}");
          }
        } catch (e) {
          AppLogger.log("❌ Error loading image for post: $e");
        }
      } else {
      }
    } catch (e) {
      AppLogger.log("❌ General error in _loadMissingMarkerImage: $e");
    }
  }

  // Start monitoring camera position
  void _startCameraMonitor() {
    // Cancel existing timer if any
    _cameraMonitorTimer?.cancel();
    
    // Create a new timer that checks camera position every 5 seconds
    _cameraMonitorTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (_mapboxMap != null && _isMapLoaded) {
        _updateCameraOptions();
      }
    });
  }

  /// Loads all posts from PostService
  Future<void> _loadAllPosts() async {
    // Add check for the flag
    if (_showingSpecificPost) {
      return;
    }
    try {
      final posts = await PostService.getAllPosts();

      // Удаляем дубликаты по post.id, сохраняем первый встретившийся порядок
      final Set<String> seenIds = {};
      final List<Post> uniquePosts = [];
      for (final p in posts) {
        if (seenIds.add(p.id)) {
          uniquePosts.add(p);
        }
      }
      
      if (mounted) {
        setState(() {
          _posts = uniquePosts;
        });
        
        // Загружаем маркеры на карту, если карта уже загружена
        if (_isMapLoaded) {
          // Если фильтр активен, применяем его
          if (_showOnlyFavorites) {
            _reloadMarkers(); // This one already checks the flag internally
          } else {
            // Иначе загружаем все посты
            // We might need a dedicated function that doesn't clear all markers here
            // For now, let's ensure _reloadMarkers is called, which checks the flag.
             _reloadMarkers(); // Ensure flag check is hit
          }
        }
      }
    } catch (e) {
      AppLogger.log("Error loading posts: $e");
    }
  }

  /// Метод для загрузки маркеров постов
  Future<void> _loadPostMarkers() async {
    // Быстрые гарды: карта должна быть инициализирована и загружена, должны быть посты
    if (_mapboxMap == null || !_isMapLoaded || _posts.isEmpty) {
      return;
    }

    // Если уже идёт обработка аннотаций, не запускаем параллельно
    if (_isProcessingAnnotations) {
      return;
    }

    try {
      // Перед перерисовкой убедимся, что изображения маркеров восстановлены в стиле
      // (актуально после переключений между экранами/возврата из бэкграунда)
      await MapboxConfig.reinstallCachedMarkerImages(_mapboxMap!);

      // Делегируем единый путь перезагрузки, который сам создаёт менеджер и маппит id->post
      await _reloadMarkers();
    } catch (_) {
      // Ошибки уже логируются в _reloadMarkers/MapboxConfig
    }
  }

  // Метод для добавления обработчика кликов по маркерам
  void _addMarkerClickListener() {
    if (_pointAnnotationManager != null) {
      // Создаем обработчик кликов
      try {
        // Добавляем обработчик кликов
        _pointAnnotationManager!.addOnPointAnnotationClickListener(_markerClickListener);
      } catch (e) {
        AppLogger.log("Error adding marker click listener: $e");
      }
    }
  }

  /// Перемещение камеры к указанной позиции
  Future<void> _moveCamera(GeoLocation location) async {
    if (_mapboxMap == null) return;

    try {
      // Обновляем настройки камеры перед перемещением
      await _updateCameraOptions();

      // Используем сохраненный зум или значение по умолчанию
      double zoom = _lastCameraOptions?.zoom ?? 12.0;

      final cameraOptions = CameraOptions(
          center: Point(
              coordinates: Position(
                  location.longitude,
                  location.latitude
              )
          ),
          zoom: zoom // Используем сохраненный зум
      );
      await _mapboxMap!.setCamera(cameraOptions);
    } catch (e) {
      AppLogger.log("Ошибка перемещения камеры: $e");
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
        return;
      }


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
                break;
              }
            }
          } catch (e) {
            AppLogger.log("⚠️ Error finding recent post: $e");
          }

          // Переменная для хранения ID изображения маркера
          String markerImageId = "post-marker-" + (recentPost?.id ?? "temp-" + DateTime.now().millisecondsSinceEpoch.toString());

          // Если нашли недавний пост и у него есть изображения, используем первое изображение
          if (recentPost != null && recentPost.imageUrls.isNotEmpty) {
            try {
              // Get the photo URL and adjust if needed to prevent duplicate paths
              String photoUrl = recentPost.imageUrls[0];
              if (photoUrl.startsWith('http')) {
                // If it's already a full URL, use it as is
              } else {
                // Adjust relative path if needed
                if (photoUrl.startsWith('/travel/')) {
                  // Remove duplicate '/travel' prefix
                  photoUrl = photoUrl.replaceFirst('/travel', '');
                } else if (photoUrl.startsWith('/')) {
                  // If it starts with /, remove it to avoid double slashes
                  photoUrl = photoUrl.substring(1);
                }

                // Construct the full URL
                photoUrl = '${ApiConfig.baseUrl}/$photoUrl';
              }


              // Загружаем первое изображение по URL
              final http.Response response = await http.get(Uri.parse(photoUrl));
              if (response.statusCode == 200) {
                final Uint8List imageBytes = response.bodyBytes;

                // Регистрируем изображение как маркер
                markerImageId = await MapboxConfig.registerPostImageAsMarker(
                    _mapboxMap!,
                    imageBytes,
                    recentPost.id
                );

              } else {
                // Сохраняем уникальный ID
              }
            } catch (e) {
              // Сохраняем уникальный ID
            }
          }
          // Если есть локальные изображения, используем их (для обратной совместимости)
          else if (recentPost != null && recentPost.images.isNotEmpty) {
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

            } catch (e) {
              // Сохраняем уникальный ID
            }
          }

          // Проверяем, что изображение было успешно добавлено в стиль
          bool hasImage = false;
          try {
            hasImage = await _mapboxMap!.style.hasStyleImage(markerImageId);
            if (!hasImage) {

              // Дополнительно проверим, есть ли изображение в кэше
              final bool isInCache = MapboxConfig.markerImageBytesCache.containsKey(markerImageId);

              // Попробуем использовать базовый маркер вместо изображения
              markerImageId = "marker-15";
            } else {
            }
          } catch (e) {
            AppLogger.log("❌ Error checking marker image: $e");
            // В случае ошибки используем базовый маркер
            markerImageId = "marker-15";
            hasImage = true;
          }

          // Создаем опции для анимированного маркера с миниатюрой
          var options = PointAnnotationOptions(
            geometry: Point(
                coordinates: Position(
                    location.longitude,
                    location.latitude
                )
            ),
            iconSize: 0.3, // Увеличиваем размер для лучшей видимости (уменьшен в 2 раза)
            iconImage: hasImage ? markerImageId : "", // Пустая строка, если изображение не найдено
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


          // Final refresh to show all markers including the new one
          await _loadPostMarkers();

        } catch (e) {
          AppLogger.log("❌ Error during marker animation: $e");
          // Ensure markers are refreshed even if animation fails
          await _loadPostMarkers();
        }
      }
    } catch (e) {
      AppLogger.log("❌ Error animating new post marker: $e");
      if (mounted) {
        // Make sure we still display the markers even if animation fails
        _loadPostMarkers();
      }
    }
  }

  // Открываем экран создания поста
  void _openUploadImageScreen() async {
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => const UploadDescriptionScreen(),
        ),
      );

      // Если пост был опубликован и получена локация
      if (result != null && result is GeoLocation) {
        
        // Немедленно обновляем все посты для отображения нового поста
        _loadAllPosts();
        
        // Анимируем появление нового маркера
        _animateNewPostMarker(result);

        // 1) Мгновенно подмержим посты из ближайших локаций, чтобы новый пост появился в ленте сразу
        try {
          final nearbyPosts = await PostService.getPostsByCoordinates(result.latitude, result.longitude, 0.002);
          if (mounted && nearbyPosts.isNotEmpty) {
            setState(() {
              final Map<String, Post> unique = { for (final p in _posts) p.id: p };
              for (final p in nearbyPosts) {
                unique[p.id] = p;
              }
              _posts = unique.values.toList();
            });
          }
        } catch (e) {
        }

        // 2) Полная фоновая перезагрузка всех постов после небольшой задержки (кэш на сервере успеет обновиться)
        Future.delayed(const Duration(seconds: 1), () async {
          try {
            final refreshed = await PostService.forceRefreshPosts();
            if (mounted && refreshed.isNotEmpty) {
              setState(() {
                _posts = refreshed;
              });
            }
          } catch (e) {
            AppLogger.log('⚠️ Ошибка полной перезагрузки постов после публикации: $e');
          }
        });
      }
    } catch (e) {
      AppLogger.log('Error opening upload screen: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _filterTitle != null && _activeView == 'map' 
        ? AppBar(
            title: Text(_filterTitle!, style: const TextStyle(color: Colors.black87)),
            backgroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.black87),
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () {
                // Возвращаемся к соответствующей вкладке в зависимости от источника
                if (_mapFilterService.sourceView == 'profile') {
                  // Возвращаемся на вкладку My Map
                  _mapFilterService.resetFilters();
                  if (mainScreenKey.currentState != null) {
                    mainScreenKey.currentState!.switchToTab(3); // Индекс вкладки My Map
                  }
                } else if (_mapFilterService.sourceView == 'favorites') {
                  // Возвращаемся на вкладку Favorites
                  _mapFilterService.resetFilters();
                  if (mainScreenKey.currentState != null) {
                    mainScreenKey.currentState!.switchToTab(2); // Индекс вкладки Favorites
                  }
                } else if (_mapFilterService.sourceView == 'followings') {
                  // Возвращаемся на вкладку Following
                  _mapFilterService.resetFilters();
                  if (mainScreenKey.currentState != null) {
                    mainScreenKey.currentState!.switchToTab(1); // Индекс вкладки Following
                  }
                } else {
                  // Для остальных случаев просто сбрасываем фильтры
                  _mapFilterService.resetFilters();
                }
              },
            ),
          )
        : null,
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
          
          // Кнопка геолокации в правом верхнем углу
          if (_activeView == 'map')
            Positioned(
              top: 20,
              right: 20,
              child: Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 3),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: _moveToCurrentPosition,
                  child: Center(
                    child: Image.asset(
                      'assets/Images/geo.png',
                      width: 24,
                      height: 24,
                      color: Colors.blue.shade700,
                    ),
                  ),
                ),
              ),
            ),
          
          // Показываем индикатор активного фильтра избранных постов (только если нет заголовка в AppBar)
          if (_showOnlyFavorites && _activeView == 'map' && _filterTitle == null)
            Positioned(
              top: 16,
              left: 16,
              right: 16,
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, color: Colors.yellow),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Showing favorite posts only',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        _mapFilterService.resetFilters();
                      },
                      child: Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      // Убираем floatingActionButton с геолокацией
      // floatingActionButton: _activeView == 'map' ? FloatingActionButton(
      //   onPressed: _moveToCurrentPosition,
      //   heroTag: 'myLocation',
      //   child: Icon(Icons.my_location),
      // ) : null,
    );
  }

  // Сдвоенные иконки для переключения между картой и лентой
  Widget _buildViewToggle() {
    final screenWidth = MediaQuery.of(context).size.width;
    final containerWidth = screenWidth * 0.35; // 35% от ширины экрана
    final containerHeight = containerWidth * 0.35; // Пропорция высоты к ширине
    
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Контейнер с иконками map и list
        Container(
          width: containerWidth.clamp(140.0, 200.0), // Минимум 140, максимум 200
          height: containerHeight.clamp(50.0, 70.0), // Минимум 50, максимум 70
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
                  activeAsset: 'assets/Images/map.svg',
                  inactiveAsset: 'assets/Images/mapgrey.svg',
                  isActive: _activeView == 'map',
                  view: 'map',
                ),
              ),
              // Иконка ленты
              Expanded(
                child: _buildToggleIcon(
                  activeAsset: 'assets/Images/listblack.svg',
                  inactiveAsset: 'assets/Images/list.svg',
                  isActive: _activeView == 'feed',
                  view: 'feed',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Одна иконка переключения
  Widget _buildToggleIcon({
    required String activeAsset,
    required String inactiveAsset,
    required bool isActive,
    required String view,
  }) {
    return InkWell(
      onTap: () async {

        // Перед переключением на карту, убедимся, что у нас есть актуальные настройки камеры
        if (view == 'map' && _mapboxMap != null) {
          // Обновляем настройки камеры
          await _updateCameraOptions();
        }

        setState(() {
          _activeView = view;
          // КРИТИЧНО: Сбрасываем флаги при переключении на карту
          if (view == 'map') {
            _showingSpecificPost = false;
            _isProcessingAnnotations = false;
            _highlightedPostId = null;
            _markerClickStage = 0;
          }
          // Сбрасываем состояние маркера при переходе на feed
          if (view == 'feed') {
            _highlightedPostId = null;
            _markerClickStage = 0;
          }
        });
        
        // Если переключились на вид карты, принудительно пересоздаем маркеры (как при первоначальной загрузке)
        if (view == 'map' && _isMapLoaded) {
          // Используем небольшую задержку для полной перезагрузки
          Future.delayed(Duration(milliseconds: 500), () {
            if (mounted && _activeView == 'map' && _isMapLoaded && _mapboxMap != null) {
              
              // КРИТИЧНО: Принудительно пересоздаем менеджер аннотаций
              _pointAnnotationManager = null;
              _markerPostMap.clear();
              
              // Загружаем маркеры (создаст новый менеджер)
              _loadPostMarkers();
            }
          });
        }

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
      child: Center(
        child: SvgPicture.asset(
          isActive ? activeAsset : inactiveAsset,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  Widget _buildMapView() {
    try {
      return Stack(
        children: [
          // Карта показывается сразу без блокирующего индикатора
          SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: ClipRRect(
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30.0),
                topRight: Radius.circular(30.0),
                bottomLeft: Radius.zero,
                bottomRight: Radius.zero,
              ),
              child: MapWidget(
                key: ValueKey('post_map'), // Стабильный ключ
                // Используем легкий стиль для лучшей производительности
                styleUri: MapboxConfig.STREETS_STYLE_URI,
                // Обработчик создания карты
                onMapCreated: _onMapCreated,
                // Начальное положение камеры
                cameraOptions: _lastCameraOptions ?? (_currentPosition != null
                    ? CameraOptions(
                  center: Point(
                    coordinates: Position(
                      _currentPosition!.longitude,
                      _currentPosition!.latitude
                    ),
                  ),
                  zoom: 12.0,
                )
                    : null
                ),
                // Настройки рендеринга для лучшей совместимости
                textureView: MapboxConfig.USE_TEXTURE_VIEW,
                onTapListener: (context) {
                  // Откладываем обработку тапа карты, чтобы дать шанс обработаться клику по маркеру
                  Future.delayed(const Duration(milliseconds: 220), () {
                    // Не сбрасываем, если только что кликнули по маркеру или идёт обработка аннотаций
                    if (_suppressMapTapReset || _isProcessingAnnotations) {
                      return;
                    }
                    // Если недавно был клик по маркеру — тоже игнорируем
                    if (_lastMarkerTapAt != null && DateTime.now().difference(_lastMarkerTapAt!) < const Duration(milliseconds: 300)) {
                      return;
                    }
                    if (_isMapLoaded) {
                      if (_highlightedPostId != null) {
                        _clearHighlightKeepMarkers();
                      }
                    }
                  });
                },
              ),
            ),
          ),

          // Маркер геолокации теперь добавляется непосредственно на карту через annotations



          // Информация о выбранном посте
          // if (_selectedPost != null)
          //   _buildPostDetails(),

          // Сообщение об ошибке, если есть
          if (_error.isNotEmpty)
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
                          _error = ''; // Используем пустую строку вместо null
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
      // Обработка ошибок отрисовки карты
      AppLogger.log("Error building map view: $e");
      return Center(
        child: Text("Ошибка построения карты: $e"),
      );
    }
  }

  /// Initialize map and related components
  Future<void> _initializeMap() async {
    // Add check for the flag
    if (_showingSpecificPost) {
      return;
    }
    if (!mounted) return;
    
    setState(() {
      _error = ''; // Сбрасываем ошибки
    });

    
    // Карта теперь показывается сразу, маркеры загрузятся при создании карты
    // Больше не блокируем отображение карты индикатором загрузки
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
      AppLogger.log("Ошибка отображения деталей поста: $e");
      return const SizedBox.shrink();
    }
  }

  // Вид с лентой постов
  Widget _buildFeedView() {
    // Фильтруем посты по поисковому запросу
    final filteredPosts = _searchQuery.isEmpty
        ? _posts
        : _posts.where((post) {
            return post.title.toLowerCase().contains(_searchQuery.toLowerCase());
          }).toList();
    
    // Оборачиваем всю ленту в Column со строкой поиска
    return Column(
      children: [
        // Строка поиска
        Container(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.white,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search posts...',
              prefixIcon: Icon(Icons.search, color: Colors.grey),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.blue.shade700, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade50,
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _searchQuery = value;
              });
            },
          ),
        ),
        // Лента постов
        Expanded(
          child: RefreshIndicator(
            key: _refreshIndicatorKey,
            onRefresh: _refreshFeed,
            child: filteredPosts.isEmpty
                ? ListView(
                    // Нужен ListView даже для пустого контента, чтобы RefreshIndicator работал
                    physics: AlwaysScrollableScrollPhysics(),
                    children: [
                      Container(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _searchQuery.isEmpty ? Icons.photo_album : Icons.search_off,
                                size: 64,
                                color: Colors.grey,
                              ),
                              SizedBox(height: 16),
                              Text(
                                _searchQuery.isEmpty ? 'No posts yet' : 'Nothing found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                _searchQuery.isEmpty
                                    ? 'Posts from you and people you follow will appear here'
                                    : 'Try changing your search query',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  )
                : _buildFeedContentWithPosts(filteredPosts),
          ),
        ),
      ],
    );
  }

  // Получение информации об авторе поста
  Future<Map<String, dynamic>> _getPostAuthorInfo(Post post) async {
    if (_isCurrentUserPost(post)) {
      // Если пост принадлежит текущему пользователю, возвращаем данные текущего пользователя
      return {
        'firstName': _userFullName.split(' ').first,
        'lastName': _userFullName.split(' ').length > 1 ? _userFullName.split(' ').last : '',
        'profileImageUrl': _userProfileImage,
      };
    }

    // Иначе получаем информацию о пользователе по ID через API
    final userData = await UserService.getUserInfoById(post.user);
    return userData;
  }

  /// Показать модальное окно с комментариями
  void _showCommentsModal(Post post) {
    // Показываем комментарии в модальном окне снизу
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Важно для правильного отображения клавиатуры
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: CommentsScreen(
            photoId: post.id,
            photoUrl: post.imageUrls.isNotEmpty
                ? post.imageUrls.first
                : (post.images.isNotEmpty
                ? post.images.first.path
                : 'https://via.placeholder.com/300'),
          ),
        );
      },
    ).then((_) {
      // Обновляем список постов после закрытия окна комментариев
      _loadAllPosts();
    });
  }

  /// Открыть страницу с постами локации
  void _openLocationPostsScreen(Post post) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LocationPostsScreen(
          initialPost: post,
          locationName: post.locationName,
          latitude: post.location.latitude,
          longitude: post.location.longitude,
        ),
      ),
    );
  }

  // Показать пост на карте - модифицированный метод
  void _showOnMap(Post post) {
    if (post.location == null) {
      AppLogger.log("❌ Невозможно показать пост на карте: отсутствуют координаты");
      return;
    }
    
    
    // Устанавливаем источник как ленту (feed)
    _mapFilterService.setSourceView('feed');
    
    // Check the annotation processing lock FIRST
    if (_isProcessingAnnotations) {
        return; // Exit if another annotation operation is running
    }

    // НЕ устанавливаем флаг _showingSpecificPost, чтобы все маркеры загрузились
    // вместо этого используем существующую логику выделения маркера
    
    // Сохраняем пост для дальнейшего использования
    _lastViewedPost = post;
    _lastViewedPostIndex = _posts.indexWhere((p) => p.id == post.id);
    if (_lastViewedPostIndex == -1) {
    }

    _updateCameraOptions();

    setState(() {
      _activeView = 'map';
    });
    
    Future.delayed(Duration(milliseconds: 500), () async {
      if (!mounted || _mapboxMap == null || !_isMapLoaded) { 
         AppLogger.log("❌ Карта недоступна после переключения вида");
         return; 
      }
      
      
      try {
        
        // ИСПРАВЛЕНИЕ: Убираем отдельный вызов _loadPostMarkers()
        // так как _highlightClickedMarker сам пересоздаст все маркеры
        // Это исправляет проблему дублирования маркеров
        
        // Небольшая задержка, чтобы карта была готова
        await Future.delayed(Duration(milliseconds: 100));
        
        // Выделяем нужный маркер увеличенным размером
        // Этот метод сам загрузит все маркеры и выделит нужный
        _cancelHighlightInProgress = false;
        final int opVersionMapSelect = ++_highlightOperationVersion;
        await _highlightClickedMarker(post.id, opVersion: opVersionMapSelect);
         
         // Создаем точку для перемещения камеры
         final point = Point(
           coordinates: Position(
             post.location!.longitude, 
             post.location!.latitude
           )
         );
        
        // Получаем текущий zoom карты
        double currentZoom = 12.0;
        try {
          final cameraState = await _mapboxMap!.getCameraState();
          if (cameraState != null) {
            currentZoom = cameraState.zoom;
          }
        } catch (e) {
        }
        
        // Переместим камеру к нужной локации
        await _mapboxMap!.flyTo(
          CameraOptions(
            center: point,
            zoom: currentZoom,
            pitch: 30.0,
          ),
          MapAnimationOptions(duration: 1000),
        );
        
      } catch (e) {
        AppLogger.log("❌ Ошибка при отображении поста на карте: $e");
      }
    });
  }

  // Метод для визуального выделения маркера без создания нового
  void _tryHighlightMarkerVisually(Post post) {
    
    // Здесь можно добавить логику для визуального выделения маркера
    // Например, анимировать блинк для маркера или изменить его цвет
    // Но сейчас просто оставляем эту функцию как заглушку
  }

  // Метод для добавления выделенного маркера поверх других
  Future<void> _addHighlightedMarker(Post post) async {
    if (_mapboxMap == null || _pointAnnotationManager == null) return;
    
    try {
      // Создаем точку для маркера
      final point = Point(
        coordinates: Position(
          post.location.longitude, 
          post.location.latitude
        )
      );
      
      // Проверяем наличие фото-маркера для этого поста
      final String markerImageId = "post-marker-${post.id}";
      bool hasImage = await _mapboxMap!.style.hasStyleImage(markerImageId);
      final iconId = hasImage ? markerImageId : "marker-15";
      
      
      // Создаем опции для выделенного маркера
      // Добавляем маркер с плавным появлением
      final staged = PointAnnotationOptions(
        geometry: point,
        iconSize: 0.01,
        iconImage: iconId,
        textField: post.locationName,
        textSize: 14.0,
        textOffset: [0, 3.0],
        textColor: 0xFF000000,
        textHaloColor: 0xFFFFFFFF,
        textHaloWidth: 2.0,
        iconOffset: [0, 0],
        iconAnchor: IconAnchor.CENTER,
      );

      final annotation = await _pointAnnotationManager!.create(staged);
      if (annotation != null) {
        await _animateMarkerAppearance(annotation, 0.75, durationMs: 160);
      }
      
      // Сохраняем соответствие для нового маркера
      if (annotation != null) {
        _markerPostMap[annotation.id] = post;
      }
    } catch (e) {
      AppLogger.log("❌ Ошибка при создании выделенного маркера: $e");
    }
  }

  // Метод для редактирования поста
  void _editPost(Post post) {
    Navigator.push<dynamic>(
      context,
      MaterialPageRoute(
        builder: (context) => EditPostScreen(post: post),
      ),
    ).then((result) {
      if (result != null) {
        // Если пост был обновлен, обновляем данные и обновляем UI
        if (result is Post) {
          // Обновляем пост в локальном списке
          final index = _posts.indexWhere((p) => p.id == post.id);
          if (index != -1) {
            setState(() {
              _posts[index] = result;
              
              // Если у нас есть выбранный пост и это тот, который мы обновили
              if (_selectedPost != null && _selectedPost!.id == post.id) {
                _selectedPost = result;
              }
            });
          }
        }
        // В любом случае обновляем посты
        _loadAllPosts();
      }
    });
  }

  /// View post details
  void _openPostDetails(Post post) {
    // Navigation to post details screen should be here

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
        title: const Text('Delete post?'),
        content: const Text('This post will be permanently deleted. Continue?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
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
              content: Text('Deleting post...'),
              duration: Duration(seconds: 1),
            ),
          );
        }

        // Удаляем пост через сервис
        final bool success = await PostService.deletePost(post.id);

        if (!success) {
          throw Exception("Server returned an error while deleting post");
        }

        // Оптимистически удаляем пост из локального списка и закрываем детали
        if (mounted) {
          setState(() {
            _posts.removeWhere((p) => p.id == post.id);
            if (_selectedPost?.id == post.id) {
              _selectedPost = null;
            }
          });
        }

        // Форсируем обновление постов и маркеров, игнорируя флаг показа конкретного поста
        _showingSpecificPost = false;
        await _loadAllPosts();
        if (_isMapLoaded) {
          _reloadMarkers();
        }

        // Показываем сообщение об успешном удалении
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post deleted'),
            ),
          );
        }
      } catch (e) {
        // Показываем сообщение об ошибке
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete post. Please try again later.'),
              backgroundColor: Colors.red,
            ),
          );
        }

        // Всё равно пытаемся обновить список постов и маркеры
        try {
          _showingSpecificPost = false;
          await _loadAllPosts();
          if (_isMapLoaded) {
            _reloadMarkers();
          }
        } catch (refreshError) {
          AppLogger.log("Ошибка при обновлении списка постов после ошибки удаления: $refreshError");
        }
      }
    }
  }

  /// Initialize location service
  Future<void> _initializeLocationService() async {

    try {
      // Check location permissions
      bool hasPermission = await _checkLocationPermission();

      if (!hasPermission) {
        return;
      }

      // Всегда определяем текущее местоположение для кнопки "Моя геолокация"
      // Get current position
      geo.Position position = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );


      if (mounted) {
        setState(() {
          _currentPosition = GeoLocation(
              latitude: position.latitude,
              longitude: position.longitude
          );
        });
      }
    } catch (e) {
      AppLogger.log("Error initializing location service: $e");
      if (mounted) {
        setState(() {
          _error = "Error getting current position: $e";
        });
      }
    }
  }

  /// Properly cleans up all map-related resources (Now Async and Safe)
  Future<void> _cleanupMapResources() async { // Make async
    // Check if mounted
    if (!mounted) {
      return;
    }

    // Check and set lock flag
    if (_isProcessingAnnotations) {
      return;
    }
     // No need for setState here unless UI depends on this flag immediately
     _isProcessingAnnotations = true; 

    if (_mapboxMap != null) {
      try {

        // Safely remove the annotation manager
        if (_pointAnnotationManager != null) {
          try {
            // Check again before await, as state might change
            if (!mounted || _mapboxMap == null) {
                 _isProcessingAnnotations = false; // Release lock if check fails
                 return; 
            }
            await _mapboxMap!.annotations.removeAnnotationManager(_pointAnnotationManager!);
             // Set to null only after successful removal and if still mounted
            if (mounted) {
                _pointAnnotationManager = null;
            }
          } catch (e) {
            AppLogger.log("🔴 Error while clearing annotations during HomeTab cleanup: $e");
            // Still try to nullify if mounted
             if (mounted) {
                _pointAnnotationManager = null;
             }
          }
        }
        
        // Release map instance *after* potentially async operations
        if (mounted) {
            _mapboxMap = null;
            _isMapLoaded = false; // Set map loaded to false
        }

      } catch (e) {
        AppLogger.log("🔴 Error while cleaning up map resources in HomeTab: $e");
        // Attempt cleanup even on error
        if (mounted) {
            _pointAnnotationManager = null;
            _mapboxMap = null;
            _isMapLoaded = false;
        }
      } finally {
         // Release lock flag
         if (mounted) {
           _isProcessingAnnotations = false; 
         }
      }
    } else {
        // Map was already null
        if (mounted) {
            _pointAnnotationManager = null;
            _isMapLoaded = false; // Ensure loaded is false
        }
        // Release lock if map was already null
         if (mounted) { // Check mounted before state change
            _isProcessingAnnotations = false;
         }
    }
  }

  /// Метод для перезагрузки стиля карты и маркеров при переключении экранов
  Future<void> _reloadMapStyleAndMarkers() async {
    if (_mapboxMap == null || !_isMapLoaded) {
      return;
    }
    
    try {
      
      // Сбрасываем флаги выделения
      _showingSpecificPost = false;
      _lastViewedPost = null;
      
      // Даем небольшую задержку, чтобы карта завершила все внутренние операции
      await Future.delayed(Duration(milliseconds: 300));
      
      // ВАЖНО: Пересоздаем менеджер аннотаций при восстановлении карты
      _pointAnnotationManager = null;
      _markerPostMap.clear();
      
      // Создаем новый менеджер аннотаций
      try {
        final annotations = await _mapboxMap!.annotations;
        _pointAnnotationManager = await annotations.createPointAnnotationManager();
        _pointAnnotationManager!.addOnPointAnnotationClickListener(_markerClickListener);
      } catch (e) {
        AppLogger.log("❌ Ошибка создания менеджера аннотаций при восстановлении: $e");
        return;
      }
      
      // Перед загрузкой маркеров гарантируем регистрацию дефолтных иконок
      try {
        await MapboxConfig.registerMapboxMarkerImages(_mapboxMap!);
      } catch (e) {
        AppLogger.log("⚠️ Error registering default markers on style reload: $e");
      }
      
      // Загружаем маркеры заново
      await _loadPostMarkers();
      
    } catch (e) {
      AppLogger.log("❌ Ошибка при перезагрузке стиля и маркеров: $e");
    }
  }
  
  // Загрузка стиль карты
  Future<void> _loadMapStyle() async {
    if (_mapboxMap == null) return;
    
    try {
      // Устанавливаем стиль карты
      await _mapboxMap!.loadStyleURI(MapboxConfig.DEFAULT_STYLE_URI);
      
      // Обновляем состояние
      setState(() {
        _isMapLoaded = true;
        _isMapLoading = false;
      });
    } catch (e) {
      AppLogger.log("Ошибка при загрузке стиля карты: $e");
      setState(() {
        _isMapLoaded = false;
        _isMapLoading = false;
        _error = e.toString();
      });
    }
  }

  /// Запускает таймер обновления постов
  void _startPostsRefreshTimer() {
    _postsRefreshTimer?.cancel();
    _postsRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _loadAllPosts();
    });

    // Начальное обновление
    _loadAllPosts();

  }

  // Загрузка данных пользователя
  Future<void> _loadUserData() async {
    try {
      AppLogger.log("📱 HomeTab: Начинаем загрузку данных пользователя...");
      final fullName = await UserService.getFullName();
      final profileImage = await UserService.getProfileImage();
      final email = await UserService.getEmail();
      final userId = await UserService.getUserId(); // Получаем ID пользователя

     if (mounted) {
        setState(() {
          _userFullName = fullName;
          _userProfileImage = profileImage;
          _userEmail = email;
          _userId = userId; // Сохраняем ID пользователя
          _userDataLoaded = true;
        });
        AppLogger.log("📱 HomeTab: Данные пользователя загружены:");
        AppLogger.log("   - Имя: $_userFullName");
        AppLogger.log("   - Email: $_userEmail");
        AppLogger.log("   - ID: $_userId");
      }
    } catch (e) {
      AppLogger.log("❌ HomeTab: Ошибка при загрузке данных пользователя: $e");
    }
  }

  /// Метод для построения основного контента в зависимости от активной вкладки
  Widget _buildMainContent() {

    // Если активна вкладка карты
    if (_activeView == 'map') {
      // Если есть сохраненные настройки камеры или текущее местоположение
      if (_lastCameraOptions != null || _currentPosition != null) {
        return Stack(
          children: [
            SizedBox(
              width: MediaQuery.of(context).size.width,
              height: MediaQuery.of(context).size.height,
              child: MapWidget(
                key: const ValueKey("mapWidget"),
                onMapCreated: _onMapCreated,
                styleUri: MapboxConfig.DEFAULT_STYLE_URI,
                // Используем сохраненные настройки камеры, или значения по умолчанию из текущего местоположения, если их нет
                cameraOptions: _lastCameraOptions ?? (_currentPosition != null ? CameraOptions(
                    center: Point(
                        coordinates: Position(
                            _currentPosition!.longitude,
                            _currentPosition!.latitude
                        )
                    ),
                    zoom: 12.0
                ) : null), // Если нет ни сохраненных настроек, ни текущего местоположения, то null
                onTapListener: (context) {
                  // Откладываем обработку тапа карты, чтобы дать шанс обработаться клику по маркеру
                  Future.delayed(const Duration(milliseconds: 220), () {
                    if (_suppressMapTapReset || _isProcessingAnnotations) {
                      return;
                    }
                    if (_lastMarkerTapAt != null && DateTime.now().difference(_lastMarkerTapAt!) < const Duration(milliseconds: 300)) {
                      return;
                    }
                    if (_isMapLoaded) {
                      _forceResetMarkers();
                    }
                  });
                },
              ),
            ),
            // Маркер геолокации теперь добавляется непосредственно на карту через annotations
          ],
        );
      } else {
        // Если нет ни сохраненных настроек, ни текущего местоположения, показываем индикатор загрузки
        return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text("Определение местоположения...", style: TextStyle(color: Colors.grey))
              ],
            )
        );
      }
    }

    // Если активна вкладка ленты
    return _buildFeedContentOnly();
  }

  PointAnnotation? _userLocationAnnotation;
  
  /// Добавляет или обновляет маркер текущей геолокации пользователя на карте
  Future<void> _addUserLocationMarker() async {
    if (_mapboxMap == null || _pointAnnotationManager == null || _currentPosition == null) {
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
        } catch (e) {
          AppLogger.log("❌ Ошибка регистрации изображения маркера геолокации: $e");
          return;
        }
      }
      
      // Создаем новый маркер геолокации
      final point = Point(
        coordinates: Position(
          _currentPosition!.longitude,
          _currentPosition!.latitude,
        ),
      );
      
      final options = PointAnnotationOptions(
        geometry: point,
        iconImage: userLocationMarkerId,
        iconSize: 0.2,
        iconAnchor: IconAnchor.BOTTOM,
      );
      
      _userLocationAnnotation = await _pointAnnotationManager!.create(options);
      
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

  /// Строит содержимое ленты постов
  // Обёртка для _buildFeedContentOnly с передачей отфильтрованных постов
  Widget _buildFeedContentWithPosts(List<Post> posts) {
    final originalPosts = _posts;
    _posts = posts;
    final result = _buildFeedContentOnly();
    _posts = originalPosts;
    return result;
  }

  Widget _buildFeedContentOnly() {
    // Этот метод теперь только строит содержимое ленты без RefreshIndicator


    // Очищаем старый маппинг post.id -> ключ группы перед пересозданием
    _postIdToGroupKey.clear();
    // НЕ очищаем _postIdToFeedIndex здесь - он будет перезаписан ниже
    // Очистка приводит к сбросу прокрутки при множественных перестроениях

    // Группируем посты по локациям
    final Map<String, List<Post>> postsByLocation = {};
    final Set<String> processedPosts = {};

    // Функция для вычисления расстояния между двумя координатами в метрах
    double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
      const int earthRadius = 6371000; // радиус Земли в метрах
      final double phi1 = lat1 * pi / 180;
      final double phi2 = lat2 * pi / 180;
      final double deltaPhi = (lat2 - lat1) * pi / 180;
      final double deltaLambda = (lon2 - lon1) * pi / 180;

      final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
          cos(phi1) * cos(phi2) *
              sin(deltaLambda / 2) * sin(deltaLambda / 2);
      final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

      return earthRadius * c; // Расстояние в метрах
    }

    // Группируем посты, находящиеся в пределах 200 метров друг от друга
    for (var post in _posts) {
      if (processedPosts.contains(post.id)) continue;

      // Ищем ближайшую существующую группу для поста
      String? closestGroup;
      double minDistance = double.infinity;

      for (var locationKey in postsByLocation.keys) {
        // Берем первый пост из группы для сравнения координат
        final firstPost = postsByLocation[locationKey]!.first;

        // Проверяем также имя локации
        bool sameName = firstPost.locationName.toLowerCase() == post.locationName.toLowerCase();

        // Считаем расстояние между текущим постом и первым постом группы
        final distance = calculateDistance(
            post.location.latitude, post.location.longitude,
            firstPost.location.latitude, firstPost.location.longitude
        );


        // Добавляем пост в группу если одинаковые имена ИЛИ расстояние меньше 200 метров
        if ((sameName || distance <= 200) && distance < minDistance) {
          closestGroup = locationKey;
          minDistance = distance;
        }
      }

      if (closestGroup != null) {
        // Если нашли ближайшую группу, добавляем пост к ней
        postsByLocation[closestGroup]!.add(post);
        // Сохраняем маппинг post.id -> ключ группы для правильного поиска контроллера
        _postIdToGroupKey[post.id] = closestGroup;
      } else {
        // Иначе создаем новую группу с этим постом, используя единый метод для ключа
        final newLocationKey = _createLocationGroupKey(
          post.locationName,
          post.location.latitude,
          post.location.longitude
        );
        postsByLocation[newLocationKey] = [post];
        // Сохраняем маппинг post.id -> ключ группы
        _postIdToGroupKey[post.id] = newLocationKey;
      }

      processedPosts.add(post.id);
    }

    postsByLocation.forEach((key, posts) {
    });

    // Сортируем локации по количеству уникальных пользователей в локации
    final List<MapEntry<String, List<Post>>> sortedLocationEntries = postsByLocation.entries.toList();
    sortedLocationEntries.sort((a, b) {
      // Считаем количество уникальных пользователей в каждой локации
      final Set<String> uniqueUsersA = a.value.map((p) => p.user).toSet();
      final Set<String> uniqueUsersB = b.value.map((p) => p.user).toSet();
      
      // Сначала сортируем по количеству уникальных пользователей (больше = выше)
      int uniqueUserComparison = uniqueUsersB.length.compareTo(uniqueUsersA.length);
      
      // Если количество уникальных пользователей одинаково, сортируем по дате новейшего поста
      if (uniqueUserComparison == 0) {
        final latestPostA = a.value.reduce((curr, next) => 
          curr.createdAt.isAfter(next.createdAt) ? curr : next);
        final latestPostB = b.value.reduce((curr, next) => 
          curr.createdAt.isAfter(next.createdAt) ? curr : next);
        return latestPostB.createdAt.compareTo(latestPostA.createdAt);
      }
      
      return uniqueUserComparison;
    });
    
    // Создаем список отображаемых виджетов
    final List<Widget> feedItems = [];

    final Set<String> renderedIds = {};
    for (var entry in sortedLocationEntries) {
      final postsInLocation = entry.value;

      // Создаем PostCard для каждого поста в группе, а не только для первого
      for (var post in postsInLocation) {
        // Пропускаем дубль одного и того же поста по id
        if (!renderedIds.add(post.id)) {
          continue;
        }
        
        // Сохраняем реальный индекс поста в UI (ПЕРЕД добавлением в feedItems)
        _postIdToFeedIndex[post.id] = feedItems.length;
        
        // Добавляем элемент с PostCard
        feedItems.add(
          FutureBuilder<Map<String, dynamic>>(
            future: _getPostAuthorInfo(post),
            builder: (context, authorSnapshot) {
              final authorInfo = authorSnapshot.data ?? {'firstName': 'Loading...', 'lastName': '', 'profileImageUrl': ''};
              final firstName = authorInfo['firstName']?.toString().trim() ?? '';
              final lastName = authorInfo['lastName']?.toString().trim() ?? '';
              final authorName = '$firstName $lastName'.trim();
              final authorProfileImage = authorInfo['profileImageUrl'] as String?;
              
              return FutureBuilder<bool>(
                future: _checkIsFollowing(post.user),
                builder: (context, snapshot) {
                  final isFollowing = snapshot.data ?? false;

                  // ИСПРАВЛЕНИЕ: Убрали GlobalKey, теперь используем ScrollController + offset
                  return Container(
                    margin: EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      // Добавляем подсветку, если это пост, который в данный момент выбран
                      border: _lastViewedPostIndex == _posts.indexWhere((p) => p.id == post.id)
                        ? Border.all(color: Colors.blue, width: 3)
                        : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: PostCard(
                      post: post,
                      userProfileImage: _userProfileImage,
                      userFullName: _userFullName,
                      authorProfileImage: authorProfileImage,
                      authorName: authorName,
                      onShowCommentsModal: _showCommentsModal,
                      onShowOnMap: _showOnMap,
                      onEditPost: _editPost,
                      onDeletePost: _deletePost,
                      isCurrentUserPost: _isCurrentUserPost(post),
                      onLikePost: _likePost,
                      onFavoritePost: _favoritePost,
                      onFollowUser: _followUser,
                      isFollowing: isFollowing,
                      onImageTap: _openImageViewer,
                      onLocationPostsClick: _openLocationPostsScreen,
                    ),
                  );
                },
              );
            },
          ),
        );
      }
    }


    // Отображаем элементы ленты (RefreshIndicator теперь находится на уровне выше)
    return ListView.separated(
      controller: _feedScrollController,
      physics: AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(left: 8, right: 8, top: 4, bottom: 90),
      itemCount: feedItems.length,
      separatorBuilder: (context, index) => SizedBox(height: 4),
      itemBuilder: (context, index) {
        // Все виджеты в feedItems уже имеют GlobalKey (строка 2872), просто возвращаем их
        return feedItems[index];
      },
    );
  }

  // Обновление ленты по свайпу вниз
  Future<void> _refreshFeed() async {
    try {
      
      // Показываем визуальный индикатор
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Updating feed...'),
            duration: Duration(milliseconds: 500),
          ),
        );
      }
      
      // Используем принудительное обновление, которое очищает кеш
      final posts = await PostService.forceRefreshPosts();
      
      
      if (mounted) {
        setState(() {
          _posts = posts;
        });
        
        // Также обновляем маркеры на карте
        if (_isMapLoaded) {
          _reloadMarkers();
        }
        
      }
      
    } catch (e) {
      AppLogger.log('❌❌❌ Ошибка при обновлении ленты: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating feed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Получаем статус подписки для нескольких пользователей
  Future<Map<String, bool>> _getFollowingStatusForUsers(List<String> userIds) async {
    final Map<String, bool> result = {};

    for (var userId in userIds) {
      try {
        if (_userEmail == userId || _userId == userId || userId == 'current_user') {
          result[userId] = false;
        } else {
          result[userId] = await SocialService.isFollowing(userId);
        }
      } catch (e) {
        AppLogger.log("Error checking following status for $userId: $e");
        result[userId] = false;
      }
    }

    return result;
  }

  // Проверяем, является ли пост текущего пользователя
  bool _isCurrentUserPost(Post post) {
    AppLogger.log("🔐 HomeTab: Проверка прав для поста ${post.id}");
    AppLogger.log("   - Пользователь поста: '${post.user}'");
    AppLogger.log("   - Текущий email: '$_userEmail'");
    AppLogger.log("   - Текущий ID: '$_userId'");
    
    // Проверяем наличие идентификаторов пользователя
    if (_userEmail.isEmpty && _userId.isEmpty) {
      AppLogger.log("   ❌ Нет идентификаторов текущего пользователя");
      return false;
    }

    // Сначала проверяем, совпадает ли пользователь поста с email текущего пользователя
    if (post.user == _userEmail) {
      AppLogger.log("   ✅ Совпадение по email");
      return true;
    }

    // Если у нас есть числовой идентификатор пользователя, проверяем, совпадает ли post.user с ним
    if (_userId.isNotEmpty && post.user == _userId) {
      AppLogger.log("   ✅ Совпадение по строковому ID");
      return true;
    }

    // Пытаемся проверить, является ли пользователь поста числовым ID
    try {
      final int? postUserId = int.tryParse(post.user);
      final int? currentUserId = int.tryParse(_userId);

      if (postUserId != null && currentUserId != null && postUserId == currentUserId) {
        AppLogger.log("   ✅ Совпадение по числовому ID: $postUserId == $currentUserId");
        return true;
      } else {
        AppLogger.log("   ⚠️ ID не совпадают: post=$postUserId, current=$currentUserId");
      }
    } catch (e) {
      AppLogger.log("   ⚠️ Ошибка парсинга ID: $e");
    }

    // Наконец, проверяем специальные значения, которые могут представлять текущего пользователя
    if (post.user == 'current_user' || post.user == 'null') {
      AppLogger.log("   ✅ Специальное значение: ${post.user}");
      return true;
    }

    AppLogger.log("   ❌ Пост НЕ принадлежит текущему пользователю");
    return false;
  }

  // Проверяем, подписан ли пользователь на автора поста
  Future<bool> _checkIsFollowing(String userId) async {
    try {
      if (_userEmail == userId || _userId == userId || userId == 'current_user') {
        return false; // Нельзя подписаться на самого себя
      }
      return await SocialService.isFollowing(userId);
    } catch (e) {
      AppLogger.log("Error checking following status: $e");
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
      AppLogger.log("Error liking post: $e");
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
      AppLogger.log("Error favoriting post: $e");
    }
  }

  // Обработчик подписки на пользователя
  Future<void> _followUser(String userId) async {
    try {
      // Проверяем, не пытается ли пользователь подписаться на самого себя
      if (_userEmail == userId || _userId == userId || userId == 'current_user') {
        return;
      }

      final isFollowing = await SocialService.isFollowing(userId);

      if (isFollowing) {
        await SocialService.unfollowUser(userId);
      } else {
        await SocialService.followUser(userId);
      }

      // Обновляем UI
      setState(() {});
    } catch (e) {
      AppLogger.log("Error following user: $e");
    }
  }

  // Метод для прокрутки к нужному посту в ленте
  void _scrollToPostInFeed(Post post) {
    _scrollToPostByIdWithController(post.id);
  }

  // Открытие просмотрщика изображений на весь экран
  void _openImageViewer(Post post, int initialIndex) {

    // Проверяем, что пост и изображения существуют
    if (post == null || (post.imageUrls.isEmpty && post.images.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Нет доступных изображений для просмотра'))
      );
      return;
    }

    // Открываем новый вертикальный просмотрщик фотографий для любого типа изображений

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => VerticalPhotoGalleryScreen(
          post: post,
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

    // Примерная высота элемента с учетом отступов
    double approximatePostHeight = 350.0;
    double marginsAndSeparator = 20.0;
    double totalItemHeight = approximatePostHeight + marginsAndSeparator;

    // ПРИМЕЧАНИЕ: Вычисляем примерный индекс видимого поста в UI ленте
    // Это приблизительное значение для отслеживания, не критично для навигации
    int visibleFeedIndex = (scrollOffset / totalItemHeight).floor();

    // Проверяем границы относительно количества постов в _posts
    if (visibleFeedIndex < 0) visibleFeedIndex = 0;
    if (visibleFeedIndex >= _posts.length) visibleFeedIndex = _posts.length - 1;

    // Пытаемся найти соответствующий пост по приблизительному индексу
    // Это не точно из-за группировки, но подходит для общего отслеживания
    _lastViewedPost = _posts[visibleFeedIndex];
    _lastViewedPostIndex = visibleFeedIndex;
  }

  Map<String, List<Post>> _groupPostsByLocation(List<Post> posts) {
    final Map<String, List<Post>> postsByLocation = {};

    // Сначала группируем посты по имени локации
    for (var post in posts) {
      final locationName = post.locationName.toLowerCase();

      if (postsByLocation.containsKey(locationName)) {
        postsByLocation[locationName]!.add(post);
      } else {
        postsByLocation[locationName] = [post];
      }
    }


    // Сортируем локации по дате создания самого нового поста
    final List<MapEntry<String, List<Post>>> sortedLocationEntries = postsByLocation.entries.toList();
    sortedLocationEntries.sort((a, b) {
      final latestPostA = a.value.reduce((curr, next) =>
      curr.createdAt.isAfter(next.createdAt) ? curr : next);
      final latestPostB = b.value.reduce((curr, next) =>
      curr.createdAt.isAfter(next.createdAt) ? curr : next);
      return latestPostB.createdAt.compareTo(latestPostA.createdAt);
    });

    return postsByLocation;
  }

  // Вспомогательный метод для расчета расстояния между постами
  double _calculateDistanceBetweenPosts(Post post1, Post post2) {
    return _calculateDistance(
        post1.location.latitude, post1.location.longitude,
        post2.location.latitude, post2.location.longitude
    );
  }

  // Вспомогательный метод для расчета расстояния между координатами в метрах
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const int earthRadius = 6371000; // радиус Земли в метрах

    // Перевод градусов в радианы
    final double phi1 = lat1 * 3.14159265359 / 180;
    final double phi2 = lat2 * 3.14159265359 / 180;
    final double deltaPhi = (lat2 - lat1) * 3.14159265359 / 180;
    final double deltaLambda = (lon2 - lon1) * 3.14159265359 / 180;

    // Формула гаверсинусов
    final double a = sin(deltaPhi / 2) * sin(deltaPhi / 2) +
        cos(phi1) * cos(phi2) *
            sin(deltaLambda / 2) * sin(deltaLambda / 2);
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c; // Расстояние в метрах
  }

  // Reload markers with current filter settings
  Future<void> _reloadMarkers() async {
    if (_mapboxMap == null) {
      return;
    }
    
    if (_isProcessingAnnotations) {
      return;
    }
    
    // Если сейчас показываем конкретный пост, не перезагружаем маркеры,
    // чтобы не сбивать выделение и увеличенный маркер
    if (_showingSpecificPost) {
      return;
    }
    
    
    // Защита от одновременных вызовов
    _isProcessingAnnotations = true;
    
    setState(() {
      _markersLoading = true;
    });
    
    try {
      // Пересоздаем менеджер аннотаций вместо deleteAll для стабильности
      try {
        // Безопасно удаляем предыдущий менеджер, чтобы очистить увеличенные/старые маркеры
        if (_pointAnnotationManager != null) {
          try {
            await _mapboxMap!.annotations.removeAnnotationManager(_pointAnnotationManager!);
          } catch (e) {
            AppLogger.log("⚠️ Error removing previous annotation manager: $e");
          } finally {
            _pointAnnotationManager = null;
          }
        }
        final annotations = await _mapboxMap!.annotations;
        _pointAnnotationManager = await annotations.createPointAnnotationManager();
        _pointAnnotationManager!.addOnPointAnnotationClickListener(_markerClickListener);
      } catch (e) {
        AppLogger.log("❌ Error creating annotation manager: $e");
        setState(() {
          _markersLoading = false;
        });
        _isProcessingAnnotations = false;
        return;
      }
      
      // Очищаем карту маркеров
      _markerPostMap = {};
      
      // Применяем фильтры
      List<Post> filteredPosts = List.from(_posts);
      
      if (_showOnlyFavorites) {
        final favoritePosts = await SocialService.getFavoritePosts();
        final favoriteIds = favoritePosts.map((post) => post.id).toSet();
        filteredPosts = filteredPosts.where((post) => favoriteIds.contains(post.id)).toList();
      } else if (_showOnlyFollowings) {
        final followingPosts = await SocialService.getFollowingNonAlbumPosts();
        final followingIds = followingPosts.map((post) => post.id).toSet();
        filteredPosts = filteredPosts.where((post) => followingIds.contains(post.id)).toList();
      }
      
      // Добавляем маркеры
      if (filteredPosts.isEmpty) {
      } else {
        await _addPostMarkersToMap(filteredPosts);
      }
      
    } catch (e) {
      AppLogger.log("❌ Error reloading markers: $e");
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _markersLoading = false;
      });
      _isProcessingAnnotations = false;
    }
  }
  
  // Обработчик изменения фильтра
  void _handleFilterChange(bool showOnlyFavorites) {
    
    setState(() {
      _showOnlyFavorites = showOnlyFavorites;
      
      // Если включен фильтр избранных, переключаемся на вид карты
      if (showOnlyFavorites && _activeView != 'map') {
        _activeView = 'map';
      }
    });
    
    // Перезагружаем маркеры на карте только если карта уже загружена
    if (_isMapLoaded) {
      Future.microtask(() => _reloadMarkers());
    }
  }
  
  // Обработчик изменения фильтра постов из followings
  void _handleFollowingsFilterChange(bool showOnlyFollowings) {
    
    setState(() {
      _showOnlyFollowings = showOnlyFollowings;
      
      // Если включен фильтр followings, переключаемся на вид карты
      if (showOnlyFollowings && _activeView != 'map') {
        _activeView = 'map';
      }
    });
    
    // Перезагружаем маркеры на карте только если карта уже загружена
    if (_isMapLoaded) {
      Future.microtask(() => _reloadMarkers());
    }
  }
  
  // Обработчик выделения конкретного поста
  void _handleHighlightPost(Post? highlightedPost) {
    AppLogger.log('🎯 HomeTab: _handleHighlightPost вызван с постом: ${highlightedPost?.id}');
    if (highlightedPost == null) {
      AppLogger.log('   ⚠️ highlightedPost == null, выход');
      return;
    }
    
    AppLogger.log('   sourceView: ${_mapFilterService.sourceView}');
    AppLogger.log('   _mapboxMap: ${_mapboxMap != null}, _isMapLoaded: $_isMapLoaded');
    
    // ВАЖНО: Сбрасываем предыдущее состояние выделения маркера
    _highlightedPostId = null;
    _markerClickStage = 0;
    
    setState(() {
      _lastViewedPost = highlightedPost;
      _lastViewedPostIndex = _posts.indexWhere((p) => p.id == highlightedPost.id);
      _activeView = 'map';
    });
    
    AppLogger.log('   setState выполнен, _activeView теперь: $_activeView');
    
    // Перемещаем камеру и сразу выделяем маркер без предварительной перезагрузки маркеров
    if (_mapboxMap != null && _isMapLoaded && highlightedPost.location != null) {
      AppLogger.log('   ✅ Начинаем процесс выделения маркера для поста ${highlightedPost.id}');
      Future.delayed(Duration(milliseconds: 400), () async {
        try {
          // 1) Сразу выделяем маркер (метод сам пересоздаст обычные и выделенный)
          _cancelHighlightInProgress = false;
          final int opVersion = ++_highlightOperationVersion;
          AppLogger.log('   🔄 Вызываем _highlightClickedMarker для поста ${highlightedPost.id}, opVersion: $opVersion');
          await _highlightClickedMarker(highlightedPost.id, opVersion: opVersion);

          // 2) Перемещаем камеру к посту
          final sourceView = _mapFilterService.sourceView;
          final double zoomLevel = (sourceView == 'followings' || sourceView == 'profile') ? 1.5 : 15.0;
          final cameraOptions = CameraOptions(
            center: Point(
              coordinates: Position(
                highlightedPost.location!.longitude,
                highlightedPost.location!.latitude,
              ),
            ),
            zoom: zoomLevel,
          );
          await _mapboxMap!.setCamera(cameraOptions);
        } catch (e) {
          AppLogger.log("❌ Error in highlight flow: $e");
        }
      });
    }
    
    // Сбрасываем выделение через некоторое время
    Future.delayed(Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _lastViewedPost = null;
          _lastViewedPostIndex = -1;
        });
      }
    });
  }
  
  // ... existing code ...
  
  // Метод для добавления всех маркеров постов на карту
  Future<void> _addPostMarkersToMap(List<Post> posts) async {
    if (_mapboxMap == null) {
      return;
    }
    
    // Инициализируем менеджер аннотаций, если он еще не создан
    if (_pointAnnotationManager == null) {
      try {
        final annotations = await _mapboxMap!.annotations;
        _pointAnnotationManager = await annotations.createPointAnnotationManager();
      } catch (e) {
        AppLogger.log("Error creating point annotation manager: $e");
        return;
      }
    }
    
    try {
      // Сначала параллельно загружаем ВСЕ изображения для некэшированных постов
      final List<Future<void>> imageLoadFutures = [];
      
      for (final post in posts) {
        if (post.location == null || 
            (post.location.latitude == 0 && post.location.longitude == 0)) {
          continue;
        }
        
        if (post.imageUrls.isNotEmpty) {
          final String cacheId = "post-marker-${post.id}";
          
          // Если изображение не в кэше, загружаем параллельно
          if (!MapboxConfig.markerImageBytesCache.containsKey(cacheId)) {
            imageLoadFutures.add(_loadMarkerImageForPost(post));
          }
        }
      }
      
      // Ждем загрузки ВСЕХ изображений параллельно
      if (imageLoadFutures.isNotEmpty) {
        await Future.wait(imageLoadFutures);
      }
      
      int markersAdded = 0;
      
      // Теперь создаем маркеры - все изображения уже загружены
      for (final post in posts) {
        // Пропускаем посты без местоположения
        if (post.location == null || 
            (post.location.latitude == 0 && post.location.longitude == 0)) {
          continue;
        }
        
        // Настройки маркера
        String markerImageId = "custom-marker";
        double iconSize = 0.3;
        bool hasImage = false;
        
        // Проверяем кэш изображений
        if (post.imageUrls.isNotEmpty) {
          final String cacheId = "post-marker-${post.id}";
          
          if (MapboxConfig.markerImageBytesCache.containsKey(cacheId)) {
            hasImage = true;
            markerImageId = cacheId;
          }
        }
        
        try {
          // Создаем опции для маркера
          final PointAnnotationOptions options = PointAnnotationOptions(
            geometry: Point(
              coordinates: Position(
                post.location.longitude,
                post.location.latitude,
              ),
            ),
            iconImage: markerImageId, // Используем ID зарегистрированного изображения или стандартный маркер
            iconSize: iconSize,
            iconAnchor: IconAnchor.BOTTOM,
            // Убрали подписи по умолчанию: textField/textSize/textOffset/textColor/textHalo*
            iconOffset: [0.0, 0.0],
            symbolSortKey: 1.0,
            iconOpacity: 1.0,
          );
          
          // Добавляем маркер на карту
          final annotation = await _pointAnnotationManager?.create(options);
          if (annotation != null) {
            _markerPostMap[annotation.id] = post;
            _postIdToAnnotation[post.id] = annotation;
            markersAdded++;
          } else {
          }
        } catch (e) {
          AppLogger.log("Ошибка при создании маркера для поста ${post.id}: $e");
          // Продолжаем с следующим постом
          continue;
        }
      }
      
    } catch (e) {
      AppLogger.log("Ошибка при добавлении маркеров постов на карту: $e");
    }
  }
  
  // Метод для очистки всех маркеров с карты
  Future<void> _clearAllMarkers() async {
    if (_pointAnnotationManager == null) {
      return;
    }
    
    try {
      // Предварительно очищаем карту маркеров
      _markerPostMap = {};
      _postIdToAnnotation.clear();
      
      // Безопасная проверка перед удалением
      final annotations = await _mapboxMap?.annotations;
      if (annotations == null) {
        return;
      }
      
      // Вместо удаления всех маркеров через deleteAll(), создаем новый менеджер
      _pointAnnotationManager = await annotations.createPointAnnotationManager();
      _pointAnnotationManager?.addOnPointAnnotationClickListener(_markerClickListener);
      
    } catch (e) {
      AppLogger.log("Ошибка при очистке маркеров: $e");
    }
  }

  // Загружаем сохраненные настройки камеры из SharedPreferences
  Future<void> _loadSavedCameraOptions() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Получаем сохраненные значения
      final double? savedZoom = prefs.getDouble('camera_zoom');
      final double? savedLat = prefs.getDouble('camera_lat');
      final double? savedLng = prefs.getDouble('camera_lng');

      // Если есть сохраненные значения, создаем CameraOptions
      if (savedZoom != null && savedLat != null && savedLng != null) {
        _lastCameraOptions = CameraOptions(
          center: Point(
            coordinates: Position(savedLng, savedLat),
          ),
          zoom: savedZoom,
        );
      } else {
      }
    } catch (e) {
      AppLogger.log("Ошибка при загрузке настроек камеры: $e");
    }
  }

  // Сохраняем настройки камеры в SharedPreferences
  Future<void> _saveCameraOptions() async {
    if (_lastCameraOptions == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();

      // Получаем значения из CameraOptions
      final double zoom = _lastCameraOptions!.zoom ?? 12.0;
      final double lat = (_lastCameraOptions!.center?.coordinates.lat ?? 0.0).toDouble();
      final double lng = (_lastCameraOptions!.center?.coordinates.lng ?? 0.0).toDouble();

      // Сохраняем значения
      await prefs.setDouble('camera_zoom', zoom);
      await prefs.setDouble('camera_lat', lat);
      await prefs.setDouble('camera_lng', lng);

    } catch (e) {
      AppLogger.log("Ошибка при сохранении настроек камеры: $e");
    }
  }

  // Вспомогательный метод для обновления настроек камеры
  Future<void> _updateCameraOptions() async {
    try {
    if (_mapboxMap != null) {
        final CameraState cameraState = await _mapboxMap!.getCameraState();

        // Только обновляем настройки, если они действительно изменились
        final newZoom = cameraState.zoom;
        final oldZoom = _lastCameraOptions?.zoom;

        if (_lastCameraOptions == null ||
            newZoom != oldZoom ||
            cameraState.center != _lastCameraOptions?.center) {

          _lastCameraOptions = CameraOptions(
              center: cameraState.center,
              zoom: cameraState.zoom,
              bearing: cameraState.bearing,
              pitch: cameraState.pitch
          );


          // Сохраняем обновленные настройки
          _saveCameraOptions();
        }
      }
    } catch (e) {
      AppLogger.log("Ошибка при обновлении настроек камеры: $e");
    }
  }


  // Modify the marker loading function to use the filtered posts
  Future<void> _loadMarkersIfNeeded() async {
    if (_mapboxMap == null || !_isMapLoaded || _markersLoading) {
      return;
    }
    
    // Проверяем флаг _showingSpecificPost
    if (_showingSpecificPost) {
      return;
    }
    
    setState(() {
      _markersLoading = true;
    });
    
    try {
      // Проверяем состояние и создаем новый менеджер аннотаций, если необходимо
      if (_pointAnnotationManager == null) {
        final annotations = await _mapboxMap!.annotations;
        _pointAnnotationManager = await annotations.createPointAnnotationManager();
        _pointAnnotationManager?.addOnPointAnnotationClickListener(_markerClickListener);
      } else {
      }
      
      // Добавляем маркеры с учетом текущих настроек фильтрации
      await _reloadMarkers();
    } catch (e) {
      AppLogger.log("Ошибка при загрузке маркеров: $e");
      setState(() {
        _markersLoading = false;
        _error = e.toString();
      });
    }
  }

  // Метод для выделения кликнутого маркера
  Future<void> _highlightClickedMarker(String markerId, {required int opVersion}) async {
    AppLogger.log("🔵 _highlightClickedMarker НАЧАЛО для markerId: $markerId, opVersion: $opVersion");
    
    // Check locks and map state first
    if (_isProcessingAnnotations) { 
      AppLogger.log("⚠️ _isProcessingAnnotations = true, выход из _highlightClickedMarker");
      return; 
    }
    if (_mapboxMap == null || !_isMapLoaded) { 
      AppLogger.log("⚠️ _mapboxMap=$_mapboxMap, _isMapLoaded=$_isMapLoaded, выход из _highlightClickedMarker");
      return; 
    }

    AppLogger.log("✅ Проверки пройдены, устанавливаем lock");
    
    // Set lock
    if (mounted) _isProcessingAnnotations = true;

    AppLogger.log("🎯 _highlightClickedMarker вызван для markerId: $markerId");

    // Фиксируем режим показа конкретного поста, чтобы избежать перерисовок
    _showingSpecificPost = true;

    // Размеры маркеров: выделенный ровно в 2 раза больше обычного
    const double normalSize = 0.3;
    const double highlightedSize = normalSize * 2;

    // ИСПРАВЛЕНИЕ: Ищем пост сначала в _posts, а не в _markerPostMap
    // так как _markerPostMap может быть пустым при первом переходе на карту
    Post? targetPost;
    
    // Сначала пробуем найти по post.id в списке _posts
    try {
      targetPost = _posts.firstWhere((p) => p.id == markerId);
      AppLogger.log("✅ Нашли целевой пост в _posts: ${targetPost.id}");
    } catch (_) {
      // Если не нашли в _posts, пробуем найти в _markerPostMap (для случая клика по маркеру)
      targetPost = _markerPostMap[markerId];
      if (targetPost == null) {
        try {
          targetPost = _markerPostMap.values.firstWhere((p) => p.id == markerId);
        } catch (_) {
          targetPost = null;
        }
      }
    }
    
    if (targetPost == null) {
      AppLogger.log("❌ Целевой пост не найден для markerId: $markerId");
      if (mounted) _isProcessingAnnotations = false; // Release lock
      return;
    }
    
    // ИСПРАВЛЕНИЕ: Вместо копирования _markerPostMap (которая может быть пустой),
    // используем список _posts для создания всех маркеров
    // Это исправляет проблему, когда маркеры не создаются при первом переходе на карту

    try {
      
      // --- Replace deleteAll with manager recreation ---
      try {
          final annotations = await _mapboxMap!.annotations;
          _pointAnnotationManager = await annotations.createPointAnnotationManager();
          // Re-add listener to the new manager
          _pointAnnotationManager?.addOnPointAnnotationClickListener(_markerClickListener);
          _markerPostMap = {}; // Clear the Dart-side map, will rebuild below
      } catch (e) {
          AppLogger.log("❌ Error recreating annotation manager in _highlightClickedMarker: $e");
          if (mounted) _isProcessingAnnotations = false; // Release lock on error
          return; // Exit if we can't get a manager
      }
      // --- End of replacement ---
      
      int createdMarkers = 0;

      // Определяем, какие посты рендерить (учитываем активные фильтры)
      List<Post> renderPosts = List<Post>.from(_posts);
      try {
        if (_showOnlyFavorites) {
          final favoritePosts = await SocialService.getFavoritePosts();
          renderPosts = favoritePosts;
        } else if (_showOnlyFollowings) {
          final followingPosts = await SocialService.getFollowingNonAlbumPosts();
          renderPosts = followingPosts;
        }
      } catch (_) {}

      // Гарантируем, что целевой пост присутствует в списке к рендеру
      if (renderPosts.indexWhere((p) => p.id == targetPost!.id) == -1) {
        renderPosts = [targetPost!, ...renderPosts];
      }

      // Заново создаем все маркеры с учетом выделения
      for (var post in renderPosts) {
        
        // Пропускаем посты без координат
        if (post.location == null) {
          continue;
        }
        
        // Создаем точку для маркера
        final point = Point(
          coordinates: Position(
            post.location!.longitude, 
            post.location!.latitude
          )
        );
        
        // Настройки маркера с учетом выделения
        final bool isTarget = (post.id == targetPost!.id);
        if (isTarget) {
          AppLogger.log("✨ Создаем увеличенный маркер для поста ${post.id}");
        }
        
        final String markerImageId = "post-marker-${post.id}";
        bool hasImage = await _mapboxMap!.style.hasStyleImage(markerImageId);
        
        // Если изображения нет, но есть в кэше — регистрируем заново
        if (!hasImage && MapboxConfig.markerImageBytesCache.containsKey(markerImageId)) {
          try {
            await MapboxConfig.registerPostImageAsMarker(
              _mapboxMap!,
              MapboxConfig.markerImageBytesCache[markerImageId]!,
              post.id,
            );
            try {
              hasImage = await _mapboxMap!.style.hasStyleImage(markerImageId);
            } catch (_) {}
          } catch (e) {
          }
        }

        // Если изображения пока нет — используем дефолтный маркер, чтобы маркеры не пропадали
        if (!hasImage) {
          // Убедимся, что дефолтный маркер зарегистрирован (добавляется на старте)
          // Если по какой-то причине его нет, попробуем fallback на 'marker-15'
          try {
            bool hasDefault = await _mapboxMap!.style.hasStyleImage("custom-marker");
            if (hasDefault) {
              // заменяем на дефолтный маркер, чтобы не пропускать маркер
              // ignore: unused_local_variable
              final _ = 0; // для выравнивания контекста
            } else {
              // ничего не делаем, продолжим с marker-15 ниже
            }
          } catch (_) {}
        }
        
        // Создаем маркер сразу с целевым размером, чтобы избежать сбоев обновления анимации
        try {
        final staged = PointAnnotationOptions(
          geometry: point,
          iconSize: isTarget ? highlightedSize : normalSize,
          iconImage: (await _mapboxMap!.style.hasStyleImage(markerImageId)) ? markerImageId : "custom-marker",
          iconAnchor: IconAnchor.BOTTOM,
          iconOffset: [0, 0],
          iconOpacity: 1.0,
        );
        
        if (_pointAnnotationManager == null) {
          continue;
        }
        
        final annotation = await _pointAnnotationManager!.create(staged);
        
        // Обновляем соответствие маркеров и постов
          if (annotation != null) {
            _markerPostMap[annotation.id] = post; // Add to the new map
            _postIdToAnnotation[post.id] = annotation; // Сохраняем ссылку для точечного обновления
            // Без анимации: размер уже установлен финальным, так надежнее при пересоздании менеджера
            createdMarkers++;
          }
        } catch (e) {
          AppLogger.log("❌ Ошибка создания маркера для поста ${post.id}: $e");
        }
      }
      
      
      // Обновляем карту маркеров (already done by adding to _markerPostMap above)
      // _markerPostMap = newMarkerPostMap; // <--- Remove this line
      
      // Добавляем обработчик для новых маркеров (already done when manager was recreated)
      // _addMarkerClickListener(); // <--- Remove this line
      
      // Устанавливаем состояние выделения для корректной работы логики кликов
      if (mounted && !_cancelHighlightInProgress && opVersion == _highlightOperationVersion) {
        setState(() {
          _highlightedPostId = targetPost!.id;
          _markerClickStage = 1;
        });
      }

    } catch (e) {
      AppLogger.log("❌ Ошибка при выделении кликнутого маркера: $e");
    } finally {
       // Release lock flag
       if (mounted) {
          _isProcessingAnnotations = false;
       }
    }
  }

  // Метод для сброса выделенного поста
  void _resetHighlightedPost() {
    if (_lastViewedPost != null) {
      _lastViewedPost = null;
      
      // Устанавливаем флаг, чтобы предотвратить вмешательство других методов
      _showingSpecificPost = false;
      
      // Перезагружаем маркеры без выделения
      _loadPostMarkers();
    }
  }
  
  // Обработчик нажатия кнопки назад на странице карты
  void _handleMapBackButton() {
    _resetHighlightedPost();
    setState(() {
      _activeView = 'feed';
    });
  }

  Widget _buildMapContent() {
    return Stack(
      children: [
        Container(
          constraints: BoxConstraints.expand(),
          child: MapWidget(
            // Исправлено: правильный параметр для токена доступа
            key: ValueKey("mapbox"),
            styleUri: MapboxConfig.NAVIGATION_STYLE_URI,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(-122.084, 37.4219983)
              ),
              zoom: _lastCameraOptions?.zoom ?? 14.0
            ),
            onMapCreated: _onMapCreated,
            onTapListener: (context) {
              // Откладываем обработку тапа карты, чтобы дать шанс обработаться клику по маркеру
              Future.delayed(const Duration(milliseconds: 220), () {
                if (_suppressMapTapReset || _isProcessingAnnotations) {
                  return;
                }
                if (_lastMarkerTapAt != null && DateTime.now().difference(_lastMarkerTapAt!) < const Duration(milliseconds: 300)) {
                  return;
                }
                if (_isMapLoaded) {
                  _forceResetMarkers();
                }
              });
            },
          ),
        ),
        // Панель загрузки, если карта или маркеры загружаются
        if (_isMapLoading || _markersLoading) 
          Center(
            child: Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.8),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 8),
                  Text("Загрузка карты..."),
                ],
              ),
            ),
          ),
        
        // Индикатор ошибки, если есть ошибка
        if (_error.isNotEmpty) 
          Center(
            child: Container(
              margin: EdgeInsets.all(20),
              padding: EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 40),
                  SizedBox(height: 10),
                  Text(
                    "Ошибка загрузки карты",
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  SizedBox(height: 5),
                  Text(_error, textAlign: TextAlign.center),
                  SizedBox(height: 15),
                  ElevatedButton(
                    onPressed: () {
                      _initializeMap();
                    },
                    child: Text("Попробовать снова"),
                  ),
                ],
              ),
            ),
          ),
          
        // Кнопка для перемещения к текущей локации
        Positioned(
          bottom: 16,
          right: 16,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Если есть выделенный маркер, показываем кнопку для сброса выделения
              // Временно скрываем кнопку сброса выделения
              // if (_lastViewedPost != null)
              //   Container(
              //     margin: EdgeInsets.only(bottom: 8),
              //     child: FloatingActionButton(
              //       heroTag: "resetMarkerButton",
              //       mini: true,
              //       backgroundColor: Colors.blue,
              //       onPressed: _resetHighlightedPost,
              //       child: Icon(Icons.highlight_off, color: Colors.white),
              //     ),
              //   ),
              FloatingActionButton(
                heroTag: "locationButton",
                backgroundColor: Colors.white,
                onPressed: _moveToUserLocation,
                child: Icon(Icons.my_location, color: Colors.blue),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  /// Перемещает камеру к текущему местоположению пользователя
  void _moveToUserLocation() async {
    if (_currentPosition != null && _mapboxMap != null) {
      try {
        
        // Сохраняем текущее положение камеры перед перемещением
        await _updateCameraOptions();
        
        // Перемещаем камеру к местоположению пользователя
        await _mapboxMap!.flyTo(
          CameraOptions(
            center: Point(
              coordinates: Position(
                _currentPosition!.longitude,
                _currentPosition!.latitude
              )
            ),
            zoom: 14.0,
          ),
          MapAnimationOptions(duration: 1000)
        );
      } catch (e) {
        AppLogger.log("❌ Ошибка перемещения к местоположению пользователя: $e");
      }
    } else {
      
      // Показываем снэкбар с сообщением
            if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Не удалось определить ваше местоположение"),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  // Публичный метод для переключения между картой и лентой
  void setActiveView(String view) {
    if (view != _activeView) {
      
      // Если переключаемся с карты на ленту, сбрасываем выделение маркера
      if (_activeView == 'map' && view == 'feed') {
        _showingSpecificPost = false;
        _lastViewedPost = null;
        _highlightedPostId = null;
        _markerClickStage = 0;
      }
      
      // КРИТИЧНО: При переключении на карту сбрасываем блокирующие флаги
      if (view == 'map') {
        _showingSpecificPost = false;
        _isProcessingAnnotations = false;
      }
      
      setState(() {
        _activeView = view;
      });
      
      // После переключения вида обрабатываем отложенные действия
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Если перешли на карту, перезагружаем маркеры
        if (view == 'map' && _isMapLoaded) {
          _reloadMarkers();
        }
        
        // Если есть отложенные действия, обрабатываем их с небольшой задержкой
        // чтобы гарантировать, что UI обновился и готов
        if (_hasPendingAction) {
          Future.delayed(Duration(milliseconds: 100), () {
            _processPendingActions();
          });
        }
      });
    }
  }
  
  // Публичный метод для перемещения камеры к указанной локации
  Future<void> moveCameraToLocation(GeoLocation location) async {
    if (_mapboxMap != null && _isMapLoaded) {
      try {
        await _moveCamera(location);
      } catch (e) {
        AppLogger.log('Error moving camera: $e');
      }
    } else {
    }
  }
  
  // Публичный метод для добавления маркера в указанной локации
  Future<void> addMarkerAtLocation(GeoLocation location, String name) async {
    if (_mapboxMap != null && _isMapLoaded && _pointAnnotationManager != null) {
      try {
        
        // Загружаем изображение маркера
        final ByteData byteData = await rootBundle.load('assets/Images/map-marker.png');
        final Uint8List bytes = byteData.buffer.asUint8List();
        
        // Создаем опции для маркера
        final pointAnnotationOptions = PointAnnotationOptions(
          geometry: Point(
            coordinates: Position(
              location.longitude,
              location.latitude,
            ),
          ),
          image: bytes,
          iconSize: 0.5, // Уменьшаем размер маркера
          iconAnchor: IconAnchor.BOTTOM,
        );
        
        // Добавляем маркер на карту
        final annotation = await _pointAnnotationManager!.create(pointAnnotationOptions);
        
        // Создаем временный пост для маркера
        final post = Post(
          id: 'search_${DateTime.now().millisecondsSinceEpoch}',
          user: 'current_user',
          description: 'Search result',
          locationName: name,
          location: location,
          images: [],
          createdAt: DateTime.now(),
        );
        
        // Сохраняем маркер и связываем его с постом
        _markerPostMap[annotation.id] = post;
        
        // Анимируем маркер
        _animateMarker(annotation.id);
      } catch (e) {
        AppLogger.log('Error adding marker: $e');
      }
    } else {
    }
  }
  
  // Публичный метод для перехода к указанному посту в ленте
  void scrollToPost(Post post) {
    
    if (_activeView != 'feed') {
      setActiveView('feed');
    }
    
    setState(() {
      _selectedPost = post;
      _lastViewedPost = post;
      _lastViewedPostIndex = _posts.indexWhere((p) => p.id == post.id);
    });
    
    // Пробуем прокрутить через ScrollController
    _scrollToPostByIdWithController(post.id);

    // Сбрасываем выделение через некоторое время
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _lastViewedPostIndex = -1;
        });
      }
    });
  }
  
  // Анимируем маркер, чтобы привлечь внимание
  void _animateMarker(String markerId) {
    // Добавляем визуальный эффект для выделения маркера
    // Например, можно изменить его размер или цвет
  }

  @override
  void setState(VoidCallback fn) {
    if (mounted) {
      super.setState(fn);
      
      // Обрабатываем отложенные действия после обновления состояния
      if (_hasPendingAction) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _processPendingActions();
        });
      }
    }
  }

  // Метод для добавления слоя с текущей локацией пользователя
  void _addUserLocationLayer() {
    if (_mapboxMap == null || _currentPosition == null) return;
    
    try {
      
      // Тут можно было бы добавить пульсирующую точку или специальный маркер
      // для текущего местоположения пользователя, но для простоты просто
      // используем существующий метод перемещения камеры
      _moveCamera(_currentPosition!);
    } catch (e) {
      AppLogger.log('Ошибка при добавлении слоя местоположения пользователя: $e');
    }
  }

  // Добавляем новый метод для плавного перемещения камеры с анимацией
  Future<void> _flyToLocation(GeoLocation location) async {
    if (_mapboxMap == null) {
      AppLogger.log('❌ _flyToLocation: Карта не инициализирована');
      return;
    }
    
    if (!_isMapLoaded) {
      AppLogger.log('❌ _flyToLocation: Карта не загружена');
      return;
    }
    
    
    try {
      // Проверяем текущий стиль карты
      bool styleLoaded = await _mapboxMap!.style.isStyleLoaded();
      if (!styleLoaded) {
        // Ждем загрузки стиля
        await Future.delayed(Duration(milliseconds: 500));
      }
      
      // Получаем текущие настройки камеры
      CameraState? currentCameraState;
      try {
        currentCameraState = await _mapboxMap!.getCameraState();
      } catch (e) {
        AppLogger.log('⚠️ _flyToLocation: Ошибка получения текущих настроек камеры: $e');
      }
      
      // Используем сохраненный зум, текущий зум или значение по умолчанию
      double zoom = currentCameraState?.zoom ?? _lastCameraOptions?.zoom ?? 14.0;
      
      // Создаем опции камеры
      final cameraOptions = CameraOptions(
        center: Point(
          coordinates: Position(
            location.longitude,
            location.latitude
          )
        ),
        zoom: zoom,
        bearing: 0.0,
        pitch: 0.0
      );
      
      
      // Применяем анимированное перемещение камеры
      await _mapboxMap!.flyTo(
        cameraOptions,
        MapAnimationOptions(duration: 1500) // 1.5 секунды на анимацию
      );
      
      // Добавляем небольшую задержку для завершения анимации
      await Future.delayed(Duration(milliseconds: 100));
      
      // Сохраняем новые настройки камеры
      _lastCameraOptions = cameraOptions;
      
    } catch (e) {
      AppLogger.log('❌ _flyToLocation: Ошибка анимированного перемещения камеры: $e');
      
      // Если не удалось использовать анимацию, используем обычное перемещение
      try {
        await _moveCamera(location);
      } catch (e2) {
        AppLogger.log('❌ _flyToLocation: Ошибка обычного перемещения камеры: $e2');
      }
    }
  }

  // Публичный метод для проверки наличия отложенных действий
  bool hasPendingAction() {
    return _hasPendingAction;
  }
  
  // Публичный метод для обработки отложенных действий
  void processPendingActions() {
    _processPendingActions();
  }

  // Публичный метод для принудительной перезагрузки маркеров при переходе на вкладку
  void reloadMarkersOnTabSwitch() {
    
    // КРИТИЧНО: Сбрасываем блокирующие флаги
    _showingSpecificPost = false;
    _isProcessingAnnotations = false;
    
    // Проверяем, что карта готова и есть посты для отображения
    if (_mapboxMap != null && _isMapLoaded && _posts.isNotEmpty && _activeView == 'map') {
      // Небольшая задержка для завершения переключения вкладок
      Future.delayed(Duration(milliseconds: 400), () async {
        if (mounted && _mapboxMap != null && _isMapLoaded && _activeView == 'map') {
          try {
            // Не пересоздаем менеджер полностью, а просто очищаем существующие маркеры
            if (_pointAnnotationManager != null) {
              await _pointAnnotationManager!.deleteAll();
              _markerPostMap.clear();
            }
            
            // Сначала восстанавливаем изображения маркеров в стиле карты
            await MapboxConfig.reinstallCachedMarkerImages(_mapboxMap!);
            
            // Затем загружаем маркеры
            await _loadPostMarkers();
          } catch (e) {
            AppLogger.log('❌ Ошибка при перезагрузке маркеров: $e');
            // В случае ошибки пробуем полную перезагрузку
            _pointAnnotationManager = null;
            _markerPostMap.clear();
            await _loadPostMarkers();
          }
        }
      });
    } else {
    }
  }

  // Обработчик события отсутствующего изображения в стиле карты
  // Удаляем этот метод, так как API не поддерживает StyleImageMissingEvent
  
  // Загрузка стандартного изображения маркера
  Future<void> _loadDefaultMarkerImage(String imageId) async {
    try {
      
      // Проверяем, уже зарегистрирован ли стандартный маркер
      bool existsInStyle = false;
      try {
        existsInStyle = await _mapboxMap!.style.hasStyleImage(imageId);
      } catch (e) {
        AppLogger.log("⚠️ Error checking style image: $e");
      }
      
      if (!existsInStyle) {
        // Загружаем стандартные маркеры карты
        try {
          await MapboxConfig.registerMapboxMarkerImages(_mapboxMap!);
        } catch (e) {
          AppLogger.log("❌ Error registering default markers: $e");
        }
      } else {
      }
    } catch (e) {
      AppLogger.log("❌ Error in _loadDefaultMarkerImage: $e");
    }
  }

  // Принудительный сброс: удаляем текущие аннотации и менеджер, пересоздаем обычные маркеры
  Future<void> _forceResetMarkers() async {
    if (_mapboxMap == null) return;

    // Если идёт обработка аннотаций/выделения — пропускаем сброс
    if (_isProcessingAnnotations) {
      return;
    }

    try {

      // Сбрасываем флаги выделения и блокировки
      _showingSpecificPost = false;
      _lastViewedPost = null;
      _highlightedPostId = null;  // Сбрасываем выделенный маркер
      _markerClickStage = 0;       // Сбрасываем стадию клика
      _isProcessingAnnotations = false;

      // Удаляем все аннотации и менеджер, если он есть
      if (_pointAnnotationManager != null) {
        try {
          await _pointAnnotationManager!.deleteAll();
        } catch (e) {
          AppLogger.log("⚠️ Error deleting annotations in force reset: $e");
        }
        try {
          await _mapboxMap!.annotations.removeAnnotationManager(_pointAnnotationManager!);
        } catch (e) {
          AppLogger.log("⚠️ Error removing annotation manager in force reset: $e");
        }
        _pointAnnotationManager = null;
      }

      // Создаем новый менеджер
      final annotations = await _mapboxMap!.annotations;
      _pointAnnotationManager = await annotations.createPointAnnotationManager();
      _pointAnnotationManager!.addOnPointAnnotationClickListener(_markerClickListener);

      // Очищаем соответствия и добавляем обычные маркеры по текущим фильтрам
      _markerPostMap.clear();

      // Применяем те же фильтры, что и в _reloadMarkers
      List<Post> filteredPosts = List.from(_posts);
      if (_showOnlyFavorites) {
        final favoritePosts = await SocialService.getFavoritePosts();
        final favoriteIds = favoritePosts.map((post) => post.id).toSet();
        filteredPosts = filteredPosts.where((post) => favoriteIds.contains(post.id)).toList();
      } else if (_showOnlyFollowings) {
        final followingPosts = await SocialService.getFollowingNonAlbumPosts();
        final followingIds = followingPosts.map((post) => post.id).toSet();
        filteredPosts = filteredPosts.where((post) => followingIds.contains(post.id)).toList();
      }

      if (filteredPosts.isNotEmpty) {
        await _addPostMarkersToMap(filteredPosts);
      }

    } catch (e) {
      AppLogger.log("❌ Force reset markers error: $e");
    }
  }

  // Мягкий сброс выделения: уменьшаем выделенный маркер до обычного размера, не трогаем остальные
  Future<void> _clearHighlightKeepMarkers() async {
    if (_pointAnnotationManager == null) return;
    final String? highlightedId = _highlightedPostId;
    // Сбросить внутренние флаги выделения
    _highlightedPostId = null;
    _markerClickStage = 0;
    _showingSpecificPost = false;

    if (highlightedId == null) return;

    try {
      // Попробуем найти аннотацию выделенного поста и уменьшить её размер
      final ann = _postIdToAnnotation[highlightedId];
      if (ann != null) {
        ann.iconSize = 0.3; // обычный размер
        await _pointAnnotationManager!.update(ann);
      } else {
        // Если прямой ссылки нет, как fallback можно мягко перезагрузить только размеры через recreate
        // но НЕ удаляем маркеры полностью. Здесь лучше ничего не делать, чтобы не мигали маркеры
      }
    } catch (e) {
      AppLogger.log("⚠️ Error clearing highlight softly: $e");
    }
  }
} 
