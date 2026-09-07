import 'dart:io';
import 'dart:typed_data';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

/// Thin wrapper around ML Kit's on-device text recognizer.
class TextRecognizerService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<String> recognize(Uint8List imageBytes) async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/livrescan_scan_${DateTime.now().microsecondsSinceEpoch}.jpg');
    await file.writeAsBytes(imageBytes);
    try {
      final input = InputImage.fromFile(file);
      final result = await _recognizer.processImage(input);
      return result.text;
    } finally {
      await file.delete();
    }
  }

  void dispose() => _recognizer.close();
}
