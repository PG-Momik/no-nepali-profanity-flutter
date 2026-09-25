## 0.2.0

- Same word lists and matching rules as the JavaScript package 0.2.0: more English and Nepali words, a built-in
  allow list of names and ordinary words, roots caught inside longer words, `x` read as `chh`, words split by
  punctuation read joined, and accents and look-alike letters removed.
- `extraWords` and `allowWords` options.
- The strict level adds ordinary words like `damn`, and no longer flags the names and words on the allow list.

## 0.1.0

- First release: the Dart port of the `no-nepali-profanity` npm package, with the same word lists and matching
  rules. `check`, `containsProfanity`, `findProfanity`, `findProfanityMatches`, `censor`, `tokenize` and
  `ProfanityFilter`, with the `languages` and `strictness` options. Word lists in
  `package:no_nepali_profanity/lexicon.dart`.
