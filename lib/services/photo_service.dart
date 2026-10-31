import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Camera / gallery fallback for student photos.
class PhotoService {
  static final _picker = ImagePicker();

  static Future<Uint8List?> pick({required bool camera}) async {
    final file = await _picker.pickImage(
      source: camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
      preferredCameraDevice: CameraDevice.rear,
    );
    return file?.readAsBytes();
  }
}
