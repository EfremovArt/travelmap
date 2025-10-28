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
  final Function(CommercialPost)? onPostTap;

  const CommercialPostMapScreen({
    Key? key,
    required this.post,
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

  @override
  void initState() {
    super.initState();
    AppLogger.log('🗺️ CommercialPostMapScreen initialized for post ${widget.post.id}');
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
      
      // Добавляем маркер для коммерческого поста
      _addCommercialPostMarker();
      
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

  /// Добавляет маркер для коммерческого поста
  Future<void> _addCommercialPostMarker() async {
    if (!widget.post.hasLocation || _pointAnnotationManager == null) {
      AppLogger.log("❌ Cannot add marker: no location data or annotation manager");
      return;
    }

    try {
      // Создаем точку для маркера
      final point = Point(
        coordinates: Position(
          widget.post.longitude!,
          widget.post.latitude!,
        ),
      );

      // Настройки маркера
      String markerImageId = "custom-marker"; // Используем стандартный маркер по умолчанию
      double iconSize = 0.4; // Стандартный размер
      bool hasCustomImage = false;
      
      // Если у коммерческого поста есть изображения, используем одно из них для маркера
      final imageUrl = _getPostImageUrl();
      if (imageUrl.isNotEmpty) {
        try {
          AppLogger.log("🔄 Loading image for commercial post marker from: $imageUrl");
          
          // Загружаем изображение из URL
          final response = await http.get(Uri.parse(imageUrl));
          
          if (response.statusCode == 200) {
            // Регистрируем изображение как круглый маркер
            final String customMarkerId = await MapboxConfig.registerPostImageAsMarker(
              _mapboxMap!,
              response.bodyBytes,
              "commercial-${widget.post.id}",
            );
            
            // Проверяем, что изображение успешно зарегистрировано
            final bool imageRegistered = await _mapboxMap!.style.hasStyleImage(customMarkerId);
            if (imageRegistered) {
              markerImageId = customMarkerId;
              iconSize = 0.5; // Увеличиваем размер для кастомного изображения
              hasCustomImage = true;
              AppLogger.log("✅ Custom marker image registered: $customMarkerId");
            } else {
              AppLogger.log("⚠️ Failed to register custom marker image, using default");
            }
          } else {
            AppLogger.log("⚠️ Failed to load image (${response.statusCode}), using default marker");
          }
        } catch (e) {
          AppLogger.log("⚠️ Error processing image for marker: $e, using default marker");
        }
      }

      // Создаем опции для аннотации
      final pointAnnotationOptions = PointAnnotationOptions(
        geometry: point,
        iconImage: markerImageId,
        iconSize: iconSize,
        iconAnchor: IconAnchor.BOTTOM,
        textField: widget.post.locationName ?? 'Commercial Post',
        textSize: 12.0,
        textOffset: [0.0, 2.0],
        textColor: Colors.black.value,
        textHaloColor: Colors.white.value,
        textHaloWidth: 2.0,
        iconOffset: [0.0, 0.0],
        iconOpacity: 1.0,
      );

      // Добавляем маркер
      await _pointAnnotationManager!.create(pointAnnotationOptions);
      AppLogger.log("✅ Commercial post marker added at ${widget.post.latitude}, ${widget.post.longitude}");
      AppLogger.log("🔹 Marker details: imageId=$markerImageId, size=$iconSize, hasCustomImage=$hasCustomImage");

      // Перемещаем камеру к маркеру
      await _moveCameraToPost();

    } catch (e) {
      AppLogger.log("❌ Error adding commercial post marker: $e");
    }
  }

  /// Получает URL изображения для поста
  String _getPostImageUrl() {
    if (widget.post.hasImages && widget.post.imageUrls.isNotEmpty) {
      return ApiConfig.formatImageUrl(widget.post.imageUrls.first);
    } else if (widget.post.imageUrl != null && widget.post.imageUrl!.isNotEmpty) {
      return ApiConfig.formatImageUrl(widget.post.imageUrl!);
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
        zoom: 15.0,
      );

      await _mapboxMap!.setCamera(cameraOptions);
      AppLogger.log("📱 Camera moved to commercial post location");
    } catch (e) {
      AppLogger.log("❌ Error moving camera: $e");
    }
  }

  /// Обработчик клика по маркеру
  bool _onMarkerClick(PointAnnotation annotation) {
    AppLogger.log("📍 Commercial post marker clicked with ID: ${annotation.id}");
    
    // Сразу возвращаемся к посту
    Navigator.pop(context); // Закрываем экран карты
    if (widget.onPostTap != null) {
      widget.onPostTap!(widget.post);
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
              zoom: 15.0,
            ),
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
