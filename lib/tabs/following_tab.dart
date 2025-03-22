import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FollowingTab extends StatelessWidget {
  const FollowingTab({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'People You Follow',
            style: GoogleFonts.poppins(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          
          // Search bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'Search for travelers',
                      hintStyle: TextStyle(
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          Expanded(
            child: ListView(
              children: [
                _buildFollowingItem(
                  'John Doe',
                  'Travel enthusiast | 45 countries visited',
                  'https://randomuser.me/api/portraits/men/32.jpg',
                  true,
                ),
                _buildFollowingItem(
                  'Sarah Wilson',
                  'Adventure seeker | Photographer',
                  'https://randomuser.me/api/portraits/women/44.jpg',
                  true,
                ),
                _buildFollowingItem(
                  'Mike Johnson',
                  'Backpacker | 30 countries visited',
                  'https://randomuser.me/api/portraits/men/67.jpg',
                  false,
                ),
                _buildFollowingItem(
                  'Emma Brown',
                  'Food traveler | Culinary adventures',
                  'https://randomuser.me/api/portraits/women/63.jpg',
                  true,
                ),
                _buildFollowingItem(
                  'Robert Smith',
                  'Luxury traveler | Hotel reviews',
                  'https://randomuser.me/api/portraits/men/91.jpg',
                  false,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFollowingItem(String name, String bio, String imageUrl, bool isFollowing) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(imageUrl),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  bio,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {},
            style: TextButton.styleFrom(
              backgroundColor: isFollowing ? Colors.grey.shade200 : Colors.blue.shade600,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Text(
              isFollowing ? 'Unfollow' : 'Follow',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isFollowing ? Colors.black87 : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
} 