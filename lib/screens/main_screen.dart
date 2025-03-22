import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../tabs/home_tab.dart';
import '../tabs/following_tab.dart';
import '../tabs/favorites_tab.dart';
import '../tabs/my_map_tab.dart';
import '../screens/profile_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  
  final List<Widget> _tabs = [
    const HomeTab(),
    const FollowingTab(),
    const FavoritesTab(),
    const MyMapTab(),
  ];

  // Метод для открытия экрана профиля
  void _openProfileScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProfileScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            // Logo
            Row(
              children: [
                Icon(
                  Icons.explore,
                  color: Colors.blue.shade800,
                  size: 24,
                ),
                const SizedBox(width: 8),
                Text(
                  'TRAVEL MAP',
                  style: GoogleFonts.montserrat(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Search icon
          IconButton(
            icon: const Icon(Icons.search, color: Colors.black87),
            onPressed: () {
              // TODO: Implement search functionality
            },
          ),
          // Profile icon
          IconButton(
            icon: const Icon(Icons.person, color: Colors.black87),
            onPressed: _openProfileScreen,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _tabs[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.blue.shade700,
        unselectedItemColor: Colors.grey.shade600,
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outline),
            activeIcon: Icon(Icons.people),
            label: 'Following',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Favorites',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map_outlined),
            activeIcon: Icon(Icons.map),
            label: 'My Map',
          ),
        ],
      ),
    );
  }
} 