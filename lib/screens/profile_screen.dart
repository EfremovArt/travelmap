import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
  
  File? _profileImage;
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isEditing = false;
  
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
      
      setState(() {
        _firstNameController.text = prefs.getString('firstName') ?? '';
        _lastNameController.text = prefs.getString('lastName') ?? '';
        _emailController.text = prefs.getString('email') ?? '';
        
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
            const SnackBar(content: Text('Profile saved successfully'))
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
          const SnackBar(content: Text('Error saving profile'))
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
          'Select image from',
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
                'Gallery',
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
                'Camera',
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
  
  // Delete account
  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Account?',
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(
              'Delete',
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
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear(); // Delete all user data
        
        setState(() {
          _profileImage = null;
          _firstNameController.clear();
          _lastNameController.clear();
          _emailController.clear();
          _birthdayController.clear();
          _selectedDate = null;
          _isEditing = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Account deleted successfully'))
          );
        }
      } catch (e) {
        print('Error deleting account: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error deleting account'))
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
          'Profile',
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
                          
                          // Delete account button (only in edit mode)
                          if (_isEditing)
                            TextButton.icon(
                              onPressed: _deleteAccount,
                              icon: const Icon(
                                Icons.delete_forever,
                                color: Colors.red,
                              ),
                              label: Text(
                                'Delete Account',
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
                  child: _profileImage != null
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
              _isEditing ? "Edit Profile" : "Profile",
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
              'Personal Information',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade700,
              ),
            ),
            const SizedBox(height: 16),
            _buildInfoItem('First Name', _firstNameController.text),
            const Divider(),
            _buildInfoItem('Last Name', _lastNameController.text),
            const Divider(),
            _buildInfoItem('Email', _emailController.text),
            const Divider(),
            _buildInfoItem('Birthday', _birthdayController.text),
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
            value.isNotEmpty ? value : 'Not provided',
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
              'Edit Profile',
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
                hintText: 'First name',
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
                  return 'Please enter your first name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                hintText: 'Last name',
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
                  return 'Please enter your last name';
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
                  return 'Please enter your email';
                }
                
                final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                if (!emailRegex.hasMatch(value)) {
                  return 'Please enter a valid email';
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
                hintText: 'Birthday',
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