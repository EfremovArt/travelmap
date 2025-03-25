import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'loginscreen.dart'; // Импортируем файл входа
import 'home_screen.dart';
// Используем корректный путь импорта для MainScreen
// Судя по структуре вашего проекта, main_screen.dart находится в корне
// Если он находится в папке, укажите правильный путь
import 'screens/main_screen.dart';
import 'config/mapbox_config.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

// Используем класс ProfileScreen из вашего файла profile_screen.dart
import 'screens/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Устанавливаем ориентацию и настройки статус-бара
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Инициализируем Mapbox с токеном доступа
  try {
    final String mapboxAccessToken = MapboxConfig.ACCESS_TOKEN;
    print('Инициализация Mapbox с токеном: ${mapboxAccessToken.substring(0, 10)}...');

    MapboxOptions.setAccessToken(mapboxAccessToken);
    print('Mapbox токен установлен успешно');
  } catch (e) {
    print('Ошибка при установке токена Mapbox: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  bool _isLoggedIn = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this); // Добавляем наблюдатель
    _checkLoginStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Удаляем наблюдатель
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Обработка событий жизненного цикла приложения
    if (state == AppLifecycleState.detached) {
      // Приложение полностью закрывается
      _clearSharedPreferences();
    }
  }

  // Метод для очистки SharedPreferences при закрытии
  Future<void> _clearSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      print('SharedPreferences очищены при закрытии приложения');
    } catch (e) {
      print('Ошибка при очистке SharedPreferences: $e');
    }
  }

  Future<void> _checkLoginStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      setState(() {
        _isLoggedIn = userId != null;
        _isLoading = false;
      });
    } catch (e) {
      print('Ошибка при проверке статуса входа: $e');
      setState(() {
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
        // Добавляем настройки для AppBar и других элементов
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
      // Определяем начальный экран и гарантируем, что у навигатора будет хотя бы один маршрут
      initialRoute: '/',
      routes: {
        '/': (context) => _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _isLoggedIn
            ? const MainScreen() // Используем MainScreen вместо HomeScreen
            : const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/main': (context) => const MainScreen(),
        '/profile': (context) => const ProfileScreen(),
        '/login': (context) => const LoginScreen(),
      },
    );
  }
}