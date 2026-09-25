/// The word lists behind the filter: tagged entries ([words], [stems], [phrases]), flat lists by script
/// ([latinWords], [devanagariWords]…) and the Nepali postpositions taken off a word.
///
/// ```dart
/// import 'package:no_nepali_profanity/lexicon.dart' as lexicon;
///
/// lexicon.latinWords.contains('muji');   // true
/// ```
library;

export 'src/lexicon.dart';
export 'src/types.dart' show Language, Strictness;
