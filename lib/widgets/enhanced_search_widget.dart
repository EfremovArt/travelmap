import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/search_result.dart';
import '../services/mapbox_service.dart';
import '../utils/logger.dart';

/// Enhanced search widget for locations
class EnhancedSearchWidget extends StatefulWidget {
  final Function(SearchResult) onLocationSelected;
  final String hintText;
  final double? proximityLng;
  final double? proximityLat;

  const EnhancedSearchWidget({
    Key? key,
    required this.onLocationSelected,
    this.hintText = 'Search locations...',
    this.proximityLng,
    this.proximityLat,
  }) : super(key: key);

  @override
  _EnhancedSearchWidgetState createState() => _EnhancedSearchWidgetState();
}

class _EnhancedSearchWidgetState extends State<EnhancedSearchWidget> {
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  List<SearchResult> _searchResults = [];
  bool _locationSelected = false; // Флаг для отслеживания выбора локации

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _performSearch(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
        _locationSelected = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _locationSelected = false; // Сбрасываем флаг при новом поиске
    });

    try {
      // Use universal search with proximity to prioritize nearby POI
      final results = await MapboxService.searchLocationWithAttractions(
        query,
        proximityLng: widget.proximityLng,
        proximityLat: widget.proximityLat,
      );

      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    } catch (e) {
      AppLogger.log('Error in enhanced search: $e');
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Search field
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: widget.hintText,
              hintStyle: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontSize: 16,
              ),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.clear, color: Colors.grey),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchResults = [];
                          _locationSelected = false; // Сбрасываем флаг при очистке
                        });
                      },
                    ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            style: GoogleFonts.poppins(fontSize: 16),
            onChanged: (value) {
              // Сбрасываем флаг выбора локации при изменении текста
              if (_locationSelected) {
                setState(() {
                  _locationSelected = false;
                });
              }
              
              // Debounce for search
              Future.delayed(const Duration(milliseconds: 500), () {
                if (_searchController.text == value) {
                  _performSearch(value);
                }
              });
            },
            onSubmitted: _performSearch,
          ),
        ),

        // Search results
        if (_searchResults.isNotEmpty)
          Container(
            height: 300,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ListView.builder(
              itemCount: _searchResults.length,
              itemBuilder: (context, index) {
                final result = _searchResults[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                    child: Icon(
                      _getIconForResult(result),
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    result.name,
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    result.placeAddress,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey,
                  ),
                  onTap: () {
                    // Сначала вызываем callback для обработки выбранной локации
                    widget.onLocationSelected(result);
                    
                    // Устанавливаем выбранное название в поле поиска
                    _searchController.text = result.placeName;
                    
                    // Закрываем список подсказок и клавиатуру
                    FocusScope.of(context).unfocus();
                    setState(() {
                      _isSearching = false;
                      _searchResults = [];
                      _locationSelected = true; // Устанавливаем флаг выбора локации
                    });
                  },
                );
              },
            ),
          ),

        // No results state - показываем только если не было выбрано местоположение
        if (!_isSearching && _searchResults.isEmpty && _searchController.text.isNotEmpty && !_locationSelected)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Icon(
                  Icons.search_off,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  'No results found',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Try changing your search query',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
      ],
    );
  }

  IconData _getIconForResult(SearchResult result) {
    final name = result.name.toLowerCase();
    
    if (name.contains('museum')) {
      return Icons.museum;
    } else if (name.contains('restaurant') || name.contains('cafe') || name.contains('food')) {
      return Icons.restaurant;
    } else if (name.contains('hotel') || name.contains('lodging')) {
      return Icons.hotel;
    } else if (name.contains('park')) {
      return Icons.park;
    } else if (name.contains('shopping') || name.contains('store')) {
      return Icons.shopping_bag;
    } else if (name.contains('attraction') || name.contains('monument') || name.contains('landmark')) {
      return Icons.place;
    } else {
      return Icons.location_on;
    }
  }
}
