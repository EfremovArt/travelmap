import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../utils/logger.dart';
typedef PermissionCallback = void Function(bool isGranted);

class PermissionsManager {
  /// Check if location services are enabled and request permissions if needed
  static Future<bool> checkLocationPermission({
    required BuildContext context,
    PermissionCallback? onPermissionResult,
  }) async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      // Check if location services are enabled
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Show dialog to enable location services
        final bool shouldProceed = await _showLocationServicesDialog(context);
        if (!shouldProceed) {
          onPermissionResult?.call(false);
          return false;
        }
        
        // Check again after user action
        serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          onPermissionResult?.call(false);
          return false;
        }
      }

      // Check location permission
      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // Request permission
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permission denied
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Приложению необходим доступ к местоположению для работы с картой'),
              ),
            );
          }
          onPermissionResult?.call(false);
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permission permanently denied
        if (context.mounted) {
          await _showAppSettingsDialog(context);
        }
        onPermissionResult?.call(false);
        return false;
      }

      // Permission granted
      onPermissionResult?.call(true);
      return true;
    } catch (e) {
      AppLogger.log("Ошибка при проверке разрешений местоположения: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при проверке разрешений: $e'),
          ),
        );
      }
      onPermissionResult?.call(false);
      return false;
    }
  }

  /// Show dialog explaining that location services are required
  static Future<bool> _showLocationServicesDialog(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Службы геолокации отключены'),
          content: const Text(
            'Для использования всех функций карты необходимо включить службы геолокации на вашем устройстве.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Отмена'),
              onPressed: () {
                Navigator.of(context).pop(false);
              },
            ),
            TextButton(
              child: const Text('Открыть настройки'),
              onPressed: () async {
                Navigator.of(context).pop(true);
                await Geolocator.openLocationSettings();
              },
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  /// Show dialog explaining how to enable permissions in app settings
  static Future<void> _showAppSettingsDialog(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Требуется разрешение на определение местоположения'),
          content: const Text(
            'Разрешение на определение местоположения отклонено навсегда. Пожалуйста, включите его в настройках приложения.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Отмена'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Открыть настройки'),
              onPressed: () async {
                Navigator.of(context).pop();
                await Geolocator.openAppSettings();
              },
            ),
          ],
        );
      },
    );
  }
} 