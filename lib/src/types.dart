/// A language the filter checks.
enum Language { english, romanized, devanagari }

/// How much the filter catches.
enum Strictness {
  /// Severe profanity only.
  lenient,

  /// Adds milder insults (idiot, murkha, sala…). The default.
  standard,

  /// Adds words and stems that are also ordinary words (damn, cum, rand). Known names and words, like Randip and
  /// condition, stay allowed.
  strict,
}

/// One place where profanity was found in the original text.
class ProfanityMatch {
  /// The matched text exactly as it appears in the input, e.g. "F.U.C.K".
  final String text;

  /// The normalized form that was matched, e.g. "fuck". The same value [findProfanity] returns.
  final String normalized;

  /// Start index in the input, in UTF-16 code units like [String.substring].
  final int start;

  /// End index in the input, exclusive.
  final int end;

  const ProfanityMatch({required this.text, required this.normalized, required this.start, required this.end});

  @override
  bool operator ==(Object other) =>
      other is ProfanityMatch &&
      other.text == text &&
      other.normalized == normalized &&
      other.start == start &&
      other.end == end;

  @override
  int get hashCode => Object.hash(text, normalized, start, end);

  @override
  String toString() => 'ProfanityMatch(text: $text, normalized: $normalized, start: $start, end: $end)';
}

/// Returns the replacement for a whole match when censoring.
typedef Replacer = String Function(ProfanityMatch match);
