// Исправленные методы для HomeTab

// Исправленный метод _processPendingActions
/*
Замените этот метод в файле lib/tabs/home_tab.dart

void _processPendingActions() {
  // Остальной код метода остается тем же
  
  if (_pendingLocation != null && _pendingLocationName != null) {
    // ...
    
    // Отложенное выполнение для гарантии обновления UI
    Future.delayed(Duration(milliseconds: 300), () async {
      // ...
      
      // Сохраняем локальную копию локации
      final localLocation = _pendingLocation!;
      final localLocationName = _pendingLocationName!;
      
      // Перемещаем камеру к локации с анимацией
      try {
        await _flyToLocation(localLocation);
        AppLogger.log('✅ Камера перемещена к локации');
      } catch (e) {
        AppLogger.log('⚠️ Ошибка при перемещении камеры: $e');
        // Пробуем обычное перемещение камеры
        try {
          if (mounted && _mapboxMap != null) {
            await _moveCamera(localLocation);
          }
        } catch (e2) {
          AppLogger.log('❌ Ошибка обычного перемещения камеры: $e2');
        }
      }
      
      // Добавляем маркер
      if (mounted && _pointAnnotationManager != null) {
        try {
          await _addCustomMarker(localLocation, localLocationName);
          AppLogger.log('✅ Добавлен маркер для локации');
        } catch (e) {
          AppLogger.log('⚠️ Ошибка при добавлении маркера: $e');
        }
      }
    });
  }
  // ... остальной код метода
}
*/

// Исправленный метод в PostCard для безопасной обработки состояния
/*
Замените в lib/widgets/post_card.dart в методе _loadCommentsCount:

Future<void> _loadCommentsCount() async {
  try {
    if (widget.post.id.isEmpty) {
      AppLogger.log('❌ Некорректный ID поста: ${widget.post.id}');
      return;
    }

    if (!mounted) {
      AppLogger.log('⚠️ Виджет больше не монтирован, отменяем загрузку комментариев');
      return;
    }
    
    setState(() {
      _isLoadingComments = true;
    });

    AppLogger.log('🔄 Запрос количества комментариев для поста ID: ${widget.post.id}');
    final result = await _socialService.getComments(widget.post.id, page: 1, perPage: 1);
    
    if (!mounted) {
      AppLogger.log('⚠️ Виджет больше не монтирован после загрузки, отменяем обновление');
      return;
    }
    
    if (result['success'] == true && result['pagination'] != null) {
      setState(() {
        _commentsCount = result['pagination']['total'] ?? 0;
      });
    } else {
      // В случае ошибки (включая 404), просто устанавливаем 0 комментариев
      AppLogger.log('⚠️ Не удалось получить комментарии: ${result['error']}');
      setState(() {
        _commentsCount = 0;
      });
    }
  } catch (e) {
    AppLogger.log('❌ Ошибка при загрузке количества комментариев: $e');
    if (mounted) {
      setState(() {
        _commentsCount = 0;
      });
    }
  } finally {
    if (mounted) {
      setState(() {
        _isLoadingComments = false;
      });
    }
  }
}
*/ 