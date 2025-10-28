class AppLogger {
  static bool _enableLogs = false;

  /// Initialize logger with logs enabled or disabled
  static void init({bool enableLogs = false}) {
    _enableLogs = enableLogs;
  }

  /// Print log message if logging is enabled
  static void log(String message) {
    if (_enableLogs) {
      print(message);
    }
  }

  /// Get current logging state
  static bool get isLoggingEnabled => _enableLogs;

  /// Enable or disable logging
  static void setLoggingEnabled(bool enabled) {
    _enableLogs = enabled;
  }
} 