import '../../../scan/domain/entities/vocab_candidate.dart';
import '../../../../core/srs/sm2_scheduler.dart';

class Flashcard {
  const Flashcard({
    required this.id,
    required this.deckId,
    required this.original,
    required this.translation,
    required this.type,
    required this.exampleSentence,
    required this.srs,
    this.partOfSpeech,
  });

  final int id;
  final int deckId;
  final String original;
  final String translation;
  final VocabType type;
  final String exampleSentence;
  final String? partOfSpeech;
  final Sm2State srs;

  bool get isDue => !srs.dueDate.isAfter(DateTime.now());
}
