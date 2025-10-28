import 'dart:io';
import 'package:flutter/material.dart';
import '../models/comment.dart';
import '../services/social_service.dart';
import '../utils/date_formatter.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import '../utils/logger.dart';
import 'package:cached_network_image/cached_network_image.dart';

class CommentsScreen extends StatefulWidget {
  final String photoId;
  final String photoUrl;

  const CommentsScreen({
    Key? key,
    required this.photoId,
    required this.photoUrl,
  }) : super(key: key);

  @override
  _CommentsScreenState createState() => _CommentsScreenState();
}

class _CommentsScreenState extends State<CommentsScreen> {
  final SocialService _socialService = SocialService();
  final TextEditingController _commentController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AuthService _authService = AuthService();
  
  List<Comment> _comments = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  bool _hasMoreComments = true;
  int _currentPage = 1;
  int _totalComments = 0;
  String _errorMessage = '';
  bool _isLoggedIn = false;
  bool _photoExists = true;
  int _currentUserId = 0;
  int _photoOwnerId = 0; // ID владельца фото/поста

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    // Проверка авторизации и загрузка комментариев
    _checkAuthAndLoadPhoto();
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
  
  // Проверка существования фотографии перед загрузкой комментариев
  Future<void> _checkAuthAndLoadPhoto() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    // Проверяем валидность ID фотографии
    if (widget.photoId == null || widget.photoId.isEmpty || widget.photoId == 'undefined' || widget.photoId == 'null') {
      setState(() {
        _errorMessage = 'Invalid photo ID';
        _photoExists = false;
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
    
    // Проверяем существование фотографии
    try {
      AppLogger.log('📷 Checking photo with ID: ${widget.photoId}');
      final result = await _socialService.getComments(widget.photoId, page: 1, perPage: 1);
      
      if (result['success'] == false) {
        // Обрабатываем ситуацию, когда фотография не найдена
        setState(() {
          _errorMessage = 'Photo not found or has been deleted';
          _photoExists = false;
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
      
      // Получаем информацию о владельце фото из первого комментария, если есть комментарии
      if (result['comments'] is List && (result['comments'] as List).isNotEmpty) {
        final photoInfo = await _socialService.getPhotoInfo(widget.photoId);
        if (photoInfo['success'] == true && photoInfo['photo'] != null) {
          setState(() {
            _photoOwnerId = photoInfo['photo']['userId'] is int 
                ? photoInfo['photo']['userId'] 
                : int.tryParse(photoInfo['photo']['userId'].toString()) ?? 0;
          });
          AppLogger.log('📷 Photo owner ID: $_photoOwnerId');
        }
      }
      
      // Фотография существует, проверяем авторизацию и загружаем комментарии
      _photoExists = true;
      _checkAuthAndLoadComments();
    } catch (e) {
      setState(() {
        _errorMessage = 'Error checking photo: $e';
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load photo information'),
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
      AppLogger.log('🔄 Loading comments for photo ID: ${widget.photoId}');
      final result = await _socialService.getComments(
        widget.photoId,
        page: _currentPage,
        perPage: 20,
      );
      
      if (result['success'] == true) {
        // Извлекаем ID владельца фото, если он есть в ответе
        if (result.containsKey('photoOwnerId')) {
          final ownerId = result['photoOwnerId'];
          setState(() {
            _photoOwnerId = ownerId is int ? ownerId : int.tryParse(ownerId.toString()) ?? 0;
          });
          AppLogger.log('📷 Photo owner ID from comments: $_photoOwnerId');
        }
        
        final List<dynamic> commentsList = result['comments'];
        final List<Comment> parsedComments = commentsList.map((data) {
          return Comment.fromJson(data);
        }).toList();
        
        setState(() {
          if (_currentPage == 1) {
            _comments = parsedComments;
          } else {
            _comments.addAll(parsedComments);
          }
          
          _totalComments = result['pagination']['total'] ?? 0;
          _hasMoreComments = _comments.length < _totalComments;
          _currentPage++;
          _isLoading = false;
        });
      } else {
        // Проверяем наличие ошибки, связанной с отсутствием ресурса (404)
        bool isNotFoundError = result['error']?.contains('не найден') ?? false;
        
        setState(() {
          if (isNotFoundError) {
            // Обрабатываем случай, когда комментарии не найдены (пустой список)
            _errorMessage = '';
            _comments = [];
            _totalComments = 0;
            _hasMoreComments = false;
            _isLoading = false;
          } else {
            // Другие ошибки
            _errorMessage = result['error'] ?? 'Ошибка при загрузке комментариев';
            _isLoading = false;
          }
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
    if (comment.isEmpty || !_photoExists) return;
    
    setState(() {
      _isSubmitting = true;
      _errorMessage = '';
    });
    
    try {
      final result = await _socialService.addComment(widget.photoId, comment);
      
      if (result['success'] == true) {
        // Очищаем поле ввода
        _commentController.clear();
        
        // Добавляем новый комментарий непосредственно в список, 
        // без необходимости перезагружать все комментарии
        if (result['comment'] != null) {
          final newComment = Comment.fromJson(result['comment']);
          
          setState(() {
            // Добавляем комментарий в начало списка
            _comments.insert(0, newComment);
            _totalComments = _totalComments + 1;
            _isSubmitting = false;
          });
        } else {
          // Если по какой-то причине данные комментария не доступны,
          // перезагружаем полностью
          setState(() {
            _currentPage = 1;
            _hasMoreComments = true;
            _isSubmitting = false;
          });
          
          await _loadComments();
        }
      } else {
        // Проверяем наличие ошибки, связанной с отсутствием фотографии
        bool isNotFoundError = result['error']?.contains('не найдена') ?? false;
        
        setState(() {
          _isSubmitting = false;
          
          if (isNotFoundError) {
            // Показываем более дружелюбное сообщение об ошибке
            _errorMessage = 'Не удалось добавить комментарий: фотография не найдена или была удалена';
            
            // Обновляем UI для отображения состояния отсутствия фотографии
            _comments = [];
            _totalComments = 0;
            _hasMoreComments = false;
            _photoExists = false;
          } else {
            _errorMessage = result['error'] ?? 'Ошибка при добавлении комментария';
          }
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
      
      final result = await _socialService.deleteComment(commentId);
      
      if (result['success'] == true) {
        AppLogger.log('✅ Комментарий успешно удален на сервере: $commentId');
        // Удаляем комментарий из списка
        setState(() {
          _comments.removeWhere((c) => c.id == commentId);
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
  bool _canDeleteComment(Comment comment) {
    // Комментарий можно удалить, если:
    // 1. Пользователь является автором комментария
    // 2. Пользователь является владельцем фотографии
    AppLogger.log('🔍 Проверка прав на удаление: commentUserId=${comment.userId}, currentUserId=$_currentUserId, photoOwnerId=$_photoOwnerId');
    return comment.userId == _currentUserId || _currentUserId == _photoOwnerId;
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
          // Заголовок с превью и количеством комментариев
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
                            return CommentItem(
                              comment: comment, 
                              canDelete: _canDeleteComment(comment),
                              onDelete: () => _showDeleteConfirmation(comment.id),
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

// Виджет для отображения одного комментария
class CommentItem extends StatelessWidget {
  final Comment comment;
  final bool canDelete;
  final VoidCallback? onDelete;

  const CommentItem({
    Key? key, 
    required this.comment, 
    this.canDelete = false,
    this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final String? profileImageUrl = comment.userProfileImageUrl;
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
                      '${comment.userFirstName ?? ''} ${comment.userLastName ?? ''}'.trim(),
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
                      DateFormatter.formatDateTime(comment.createdAt),
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
                  comment.text,
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