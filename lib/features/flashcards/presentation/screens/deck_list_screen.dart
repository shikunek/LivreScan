import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme.dart';
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
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              // Closes an open row when another one is opened or tapped.
              child: SlidableAutoCloseBehavior(
                child: CustomScrollView(
                  physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    CupertinoSliverRefreshControl(
                      onRefresh: () async {
                        await ref
                            .refresh(decksProvider.future)
                            .then<void>((_) {}, onError: (_) {});
                      },
                    ),
                    const SliverToBoxAdapter(child: _Header()),
                    ..._deckSlivers(context, ref, decks),
                  ],
                ),
              ),
            ),
            const _ScanButton(),
          ],
        ),
      ),
    );
  }

  List<Widget> _deckSlivers(BuildContext context, WidgetRef ref, AsyncValue<List<Deck>> decks) {
    return decks.when(
      loading: () => const [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CupertinoActivityIndicator(radius: 14)),
        ),
      ],
      error: (error, _) => [
        SliverFillRemaining(
          hasScrollBody: false,
          child: _ErrorState(error: error, onRetry: () => ref.invalidate(decksProvider)),
        ),
      ],
      data: (decks) => decks.isEmpty
          ? const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Zatím žádné decky. Naskenuj stránku knihy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.inkSecondary),
                    ),
                  ),
                ),
              ),
            ]
          : [
              SliverList.separated(
                itemCount: decks.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final deck = decks[index];
                  return Slidable(
                    key: ValueKey(deck.id),
                    groupTag: 'decks',
                    // Swipe right-to-left to slide out "Smazat"; tapping it deletes.
                    endActionPane: ActionPane(
                      motion: const DrawerMotion(),
                      extentRatio: 0.28,
                      children: [
                        SlidableAction(
                          label: 'Smazat',
                          backgroundColor: AppColors.dangerTint,
                          foregroundColor: AppColors.danger,
                          onPressed: (_) async {
                            HapticFeedback.mediumImpact();
                            final messenger = ScaffoldMessenger.of(context);
                            final deleted =
                                await ref.read(decksProvider.notifier).delete(deck.id);
                            if (!deleted) {
                              messenger.showSnackBar(
                                const SnackBar(content: Text('Deck se nepodařilo smazat.')),
                              );
                            }
                          },
                        ),
                      ],
                    ),
                    child: _DeckRow(deck: deck),
                  );
                },
              ),
            ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
          child: Text('Decky', style: serifStyle(fontSize: 34, letterSpacing: -0.5)),
        ),
        const LanguagePairBar(),
        const Divider(),
      ],
    );
  }
}

class _ScanButton extends StatelessWidget {
  const _ScanButton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
      child: FilledButton.icon(
        style: pillButtonStyle,
        onPressed: () {
          HapticFeedback.lightImpact();
          context.push('/scan');
        },
        icon: const Icon(CupertinoIcons.camera, size: 20),
        label: const Text('Skenovat stránku'),
      ),
    );
  }
}

class _DeckRow extends StatelessWidget {
  const _DeckRow({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context) {
    // Opaque so the delete background doesn't show through while swiping.
    return Material(
      color: AppColors.background,
      child: InkWell(
        highlightColor: AppColors.hairline,
        onTap: () => context.push('/deck/${deck.id}/review'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(deck.name, style: const TextStyle(fontSize: 17, color: AppColors.ink)),
                    const SizedBox(height: 2),
                    Text(
                      '${languageByCode(deck.sourceLang).name} → ${languageByCode(deck.targetLang).name}',
                      style: const TextStyle(fontSize: 13, color: AppColors.inkSecondary),
                    ),
                  ],
                ),
              ),
              CupertinoButton(
                padding: const EdgeInsets.all(10),
                minimumSize: const Size(40, 40),
                onPressed: () => context.push('/deck/${deck.id}/words'),
                child: const Icon(
                  CupertinoIcons.list_bullet,
                  size: 20,
                  color: AppColors.inkSecondary,
                  semanticLabel: 'Slovíčka v decku',
                ),
              ),
              const Icon(CupertinoIcons.chevron_right, size: 16, color: AppColors.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Nepodařilo se načíst decky:\n$error', textAlign: TextAlign.center),
          const SizedBox(height: 20),
          FilledButton(onPressed: onRetry, child: const Text('Zkusit znovu')),
        ],
      ),
    );
  }
}
