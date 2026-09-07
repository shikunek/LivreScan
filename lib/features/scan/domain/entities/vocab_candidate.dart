enum VocabType { word, phrase }

enum Cefr { a1, a2, b1, b2, c1, c2 }

class VocabCandidate {
  const VocabCandidate({
    required this.original,
    required this.translation,
    required this.type,
    required this.exampleSentence,
    this.partOfSpeech,
    this.difficulty,
  });

  final String original;
  final String translation;
  final VocabType type;
  final String exampleSentence;
  final String? partOfSpeech;
  final Cefr? difficulty;
}
