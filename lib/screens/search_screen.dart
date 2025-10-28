import 'dart:async';
import 'package:flutter/material.dart';
import '../models/location.dart';
import '../models/post.dart';
import '../models/search_result.dart';
import '../services/mapbox_service.dart';
import '../services/post_service.dart';
import '../tabs/home_tab.dart';
import '../utils/logger.dart';
import '../utils/debouncer.dart';
import '../screens/main_screen.dart';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';

class SearchScreen extends StatefulWidget {
  final GlobalKey<HomeTabState>? homeTabKey;

  const SearchScreen({
    Key? key,
    this.homeTabKey,
  }) : super(key: key);

  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  final Debouncer _debouncer = Debouncer(milliseconds: 500);
  
  List<SearchResult> _locationResults = [];
  List<Post> _postResults = [];
  bool _isSearching = false;
  bool _showLocations = true; // По умолчанию показываем локации
  
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _showLocations = _tabController.index == 0;
      });
      _performSearch(_searchController.text);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _locationResults = [];
        _postResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
    });

    try {
      if (_showLocations) {
        // Поиск локаций с поддержкой достопримечательностей
        final locations = await MapboxService.searchLocationWithAttractions(query);
        setState(() {
          _locationResults = locations;
        });
      } else {
        // Поиск постов
        final allPosts = await PostService.getAllPosts();
        final filteredPosts = allPosts.where((post) {
          final postText = '${post.locationName} ${post.description}'.toLowerCase();
          return postText.contains(query.toLowerCase());
        }).toList();
        
        setState(() {
          _postResults = filteredPosts;
        });
      }
    } catch (e) {
      AppLogger.log('Error in search: $e');
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _onLocationSelected(SearchResult location) {
    AppLogger.log('Selected location: ${location.name} (${location.latitude}, ${location.longitude})');
    
    if (widget.homeTabKey?.currentState != null) {
      final homeTabState = widget.homeTabKey!.currentState!;
      
      // Закрываем сначала поиск, чтобы избежать проблем с перерисовкой
      Navigator.pop(context);
      
      // Переключаемся на вкладку Home
      if (mainScreenKey.currentState != null) {
        AppLogger.log('Switching to Home tab');
        mainScreenKey.currentState!.switchToTab(0);
      }
      
      // Используем Future.delayed для выполнения операций после переключения вкладки
      Future.delayed(Duration(milliseconds: 300), () {
        // Сохраняем информацию о локации, которую нужно показать
        homeTabState.setPendingLocationToShow(location.location, location.name);
        
        // Переключаемся на карту
        homeTabState.setActiveView('map');
        
        AppLogger.log('Location selection processed: ${location.name}');
      });
    } else {
      AppLogger.log('HomeTab key is null or currentState is null');
      Navigator.pop(context);
    }
  }

  void _onPostSelected(Post post) {
    AppLogger.log('Selected post: ${post.id} at ${post.locationName}');
    
    if (widget.homeTabKey?.currentState != null) {
      final homeTabState = widget.homeTabKey!.currentState!;
      
      // Закрываем сначала поиск
      Navigator.pop(context);
      
      // Переключаемся на вкладку Home
      if (mainScreenKey.currentState != null) {
        AppLogger.log('Switching to Home tab');
        mainScreenKey.currentState!.switchToTab(0);
      }
      
      // Используем Future.delayed для выполнения операций после переключения вкладки
      Future.delayed(Duration(milliseconds: 300), () {
        // Сохраняем информацию о посте, который нужно показать
        homeTabState.setPendingPostToShow(post);
        
        // Переключаемся на ленту
        homeTabState.setActiveView('feed');
        
        AppLogger.log('Post selection processed: ${post.id}');
      });
    } else {
      AppLogger.log('HomeTab key is null or currentState is null');
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Search'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(icon: Icon(Icons.map), text: 'Locations'),
            Tab(icon: Icon(Icons.photo), text: 'Posts'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: _showLocations ? 'Search for locations...' : 'Search for posts...',
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        _performSearch('');
                      },
                    )
                  : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onChanged: (value) {
                _debouncer.run(() => _performSearch(value));
              },
            ),
          ),
          Expanded(
            child: _isSearching
              ? Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    // Locations tab
                    _buildLocationResultsList(),
                    // Posts tab
                    _buildPostResultsList(),
                  ],
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationResultsList() {
    if (_locationResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Text('No locations found'),
      );
    }

    return ListView.builder(
      itemCount: _locationResults.length,
      itemBuilder: (context, index) {
        final location = _locationResults[index];
        return ListTile(
          leading: Icon(Icons.location_on, color: Colors.red),
          title: Text(location.placeName),
          subtitle: Text(location.placeAddress),
          onTap: () => _onLocationSelected(location),
        );
      },
    );
  }

  Widget _buildPostResultsList() {
    if (_postResults.isEmpty && _searchController.text.isNotEmpty) {
      return Center(
        child: Text('No posts found'),
      );
    }

    return ListView.builder(
      itemCount: _postResults.length,
      itemBuilder: (context, index) {
        final post = _postResults[index];
        return ListTile(
          leading: post.imageUrls.isNotEmpty
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: post.imageUrls.first,
                  fit: BoxFit.cover,
                  progressIndicatorBuilder: (context, url, progress) => Center(
                    child: CircularProgressIndicator(value: progress.progress),
                  ),
                  errorWidget: (context, url, error) => const Icon(
                    Icons.broken_image,
                    size: 24,
                    color: Colors.grey,
                  ),
                ),
              )
            : Container(
                width: 56,
                height: 56,
                color: Colors.grey[300],
                child: Icon(Icons.photo, color: Colors.grey[600]),
              ),
          title: Text(post.locationName),
          subtitle: Text(
            post.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () => _onPostSelected(post),
        );
      },
    );
  }
} 