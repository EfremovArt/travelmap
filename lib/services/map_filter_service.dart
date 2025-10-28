import 'dart:async';
import '../models/post.dart';

/// Сервис для управления фильтрацией отображения маркеров на карте
class MapFilterService {
  static final MapFilterService _instance = MapFilterService._internal();
  
  factory MapFilterService() {
    return _instance;
  }
  
  MapFilterService._internal();
  
  // Потоки состояния
  final _showOnlyFavoritesController = StreamController<bool>.broadcast();
  Stream<bool> get showOnlyFavoritesStream => _showOnlyFavoritesController.stream;
  
  final _showOnlyFollowingsController = StreamController<bool>.broadcast();
  Stream<bool> get showOnlyFollowingsStream => _showOnlyFollowingsController.stream;
  
  final _highlightPostController = StreamController<Post?>.broadcast();
  Stream<Post?> get highlightPostStream => _highlightPostController.stream;
  
  final _filterTitleController = StreamController<String?>.broadcast();
  Stream<String?> get filterTitleStream => _filterTitleController.stream;
  
  // Текущее состояние
  bool _showOnlyFavorites = false;
  bool get showOnlyFavorites => _showOnlyFavorites;
  
  bool _showOnlyFollowings = false;
  bool get showOnlyFollowings => _showOnlyFollowings;
  
  Post? _highlightedPost;
  Post? get highlightedPost => _highlightedPost;
  
  // Откуда пользователь пришел на карту
  String _sourceView = 'feed'; // 'feed', 'favorites', 'followings' или 'profile'
  String get sourceView => _sourceView;
  
  String? _filterTitle;
  String? get filterTitle => _filterTitle;
  
  // ID поста, к которому нужно прокрутить при возврате в профиль
  String? _scrollToPostId;
  String? get scrollToPostId => _scrollToPostId;
  
  // Установка режима отображения только избранных постов
  void setShowOnlyFavorites(bool value) {
    _showOnlyFavorites = value;
    _showOnlyFavoritesController.add(value);
  }
  
  // Установка режима отображения только постов из followings
  void setShowOnlyFollowings(bool value) {
    _showOnlyFollowings = value;
    _showOnlyFollowingsController.add(value);
  }
  
  // Установка поста для выделения на карте
  void setHighlightedPost(Post? post) {
    _highlightedPost = post;
    _highlightPostController.add(post);
  }
  
  // Установка заголовка фильтра
  void setFilterTitle(String? title) {
    _filterTitle = title;
    _filterTitleController.add(title);
  }
  
  // Установка ID поста для прокрутки при возврате в профиль
  void setScrollToPostId(String? postId) {
    print('🔧 MapFilterService: setScrollToPostId($postId)');
    _scrollToPostId = postId;
  }
  
  // Очистка ID поста для прокрутки
  void clearScrollToPostId() {
    print('🔧 MapFilterService: clearScrollToPostId() - было: $_scrollToPostId');
    _scrollToPostId = null;
  }
  
  // Показать избранные посты с выделением конкретного поста
  void showFavoritesWithHighlight(Post? post) {
    _showOnlyFavorites = true;
    _showOnlyFollowings = false;
    _highlightedPost = post;
    _sourceView = 'favorites'; // Устанавливаем источник как избранное
    _filterTitle = 'Favorites';
    _showOnlyFavoritesController.add(true);
    _showOnlyFollowingsController.add(false);
    _highlightPostController.add(post);
    _filterTitleController.add(_filterTitle);
  }
  
  // Показать посты из followings с выделением конкретного поста
  void showFollowingsWithHighlight(Post? post) {
    print('🔧 MapFilterService: showFollowingsWithHighlight вызван с постом: ${post?.id}');
    _showOnlyFavorites = false;
    _showOnlyFollowings = true;
    _highlightedPost = post;
    _sourceView = 'followings'; // Устанавливаем источник как followings
    _filterTitle = 'Followings';
    print('   Отправляем в streams: favorites=false, followings=true, post=${post?.id}');
    _showOnlyFavoritesController.add(false);
    _showOnlyFollowingsController.add(true);
    _highlightPostController.add(post);
    _filterTitleController.add(_filterTitle);
    print('   ✅ Все streams обновлены');
  }
  
  // Установить источник перехода на карту
  void setSourceView(String source) {
    _sourceView = source;
  }
  
  // Сброс всех фильтров
  void resetFilters() {
    print('🔧 MapFilterService: resetFilters() вызван! scrollToPostId был: $_scrollToPostId');
    _showOnlyFavorites = false;
    _showOnlyFollowings = false;
    _highlightedPost = null;
    _sourceView = 'feed'; // Сбрасываем источник
    _filterTitle = null;
    _scrollToPostId = null; // Сбрасываем ID для прокрутки
    _showOnlyFavoritesController.add(false);
    _showOnlyFollowingsController.add(false);
    _highlightPostController.add(null);
    _filterTitleController.add(null);
  }
  
  // Закрытие потоков при завершении работы приложения
  void dispose() {
    _showOnlyFavoritesController.close();
    _showOnlyFollowingsController.close();
    _highlightPostController.close();
    _filterTitleController.close();
  }
} 
