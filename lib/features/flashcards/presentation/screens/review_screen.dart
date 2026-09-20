import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
import '../../../../core/srs/sm2_scheduler.dart';
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

  void _flip() {
    HapticFeedback.selectionClick();
    setState(() => _revealed = !_revealed);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(reviewControllerProvider(widget.deckId));

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: state.when(
          loading: () => const Center(child: CupertinoActivityIndicator(radius: 14)),
          error: (error, _) => Center(
            child: Text('Nepodařilo se načíst kartičky:\n$error', textAlign: TextAlign.center),
          ),
          data: (cards) => cards.isEmpty
              ? _EmptyState(onDone: () => context.go('/'))
              : _ReviewSession(
                  card: cards.first,
                  remaining: cards.length,
                  revealed: _revealed,
                  onFlip: _flip,
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
    required this.onFlip,
    required this.onGrade,
  });

  final Flashcard card;
  final int remaining;
  final bool revealed;
  final VoidCallback onFlip;
  final ValueChanged<ReviewGrade> onGrade;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Text(
            'Zbývá $remaining',
            style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
          ),
        ),
        Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onFlip,
            child: _FlashcardFace(card: card, revealed: revealed),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          child: revealed
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _GradeButton(
                      emoji: '😞',
                      label: 'Znovu',
                      onTap: () => onGrade(ReviewGrade.again),
                    ),
                    const SizedBox(width: 16),
                    _GradeButton(
                      emoji: '😐',
                      label: 'Těžké',
                      onTap: () => onGrade(ReviewGrade.hard),
                    ),
                    const SizedBox(width: 16),
                    _GradeButton(
                      emoji: '😊',
                      label: 'Dobré',
                      onTap: () => onGrade(ReviewGrade.good),
                    ),
                  ],
                )
              // Same height as the grade buttons so nothing shifts when they
              // appear after the translation is revealed.
              : const SizedBox(height: _gradeButtonSize),
        ),
      ],
    );
  }
}

/// The word stays put at the top; the translation appears underneath it.
class _FlashcardFace extends StatelessWidget {
  const _FlashcardFace({required this.card, required this.revealed});

  final Flashcard card;
  final bool revealed;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(32, 72, 32, 24),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Text(
              card.original,
              textAlign: TextAlign.center,
              style: serifStyle(fontSize: 42, letterSpacing: -0.5),
            ),
            const SizedBox(height: 28),
            if (revealed) ...[
              Container(width: 36, height: 0.5, color: AppColors.outline),
              const SizedBox(height: 28),
              Text(
                card.translation,
                textAlign: TextAlign.center,
                style: serifStyle(fontSize: 28, color: AppColors.clay),
              ),
              if (card.exampleSentence.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  card.exampleSentence,
                  textAlign: TextAlign.center,
                  style: serifStyle(
                    fontSize: 16,
                    color: AppColors.inkSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ] else
              const Text(
                'Ťukni pro zobrazení překladu',
                style: TextStyle(fontSize: 13, color: AppColors.inkMuted),
              ),
          ],
        ),
      ),
    );
  }
}

const _gradeButtonSize = 64.0;

/// Round outlined emoji button; [label] is kept for screen readers.
class _GradeButton extends StatelessWidget {
  const _GradeButton({required this.emoji, required this.label, required this.onTap});

  final String emoji;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(side: BorderSide(color: AppColors.outline, width: 0.5)),
        child: InkWell(
          customBorder: const CircleBorder(),
          highlightColor: AppColors.hairline,
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          child: SizedBox(
            width: _gradeButtonSize,
            height: _gradeButtonSize,
            child: Center(child: Text(emoji, style: const TextStyle(fontSize: 30))),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onDone});

  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(CupertinoIcons.checkmark_circle, size: 48, color: AppColors.outline),
          const SizedBox(height: 12),
          const Text('Žádné kartičky k opakování.'),
          const SizedBox(height: 24),
          FilledButton(
            style: pillButtonStyle,
            onPressed: onDone,
            child: const Text('Zpět na decky'),
          ),
        ],
      ),
    );
  }
}
