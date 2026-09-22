import 'package:go_router/go_router.dart';

import '../features/flashcards/presentation/screens/deck_list_screen.dart';
import '../features/flashcards/presentation/screens/review_screen.dart';
import '../features/flashcards/presentation/screens/word_list_screen.dart';
import '../features/scan/domain/entities/scan_destination.dart';
import '../features/scan/presentation/screens/camera_screen.dart';
import '../features/scan/presentation/screens/scan_result_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const DeckListScreen(),
    ),
    GoRoute(
      path: '/scan',
      builder: (context, state) => const CameraScreen(),
    ),
    GoRoute(
      path: '/scan/review',
      builder: (context, state) {
        final request = state.extra as ScanRequest;
        return ScanResultScreen(images: request.images, destination: request.destination);
      },
    ),
    GoRoute(
      path: '/deck/:deckId/words',
      builder: (context, state) => WordListScreen(
        deckId: int.parse(state.pathParameters['deckId']!),
      ),
    ),
    GoRoute(
      path: '/deck/:deckId/review',
      builder: (context, state) => ReviewScreen(
        deckId: int.parse(state.pathParameters['deckId']!),
      ),
    ),
  ],
);
