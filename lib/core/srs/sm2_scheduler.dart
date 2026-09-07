/// How the learner rated their recall of a card during review.
enum ReviewGrade { again, hard, good, easy }

class Sm2State {
  const Sm2State({
    required this.easeFactor,
    required this.intervalDays,
    required this.repetitions,
    required this.dueDate,
  });

  factory Sm2State.initial() => Sm2State(
        easeFactor: 2.5,
        intervalDays: 0,
        repetitions: 0,
        dueDate: DateTime.now(),
      );

  final double easeFactor;
  final int intervalDays;
  final int repetitions;
  final DateTime dueDate;
}

/// Classic SM-2 spaced-repetition scheduler (as used by Anki/SuperMemo).
class Sm2Scheduler {
  Sm2State next(Sm2State current, ReviewGrade grade) {
    if (grade == ReviewGrade.again) {
      return Sm2State(
        easeFactor: current.easeFactor,
        intervalDays: 1,
        repetitions: 0,
        dueDate: DateTime.now().add(const Duration(days: 1)),
      );
    }

    final quality = switch (grade) {
      ReviewGrade.hard => 3,
      ReviewGrade.good => 4,
      ReviewGrade.easy => 5,
      ReviewGrade.again => 0,
    };

    final newEase = (current.easeFactor +
            (0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02)))
        .clamp(1.3, double.infinity);

    final repetitions = current.repetitions + 1;
    final intervalDays = switch (repetitions) {
      1 => 1,
      2 => 6,
      _ => (current.intervalDays * newEase).round(),
    };

    return Sm2State(
      easeFactor: newEase,
      intervalDays: intervalDays,
      repetitions: repetitions,
      dueDate: DateTime.now().add(Duration(days: intervalDays)),
    );
  }
}
