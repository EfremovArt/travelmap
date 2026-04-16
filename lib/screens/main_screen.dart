import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../tabs/home_tab.dart';
import '../tabs/following_tab.dart';
import '../tabs/favorites_tab.dart';
import '../tabs/my_map_tab.dart';
import '../tabs/albums_tab.dart';
import '../screens/profile_screen.dart';
import '../services/map_filter_service.dart';
import '../utils/logger.dart';

// Создаем глобальный ключ для доступа к MainScreen
final GlobalKey<_MainScreenState> mainScreenKey = GlobalKey<_MainScreenState>();

class MainScreen extends StatefulWidget {
  MainScreen({Key? key}) : super(key: key ?? mainScreenKey);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  final MapFilterService _mapFilterService = MapFilterService();
  
  // Создаем ключ для HomeTab
  final GlobalKey<HomeTabState> _homeTabKey = GlobalKey<HomeTabState>();
  
  late final List<Widget> _tabs;
  
  @override
  void initState() {
    super.initState();
    
    // Инициализируем _tabs в initState
    _tabs = [
      HomeTab(homeStateKey: _homeTabKey, key: _homeTabKey),
      const FollowingTab(),
      const FavoritesTab(),
      const MyMapTab(),
      const AlbumsTab(),
    ];
  }
  
  // Метод для открытия экрана профиля
  void _openProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }
  
  // Метод для смены вкладки с обработкой сброса фильтров
  void _onTabChanged(int index) {
    if (index == _selectedIndex) {
      // User tapped the same tab we were already on
      AppLogger.log("User tapped Home tab again, resetting filters");
      _mapFilterService.resetFilters();
    }
    AppLogger.log("Switching tab from $_selectedIndex to $index");
    
    // Сначала обновляем индекс
    setState(() {
      _selectedIndex = index;
    });
    
    // Даем небольшую задержку для инициализации виджетов
    Future.delayed(Duration(milliseconds: 300), () {
      // Если переключились на вкладку Home, убедимся что карта правильно инициализирована
      if (index == 0) {
        AppLogger.log("Switched to Home tab");
        // Принудительно перезагружаем маркеры при переходе на вкладку карты
        if (_homeTabKey.currentState != null) {
          _homeTabKey.currentState!.reloadMarkersOnTabSwitch();
        }
      }
    });
  }
  
  // Публичный метод для переключения вкладок из других классов
  void switchToTab(int index) {
    AppLogger.log("📱 Публичный вызов switchToTab($index) из текущего $_selectedIndex");
    
    if (index == _selectedIndex) {
      AppLogger.log("📱 Уже находимся на вкладке $index, выполняем дополнительные действия для текущей вкладки");
      
      // Если уже на вкладке Home, выполняем дополнительные действия
      if (index == 0 && _homeTabKey.currentState != null) {
        // Проверяем, есть ли отложенные действия
        final homeState = _homeTabKey.currentState!;
        if (homeState.hasPendingAction()) {
          AppLogger.log("📱 Обнаружены отложенные действия в HomeTab, обрабатываем");
          // Отложенное действие на случай, если вкладка еще не полностью инициализирована
          Future.delayed(Duration(milliseconds: 100), () {
            // Обрабатываем отложенные действия
            homeState.processPendingActions();
          });
        }
      }
      
      return;
    }
    
    AppLogger.log("📱 Переключение с вкладки $_selectedIndex на $index");
    
    // Сначала обновляем индекс
    setState(() {
      _selectedIndex = index;
    });
    
    // Даем небольшую задержку для инициализации виджетов
    Future.delayed(Duration(milliseconds: 500), () {
      // Если переключились на вкладку Home, убедимся что карта правильно инициализирована
      if (index == 0 && _homeTabKey.currentState != null) {
        final homeState = _homeTabKey.currentState!;
        
        // Проверяем, есть ли отложенные действия
        if (homeState.hasPendingAction()) {
          AppLogger.log("📱 Обнаружены отложенные действия в HomeTab после переключения, обрабатываем");
          // Обрабатываем отложенные действия
          homeState.processPendingActions();
        } else {
          AppLogger.log("📱 Нет отложенных действий в HomeTab после переключения");
          // Принудительно перезагружаем маркеры при переходе на вкладку карты
          homeState.reloadMarkersOnTabSwitch();
        }
      }
    });
  }
  
  // Публичный геттер для получения текущего индекса вкладки
  int get currentTabIndex => _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            // TravelMap текст в стиле splash screen
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // "Travel" text
                Text(
                  'Travel',
                  style: TextStyle(
                    fontFamily: 'Rubik One',
                    fontWeight: FontWeight.w400,
                    fontSize: 24,
                    color: Colors.black,
                  ),
                ),
                // "Map" word with Rubik Microbe font
                Text(
                  'Map',
                  style: TextStyle(
                    fontFamily: 'Rubik Microbe',
                    fontWeight: FontWeight.w400,
                    fontSize: 24,
                    color: Colors.black,
                  ),
                ),
              ],
            ),
            SizedBox(width: 20), // Добавляем отступ после логотипа
          ],
        ),
        actions: [
          // Profile icon in rounded gray square
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                icon: Image.asset(
                  'assets/Images/profile.png',
                  width: 24,
                  height: 24,
                ),
                onPressed: _openProfileScreen,
              ),
            ),
          ),
        ],
      ),
      // Используем IndexedStack, чтобы сохранять состояние вкладок (в т.ч. карты)
      body: IndexedStack(
        index: _selectedIndex,
        children: _tabs,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Color.fromRGBO(0, 122, 255, 1), // iOS Blue - яркий синий
        unselectedItemColor: Colors.grey.shade600,
        currentIndex: _selectedIndex,
        iconSize: 24.0,
        onTap: _onTabChanged,
        showSelectedLabels: false,
        showUnselectedLabels: false,
        items: [
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/Images/home.svg',
              color: Colors.grey.shade700,
              width: 24,
              height: 24,
            ),
            activeIcon: SvgPicture.asset(
              'assets/Images/home.svg',
              color: Color.fromRGBO(0, 122, 255, 1), // iOS Blue
              width: 24,
              height: 24,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/Images/following.svg',
              color: Colors.grey.shade700,
              width: 24,
              height: 24,
            ),
            activeIcon: SvgPicture.asset(
              'assets/Images/following.svg',
              color: Color.fromRGBO(0, 122, 255, 1), // iOS Blue
              width: 24,
              height: 24,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/Images/favorites.svg',
              color: Colors.grey.shade700,
              width: 24,
              height: 24,
            ),
            activeIcon: SvgPicture.asset(
              'assets/Images/favorites.svg',
              color: Color.fromRGBO(0, 122, 255, 1), // iOS Blue
              width: 24,
              height: 24,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: SvgPicture.asset(
              'assets/Images/mymap.svg',
              color: Colors.grey.shade700,
              width: 24,
              height: 24,
            ),
            activeIcon: SvgPicture.asset(
              'assets/Images/mymap.svg',
              color: Color.fromRGBO(0, 122, 255, 1), // iOS Blue
              width: 24,
              height: 24,
            ),
            label: '',
          ),
          BottomNavigationBarItem(
            icon: Icon(
              Icons.photo_album_outlined,
              color: Colors.grey.shade700,
              size: 24,
            ),
            activeIcon: Icon(
              Icons.photo_album,
              color: Color.fromRGBO(0, 122, 255, 1), // iOS Blue
              size: 24,
            ),
            label: '',
          ),
        ],
      ),
    );
  }
} 