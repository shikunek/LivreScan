import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/camera/gallery_picker.dart';

/// Lets the user photograph a book page (or pick one from the gallery),
/// then confirm it before it's sent off for OCR + vocabulary extraction.
class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  final _galleryPicker = GalleryPicker();

  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String? _error;
  FlashMode _flashMode = FlashMode.off;

  Uint8List? _capturedBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setUpCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _setUpCamera();
    }
  }

  Future<void> _setUpCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'Na zařízení nebyla nalezena žádná kamera.');
        return;
      }

      final backCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      setState(() {
        _controller = controller;
        _error = null;
        _initializeControllerFuture = controller.initialize();
      });
      await _initializeControllerFuture;
    } catch (e) {
      setState(() => _error = 'Kameru se nepodařilo spustit: $e');
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || controller.value.isTakingPicture) {
      return;
    }
    try {
      final file = await controller.takePicture();
      final bytes = await file.readAsBytes();
      setState(() => _capturedBytes = bytes);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fotku se nepodařilo pořídit: $e')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    final bytes = await _galleryPicker.pickImage();
    if (bytes == null) return;
    setState(() => _capturedBytes = bytes);
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await controller.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  void _retake() => setState(() => _capturedBytes = null);

  void _usePhoto() {
    final bytes = _capturedBytes;
    if (bytes == null) return;
    context.push('/scan/review', extra: bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Skenovat stránku'),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_capturedBytes != null) {
      return _CapturePreview(
        bytes: _capturedBytes!,
        onRetake: _retake,
        onUse: _usePhoto,
      );
    }

    if (_error != null) {
      return _CameraError(message: _error!, onRetry: _setUpCamera, onPickFromGallery: _pickFromGallery);
    }

    final controller = _controller;
    final initializeFuture = _initializeControllerFuture;
    if (controller == null || initializeFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<void>(
      future: initializeFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        return _CameraLiveView(
          controller: controller,
          flashMode: _flashMode,
          onToggleFlash: _toggleFlash,
          onCapture: _capture,
          onPickFromGallery: _pickFromGallery,
        );
      },
    );
  }
}

class _CameraLiveView extends StatelessWidget {
  const _CameraLiveView({
    required this.controller,
    required this.flashMode,
    required this.onToggleFlash,
    required this.onCapture,
    required this.onPickFromGallery,
  });

  final CameraController controller;
  final FlashMode flashMode;
  final VoidCallback onToggleFlash;
  final VoidCallback onCapture;
  final VoidCallback onPickFromGallery;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio,
            child: CameraPreview(controller),
          ),
        ),
        // Framing guide so the user lines the page up straight.
        Positioned.fill(
          child: IgnorePointer(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            onPressed: onToggleFlash,
            icon: Icon(
              flashMode == FlashMode.torch ? Icons.flash_on : Icons.flash_off,
              color: Colors.white,
            ),
            style: IconButton.styleFrom(backgroundColor: Colors.black45),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 24,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: onPickFromGallery,
                icon: const Icon(Icons.photo_library, color: Colors.white, size: 32),
              ),
              _ShutterButton(onPressed: onCapture),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ],
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 4),
        ),
        padding: const EdgeInsets.all(4),
        child: const DecoratedBox(
          decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        ),
      ),
    );
  }
}

class _CapturePreview extends StatelessWidget {
  const _CapturePreview({required this.bytes, required this.onRetake, required this.onUse});

  final Uint8List bytes;
  final VoidCallback onRetake;
  final VoidCallback onUse;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(child: Center(child: Image.memory(bytes))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRetake,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Znovu'),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: onUse,
                  icon: const Icon(Icons.check),
                  label: const Text('Použít fotku'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry, required this.onPickFromGallery});

  final String message;
  final VoidCallback onRetry;
  final VoidCallback onPickFromGallery;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white54, size: 48),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.white), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            FilledButton(onPressed: onRetry, child: const Text('Zkusit znovu')),
            TextButton(
              onPressed: onPickFromGallery,
              child: const Text('Vybrat fotku z galerie'),
            ),
          ],
        ),
      ),
    );
  }
}
