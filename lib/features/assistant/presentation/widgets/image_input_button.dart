import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/localization/app_localizations.dart';

class ImageInputButton extends StatelessWidget {
  final void Function(String imagePath) onImageSelected;
  const ImageInputButton({super.key, required this.onImageSelected});

  Future<void> _handleTap(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded, color: AppColors.gold),
              title: const Text('Take Photo',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded, color: AppColors.gold),
              title: const Text('Choose from Gallery',
                  style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null || !context.mounted) return;

    final permission = source == ImageSource.camera
        ? await Permission.camera.request()
        : await Permission.photos.request();

    if (!permission.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(source == ImageSource.camera
                ? 'Camera permission is required.'
                : 'Photo library permission is required.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    final file = await ImagePicker().pickImage(
      source: source,
      imageQuality: 85,
    );
    if (file != null) {
      onImageSelected(file.path);
      // TODO: Task 5.2 — OCR pipeline'a gönder
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _handleTap(context),
      child: SizedBox(
        width: 40, height: 40,
        child: Icon(
          Icons.camera_alt_outlined,
          color: Colors.white.withOpacity(0.4),
          size: 22,
        ),
      ),
    );
  }
}