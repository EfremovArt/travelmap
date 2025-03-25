import 'dart:io';
import 'package:flutter/material.dart';
import '../models/post.dart';

/// Виджет карточки поста, используемый в ленте.
class PostCard extends StatelessWidget {
  final Post post;
  final File? userProfileImage;
  final String userFullName;
  final Function(Post) onShowCommentsModal;
  final Function(Post) onShowOnMap;
  final Function(Post) onEditPost;
  final Function(Post) onDeletePost;
  final bool isCurrentUserPost;
  final Function(Post)? onLikePost;
  final Function(Post)? onFavoritePost;
  final Function(String)? onFollowUser;
  final bool isFollowing;
  final Function(Post, int)? onImageTap;

  const PostCard({
    Key? key,
    required this.post,
    required this.userProfileImage,
    required this.userFullName,
    required this.onShowCommentsModal,
    required this.onShowOnMap,
    required this.onEditPost,
    required this.onDeletePost,
    required this.isCurrentUserPost,
    this.onLikePost,
    this.onFavoritePost,
    this.onFollowUser,
    this.isFollowing = false,
    this.onImageTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Для галереи - если у поста одно изображение, используем его,
    // иначе используем все имеющиеся изображения
    final List<File> galleryImages = post.images.isNotEmpty ? post.images : [];
    
    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Шапка поста (аватар, имя, количество комментариев и дата)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Аватарка пользователя (из профиля)
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: userProfileImage != null
                    ? FileImage(userProfileImage!)
                    : null,
                  child: userProfileImage == null
                    ? Icon(Icons.person, color: Colors.grey.shade600, size: 24)
                    : null,
                ),
                
                SizedBox(width: 12),
                
                // Информация о пользователе и комментариях
                Expanded(
                  child: Row(
                    children: [
                      // Имя пользователя (из профиля)
                      Text(
                        userFullName, // Полное имя из профиля
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      SizedBox(width: 8),
                      // Иконка комментариев с их количеством (кликабельная)
                      GestureDetector(
                        onTap: () => onShowCommentsModal(post),
                        child: Row(
                          children: [
                            Icon(Icons.comment, size: 16, color: Colors.grey),
                            SizedBox(width: 4),
                            Text(
                              "5", // Количество комментариев
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      // Кнопка Follow/Following для чужих постов
                      if (!isCurrentUserPost && onFollowUser != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: ElevatedButton(
                            onPressed: () => onFollowUser!(post.user),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isFollowing ? Colors.grey : Colors.blue,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              minimumSize: Size(60, 24),
                              textStyle: TextStyle(fontSize: 12),
                            ),
                            child: Text(isFollowing ? 'Following' : 'Follow'),
                          ),
                        ),
                    ],
                  )
                ),
                
                // Дата и время публикации
                Text(
                  "${post.createdAt.day}.${post.createdAt.month}.${post.createdAt.year} ${post.createdAt.hour.toString().padLeft(2, '0')}:${post.createdAt.minute.toString().padLeft(2, '0')}",
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Описание поста
          if (post.description.isNotEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                post.description,
                style: TextStyle(fontSize: 15),
              ),
            ),
          
          // Галерея изображений с кнопками
          if (galleryImages.isNotEmpty)
            Stack(
              children: [
                // Изображения
                Container(
                  height: 300,
                  child: PageView.builder(
                    itemCount: galleryImages.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          // При нажатии на изображение открываем просмотрщик на весь экран
                          if (onImageTap != null) {
                            onImageTap!(post, index);
                          }
                        },
                        child: Image.file(
                          galleryImages[index],
                          fit: BoxFit.cover,
                        ),
                      );
                    },
                  ),
                ),
                
                // Индикатор количества изображений
                if (galleryImages.length > 1)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "${galleryImages.length} фото",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                
                // Кнопки редактирования и удаления для своих постов
                // ИЛИ кнопки лайка, избранного и комментариев для чужих постов
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: isCurrentUserPost 
                      ? _buildCurrentUserPostControls() 
                      : _buildOtherUserPostControls(),
                  ),
                ),
              ],
            ),
          
          // Геолокация и информация о подписчиках (компактная)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                // Геолокация - полное название места
                Expanded(
                  child: GestureDetector(
                    onTap: () => onShowOnMap(post),
                    child: Row(
                      children: [
                        Icon(Icons.location_on, size: 18, color: Colors.blue),
                        SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            post.locationName, // Полное название локации
                            style: TextStyle(
                              color: Colors.blue,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Информация о подписчиках
                Row(
                  children: [
                    // Аватарки подписчиков
                    SizedBox(
                      width: 60,
                      height: 24,
                      child: Stack(
                        children: [
                          for (int i = 0; i < 3; i++)
                            Positioned(
                              left: i * 20.0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: CircleAvatar(
                                  radius: 10,
                                  backgroundImage: NetworkImage(
                                    "https://randomuser.me/api/portraits/men/${30 + i}.jpg"
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SizedBox(width: 4),
                    // Количество подписчиков
                    Text(
                      "+1.2K",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  // Элементы управления для своего поста (редактирование и удаление)
  Widget _buildCurrentUserPostControls() {
    return Column(
      children: [
        // Кнопка редактирования
        IconButton(
          icon: Icon(Icons.edit, color: Colors.white, size: 22),
          onPressed: () => onEditPost(post),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
        ),
        // Разделительная линия
        Container(
          height: 1,
          width: 20,
          color: Colors.white.withOpacity(0.3),
        ),
        // Кнопка удаления
        IconButton(
          icon: Icon(Icons.delete, color: Colors.white, size: 22),
          onPressed: () => onDeletePost(post),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
        ),
      ],
    );
  }
  
  // Элементы управления для чужого поста (избранное, лайк, комментарии)
  Widget _buildOtherUserPostControls() {
    return Column(
      children: [
        // Кнопка добавления в избранное
        IconButton(
          icon: Icon(Icons.star_border, color: Colors.white, size: 22),
          onPressed: onFavoritePost != null ? () => onFavoritePost!(post) : null,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
        ),
        // Разделительная линия
        Container(
          height: 1,
          width: 20,
          color: Colors.white.withOpacity(0.3),
        ),
        // Кнопка лайка
        IconButton(
          icon: Icon(Icons.favorite_border, color: Colors.white, size: 22),
          onPressed: onLikePost != null ? () => onLikePost!(post) : null,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
        ),
        // Разделительная линия
        Container(
          height: 1,
          width: 20,
          color: Colors.white.withOpacity(0.3),
        ),
        // Кнопка комментариев
        IconButton(
          icon: Icon(Icons.comment, color: Colors.white, size: 22),
          onPressed: () => onShowCommentsModal(post),
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(
            minWidth: 40,
            minHeight: 40,
          ),
        ),
      ],
    );
  }
} 