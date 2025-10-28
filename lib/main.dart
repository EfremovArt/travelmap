import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/auth_service.dart';
import 'loginscreen.dart';
import 'home_screen.dart';
import 'screens/main_screen.dart';
import 'config/mapbox_config.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'screens/profile_screen.dart';
import 'screens/edit/edit_post_screen.dart';
import 'screens/splash_screen.dart';
import 'models/post.dart';
import 'utils/logger.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox_flutter;

// Create a global instance of AuthService
final authService = AuthService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logger with logs disabled for production
  AppLogger.init(enableLogs: true);
  
  // Initialize the authorization service to load session cookies
  await authService.initialize();
  
  // Setting screen orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white, // Белый цвет
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Initialize Mapbox with access token
  try {
    final String mapboxAccessToken = MapboxConfig.ACCESS_TOKEN;
    AppLogger.log('Initializing Mapbox with token: ${mapboxAccessToken.substring(0, 10)}...');

    // Set access token for Mapbox SDK
    MapboxOptions.setAccessToken(mapboxAccessToken);
    
    // Важно для Android: инициализация нативного вью до создания плагинов
    if (Platform.isAndroid) {
      // Явная инициализация Mapbox на Android
      try {
        // Специальной инициализации для Android не требуется
        // Достаточно только установить токен доступа выше

      } catch (e) {
        AppLogger.log('⚠️ Error initializing Mapbox for Android: $e');
      }
    }
    
    AppLogger.log('Mapbox token set successfully');
  } catch (e) {
    AppLogger.log('Error setting Mapbox token: $e');
    // Try with alternative token if first one fails
    try {
      AppLogger.log('Trying alternative token...');
      MapboxOptions.setAccessToken(MapboxConfig.ALTERNATIVE_ACCESS_TOKEN);
    } catch (e) {
      AppLogger.log('Alternative token also failed: $e');
    }
  }

  // Check if user is authorized
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool isLoggedIn = prefs.getString('user_email') != null;
  
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkLoginStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Удаляем наблюдатель
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Processing application lifecycle events
    if (state == AppLifecycleState.detached) {
      // Application is fully closed
      _clearSharedPreferences();
    }
  }

  // Method to clear SharedPreferences when closing
  Future<void> _clearSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      AppLogger.log('SharedPreferences cleared when closing the application');
    } catch (e) {
      AppLogger.log('Error clearing SharedPreferences: $e');
    }
  }

  Future<void> _checkLoginStatus() async {
    try {
      // Show splash screen for at least 2 seconds
      final splashDuration = Future.delayed(const Duration(seconds: 2));
      
      // Check authorization via API
      final result = await authService.checkAuth();
      
      // Wait for minimum splash duration
      await splashDuration;
      
      setState(() {
        _isLoggedIn = result['isAuthenticated'] == true;
        _isLoading = false;
      });
    } catch (e) {
      AppLogger.log('Error checking authorization: $e');
      // Wait for minimum splash duration even on error
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Travel Map',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
        cardColor: Colors.white,
        fontFamily: 'Gilroy',
        // Add settings for AppBar and other elements
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.blue.shade700,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue.shade700,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
      // Define the initial screen and ensure the navigator has at least one route
      initialRoute: '/',
      routes: {
        '/': (context) => _isLoading
            ? const SplashScreen()
            : _isLoggedIn
            ? MainScreen() // MainScreen будет использовать глобальный ключ из main_screen.dart
            : const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/main': (context) => MainScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/login': (context) => const LoginScreen(),
        '/edit_post': (context) => EditPostScreen(
              post: ModalRoute.of(context)!.settings.arguments as Post,
            ),
      },
    );
  }
}