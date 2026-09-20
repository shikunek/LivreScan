import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/languages.dart';
import '../../domain/entities/flashcard.dart';
import '../providers/deck_cards_provider.dart';
import '../providers/decks_provider.dart';

/// Every word/phrase saved in one deck, newest first.
class WordListScreen extends ConsumerWidget {
  const WordListScreen({super.key, required this.deckId});

  final int deckId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(deckCardsProvider(deckId));
    final deck = ref.watch(decksProvider).valueOrNull?.where((d) => d.id == deckId).firstOrNull;
    final languages = deck == null
        ? null
        : '${languageByCode(deck.sourceLang).name} → ${languageByCode(deck.targetLang).name}';

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: cards.when(
          loading: () => const Center(child: CupertinoActivityIndicator(radius: 14)),
          error: (error, _) => Center(
            child: Text('Nepodařilo se načíst slovíčka:\n$error', textAlign: TextAlign.center),
          ),
          data: (cards) => CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(
                child: _Header(subtitle: [?languages, _wordCount(cards.length)].join(' · ')),
              ),
              if (cards.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        'V tomhle decku zatím nejsou žádná slovíčka.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.inkSecondary),
                      ),
                    ),
                  ),
                )
              else
                SliverList.separated(
                  itemCount: cards.length,
                  separatorBuilder: (_, _) => const Divider(),
                  itemBuilder: (context, index) => _WordRow(card: cards[index]),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }
}

String _wordCount(int count) {
  if (count == 1) return '1 slovíčko';
  if (count >= 2 && count <= 4) return '$count slovíčka';
  return '$count slovíček';
}

class _Header extends StatelessWidget {
  const _Header({required this.subtitle});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
          child: Text('Slovíčka', style: serifStyle(fontSize: 34, letterSpacing: -0.5)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 14),
          child: Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
          ),
        ),
        const Divider(),
      ],
    );
  }
}

class _WordRow extends StatelessWidget {
  const _WordRow({required this.card});

  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(card.original, style: const TextStyle(fontSize: 17, color: AppColors.ink)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              card.translation,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 16, color: AppColors.inkSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
