import 'dart:typed_data';

/// Where the cards from one scan are saved.
sealed class ScanDestination {
  const ScanDestination();
}

/// The first deck of this language pair, created on first use.
class DefaultDeck extends ScanDestination {
  const DefaultDeck();
}

/// A deck that already exists.
class ExistingDeck extends ScanDestination {
  const ExistingDeck(this.deckId);

  final int deckId;
}

/// A deck created for this scan. It is only created once the scan has found
/// something to save, so cancelling or an empty scan leaves no empty deck.
class NewDeck extends ScanDestination {
  const NewDeck(this.name);

  final String name;
}

/// Everything the review screen needs to run one scan.
class ScanRequest {
  const ScanRequest({required this.images, this.destination = const DefaultDeck()});

  final List<Uint8List> images;
  final ScanDestination destination;
}
