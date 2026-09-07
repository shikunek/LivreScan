import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

/// Lets the user pick an existing photo of a book page from the gallery,
/// as an alternative to capturing a new one with the camera.
class GalleryPicker {
  final _picker = ImagePicker();

  Future<Uint8List?> pickImage() async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 2400,
      imageQuality: 90,
    );
    if (file == null) return null;
    return file.readAsBytes();
  }
}
