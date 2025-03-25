import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_sign_in/google_sign_in.dart';

// Встроенная реализация GoogleAuthService прямо в файл
class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      print('Ошибка при выходе из аккаунта Google: $e');
      throw Exception('Не удалось выйти из аккаунта Google: $e');
    }
  }
}

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _firstNameController = TextEditingController();
  final TextEditingController _lastNameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _birthdayController = TextEditingController();

  final GoogleAuthService _googleAuthService = GoogleAuthService();

  File? _profileImage;
  String? _profileImageUrl; // Для изображения из Google-аккаунта
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isEditing = false;
  bool _isGoogleAccount = false;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _birthdayController.dispose();
    super.dispose();
  }

  // Load user data from SharedPreferences
  Future<void> _loadUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final prefs = await SharedPreferences.getInstance();

      // Проверяем тип аутентификации
      final accessType = prefs.getString('access_type') ?? '';
      _isGoogleAccount = accessType == 'google';

      setState(() {
        _firstNameController.text = prefs.getString('firstName') ?? '';
        _lastNameController.text = prefs.getString('lastName') ?? '';
        _emailController.text = prefs.getString('user_email') ?? prefs.getString('email') ?? '';

        // Получаем URL изображения профиля для Google-аккаунта
        _profileImageUrl = prefs.getString('photoUrl');

        final birthday = prefs.getString('birthday');
        if (birthday != null && birthday.isNotEmpty) {
          _selectedDate = DateTime.parse(birthday);
          _birthdayController.text = DateFormat('MM/dd/yyyy').format(_selectedDate!);
        }

        final imagePath = prefs.getString('profileImage');
        if (imagePath != null && imagePath.isNotEmpty) {
          _profileImage = File(imagePath);
        }
      });
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Save user data to SharedPreferences
  Future<void> _saveUserData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      if (_formKey.currentState?.validate() ?? false) {
        final prefs = await SharedPreferences.getInstance();

        await prefs.setString('firstName', _firstNameController.text);
        await prefs.setString('lastName', _lastNameController.text);
        await prefs.setString('email', _emailController.text);

        if (_selectedDate != null) {
          await prefs.setString('birthday', _selectedDate!.toIso8601String());
        }

        if (_profileImage != null) {
          await prefs.setString('profileImage', _profileImage!.path);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Профиль успешно сохранен'))
          );
          setState(() {
            _isEditing = false;
          });
        }
      }
    } catch (e) {
      print('Error saving user data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ошибка при сохранении профиля'))
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Pick an image from gallery or camera
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedImage = await picker.pickImage(source: source);

      if (pickedImage != null) {
        setState(() {
          _profileImage = File(pickedImage.path);
          _profileImageUrl = null; // Сбрасываем URL, если выбрано локальное изображение
        });
      }
    } catch (e) {
      print('Error picking image: $e');
    }
  }

  // Show dialog to choose image source
  void _showImageSourceDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Выберите источник изображения',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(
                'Галерея',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(
                'Камера',
                style: GoogleFonts.poppins(),
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  // Select birthday date
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Colors.blue.shade700,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _birthdayController.text = DateFormat('MM/dd/yyyy').format(picked);
      });
    }
  }

  // Выход из аккаунта
  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Выйти из аккаунта?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите выйти из своего аккаунта?',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Отмена',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade700,
            ),
            child: Text(
              'Выйти',
              style: GoogleFonts.poppins(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() {
          _isLoading = true;
        });

        // Если это Google-аккаунт, выходим через сервис
        if (_isGoogleAccount) {
          await _googleAuthService.signOut();
        }

        // Очищаем данные пользователя
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (mounted) {
          // Перенаправляем на экран входа - используем простой подход
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        print('Ошибка при выходе из аккаунта: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ошибка при выходе из аккаунта'))
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Delete account
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Удалить аккаунт?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Вы уверены, что хотите удалить свой аккаунт? Это действие нельзя отменить.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Отмена',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              'Удалить',
              style: GoogleFonts.poppins(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        setState(() {
          _isLoading = true;
        });

        // Если это Google-аккаунт, выходим через сервис
        if (_isGoogleAccount) {
          await _googleAuthService.signOut();
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // Удаляем все данные пользователя

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Аккаунт успешно удален'))
          );

          // Перенаправляем на экран входа - используем простой подход
          Navigator.of(context).pushNamedAndRemoveUntil('/login', (route) => false);
        }
      } catch (e) {
        print('Ошибка при удалении аккаунта: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Ошибка при удалении аккаунта'))
          );
        }
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Toggle edit mode
  void _toggleEditMode() {
    setState(() {
      _isEditing = !_isEditing;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        title: Text(
          'Профиль',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          _isEditing
              ? IconButton(
            icon: const Icon(Icons.check, color: Colors.white),
            onPressed: _saveUserData,
          )
              : IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _toggleEditMode,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Profile header with image
          _buildProfileHeader(),

          // Profile information
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // User information
                    if (_isEditing)
                      _buildEditForm()
                    else
                      _buildProfileInfo(),

                    const SizedBox(height: 32),

                    // Sign out button
                    ElevatedButton.icon(
                      onPressed: _signOut,
                      icon: const Icon(
                        Icons.logout,
                        color: Colors.white,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      label: Text(
                        'Выйти из аккаунта',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Delete account button (only in edit mode)
                    if (_isEditing)
                      TextButton.icon(
                        onPressed: _deleteAccount,
                        icon: const Icon(
                          Icons.delete_forever,
                          color: Colors.red,
                        ),
                        label: Text(
                          'Удалить аккаунт',
                          style: GoogleFonts.poppins(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Build profile header with big image
  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      height: 260,
      decoration: BoxDecoration(
        color: Colors.blue.shade700,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              children: [
                // Profile image with border
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 4.0,
                    ),
                  ),
                  child: _profileImageUrl != null && _profileImage == null
                      ? ClipOval(
                    child: CachedNetworkImage(
                      imageUrl: _profileImageUrl!,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => CircularProgressIndicator(),
                      errorWidget: (context, url, error) => Icon(
                        Icons.person,
                        size: 80,
                        color: Colors.grey,
                      ),
                    ),
                  )
                      : _profileImage != null
                      ? ClipOval(
                    child: Image.file(
                      _profileImage!,
                      width: 160,
                      height: 160,
                      fit: BoxFit.cover,
                    ),
                  )
                      : const CircleAvatar(
                    radius: 80,
                    backgroundColor: Colors.grey,
                    child: Icon(
                      Icons.person,
                      size: 80,
                      color: Colors.white,
                    ),
                  ),
                ),

                // Camera icon for editing profile image
                if (_isEditing)
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: _showImageSourceDialog,
                      child: Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.camera_alt,
                          color: Colors.blue.shade700,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              _isEditing ? "Изменить профиль" : "Профиль",
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build profile information in view mode
  Widget _buildProfileInfo() {
    final TextStyle labelStyle = GoogleFonts.poppins(
      fontSize: 14,
      color: Colors.grey.shade600,
    );

    final TextStyle valueStyle = GoogleFonts.poppins(
      fontSize: 16,
      fontWeight: FontWeight.w500,
    );

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Личная информация',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoItem('Имя', _firstNameController.text),
            const Divider(),
            _buildInfoItem('Фамилия', _lastNameController.text),
            const Divider(),
            _buildInfoItem('Email', _emailController.text),
            const Divider(),
            _buildInfoItem('Дата рождения', _birthdayController.text),

            if (_isGoogleAccount) ...[
              const Divider(),
              _buildInfoItem('Аккаунт', 'Google'),
            ],
          ],
        ),
      ),
    );
  }

  // Build single info item for view mode
  Widget _buildInfoItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const Spacer(),
          Text(
            value.isNotEmpty ? value : 'Не указано',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // Build edit form in edit mode
  Widget _buildEditForm() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Редактировать профиль',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                hintText: 'Имя',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста, введите ваше имя';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                hintText: 'Фамилия',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста, введите вашу фамилию';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(
                hintText: 'Email',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Пожалуйста, введите ваш email';
                }

                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(value)) {
                  return 'Пожалуйста, введите корректный email';
                }

                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _birthdayController,
              readOnly: true,
              onTap: _selectDate,
              decoration: InputDecoration(
                hintText: 'Дата рождения',
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                suffixIcon: const Icon(Icons.calendar_month),
              ),
            ),
          ],
        ),
      ),
    );
  }
}