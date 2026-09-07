class Deck {
  const Deck({
    required this.id,
    required this.name,
    required this.sourceLang,
    required this.targetLang,
  });

  final int id;
  final String name;
  final String sourceLang;
  final String targetLang;
}
