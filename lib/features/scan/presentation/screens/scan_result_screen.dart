import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/settings/language_settings.dart';
import '../../../flashcards/domain/entities/flashcard.dart';
import '../providers/scan_controller.dart';

/// Runs OCR + extraction automatically as soon as it opens (no user
/// selection step) and shows what got added to the deck. Accepts one or
/// several page photos, processed in order and merged into one save.
class ScanResultScreen extends ConsumerStatefulWidget {
  const ScanResultScreen({super.key, required this.images});

  final List<Uint8List> images;

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
              const CircularProgressIndicator(),
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
                const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                const SizedBox(height: 12),
                Text('Nepodařilo se zpracovat fotky:\n$error', textAlign: TextAlign.center),
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
              return ListTile(
                title: Text(card.original),
                subtitle: card.exampleSentence.isEmpty ? null : Text(card.exampleSentence),
                trailing: Text(card.translation, style: Theme.of(context).textTheme.bodyMedium),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => context.go('/'),
            child: const Text('Hotovo'),
          ),
        ),
      ],
    );
  }
}
