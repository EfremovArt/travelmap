import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'services/auth_service.dart';
import '../utils/logger.dart';

// Built-in implementation of GoogleAuthService directly in the loginscreen.dart file
class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: [
      'email',
      'profile',
    ],
  );

  // Authentication via Google
  Future<Map<String, dynamic>> signInWithGoogle() async {
    try {
      // Attempt to sign in via Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      // If user canceled the sign-in or an error occurred
      if (googleUser == null) {
        return {
          'success': false,
          'error': 'Authentication canceled by user',
        };
      }

      // Get authentication data
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Create a unique ID for the user (can be replaced with UUID if available)
      final String userId = DateTime.now().millisecondsSinceEpoch.toString();

      // Return user data
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
      AppLogger.log('Error signing in with Google: $e');
      return {
        'success': false,
        'error': 'An error occurred during Google authentication: $e',
      };
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      AppLogger.log('Error signing out of Google account: $e');
      throw Exception('Failed to sign out of Google account: $e');
    }
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;
  bool _isEmulator = false;
  String _errorMessage = '';
  final GoogleAuthService _googleAuthService = GoogleAuthService();

  @override
  void initState() {
    super.initState();
    _checkEmulator();
    _checkLoggedInUser();
  }

  // Check if the application is running in an emulator
  Future<void> _checkEmulator() async {
    final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        // Most emulators contain "emulator" or "sdk" in their model or product name
        _isEmulator = androidInfo.model.toLowerCase().contains('sdk') ||
            androidInfo.model.toLowerCase().contains('emulator') ||
            androidInfo.product.toLowerCase().contains('sdk') ||
            androidInfo.product.toLowerCase().contains('emulator') ||
            (androidInfo.fingerprint.toLowerCase().contains('generic') &&
                androidInfo.fingerprint.toLowerCase().contains('android'));

        AppLogger.log('Running in emulator: $_isEmulator');
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        // For iOS simulator
        _isEmulator = !iosInfo.isPhysicalDevice;
        AppLogger.log('Running in simulator: $_isEmulator');
      }
    } catch (e) {
      AppLogger.log('Error determining emulator: $e');
      _isEmulator = false;
    }
  }

  // Check logged-in user
  Future<void> _checkLoggedInUser() async {
    try {
      final authService = AuthService();
      final result = await authService.checkAuth();
      
      if (result['isAuthenticated'] == true) {
        // If user is authenticated on the server, go to main screen
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/main');
        }
      }
    } catch (e) {
      AppLogger.log('Error checking authentication: $e');
    }
  }

  // Authentication via Google
  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = AuthService();
      AppLogger.log('Starting Google authentication process from LoginScreen');
      final result = await authService.signInWithGoogle();

      AppLogger.log('Google authentication result: $result');

      if (!mounted) return;

      if (result['success'] == true) {
        AppLogger.log('Successful Google authentication');
        // Go to main screen
        Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
      } else {
        String errorMsg = result['message'] ?? 'Error signing in with Google';
        AppLogger.log('Error during authentication: $errorMsg');
        
        // Show more detailed error
        setState(() {
          _errorMessage = errorMsg;
          _isLoading = false;
        });
        
        // Show error dialog for better UX
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Authentication Error'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMsg),
                SizedBox(height: 10),
                Text(
                  'Check internet connection and try again.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        AppLogger.log('Exception during authentication: $e');
        setState(() {
          _errorMessage = 'An unexpected error occurred: $e';
          _isLoading = false;
        });
        
        // Show error dialog
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text('Application Error'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('An unexpected error occurred:'),
                SizedBox(height: 8),
                Text(
                  e.toString(),
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                Text(
                  'Restart the application and try again.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('OK'),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    // _controller?.dispose(); // Удалено, т.к. больше не используем видео
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Получаем размер экрана
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    
    // Базовый размер из дизайна
    const baseWidth = 428.0;
    const baseHeight = 926.0;
    
    // Коэффициенты масштабирования
    final scaleX = screenWidth / baseWidth;
    final scaleY = screenHeight / baseHeight;
    final scale = scaleX < scaleY ? scaleX : scaleY;
    
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Круглые изображения на фоне
          _buildBackgroundCircle(
            left: 36 * scaleX,
            top: 113 * scaleY,
            size: 103 * scale,
            assetPath: 'assets/Images/1.png',
          ),
          _buildBackgroundCircle(
            left: 276 * scaleX,
            top: 97 * scaleY,
            size: 76 * scale,
            assetPath: 'assets/Images/2.png',
          ),
          _buildBackgroundCircle(
            left: 359 * scaleX,
            top: 207 * scaleY,
            size: 122 * scale,
            assetPath: 'assets/Images/3.png',
          ),
          _buildBackgroundCircle(
            left: 322 * scaleX,
            top: 552 * scaleY,
            size: 169 * scale,
            assetPath: 'assets/Images/4.png',
          ),
          _buildBackgroundCircle(
            left: 27 * scaleX,
            top: 627 * scaleY,
            size: 72 * scale,
            assetPath: 'assets/Images/5.png',
          ),
          
          // Кольцо 6.png (бублик) - просто картинка БЕЗ масштабирования
          Positioned(
            left: (screenWidth - 250) / 2,
            top: 320,
            child: Image.asset(
              'assets/Images/6.png',
            ),
          ),
          
          // Белый прямоугольник (Rectangle 8)
          Positioned(
            left: 70 * scaleX,
            top: 417 * scaleY,
            child: Container(
              width: 307 * scaleX,
              height: 56 * scaleY,
              color: Colors.white,
            ),
          ),
          
          // Картинка 7.png - по ширине круга (250px)
          Positioned(
            left: (screenWidth - 250) / 2,
            top: 417 * scaleY,
            child: Image.asset(
              'assets/Images/7.png',
              width: 250,
              height: 56 * scaleY,
            ),
          ),

          // Кнопки авторизации
          Positioned(
            left: 22 * scaleX,
            top: 774 * scaleY,
            child: _buildLoginButton(
              width: 385 * scaleX,
              height: 60 * scaleY,
              scale: scale,
              text: 'Log in via Apple',
              onPressed: () {
                // TODO: Implement Apple Sign In
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Apple Sign In coming soon')),
                );
              },
              isApple: true,
            ),
          ),
          
          Positioned(
            left: 22 * scaleX,
            top: 842 * scaleY,
            child: _buildLoginButton(
              width: 385 * scaleX,
              height: 60 * scaleY,
              scale: scale,
              text: 'Log in via Google',
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              isApple: false,
            ),
          ),
          
          // Индикатор загрузки
                          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: SpinKitDoubleBounce(
                              color: Colors.white,
                              size: 50.0,
                                ),
                              ),
                            ),

          // Сообщение об ошибке
          if (_errorMessage.isNotEmpty && !_isLoading)
            Positioned(
              left: 22 * scaleX,
              right: 22 * scaleX,
              bottom: 100 * scaleY,
              child: Container(
                padding: EdgeInsets.all(16 * scale),
                              decoration: BoxDecoration(
                  color: Colors.red.shade800.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(10 * scale),
                                border: Border.all(
                                  color: Colors.red.shade300,
                                  width: 1,
                                ),
                                  ),
                child: Row(
                  children: [
                    Expanded(
                              child: Text(
                                _errorMessage,
                        style: TextStyle(
                                  color: Colors.white,
                          fontSize: 14 * scale,
                          fontFamily: 'Gilroy',
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                    IconButton(
                      icon: Icon(Icons.close, color: Colors.white, size: 20 * scale),
                      onPressed: () {
                        setState(() {
                          _errorMessage = '';
                        });
                      },
                    ),
                  ],
                              ),
                            ),
                          ),
                        ],
                      ),
    );
  }
  
  Widget _buildBackgroundCircle({
    required double left,
    required double top,
    required double size,
    required String assetPath,
  }) {
    return Positioned(
      left: left,
      top: top,
      child: ClipOval(
        child: Image.asset(
          assetPath,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            AppLogger.log('❌ Error loading asset: $assetPath, error: $error');
            return Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[300],
              ),
              child: Icon(
                Icons.image_not_supported,
                size: size * 0.3,
                color: Colors.grey[600],
              ),
            );
          },
        ),
      ),
    );
  }
  
  Widget _buildLoginButton({
    required double width,
    required double height,
    required double scale,
    required String text,
    required VoidCallback? onPressed,
    required bool isApple,
  }) {
    return Container(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFF1F1F4),
          foregroundColor: Colors.black,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10 * scale),
          ),
          padding: EdgeInsets.symmetric(
            horizontal: 22 * scale,
            vertical: 0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text,
              style: TextStyle(
                fontFamily: 'Gilroy',
                fontWeight: FontWeight.w600,
                fontSize: 16 * scale,
                height: 18 / 16,
                letterSpacing: -0.408 * scale,
                color: Colors.black,
              ),
            ),
            isApple 
              ? Icon(
                  Icons.apple,
                  size: 24 * scale,
                  color: Colors.black,
                )
              : Image.asset(
                  'assets/Images/google_logo.png',
                  width: 24 * scale,
                  height: 24 * scale,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.g_mobiledata,
                      size: 24 * scale,
                      color: Colors.black,
                    );
                  },
                ),
          ],
        ),
      ),
    );
  }
}