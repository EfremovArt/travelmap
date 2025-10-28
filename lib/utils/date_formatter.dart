import 'package:intl/intl.dart';

class DateFormatter {
  // Форматирование даты для отображения в комментариях
  static String formatCommentDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    // Если меньше минуты
    if (difference.inMinutes < 1) {
      return 'только что';
    }
    
    // Если меньше часа
    if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes ${_pluralizeMinutes(minutes)} назад';
    }
    
    // Если сегодня
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'сегодня в ${DateFormat.Hm().format(date)}';
    }
    
    // Если вчера
    final yesterday = now.subtract(Duration(days: 1));
    if (date.day == yesterday.day && date.month == yesterday.month && date.year == yesterday.year) {
      return 'вчера в ${DateFormat.Hm().format(date)}';
    }
    
    // Если в этом году
    if (date.year == now.year) {
      return DateFormat('d MMM в H:mm').format(date);
    }
    
    // Иначе полная дата
    return DateFormat('d MMM yyyy в H:mm').format(date);
  }
  
  // Форматирование даты для отображения в постах
  static String formatPostDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    // Если меньше часа
    if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes ${_pluralizeMinutes(minutes)} назад';
    }
    
    // Если меньше суток
    if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$hours ${_pluralizeHours(hours)} назад';
    }
    
    // Если меньше недели
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${_pluralizeDays(days)} назад';
    }
    
    // Если в этом году
    if (date.year == now.year) {
      return DateFormat('d MMM').format(date);
    }
    
    // Иначе полная дата
    return DateFormat('d MMM yyyy').format(date);
  }
  
  // Вспомогательные методы для множественного числа
  static String _pluralizeMinutes(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'минуту';
    } else if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'минуты';
    } else {
      return 'минут';
    }
  }
  
  static String _pluralizeHours(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'час';
    } else if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'часа';
    } else {
      return 'часов';
    }
  }
  
  static String _pluralizeDays(int count) {
    if (count % 10 == 1 && count % 100 != 11) {
      return 'день';
    } else if ([2, 3, 4].contains(count % 10) && ![12, 13, 14].contains(count % 100)) {
      return 'дня';
    } else {
      return 'дней';
    }
  }
  
  // Общий метод форматирования даты и времени
  static String formatDateTime(DateTime date) {
    final now = DateTime.now();
    
    // Если сегодня
    if (date.day == now.day && date.month == now.month && date.year == now.year) {
      return 'сегодня в ${DateFormat.Hm().format(date)}';
    }
    
    // Если вчера
    final yesterday = now.subtract(Duration(days: 1));
    if (date.day == yesterday.day && date.month == yesterday.month && date.year == yesterday.year) {
      return 'вчера в ${DateFormat.Hm().format(date)}';
    }
    
    // Если в этом году
    if (date.year == now.year) {
      return DateFormat('d MMM в H:mm').format(date);
    }
    
    // Иначе полная дата
    return DateFormat('d MMM yyyy в H:mm').format(date);
  }

  // Форматирование относительной даты (используется в альбомах)
  static String formatRelativeDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    // Если меньше минуты
    if (difference.inMinutes < 1) {
      return 'только что';
    }
    
    // Если меньше часа
    if (difference.inHours < 1) {
      final minutes = difference.inMinutes;
      return '$minutes ${_pluralizeMinutes(minutes)} назад';
    }
    
    // Если меньше суток
    if (difference.inDays < 1) {
      final hours = difference.inHours;
      return '$hours ${_pluralizeHours(hours)} назад';
    }
    
    // Если меньше недели
    if (difference.inDays < 7) {
      final days = difference.inDays;
      return '$days ${_pluralizeDays(days)} назад';
    }
    
    // Если в этом году
    if (date.year == now.year) {
      return DateFormat('d MMM').format(date);
    }
    
    // Иначе полная дата
    return DateFormat('d MMM yyyy').format(date);
  }
} 