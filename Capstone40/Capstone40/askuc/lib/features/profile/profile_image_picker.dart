import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../services/auth_service.dart';

class ProfileImagePicker extends StatefulWidget {
  const ProfileImagePicker({super.key, this.photoUrl, this.onUpdated});

  final String? photoUrl;
  final VoidCallback? onUpdated;

  @override
  State<ProfileImagePicker> createState() => _ProfileImagePickerState();
}

class _ProfileImagePickerState extends State<ProfileImagePicker> {
  bool _isUploading = false;
  Uint8List? _selectedImageBytes;

  Future<void> _pickAndUploadImage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You must be signed in to update your profile image.'),
        ),
      );
      return;
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 512,
      maxHeight: 512,
    );

    if (pickedFile == null) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      final imageBytes = await pickedFile.readAsBytes();
      if (!mounted) return;

      if (imageBytes.lengthInBytes > 600 * 1024) {
        throw StateError('Please choose a smaller image.');
      }

      setState(() {
        _selectedImageBytes = imageBytes;
      });

      // A compressed image is stored with the signed-in user's Firestore
      // profile. This keeps the picture tied to the account and avoids a
      // Firebase Storage upload remaining in progress when Storage is not set
      // up for the project.
      final photoDataUrl = 'data:image/jpeg;base64,${base64Encode(imageBytes)}';
      await AuthService.updateStudentPhotoUrl(photoDataUrl);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile image updated successfully.')),
      );

      widget.onUpdated?.call();
    } on FirebaseException catch (error) {
      if (!mounted) return;
      final message = 'Failed to save image: ${error.message ?? error.code}';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to upload image: $error')));
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
            child: _selectedImageBytes != null
                ? ClipOval(
                    child: Image.memory(
                      _selectedImageBytes!,
                      fit: BoxFit.cover,
                      width: 80,
                      height: 80,
                    ),
                  )
                : hasImage
                ? _savedProfileImage(widget.photoUrl!)
                : const Icon(Icons.person, color: Color(0xFF0866E8), size: 38),
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
                  : const Icon(Icons.camera_alt, color: Colors.white, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _savedProfileImage(String photoUrl) {
    if (photoUrl.startsWith('data:image/')) {
      try {
        final encodedImage = photoUrl.split(',').last;
        return ClipOval(
          child: Image.memory(
            base64Decode(encodedImage),
            fit: BoxFit.cover,
            width: 80,
            height: 80,
          ),
        );
      } catch (_) {
        return const Icon(Icons.person, color: Color(0xFF0866E8), size: 38);
      }
    }

    return ClipOval(
      child: Image.network(
        photoUrl,
        fit: BoxFit.cover,
        width: 80,
        height: 80,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, color: Color(0xFF0866E8), size: 38);
        },
      ),
    );
  }
}
