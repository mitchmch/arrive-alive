import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Selects one bounded gallery image and copies it into app-owned storage.
///
/// Only the local path is persisted in the profile. A future backend can upload
/// this file separately; the app never represents a local image as uploaded.
class ProfilePhotoService {
  ProfilePhotoService({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  final ImagePicker _picker;

  Future<String?> selectAndStore(int userId) async {
    final selected = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 78,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (selected == null) return null;

    final directory = await getApplicationDocumentsDirectory();
    final photos = Directory(p.join(directory.path, 'profile_photos'));
    await photos.create(recursive: true);
    final extension = p.extension(selected.path).toLowerCase();
    final safeExtension =
        const {'.jpg', '.jpeg', '.png', '.webp'}.contains(extension)
            ? extension
            : '.jpg';
    final revision = DateTime.now().microsecondsSinceEpoch;
    final destination =
        p.join(photos.path, 'user_${userId}_$revision$safeExtension');
    return (await File(selected.path).copy(destination)).path;
  }

  Future<void> keepOnly(int userId, String? keepPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final photos = Directory(p.join(directory.path, 'profile_photos'));
    if (!await photos.exists()) return;
    await for (final candidate in photos.list().where(
          (entry) =>
              entry is File &&
              p.basename(entry.path).startsWith('user_${userId}_') &&
              entry.path != keepPath,
        )) {
      await candidate.delete();
    }
  }

  Future<void> remove(String? path) async {
    if (path == null || path.isEmpty) return;
    final file = File(path);
    if (await file.exists()) await file.delete();
  }
}
