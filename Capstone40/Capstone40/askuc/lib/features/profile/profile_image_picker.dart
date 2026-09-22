import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';

class ProfileImagePicker extends StatefulWidget {
  const ProfileImagePicker({
    super.key,
    this.photoUrl,
    this.onUpdated,
  });

  final String? photoUrl;
  final VoidCallback? onUpdated;

  @override
  State<ProfileImagePicker> createState() => _ProfileImagePickerState();
}

class _ProfileImagePickerState extends State<ProfileImagePicker> {
  bool _isUploading = false;

  Future<void> _pickAndUploadImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to update your profile image.')),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
      maxHeight: 1200,
    );

    if (pickedFile == null) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final imageBytes = await pickedFile.readAsBytes();
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('student_profiles')
          .child('${user.uid}.jpg');

      await storageRef.putData(imageBytes, SettableMetadata(contentType: 'image/jpeg'));
      final downloadUrl = await storageRef.getDownloadURL();

      await AuthService.updateStudentPhotoUrl(downloadUrl);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully.')),
      );

      widget.onUpdated?.call();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = (widget.photoUrl ?? '').trim().isNotEmpty;

    return InkWell(
      onTap: _pickAndUploadImage,
      borderRadius: BorderRadius.circular(40),
      child: Stack(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: hasImage
                ? ClipOval(
                    child: Image.network(
                      widget.photoUrl!,
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.person,
                          color: Color(0xFF0866E8),
                          size: 38,
                        );
                      },
                    ),
                  )
                : const Icon(
                    Icons.person,
                    color: Color(0xFF0866E8),
                    size: 38,
                  ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                color: Color(0xFF0866E8),
                shape: BoxShape.circle,
              ),
              child: _isUploading
                  ? const Padding(
                      padding: EdgeInsets.all(5),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 14,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
