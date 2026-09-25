/// A small profanity matcher for English, Romanized (Latin) Nepali and Devanagari Nepali, plus the Hindi slang
/// common in Nepal.
///
/// Built for moderating user-written text — names, comments, reviews — on Nepali sites, where false positives on
/// real names are more damaging than a missed swear. It uses the same word lists and matching rules as the
/// JavaScript package, so a piece of text gets the same result in every language.
///
/// ```dart
/// containsProfanity('Great teacher!');   // false
/// findProfanity('f.u.c.k this sh1t');    // ['fuck', 'shit']
/// censor('you muji');                    // 'you ****'
/// check('you muji').censor();            // 'you ****', from a single scan
/// ```
///
/// The word lists are in `package:no_nepali_profanity/lexicon.dart`.
library;

export 'src/filter.dart'
    show
        ProfanityCheck,
        ProfanityFilter,
        check,
        containsProfanity,
        findProfanity,
        findProfanityMatches,
        censor,
        tokenize;
export 'src/types.dart';
