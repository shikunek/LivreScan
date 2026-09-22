import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/settings/language_settings.dart';
import '../../../flashcards/domain/entities/flashcard.dart';
import '../../domain/entities/scan_destination.dart';
import '../providers/scan_controller.dart';

/// Runs OCR + extraction automatically as soon as it opens (no user
/// selection step) and shows what got added to the deck. Accepts one or
/// several page photos, processed in order and merged into one save.
class ScanResultScreen extends ConsumerStatefulWidget {
  const ScanResultScreen({
    super.key,
    required this.images,
    this.destination = const DefaultDeck(),
  });

  final List<Uint8List> images;
  final ScanDestination destination;

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_run);
  }

  void _run() {
    final languages = ref.read(languageSettingsProvider);
    ref.read(scanControllerProvider.notifier).processAndSave(
          images: widget.images,
          sourceLang: languages.source,
          targetLang: languages.target,
          destination: widget.destination,
        );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanControllerProvider);
    final progress = ref.watch(scanProgressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nové kartičky')),
      body: state.when(
        loading: () => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CupertinoActivityIndicator(radius: 14),
              const SizedBox(height: 16),
              Text(
                progress == null || progress.total <= 1
                    ? 'Rozpoznávám text a hledám slovíčka…'
                    : 'Zpracovávám stránku ${progress.current} z ${progress.total}…',
              ),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 12),
                Text(_friendlyError(error), textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _run,
                  child: const Text('Zkusit znovu'),
                ),
              ],
            ),
          ),
        ),
        data: (cards) => _ResultList(cards: cards),
      ),
    );
  }
}

/// What went wrong, in words the user can act on. Unknown errors keep the
/// technical text so they can still be reported.
String _friendlyError(Object error) {
  if (error is DioException) {
    final status = error.response?.statusCode;
    // The backend's own errors are `{"detail": {"message": ..., "reason":
    // ...}}` (a machine-readable reason alongside the English message it
    // logs) -- see backend/app/main.py.
    final body = error.response?.data;
    final detail = body is Map ? body['detail'] : null;
    final reasonCode = detail is Map ? detail['reason'] as String? : null;

    if (reasonCode == 'quota_exceeded') {
      return 'Dnešní počet zdarma naskenovaných stránek je vyčerpaný.\nZkus to zítra.';
    }
    if (reasonCode == 'unauthorized') {
      return 'Appka potřebuje aktualizaci, aby mohla dál skenovat.';
    }
    if (status == 429 || status == 503) {
      return 'Server je teď vytížený.\nZkus to za chvilku.';
    }
    if (status != null && status >= 500) {
      return 'Server teď nedokázal stránku zpracovat.\nZkus to znovu.';
    }
    if (error.type == DioExceptionType.connectionError ||
        error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.receiveTimeout) {
      return 'Nepodařilo se spojit se serverem.\nZkontroluj připojení k internetu.';
    }
  }
  return 'Nepodařilo se zpracovat fotky:\n$error';
}

class _ResultList extends StatelessWidget {
  const _ResultList({required this.cards});

  final List<Flashcard> cards;

  @override
  Widget build(BuildContext context) {
    if (cards.isEmpty) {
      return const Center(child: Text('Na těchhle stránkách se nenašla žádná nová slovíčka.'));
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Přidáno ${cards.length} ${cards.length == 1 ? 'kartička' : 'kartiček'}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: cards.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final card = cards[index];
              // The example sentence is still saved with the card, just not
              // shown here for now.
              return ListTile(
                title: Text(card.original),
                trailing: Text(card.translation, style: Theme.of(context).textTheme.bodyMedium),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            style: pillButtonStyle,
            onPressed: () => context.go('/'),
            child: const Text('Hotovo'),
          ),
        ),
      ],
    );
  }
}
