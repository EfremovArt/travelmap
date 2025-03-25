import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:uuid/uuid.dart';
import '../../models/location.dart';
import '../../models/post.dart';
import '../../services/post_service.dart';
import '../../services/user_service.dart';

class UploadDescriptionScreen extends StatefulWidget {
  final List<File> images;
  final GeoLocation selectedLocation;
  final String locationName;

  const UploadDescriptionScreen({
    Key? key,
    required this.images,
    required this.selectedLocation,
    required this.locationName,
  }) : super(key: key);

  @override
  State<UploadDescriptionScreen> createState() => _UploadDescriptionScreenState();
}

class _UploadDescriptionScreenState extends State<UploadDescriptionScreen> {
  final TextEditingController _descriptionController = TextEditingController();
  bool _isPublishing = false;

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _publishPost() async {
    if (_isPublishing) return;
    
    setState(() {
      _isPublishing = true;
    });
    
    try {
      // Check that we have all required data
      if (widget.images.isEmpty) {
        throw Exception('No images selected');
      }
      
      // Получаем email пользователя для идентификации
      final userEmail = await UserService.getEmail();
      final userId = userEmail.isNotEmpty ? userEmail : 'current_user';
      
      print('📝 Creating new post with user ID: $userId');
      
      // Create new post
      final post = Post(
        id: const Uuid().v4(),
        images: widget.images,
        location: widget.selectedLocation,
        locationName: widget.locationName,
        description: _descriptionController.text.trim(),
        createdAt: DateTime.now(),
        user: userId, // Использование email пользователя вместо статического значения
      );
      
      // Save post
      await PostService.savePost(post);
      
      if (!mounted) return;
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post published successfully!'))
      );
      
      // Get result for return (location)
      final result = widget.selectedLocation;
      
      print('Publication completed, returning location: ${result.latitude}, ${result.longitude}');
      
      // Close all upload screens and return
      Navigator.of(context).pop(result); // Return to location screen
      Navigator.of(context).pop(result); // Return to image screen
      Navigator.of(context).pop(result); // Return to main screen with location data
      
    } catch (e) {
      print('Failed to publish post: $e');
      
      // Handle errors
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to publish post: $e'))
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPublishing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "If you have something to say",
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Предпросмотр изображений
          Container(
            height: 120,
            margin: const EdgeInsets.symmetric(vertical: 16),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: widget.images.length,
              itemBuilder: (context, index) {
                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    image: DecorationImage(
                      image: FileImage(widget.images[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Отображение выбранной локации
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.place, color: Colors.red),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.locationName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          
          // Поле для ввода описания
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _descriptionController,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: 'Write your impression here...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.all(16),
                ),
              ),
            ),
          ),
          
          // Кнопка "Опубликовать"
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isPublishing ? null : _publishPost,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isPublishing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Publish',
                      style: TextStyle(fontSize: 16),
                    ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 