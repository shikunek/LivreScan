import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../../core/languages.dart';
import '../../../scan/domain/entities/vocab_candidate.dart';
import '../../domain/entities/flashcard.dart';
import '../../../../core/di/providers.dart';
import '../providers/deck_cards_provider.dart';
import '../providers/decks_provider.dart';
import '../providers/review_controller.dart';

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
                  itemBuilder: (context, index) => _WordRow(deckId: deckId, card: cards[index]),
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
  const _WordRow({required this.deckId, required this.card});

  final int deckId;
  final Flashcard card;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: InkWell(
        highlightColor: AppColors.hairline,
        onTap: () => _showCardDetail(context, deckId, card),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  card.original,
                  style: const TextStyle(fontSize: 17, color: AppColors.ink),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  card.translation,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontSize: 16, color: AppColors.inkSecondary),
                ),
              ),
              const SizedBox(width: 8),
              const Icon(CupertinoIcons.chevron_right, size: 14, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showCardDetail(BuildContext context, int deckId, Flashcard card) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppColors.background,
    // Without this the sheet caps at a fixed fraction of the screen and its
    // content (word + translation + every detail row) overflows instead of
    // scrolling -- see the SingleChildScrollView in _CardDetailSheet.
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => _CardDetailSheet(deckId: deckId, card: card),
  );
}

/// Everything stored about one card, including the SM-2 scheduling state
/// (ease factor, interval, repetitions, next due date) that the review
/// screen itself never shows. Also lets you pull the card into today's
/// review queue ahead of its normal schedule.
class _CardDetailSheet extends ConsumerWidget {
  const _CardDetailSheet({required this.deckId, required this.card});

  final int deckId;
  final Flashcard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final srs = card.srs;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: AppColors.outline,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(card.original, style: serifStyle(fontSize: 26)),
            const SizedBox(height: 4),
            Text(card.translation, style: serifStyle(fontSize: 20, color: AppColors.clay)),
            const SizedBox(height: 20),
            _DetailRow(label: 'Typ', value: card.type == VocabType.phrase ? 'fráze' : 'slovo'),
            _DetailRow(label: 'Slovní druh', value: card.partOfSpeech ?? '—'),
            if (card.exampleSentence.isNotEmpty)
              _DetailRow(label: 'Příkladová věta', value: card.exampleSentence),
            const Padding(
              padding: EdgeInsets.fromLTRB(0, 20, 0, 8),
              child: Text(
                'OPAKOVÁNÍ (SM-2)',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.inkMuted,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            _DetailRow(label: 'Ease factor', value: srs.easeFactor.toStringAsFixed(2)),
            _DetailRow(
              label: 'Interval',
              value: srs.repetitions == 0 ? 'zatím neopakováno' : '${srs.intervalDays} ${_dayWord(srs.intervalDays)}',
            ),
            _DetailRow(label: 'Počet opakování', value: '${srs.repetitions}'),
            _DetailRow(label: 'Další opakování', value: _formatDueDate(srs.dueDate)),
            if (!card.isDue) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await ref.read(flashcardRepositoryProvider).markDueNow(card.id);
                    ref.invalidate(deckCardsProvider(deckId));
                    ref.invalidate(reviewControllerProvider(deckId));
                    if (context.mounted) Navigator.of(context).pop();
                  },
                  icon: const Icon(CupertinoIcons.clock, size: 18),
                  label: const Text('Procvičit hned'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(fontSize: 14, color: AppColors.inkSecondary)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 14, color: AppColors.ink)),
          ),
        ],
      ),
    );
  }
}

/// "za 2 dny" vs "za 5 dní" -- Czech declines the noun by count.
String _dayWord(int count) {
  if (count == 1) return 'den';
  if (count >= 2 && count <= 4) return 'dny';
  return 'dní';
}

String _formatDueDate(DateTime due) {
  final now = DateTime.now();
  final dueDay = DateTime(due.year, due.month, due.day);
  final today = DateTime(now.year, now.month, now.day);
  final days = dueDay.difference(today).inDays;
  final formatted = '${due.day}. ${due.month}. ${due.year}';

  if (days <= 0) return 'už teď ($formatted)';
  if (days == 1) return 'zítra ($formatted)';
  return 'za $days ${_dayWord(days)} ($formatted)';
}
