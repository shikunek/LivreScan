import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants.dart';
import '../../../flashcards/domain/entities/flashcard.dart';
import '../providers/scan_controller.dart';

/// Runs OCR + extraction automatically as soon as it opens (no user
/// selection step) and shows what got added to the deck.
class ScanResultScreen extends ConsumerStatefulWidget {
  const ScanResultScreen({super.key, required this.imageBytes});

  final Uint8List imageBytes;

  @override
  ConsumerState<ScanResultScreen> createState() => _ScanResultScreenState();
}

class _ScanResultScreenState extends ConsumerState<ScanResultScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(scanControllerProvider.notifier).processAndSave(
            imageBytes: widget.imageBytes,
            sourceLang: kDefaultSourceLang,
            targetLang: kDefaultTargetLang,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(scanControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nové kartičky')),
      body: state.when(
        loading: () => const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Rozpoznávám text a hledám slovíčka…'),
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
                Text('Nepodařilo se zpracovat fotku:\n$error', textAlign: TextAlign.center),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => ref.read(scanControllerProvider.notifier).processAndSave(
                        imageBytes: widget.imageBytes,
                        sourceLang: kDefaultSourceLang,
                        targetLang: kDefaultTargetLang,
                      ),
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
      return const Center(child: Text('Na téhle stránce se nenašla žádná nová slovíčka.'));
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
