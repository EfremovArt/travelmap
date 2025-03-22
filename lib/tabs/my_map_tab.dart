import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../config/mapbox_config.dart';

class MyMapTab extends StatefulWidget {
  const MyMapTab({Key? key}) : super(key: key);

  @override
  State<MyMapTab> createState() => _MyMapTabState();
}

class _MyMapTabState extends State<MyMapTab> {
  MapboxMap? _mapboxMap;
  bool _mapInitialized = false;
  geo.Position? _currentPosition;
  PointAnnotationManager? _pointAnnotationManager;
  
  @override
  void initState() {
    super.initState();
    _determinePosition();
  }
  
  @override
  void dispose() {
    super.dispose();
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
    
    setState(() {});
  }
  
  // Добавление маркера на карту
  void _addMarker(Point point) async {
    if (_mapboxMap == null || _pointAnnotationManager == null) return;
    
    // Создаем точечную аннотацию на карте
    final options = PointAnnotationOptions(
      geometry: point,
      textField: "Travel Point",
      textOffset: [0.0, 1.5],
      textColor: Colors.black.value,
      textSize: 12.0,
      iconSize: 1.5,
    );
    
    await _pointAnnotationManager!.create(options);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Карта Mapbox
        _currentPosition != null
            ? SizedBox(
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
                    // В новой версии, координаты нажатия нужно получить из context.point.coordinates
                    // context - это объект типа MapContentGestureContext
                    final pointCoordinates = context.point.coordinates;
                    
                    // Проверяем, что координаты не null и имеют нужные значения
                    if (pointCoordinates.isNotEmpty && pointCoordinates.length >= 2) {
                      // Создаем точку для добавления маркера
                      final longitude = pointCoordinates[0] ?? 0.0;
                      final latitude = pointCoordinates[1] ?? 0.0;
                      
                      final tapPoint = Point(
                        coordinates: Position(
                          longitude.toDouble(), // преобразуем в double
                          latitude.toDouble()   // преобразуем в double
                        )
                      );
                      
                      _addMarker(tapPoint);
                    }
                  },
                ),
              )
            : Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Loading map...',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
        
        // Фильтры сверху
        Positioned(
          top: 16,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_list,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Filter',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 24,
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Nearby',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 24,
                  width: 1,
                  color: Colors.grey.shade300,
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Saved',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Кнопка добавления точки на карте
        Positioned(
          bottom: 24,
          right: 24,
          child: FloatingActionButton(
            onPressed: () {
              // Показываем диалоговое окно для добавления новой точки
              _showAddLocationDialog();
            },
            backgroundColor: Colors.blue.shade700,
            child: const Icon(
              Icons.add_location_alt,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
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
} 