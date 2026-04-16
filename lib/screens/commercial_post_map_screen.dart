import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../models/commercial_post.dart';
import '../models/location.dart';
import '../config/mapbox_config.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';
import '../utils/map_helper.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:http/http.dart' as http;

class CommercialPostMapScreen extends StatefulWidget {
  final CommercialPost post;
  final List<CommercialPost> allPosts; // Все коммерческие посты пользователя
  final Function(CommercialPost)? onPostTap;

  const CommercialPostMapScreen({
    Key? key,
    required this.post,
    required this.allPosts,
    this.onPostTap,
  }) : super(key: key);

  @override
  State<CommercialPostMapScreen> createState() => _CommercialPostMapScreenState();
}

class _CommercialPostMapScreenState extends State<CommercialPostMapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  bool _isLoading = true;
  String? _error;
  String? _currentSelectedPostId; // ID текущего выбранного поста
  Map<String, String> _annotationIdToPostId = {}; // Маппинг ID аннотации на ID поста
  Map<String, PointAnnotation> _postIdToAnnotation = {}; // Маппинг ID поста на аннотацию
  Map<String, String> _postIdToMarkerImageId = {}; // Маппинг ID поста на ID изображения маркера

  @override
  void initState() {
    super.initState();
    _currentSelectedPostId = widget.post.id.toString();
    AppLogger.log('🗺️ CommercialPostMapScreen initialized for post ${widget.post.id} with ${widget.allPosts.length} total posts');
  }

  @override
  void dispose() {
    AppLogger.log('🗺️ CommercialPostMapScreen disposed');
    super.dispose();
  }

  /// Обработчик события создания карты
  Future<void> _onMapCreated(MapboxMap mapboxMap) async {
    AppLogger.log("🗺️ Commercial post map created successfully");
    
    if (!mounted) {
      AppLogger.log("⚠️ Widget not mounted, stopping map initialization");
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
    
    try {
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Устанавливаем стиль карты
      await mapboxMap.style.setStyleURI(MapboxConfig.STREETS_STYLE_URI);
      AppLogger.log("🎨 Map style set: ${MapboxConfig.STREETS_STYLE_URI}");
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Регистрируем изображения маркеров
      try {
        await MapboxConfig.registerMapboxMarkerImages(mapboxMap);
        AppLogger.log("🔹 Marker images registered");
      } catch (e) {
        AppLogger.log("⚠️ Error registering marker images: $e");
      }
      
      // Создаем менеджер аннотаций
      try {
        AppLogger.log("📍 Creating annotation manager");
        _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();
        AppLogger.log("✅ Annotation manager created");
        
        // Добавляем обработчик кликов по маркерам
        _pointAnnotationManager?.addOnPointAnnotationClickListener(
          MyPointAnnotationClickListener(_onMarkerClick)
        );
      } catch (e) {
        AppLogger.log("⚠️ Error creating annotation manager: $e");
      }
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = null;
        });
      }
      
      // Добавляем маркеры для всех коммерческих постов
      _addAllCommercialPostMarkers();
      
    } catch (e) {
      AppLogger.log("❌ Error initializing commercial post map: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = e.toString();
        });
      }
    }
  }

  /// Добавляет маркеры для всех коммерческих постов
  Future<void> _addAllCommercialPostMarkers() async {
    if (_pointAnnotationManager == null) {
      AppLogger.log("❌ Cannot add markers: annotation manager is null");
      return;
    }

    try {
      _annotationIdToPostId.clear();
      _postIdToAnnotation.clear();
      _postIdToMarkerImageId.clear();
      
      // Проходим по всем постам и добавляем маркеры
      for (final post in widget.allPosts) {
        if (!post.hasLocation) continue;
        
        final postId = post.id.toString();
        final isSelected = postId == _currentSelectedPostId;
        
        // Создаем точку для маркера
        final point = Point(
          coordinates: Position(
            post.longitude!,
            post.latitude!,
          ),
        );

        // Настройки маркера
        String markerImageId = "custom-marker"; // Используем стандартный маркер по умолчанию
        double iconSize = isSelected ? 0.5 : 0.25; // Выделенный маркер больше
        
        // Если у коммерческого поста есть изображения, используем одно из них для маркера
        final imageUrl = _getPostImageUrl(post);
        if (imageUrl.isNotEmpty) {
          try {
            // Загружаем изображение из URL
            final response = await http.get(Uri.parse(imageUrl));
            
            if (response.statusCode == 200) {
              // Регистрируем изображение как круглый маркер
              final String customMarkerId = await MapboxConfig.registerPostImageAsMarker(
                _mapboxMap!,
                response.bodyBytes,
                "commercial-$postId",
              );
              
              // Проверяем, что изображение успешно зарегистрировано
              final bool imageRegistered = await _mapboxMap!.style.hasStyleImage(customMarkerId);
              if (imageRegistered) {
                markerImageId = customMarkerId;
                AppLogger.log("✅ Custom marker image registered: $customMarkerId");
              }
            }
          } catch (e) {
            AppLogger.log("⚠️ Error processing image for marker: $e, using default marker");
          }
        }

        // Сохраняем информацию о маркере для этого поста
        _postIdToMarkerImageId[postId] = markerImageId;
        
        // Создаем опции для аннотации
        final pointAnnotationOptions = PointAnnotationOptions(
          geometry: point,
          iconImage: markerImageId,
          iconSize: iconSize,
          iconAnchor: IconAnchor.BOTTOM,
        );

        // Добавляем маркер
        final annotation = await _pointAnnotationManager!.create(pointAnnotationOptions);
        _annotationIdToPostId[annotation.id] = postId;
        _postIdToAnnotation[postId] = annotation; // Сохраняем ссылку на аннотацию
        
        AppLogger.log("✅ Commercial post marker added: postId=$postId, isSelected=$isSelected, imageId=$markerImageId");
      }

      // Перемещаем камеру к выбранному посту
      await _moveCameraToPost();

    } catch (e) {
      AppLogger.log("❌ Error adding commercial post markers: $e");
    }
  }
  
  /// Добавляет маркеры (используется при первой загрузке и при перерисовке)
  Future<void> _addMarkersOnly() async {
    if (_pointAnnotationManager == null) return;
    
    try {
      // Создаем маркеры с правильными размерами
      for (final post in widget.allPosts) {
        if (!post.hasLocation) continue;
        
        final postId = post.id.toString();
        final isSelected = postId == _currentSelectedPostId;
        
        // Создаем точку для маркера
        final point = Point(
          coordinates: Position(
            post.longitude!,
            post.latitude!,
          ),
        );

        // Используем сохраненный imageId для этого поста
        final markerImageId = _postIdToMarkerImageId[postId] ?? "custom-marker";
        final iconSize = isSelected ? 0.5 : 0.25;

        // Создаем опции для аннотации
        final pointAnnotationOptions = PointAnnotationOptions(
          geometry: point,
          iconImage: markerImageId,
          iconSize: iconSize,
          iconAnchor: IconAnchor.BOTTOM,
        );

        // Добавляем маркер
        final annotation = await _pointAnnotationManager!.create(pointAnnotationOptions);
        _annotationIdToPostId[annotation.id] = postId;
        _postIdToAnnotation[postId] = annotation;
      }
      
      AppLogger.log("✅ Added ${_postIdToAnnotation.length} markers");
    } catch (e) {
      AppLogger.log("❌ Error adding markers: $e");
    }
  }
  
  /// Перерисовывает маркеры (удаляет и создает заново)
  Future<void> _redrawMarkers() async {
    if (_pointAnnotationManager == null) return;
    
    try {
      AppLogger.log("🔄 Redrawing markers...");
      
      // Удаляем все существующие маркеры
      await _pointAnnotationManager!.deleteAll();
      _annotationIdToPostId.clear();
      _postIdToAnnotation.clear();
      
      // Небольшая задержка для обновления карты
      await Future.delayed(Duration(milliseconds: 50));
      
      // Создаем маркеры заново
      await _addMarkersOnly();
      
    } catch (e) {
      AppLogger.log("❌ Error redrawing markers: $e");
    }
  }

  /// Получает URL изображения для поста
  String _getPostImageUrl(CommercialPost post) {
    if (post.hasImages && post.imageUrls.isNotEmpty) {
      return ApiConfig.formatImageUrl(post.imageUrls.first);
    } else if (post.imageUrl != null && post.imageUrl!.isNotEmpty) {
      return ApiConfig.formatImageUrl(post.imageUrl!);
    }
    return ''; // Пустая строка если нет изображений
  }

  /// Перемещает камеру к коммерческому посту
  Future<void> _moveCameraToPost() async {
    if (_mapboxMap == null || !widget.post.hasLocation) return;

    try {
      final cameraOptions = CameraOptions(
        center: Point(
          coordinates: Position(
            widget.post.longitude!,
            widget.post.latitude!,
          ),
        ),
        zoom: 1.5, // Используем зум 1.5 как в альбомах
      );

      await _mapboxMap!.setCamera(cameraOptions);
      AppLogger.log("📱 Camera moved to commercial post location with zoom 1.5");
    } catch (e) {
      AppLogger.log("❌ Error moving camera: $e");
    }
  }

  /// Обработчик клика по маркеру
  bool _onMarkerClick(PointAnnotation annotation) {
    final postId = _annotationIdToPostId[annotation.id];
    if (postId == null) {
      AppLogger.log("⚠️ Post ID not found for annotation: ${annotation.id}");
      return false;
    }
    
    AppLogger.log("📍 Commercial post marker clicked: postId=$postId, current=$_currentSelectedPostId");
    
    // Если кликнули на уже выбранный маркер - возвращаемся к посту
    if (_currentSelectedPostId == postId) {
      AppLogger.log("✅ Returning to commercial post $postId");
      Navigator.pop(context); // Закрываем экран карты
      if (widget.onPostTap != null) {
        final post = widget.allPosts.firstWhere((p) => p.id.toString() == postId);
        widget.onPostTap!(post);
      }
    } else {
      // Иначе выделяем этот маркер
      AppLogger.log("🎯 Selecting commercial post $postId");
      setState(() {
        _currentSelectedPostId = postId;
      });
      _redrawMarkers();
    }
    
    return true; // Возвращаем true чтобы указать, что событие было обработано
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.post.title),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business, size: 16, color: Colors.orange.shade600),
                SizedBox(width: 4),
                Text(
                  'Commercial',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.orange.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Карта
          MapWidget(
            key: ValueKey('commercial_post_map_${widget.post.id}'),
            styleUri: MapboxConfig.STREETS_STYLE_URI,
            onMapCreated: _onMapCreated,
            cameraOptions: CameraOptions(
              center: Point(
                coordinates: Position(
                  widget.post.longitude ?? MapboxConfig.DEFAULT_LONGITUDE,
                  widget.post.latitude ?? MapboxConfig.DEFAULT_LATITUDE,
                ),
              ),
              zoom: 1.5,
            ),
            onTapListener: (coordinate) {
              // При нажатии на пустое место карты убираем выделение со всех маркеров
              if (_currentSelectedPostId != null) {
                AppLogger.log("🗺️ Map tapped, removing marker selection");
                setState(() {
                  _currentSelectedPostId = null;
                });
                _redrawMarkers();
              }
            },
          ),
          
          // Индикатор загрузки
          if (_isLoading)
            Container(
              color: Colors.white.withOpacity(0.7),
              child: Center(
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
            
          // Сообщение об ошибке
          if (_error != null)
            Container(
              color: Colors.white,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red),
                    SizedBox(height: 16),
                    Text(
                      'Error loading map',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _error!,
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('Go Back'),
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
