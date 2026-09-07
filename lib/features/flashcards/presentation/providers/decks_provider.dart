import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/di/providers.dart';
import '../../domain/entities/deck.dart';

final decksProvider = FutureProvider.autoDispose<List<Deck>>((ref) {
  return ref.watch(flashcardRepositoryProvider).getDecks();
});
