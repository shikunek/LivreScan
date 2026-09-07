import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/srs/sm2_scheduler.dart';
import '../../../scan/domain/entities/vocab_candidate.dart';
import '../../domain/entities/flashcard.dart';
import '../providers/review_controller.dart';

/// Spaced-repetition review session for a single deck: one due card at a
/// time, tap to reveal the translation, then grade recall with SM-2.
class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key, required this.deckId});

  final int deckId;

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  bool _revealed = false;

  Future<void> _answer(int cardId, ReviewGrade grade) async {
    await ref.read(reviewControllerProvider(widget.deckId).notifier).answer(cardId, grade);
    if (mounted) setState(() => _revealed = false);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewControllerProvider(widget.deckId));

    return Scaffold(
      appBar: AppBar(title: const Text('Opakování')),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => Center(
            child: Text('Nepodařilo se načíst kartičky:\n$error', textAlign: TextAlign.center),
          ),
          data: (cards) => cards.isEmpty
              ? _EmptyState(onDone: () => context.go('/'))
              : _ReviewSession(
                  card: cards.first,
                  remaining: cards.length,
                  revealed: _revealed,
                  onReveal: () => setState(() => _revealed = true),
                  onFlip: () => setState(() => _revealed = !_revealed),
                  onGrade: (grade) => _answer(cards.first.id, grade),
                ),
        ),
      ),
    );
  }
}

class _ReviewSession extends StatelessWidget {
  const _ReviewSession({
    required this.card,
    required this.remaining,
    required this.revealed,
    required this.onReveal,
    required this.onFlip,
    required this.onGrade,
  });

  final Flashcard card;
  final int remaining;
  final bool revealed;
  final VoidCallback onReveal;
  final VoidCallback onFlip;
  final ValueChanged<ReviewGrade> onGrade;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Zbývá $remaining', style: Theme.of(context).textTheme.titleMedium),
        ),
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: GestureDetector(
                onTap: onFlip,
                child: _FlashcardFace(card: card, revealed: revealed),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: revealed
              ? Row(
                  children: [
                    Expanded(
                      child: _GradeButton(
                        label: 'Znovu',
                        color: Colors.redAccent,
                        onTap: () => onGrade(ReviewGrade.again),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GradeButton(
                        label: 'Těžké',
                        color: Colors.orange,
                        onTap: () => onGrade(ReviewGrade.hard),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GradeButton(
                        label: 'Dobré',
                        color: Colors.lightGreen,
                        onTap: () => onGrade(ReviewGrade.good),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _GradeButton(
                        label: 'Lehké',
                        color: Colors.green,
                        onTap: () => onGrade(ReviewGrade.easy),
                      ),
                    ),
                  ],
                )
              : FilledButton(
                  onPressed: onReveal,
                  child: const Text('Zobrazit překlad'),
                ),
        ),
      ],
    );
  }
}

class _FlashcardFace extends StatelessWidget {
  const _FlashcardFace({required this.card, required this.revealed});

  final Flashcard card;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Chip(label: Text(card.type == VocabType.phrase ? 'fráze' : 'slovo')),
            const SizedBox(height: 16),
            Text(
              card.original,
              style: theme.textTheme.headlineMedium,
              textAlign: TextAlign.center,
            ),
            if (revealed) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(),
              ),
              Text(
                card.translation,
                style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary),
                textAlign: TextAlign.center,
              ),
              if (card.partOfSpeech != null) ...[
                const SizedBox(height: 6),
                Text(card.partOfSpeech!, style: theme.textTheme.bodySmall),
              ],
              if (card.exampleSentence.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  card.exampleSentence,
                  style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
                  textAlign: TextAlign.center,
                ),
              ],
            ] else ...[
              const SizedBox(height: 12),
              Text('Ťukni pro zobrazení překladu', style: theme.textTheme.bodySmall),
            ],
          ],
        ),
      ),
    );
  }
}

class _GradeButton extends StatelessWidget {
  const _GradeButton({required this.label, required this.color, required this.onTap});

  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(backgroundColor: color),
      child: Text(label),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.celebration_outlined, size: 48),
          const SizedBox(height: 12),
          const Text('Žádné kartičky k opakování.'),
          const SizedBox(height: 20),
          FilledButton(onPressed: onDone, child: const Text('Zpět na decky')),
        ],
      ),
    );
  }
}
