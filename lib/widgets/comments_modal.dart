import 'package:flutter/material.dart';
import '../models/post.dart';
import '../services/social_service.dart';
import '../services/user_service.dart';
import 'package:intl/intl.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';
class CommentsModal extends StatefulWidget {
  final Post post;

  const CommentsModal({Key? key, required this.post}) : super(key: key);

  @override
  _CommentsModalState createState() => _CommentsModalState();
}

class _CommentsModalState extends State<CommentsModal> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = true;
  List<Map<String, dynamic>> _comments = [];
  bool _isSubmitting = false;
  String _currentUserProfileImage = '';
  String _error = '';
  int _currentUserId = 0;
  int _photoOwnerId = 0; // ID владельца поста/фото

  @override
  void initState() {
    super.initState();
    _loadComments();
    _loadCurrentUserData();
  }

  Future<void> _loadCurrentUserData() async {
    try {
      final userData = await UserService.getCurrentUserData();
      setState(() {
        _currentUserProfileImage = userData['profileImageUrl'] ?? '';
        _currentUserId = userData['id'] ?? 0;
      });
    } catch (e) {
      AppLogger.log('❌ Error loading current user data: $e');
    }
  }

  Future<void> _loadComments() async {
    try {
      setState(() {
        _isLoading = true;
        _error = '';
      });

      final socialService = SocialService();
      final result = await socialService.getComments(widget.post.id);

      setState(() {
        _isLoading = false;
        if (result['success'] == true && result['comments'] is List) {
          _comments = List<Map<String, dynamic>>.from(result['comments']);
          
          // Извлекаем ID владельца фото, если он есть в ответе
          if (result.containsKey('photoOwnerId')) {
            final ownerId = result['photoOwnerId'];
            _photoOwnerId = ownerId is int ? ownerId : int.tryParse(ownerId.toString()) ?? 0;
            AppLogger.log('📷 Photo owner ID from comments: $_photoOwnerId');
          } else {
            // Если нет в ответе, используем ID поста
            final postUserId = widget.post.user;
            _photoOwnerId = int.tryParse(postUserId) ?? 0;
            AppLogger.log('📷 Photo owner ID from post: $_photoOwnerId');
          }
        } else {
          _error = result['error'] ?? 'Failed to load comments';
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = 'Error: $e';
      });
      AppLogger.log('❌ Error loading comments: $e');
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      final comment = _commentController.text.trim();
      final socialService = SocialService();
      final result = await socialService.addComment(widget.post.id, comment);

      if (result['success'] == true) {
        _commentController.clear();
        // Обновляем список комментариев
        await _loadComments();
        
        // Скроллим к последнему комментарию
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['error'] ?? 'Failed to add comment')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
      AppLogger.log('❌ Error submitting comment: $e');
    } finally {
      setState(() {
        _isSubmitting = false;
      });
    }
  }

  Future<void> _deleteComment(int commentId) async {
    try {
      AppLogger.log('🗑️ CommentsModal: начинаем удаление комментария: $commentId');
      
      final socialService = SocialService();
      final result = await socialService.deleteComment(commentId);

      if (result['success'] == true) {
        AppLogger.log('✅ CommentsModal: комментарий успешно удален: $commentId');
        // Обновляем список комментариев после удаления
        await _loadComments();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment deleted successfully')),
        );
      } else {
        final errorMsg = result['error'] ?? 'Failed to delete comment';
        AppLogger.log('⚠️ CommentsModal: ошибка при удалении комментария: $errorMsg');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      AppLogger.log('❌ CommentsModal: исключение при удалении комментария: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  // Проверка, может ли текущий пользователь удалить комментарий
  bool _canDeleteComment(Map<String, dynamic> comment) {
    // Пользователь может удалить комментарий, если:
    // 1. Он автор комментария
    // 2. Он владелец поста
    final commentUserId = comment['userId'] is int ? comment['userId'] : int.tryParse(comment['userId'].toString()) ?? 0;
    AppLogger.log('🔍 Проверка прав на удаление: commentUserId=$commentUserId, currentUserId=$_currentUserId, photoOwnerId=$_photoOwnerId');
    return commentUserId == _currentUserId || _currentUserId == _photoOwnerId;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      height: MediaQuery.of(context).size.height * 0.8,
      child: Column(
        children: [
          // Заголовок модального окна
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                ),
              ],
            ),
            child: Row(
              children: [
                Text(
                  'Comments',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          
          // Список комментариев
          Expanded(
            child: _isLoading 
              ? Center(child: CircularProgressIndicator())
              : _error.isNotEmpty
                ? Center(child: Text(_error, style: TextStyle(color: Colors.red)))
                : _comments.isEmpty
                  ? Center(child: Text('No comments yet'))
                  : ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.all(16),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        final userProfileImage = comment['userProfileImageUrl'] ?? '';
                        final formattedProfileImage = ApiConfig.formatImageUrl(userProfileImage);
                        final userName = '${comment['userFirstName'] ?? ''} ${comment['userLastName'] ?? ''}'.trim();
                        final commentText = comment['text'] ?? '';
                        final createdAt = comment['createdAt'] != null
                            ? DateFormat('dd MMM yyyy, HH:mm').format(DateTime.parse(comment['createdAt']))
                            : '';
                        final commentId = comment['id'] is int ? comment['id'] : int.tryParse(comment['id'].toString()) ?? 0;
                            
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Аватарка пользователя
                              CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: formattedProfileImage.isNotEmpty
                                    ? CachedNetworkImageProvider(formattedProfileImage)
                                    : null,
                                child: formattedProfileImage.isEmpty
                                    ? Icon(Icons.person, color: Colors.grey.shade600, size: 18)
                                    : null,
                              ),
                              SizedBox(width: 12),
                              
                              // Комментарий
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Имя пользователя и дата
                                    Row(
                                      children: [
                                        Text(
                                          userName.isNotEmpty ? userName : 'User',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                          ),
                                        ),
                                        Spacer(),
                                        Text(
                                          createdAt,
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        // Кнопка удаления комментария
                                        if (_canDeleteComment(comment))
                                          IconButton(
                                            icon: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                            onPressed: () => _showDeleteConfirmation(commentId),
                                            padding: EdgeInsets.all(4),
                                            constraints: BoxConstraints(),
                                            tooltip: 'Delete comment',
                                          ),
                                      ],
                                    ),
                                    SizedBox(height: 4),
                                    
                                    // Текст комментария
                                    Text(
                                      commentText,
                                      style: TextStyle(fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),
          
          // Поле для отправки нового комментария
          SafeArea(
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8) + MediaQuery.of(context).viewInsets,
              decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  spreadRadius: 1,
                  blurRadius: 3,
                  offset: Offset(0, -1),
                ),
              ],
            ),
            child: Row(
              children: [
                // Аватарка текущего пользователя
                CircleAvatar(
                  radius: 18,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: _currentUserProfileImage.isNotEmpty
                      ? CachedNetworkImageProvider(ApiConfig.formatImageUrl(_currentUserProfileImage))
                      : null,
                  child: _currentUserProfileImage.isEmpty
                      ? Icon(Icons.person, color: Colors.grey.shade600, size: 18)
                      : null,
                ),
                SizedBox(width: 12),
                
                // Поле ввода
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    decoration: InputDecoration(
                      hintText: 'Add a comment...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: EdgeInsets.symmetric(horizontal: 16),
                    ),
                    maxLines: null,
                    textInputAction: TextInputAction.newline,
                  ),
                ),
                SizedBox(width: 8),
                
                // Кнопка отправки
                _isSubmitting
                    ? Container(
                        width: 36,
                        height: 36,
                        padding: EdgeInsets.all(8),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: Icon(Icons.send, color: Colors.blue),
                        onPressed: _submitComment,
                      ),
              ],
            ),
          ),
          ),
        ],
      ),
    );
  }

  // Показать диалог подтверждения удаления
  void _showDeleteConfirmation(int commentId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Delete Comment'),
          content: Text('Are you sure you want to delete this comment?'),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: Text('Delete', style: TextStyle(color: Colors.red)),
              onPressed: () {
                Navigator.of(context).pop();
                _deleteComment(commentId);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 