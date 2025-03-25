import 'package:google_sign_in/google_sign_in.dart';

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

  // Проверка текущего статуса аутентификации
  Future<bool> isSignedIn() async {
    try {
      return await _googleSignIn.isSignedIn();
    } catch (e) {
      print('Ошибка при проверке статуса аутентификации: $e');
      return false;
    }
  }
}