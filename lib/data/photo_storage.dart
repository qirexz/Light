import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Picks an image (camera or gallery) and copies it into the app's own
/// documents directory under progress_photos/, so it survives even if
/// the original picked file (e.g. a temp camera capture) gets cleaned
/// up by the OS. Returns the saved absolute path, or null if the user
/// cancelled the picker.
class PhotoStorage {
  static final _picker = ImagePicker();
  static const _uuid = Uuid();

  static Future<String?> pickAndStore({required bool fromCamera}) async {
    final picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (picked == null) return null;

    final docsDir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(docsDir.path, 'progress_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final ext = p.extension(picked.path).isEmpty ? '.jpg' : p.extension(picked.path);
    final destPath = p.join(photosDir.path, '${_uuid.v4()}$ext');
    await File(picked.path).copy(destPath);
    return destPath;
  }

  static Future<void> deleteIfExists(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
