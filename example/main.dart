// Run with: dart run example/main.dart
import 'package:no_nepali_profanity/no_nepali_profanity.dart';

void main() {
  print(containsProfanity('Great teacher!')); // false
  print(containsProfanity('मुजीको कक्षा')); // true
  print(findProfanity('f.u.c.k this sh1t')); // [fuck, shit]
  print(findProfanity('Randip Thapa')); // []

  print(censor('you muji')); // you ****
  print(censor('you muji', mask: '#')); // you ####
  print(censor('you muji', replace: (m) => '[censored]')); // you [censored]
  print(findProfanityMatches('you muji')); // [ProfanityMatch(text: muji, normalized: muji, start: 4, end: 8)]

  // Scan once, then inspect and censor the result.
  final result = check('you muji');
  print('${result.hasProfanity} ${result.words} ${result.censor()}'); // true [muji] you ****

  // Build a filter once for fixed options.
  final filter = ProfanityFilter(languages: [Language.romanized], strictness: Strictness.lenient);
  print(filter.findProfanity('fuck muji murkha')); // [muji]
}
