import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
// Обновленный импорт - удаляем ссылку на MainScreen, так как она не нужна прямо здесь
// Все переходы на MainScreen будут осуществляться через именованные маршруты

// Встроенная реализация GoogleAuthService прямо в файле loginscreen.dart
class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  // Аутентификация через Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Попытка входа через Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // Если пользователь отменил вход или произошла ошибка
      if (googleUser == null) {
        return {
          'success': false,
          'error': 'Авторизация отменена пользователем',
        };
      }

      // Получаем данные аутентификации
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Создаем уникальный ID для пользователя (можно заменить на UUID если доступно)
      final String userId = DateTime.now().millisecondsSinceEpoch.toString();

      // Возвращаем данные пользователя
      return {
        'success': true,
        'userData': {
          'userId': userId,
          'userName': googleUser.displayName ?? '',
          'email': googleUser.email,
          'photoUrl': googleUser.photoUrl,
          'accessType': 'google',
          'accessToken': googleAuth.accessToken,
          'idToken': googleAuth.idToken,
        },
      };
    } catch (e) {
      print('Ошибка при входе через Google: $e');
      return {
        'success': false,
        'error': 'Произошла ошибка при аутентификации Google: $e',
      };
    }
  }

  // Выход из аккаунта
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('Ошибка при выходе из аккаунта Google: $e');
      throw Exception('Не удалось выйти из аккаунта Google: $e');
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  VideoPlayerController? _controller;
  bool _isVideoInitialized = false;
  bool _isVideoError = false;
  bool _isLoading = false;
  bool _isEmulator = false;
  String _errorMessage = '';
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  @override
  void initState() {
    super.initState();
    _checkEmulator().then((_) {
      _initializeVideo();
    });
    _checkLoggedInUser();
  }

  // Проверка, запущено ли приложение в эмуляторе
  Future<void> _checkEmulator() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Большинство эмуляторов содержат "emulator" или "sdk" в имени модели или продукта
        _isEmulator = androidInfo.model.toLowerCase().contains('sdk') ||
            androidInfo.model.toLowerCase().contains('emulator') ||
            androidInfo.product.toLowerCase().contains('sdk') ||
            androidInfo.product.toLowerCase().contains('emulator') ||
            (androidInfo.fingerprint.toLowerCase().contains('generic') &&
                androidInfo.fingerprint.toLowerCase().contains('android'));

        print('Запущено в эмуляторе: $_isEmulator');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // Для iOS симулятора
        _isEmulator = !iosInfo.isPhysicalDevice;
        print('Запущено в симуляторе: $_isEmulator');
      }
    } catch (e) {
      print('Ошибка при определении эмулятора: $e');
      _isEmulator = false;
    }
  }

  Future<void> _initializeVideo() async {
    // Если мы в эмуляторе, не инициализируем видео вообще
    if (_isEmulator) {
      setState(() {
        _isVideoError = true; // Это заставит использовать градиентный фон
      });
      return;
    }

    try {
      _controller = VideoPlayerController.asset('assets/video/background.mp4');
      await _controller!.initialize();
      await _controller!.setLooping(true);
      await _controller!.setVolume(0.0);
      await _controller!.play();

      if (mounted) {
        setState(() {
          _isVideoInitialized = true;
        });
      }
    } catch (e) {
      print('Ошибка при инициализации видео: $e');
      if (mounted) {
        setState(() {
          _isVideoError = true;
        });
      }
    }
  }

  // Проверка авторизованного пользователя
  Future<void> _checkLoggedInUser() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('user_id');

      if (userId != null) {
        // Если есть сохраненный ID пользователя, переходим на главный экран с вкладками
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/main'); // Переходим на MainScreen
        }
      }
    } catch (e) {
      print('Ошибка при проверке авторизации: $e');
    }
  }

  // Авторизация через Google
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final result = await _googleAuthService.signInWithGoogle();

      if (!mounted) return;

      if (result['success']) {
        final userData = result['userData'];

        // Сохраняем данные пользователя
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user_id', userData['userId']);
        await prefs.setString('user_name', userData['userName']);
        await prefs.setString('user_email', userData['email']);
        await prefs.setString('access_type', userData['accessType']);

        // Дополнительно сохраняем имя и email для профиля
        final nameParts = userData['userName'].split(' ');
        if (nameParts.isNotEmpty) {
          await prefs.setString('firstName', nameParts[0]);
        }
        if (nameParts.length > 1) {
          await prefs.setString('lastName', nameParts.sublist(1).join(' '));
        }
        await prefs.setString('email', userData['email']);
        await prefs.setString('photoUrl', userData['photoUrl'] ?? '');

        // Переходим на главный экран используя именованный маршрут
        if (mounted) {
          Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
        }
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Ошибка при входе через Google';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Произошла ошибка: $e';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Фон: видео или градиент
          if (_isVideoInitialized && !_isVideoError && !_isEmulator && _controller != null)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller!.value.size.width,
                  height: _controller!.value.size.height,
                  child: VideoPlayer(_controller!),
                ),
              ),
            )
          else
          // Градиентный фон для эмулятора или при ошибке видео
            Container(
              width: double.infinity,
              height: double.infinity,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.blue.shade900,
                    Colors.blue.shade700,
                    Colors.blue.shade800,
                  ],
                ),
              ),
            ),

          // Размытый эффект и затемнение (только если не эмулятор)
          if (!_isEmulator)
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            )
          else
          // Простое затемнение для эмулятора
            Container(
              color: Colors.black.withOpacity(0.3),
            ),

          // Контент
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Логотип и название
                  Padding(
                    padding: const EdgeInsets.only(top: 100),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Стилизованный логотип
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.5),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.explore_outlined,
                              size: 60,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 30),
                        ShaderMask(
                          shaderCallback: (Rect bounds) {
                            return LinearGradient(
                              colors: [Colors.blue.shade300, Colors.white],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ).createShader(bounds);
                          },
                          child: Text(
                            'TRAVEL MAP',
                            style: GoogleFonts.montserrat(
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Исследуйте мир с нами',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Кнопка входа и сообщение об ошибке
                  Padding(
                    padding: const EdgeInsets.only(bottom: 80),
                    child: Column(
                      children: [
                        // Показываем индикатор загрузки или кнопку входа
                        if (_isLoading)
                          const SpinKitDoubleBounce(
                            color: Colors.white,
                            size: 50.0,
                          )
                        else
                        // Исправленная кнопка входа через Google без проблем с пикселями
                          ElevatedButton(
                            onPressed: _handleGoogleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black,
                              elevation: 3,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Image.asset(
                                  'assets/Images/google_logo.png',
                                  width: 24,
                                  height: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'Войти с аккаунтом Google',
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        const SizedBox(height: 24),

                        // Показываем сообщение об ошибке, если есть
                        if (_errorMessage.isNotEmpty)
                          Container(
                            width: MediaQuery.of(context).size.width * 0.8,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.red.shade800.withOpacity(0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _errorMessage,
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),

                        const SizedBox(height: 24),

                        Text(
                          'Требуется аккаунт Google для\nиспользования приложения',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
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