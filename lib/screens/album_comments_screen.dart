import 'dart:io';
import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/album_service.dart';
import '../utils/date_formatter.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';

class AlbumCommentsScreen extends StatefulWidget {
  final String albumId;
  final String albumTitle;
  final String? albumImageUrl;

  const AlbumCommentsScreen({
    Key? key,
    required this.albumId,
    required this.albumTitle,
    this.albumImageUrl,
  }) : super(key: key);

  @override
  _AlbumCommentsScreenState createState() => _AlbumCommentsScreenState();
}

class _AlbumCommentsScreenState extends State<AlbumCommentsScreen> {
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();
  
  List<Map<String, dynamic>> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasMoreComments = true;
  int _currentPage = 1;
  int _totalComments = 0;
  String _errorMessage = '';
  bool _isLoggedIn = false;
  bool _albumExists = true;
  int _currentUserId = 0;
  int _albumOwnerId = 0; // ID владельца альбома

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Проверка авторизации и загрузка комментариев
    _checkAuthAndLoadAlbum();
    _loadCurrentUserData();
  }
  
  // Обработчик прокрутки для пагинации
  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      if (!_isLoading && _hasMoreComments) {
        _loadComments();
      }
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  // Проверка существования альбома перед загрузкой комментариев
  Future<void> _checkAuthAndLoadAlbum() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    // Проверяем валидность ID альбома
    if (widget.albumId == null || widget.albumId.isEmpty || widget.albumId == 'undefined' || widget.albumId == 'null') {
      setState(() {
        _errorMessage = 'Invalid album ID';
        _albumExists = false;
        _isLoading = false;
      });
      
      // Показываем сообщение пользователю
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }
    
    // Проверяем существование альбома
    try {
      AppLogger.log('📷 Checking album with ID: ${widget.albumId}');
      final result = await AlbumService.getAlbumComments(widget.albumId, page: 1, perPage: 1);
      
      if (result['success'] == false) {
        // Обрабатываем ситуацию, когда альбом не найден
        setState(() {
          _errorMessage = 'Album not found or has been deleted';
          _albumExists = false;
          _isLoading = false;
        });
        
        // Показываем сообщение пользователю
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_errorMessage),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
        }
        return;
      }
      
      // Альбом существует, проверяем авторизацию и загружаем комментарии
      _albumExists = true;
      _checkAuthAndLoadComments();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking album: $e';
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load album information'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }
    
  // Проверка авторизации и загрузка комментариев
  Future<void> _checkAuthAndLoadComments() async {
    try {
      // Проверяем авторизацию
      final authResult = await _authService.checkAuth();
      
      setState(() {
        _isLoggedIn = authResult['isAuthenticated'] == true;
      });
      
      if (_isLoggedIn) {
        // Если пользователь авторизован, загружаем комментарии
        _loadComments();
      } else {
        // Если не авторизован, показываем сообщение
        setState(() {
          _errorMessage = 'Authentication required to view and add comments';
          _isLoading = false;
        });
        
        // Показываем диалог с предложением авторизоваться
        _showAuthDialog();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking authentication: $e';
        _isLoading = false;
      });
    }
  }

  // Загрузка данных текущего пользователя
  Future<void> _loadCurrentUserData() async {
    try {
      final userData = await UserService.getCurrentUserData();
      setState(() {
        _currentUserId = userData['id'] ?? 0;
      });
    } catch (e) {
      AppLogger.log('❌ Error loading current user data: $e');
    }
  }

  // Загрузка комментариев
  Future<void> _loadComments() async {
    if (!_hasMoreComments || !_isLoggedIn) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      AppLogger.log('🔄 Loading comments for album ID: ${widget.albumId}');
      final result = await AlbumService.getAlbumComments(widget.albumId, page: _currentPage, perPage: 20);
      
      if (result['success'] == true) {
        final List<dynamic> commentsList = result['comments'] ?? [];
        final List<Map<String, dynamic>> parsedComments = commentsList.map((data) {
          return Map<String, dynamic>.from(data);
        }).toList();
        
        setState(() {
          if (_currentPage == 1) {
            _comments = parsedComments;
          } else {
            _comments.addAll(parsedComments);
          }
          
          _totalComments = result['pagination']?['total'] ?? parsedComments.length;
          _hasMoreComments = _comments.length < _totalComments;
          _currentPage++;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = result['error'] ?? 'Ошибка при загрузке комментариев';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка при загрузке комментариев: $e';
        _isLoading = false;
      });
    }
  }
  
  // Отправка нового комментария
  Future<void> _submitComment() async {
    final comment = _commentController.text.trim();
    if (comment.isEmpty || !_albumExists) return;
    
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });
    
    try {
      final result = await AlbumService.addAlbumComment(widget.albumId, comment);
      
      if (result['success'] == true) {
        // Очищаем поле ввода
        _commentController.clear();
        
        // Перезагружаем комментарии
        setState(() {
          _currentPage = 1;
          _hasMoreComments = true;
          _isSubmitting = false;
        });
        
        await _loadComments();
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = result['error'] ?? 'Ошибка при добавлении комментария';
        });
        
        // Показываем уведомление пользователю
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_errorMessage),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Ошибка при отправке комментария: $e';
        _isSubmitting = false;
      });
      
      // Показываем уведомление пользователю
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Не удалось отправить комментарий'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Показываем диалоговое окно с предложением авторизоваться
  void _showAuthDialog() {
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Authentication Required'),
          content: Text('You need to log in to view and add comments'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Later'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
              },
              child: Text('Log In'),
            ),
          ],
        ),
      );
    }
  }

  // Удаление комментария
  Future<void> _deleteComment(int commentId) async {
    try {
      AppLogger.log('🗑️ Начинаем удаление комментария: $commentId');
      
      final result = await AlbumService.deleteAlbumComment(commentId.toString());
      
      if (result['success'] == true) {
        AppLogger.log('✅ Комментарий успешно удален на сервере: $commentId');
        // Удаляем комментарий из списка
        setState(() {
          _comments.removeWhere((c) => c['id'] == commentId);
          _totalComments = _totalComments - 1;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Comment deleted successfully')),
        );
      } else {
        final errorMsg = result['error'] ?? 'Failed to delete comment';
        AppLogger.log('⚠️ Ошибка при удалении комментария: $errorMsg');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg)),
        );
      }
    } catch (e) {
      AppLogger.log('❌ Ошибка при удалении комментария: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }
  
  // Проверка, может ли текущий пользователь удалить комментарий
  bool _canDeleteComment(Map<String, dynamic> comment) {
    // Комментарий можно удалить, если:
    // 1. Пользователь является автором комментария
    // 2. Пользователь является владельцем альбома
    final commentUserId = comment['user_id'] is int 
        ? comment['user_id'] 
        : int.tryParse(comment['user_id'].toString()) ?? 0;
    
    AppLogger.log('🔍 Проверка прав на удаление: commentUserId=$commentUserId, currentUserId=$_currentUserId, albumOwnerId=$_albumOwnerId');
    return commentUserId == _currentUserId || _currentUserId == _albumOwnerId;
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
          // Заголовок с количеством комментариев
          Container(
            padding: EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Comments ${_isLoading ? "" : "($_totalComments)"}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          Divider(height: 1),
          
          // Сообщение при ошибке авторизации
          if (!_isLoggedIn && !_isLoading)
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.lock, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'Authentication Required',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'You need to be logged in to view and add comments',
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          _checkAuthAndLoadComments();
                        },
                        child: Text('Try Again'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          
          // Список комментариев или индикатор загрузки
          if (_isLoggedIn || _isLoading)
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  setState(() {
                    _currentPage = 1;
                    _comments = [];
                    _hasMoreComments = true;
                  });
                  _checkAuthAndLoadComments();
                },
                child: _isLoading && _comments.isEmpty
                  ? Center(child: CircularProgressIndicator())
                  : _comments.isEmpty && _errorMessage.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.chat_bubble_outline, size: 70, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              'No comments yet',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Be the first to leave a comment!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : _errorMessage.isNotEmpty && _comments.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline, size: 70, color: Colors.red[300]),
                              SizedBox(height: 16),
                              Text(
                                _errorMessage,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.red[700],
                                ),
                              ),
                              SizedBox(height: 24),
                              if (_errorMessage.contains('авторизация') || _errorMessage.contains('authenticate'))
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
                                  },
                                  child: Text('Log In'),
                                ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _comments.length + (_hasMoreComments ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == _comments.length) {
                              // Показываем индикатор загрузки внизу списка
                              return Container(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                alignment: Alignment.center,
                                child: ElevatedButton.icon(
                                  icon: Icon(Icons.refresh),
                                  label: Text('Load More'),
                                  onPressed: _loadComments,
                                ),
                              );
                            }
                            
                            final comment = _comments[index];
                            return AlbumCommentItem(
                              comment: comment, 
                              canDelete: _canDeleteComment(comment),
                              onDelete: () => _showDeleteConfirmation(comment['id']),
                            );
                          },
                        ),
              ),
            ),
          
          // Поле ввода комментария
          if (_isLoggedIn)
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    offset: Offset(0, -1),
                    blurRadius: 3,
                  ),
                ],
              ),
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                      maxLines: null,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submitComment(),
                    ),
                  ),
                  SizedBox(width: 8),
                  // Кнопка отправки комментария
                  IconButton(
                    icon: _isSubmitting
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(Icons.send, color: Theme.of(context).primaryColor),
                    onPressed: _isSubmitting ? null : _submitComment,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Виджет для отображения одного комментария альбома
class AlbumCommentItem extends StatelessWidget {
  final Map<String, dynamic> comment;
  final bool canDelete;
  final VoidCallback? onDelete;

  const AlbumCommentItem({
    Key? key, 
    required this.comment, 
    this.canDelete = false,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String? profileImageUrl = comment['profile_image_url'];
    final String formattedImageUrl = ApiConfig.formatImageUrl(profileImageUrl);
    
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Аватар пользователя
          CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.8),
            backgroundImage: formattedImageUrl.isNotEmpty ? CachedNetworkImageProvider(formattedImageUrl) : null,
            child: formattedImageUrl.isEmpty ? Icon(Icons.person, color: Colors.white) : null,
          ),
          SizedBox(width: 12),
          // Информация о комментарии
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Верхняя строка с именем пользователя, датой и кнопкой удаления
                Row(
                  children: [
                    // Имя пользователя
                    Text(
                      '${comment['first_name'] ?? ''} ${comment['last_name'] ?? ''}'.trim(),
                      style: TextStyle(
                        fontFamily: 'Gilroy',
                        fontStyle: FontStyle.normal,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                    Spacer(),
                    // Дата
                    Text(
                      DateFormatter.formatDateTime(DateTime.parse(comment['created_at'])),
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 12,
                      ),
                    ),
                    // Кнопка удаления
                    if (canDelete && onDelete != null)
                      IconButton(
                        icon: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                        onPressed: onDelete,
                        padding: EdgeInsets.all(4),
                        constraints: BoxConstraints(),
                        tooltip: 'Delete comment',
                      ),
                  ],
                ),
                SizedBox(height: 4),
                // Текст комментария
                Text(
                  comment['comment'] ?? comment['text'] ?? '',
                  style: TextStyle(
                    fontFamily: 'Gilroy',
                    fontStyle: FontStyle.normal,
                    fontWeight: FontWeight.w400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
