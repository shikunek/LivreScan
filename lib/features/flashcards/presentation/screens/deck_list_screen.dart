import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/languages.dart';
import '../../../../shared/widgets/language_pair_bar.dart';
import '../../domain/entities/deck.dart';
import '../providers/decks_provider.dart';

class DeckListScreen extends ConsumerWidget {
  const DeckListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final decks = ref.watch(decksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('LivreScan')),
      body: Column(
        children: [
          const LanguagePairBar(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(decksProvider.future),
              child: decks.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => _ErrorState(
                  error: error,
                  onRetry: () => ref.invalidate(decksProvider),
                ),
                data: (decks) => decks.isEmpty
                    ? ListView(
                        children: const [
                          Padding(
                            padding: EdgeInsets.only(top: 120),
                            child: Center(child: Text('Zatím žádné decky. Naskenuj stránku knihy.')),
                          ),
                        ],
                      )
                    : ListView.separated(
                        itemCount: decks.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final deck = decks[index];
                          return _DeckTile(deck: deck);
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/scan'),
        icon: const Icon(Icons.camera_alt),
        label: const Text('Skenovat stránku'),
      ),
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(deck.name),
      subtitle: Text(
        '${languageByCode(deck.sourceLang).name} → ${languageByCode(deck.targetLang).name}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/deck/${deck.id}/review'),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 80),
              Text('Nepodařilo se načíst decky:\n$error', textAlign: TextAlign.center),
              const SizedBox(height: 20),
              FilledButton(onPressed: onRetry, child: const Text('Zkusit znovu')),
            ],
          ),
        ),
      ],
    );
  }
}
