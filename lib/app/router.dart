import 'dart:typed_data';

import 'package:go_router/go_router.dart';

import '../features/flashcards/presentation/screens/deck_list_screen.dart';
import '../features/flashcards/presentation/screens/review_screen.dart';
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
      builder: (context, state) => ScanResultScreen(
        imageBytes: state.extra as Uint8List,
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
