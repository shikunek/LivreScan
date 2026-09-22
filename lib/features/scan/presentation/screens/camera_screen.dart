import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/camera/gallery_picker.dart';
import '../../../../core/settings/language_settings.dart';
import '../../../flashcards/presentation/providers/decks_provider.dart';
import '../../../flashcards/domain/entities/deck.dart';
import '../../domain/entities/scan_destination.dart';
import '../widgets/scan_destination_picker.dart';

/// Lets the user photograph one or more book pages (or pick them from the
/// gallery), building up a queue of pages that all get sent off for
/// OCR + vocabulary extraction together once they tap "Hotovo".
class CameraScreen extends ConsumerStatefulWidget {
  const CameraScreen({super.key});

  @override
  ConsumerState<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends ConsumerState<CameraScreen> with WidgetsBindingObserver {
  final _galleryPicker = GalleryPicker();

  CameraController? _controller;
  Future<void>? _initializeControllerFuture;
  String? _error;
  FlashMode _flashMode = FlashMode.off;

  Uint8List? _capturedBytes;
  final List<Uint8List> _pages = [];

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
        // 4K: sharp preview, and the captured page keeps enough detail for
        // OCR to read small print (`high` is only 720p on iOS).
        ResolutionPreset.ultraHigh,
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
    final images = await _galleryPicker.pickMultipleImages();
    if (images.isEmpty) return;
    setState(() => _pages.addAll(images));
  }

  Future<void> _toggleFlash() async {
    final controller = _controller;
    if (controller == null) return;
    final next = _flashMode == FlashMode.off ? FlashMode.torch : FlashMode.off;
    await controller.setFlashMode(next);
    setState(() => _flashMode = next);
  }

  void _retake() => setState(() => _capturedBytes = null);

  /// Keeps the captured page and returns to the live camera so the user
  /// can photograph the next one, instead of leaving the screen.
  void _keepPageAndContinue() {
    final bytes = _capturedBytes;
    if (bytes == null) return;
    setState(() {
      _pages.add(bytes);
      _capturedBytes = null;
    });
  }

  void _removePage(int index) => setState(() => _pages.removeAt(index));

  Future<void> _finish() async {
    if (_pages.isEmpty) return;

    // Existing decks of the language pair being scanned; the user picks one
    // or a new deck (skipped when there is none yet).
    final languages = ref.read(languageSettingsProvider);
    // If the decks can't be loaded, don't lose the scan: fall back to the
    // default deck instead of asking.
    final decks = await ref.read(decksProvider.future).catchError((_) => const <Deck>[]);
    if (!mounted) return;
    final destination = await chooseScanDestination(
      context,
      decksForPair: [
        for (final deck in decks)
          if (deck.sourceLang == languages.source && deck.targetLang == languages.target) deck,
      ],
      now: DateTime.now(),
    );
    if (destination == null || !mounted) return;

    context.push(
      '/scan/review',
      extra: ScanRequest(images: List<Uint8List>.of(_pages), destination: destination),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        // The theme's AppBar title is dark ink; this screen is black.
        title: Text(
          _pages.isEmpty ? 'Skenovat stránku' : 'Skenovat stránky (${_pages.length})',
          style: const TextStyle(color: Colors.white),
        ),
      ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_capturedBytes != null) {
      return _CapturePreview(
        bytes: _capturedBytes!,
        hasMorePages: _pages.isNotEmpty,
        onRetake: _retake,
        onKeep: _keepPageAndContinue,
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
          pages: _pages,
          onToggleFlash: _toggleFlash,
          onCapture: _capture,
          onPickFromGallery: _pickFromGallery,
          onRemovePage: _removePage,
          onFinish: _finish,
        );
      },
    );
  }
}

class _CameraLiveView extends StatelessWidget {
  const _CameraLiveView({
    required this.controller,
    required this.flashMode,
    required this.pages,
    required this.onToggleFlash,
    required this.onCapture,
    required this.onPickFromGallery,
    required this.onRemovePage,
    required this.onFinish,
  });

  final CameraController controller;
  final FlashMode flashMode;
  final List<Uint8List> pages;
  final VoidCallback onToggleFlash;
  final VoidCallback onCapture;
  final VoidCallback onPickFromGallery;
  final ValueChanged<int> onRemovePage;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // CameraPreview already applies the correct (orientation-aware)
        // aspect ratio itself; wrapping it in another AspectRatio distorts it.
        Center(child: CameraPreview(controller)),
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (pages.isNotEmpty) ...[
                _PageThumbnailStrip(pages: pages, onRemove: onRemovePage),
                const SizedBox(height: 12),
              ],
              Row(
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
              if (pages.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: FilledButton.icon(
                    onPressed: onFinish,
                    icon: const Icon(Icons.check),
                    label: Text('Hotovo — zpracovat ${pages.length} ${_pageWord(pages.length)}'),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _pageWord(int count) {
  if (count == 1) return 'stránku';
  if (count >= 2 && count <= 4) return 'stránky';
  return 'stránek';
}

class _PageThumbnailStrip extends StatelessWidget {
  const _PageThumbnailStrip({required this.pages, required this.onRemove});

  final List<Uint8List> pages;
  final ValueChanged<int> onRemove;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: pages.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          return Stack(
            clipBehavior: Clip.none,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(pages[index], width: 48, height: 64, fit: BoxFit.cover),
              ),
              Positioned(
                top: -8,
                right: -8,
                child: GestureDetector(
                  onTap: () => onRemove(index),
                  child: const CircleAvatar(
                    radius: 10,
                    backgroundColor: Colors.black87,
                    child: Icon(Icons.close, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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
  const _CapturePreview({
    required this.bytes,
    required this.hasMorePages,
    required this.onRetake,
    required this.onKeep,
  });

  final Uint8List bytes;
  final bool hasMorePages;
  final VoidCallback onRetake;
  final VoidCallback onKeep;

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
                  onPressed: onKeep,
                  icon: const Icon(Icons.check),
                  label: Text(hasMorePages ? 'Přidat stránku' : 'Použít fotku'),
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
              child: const Text('Vybrat fotky z galerie'),
            ),
          ],
        ),
      ),
    );
  }
}
