# no_nepali_profanity

A small profanity matcher for **English**, **Romanized (Latin) Nepali** and **Devanagari Nepali**, plus the Hindi
slang common in Nepal. Built for moderating user-written text — names, comments, reviews — on Nepali sites and apps,
where false positives on real names are more damaging than a missed swear.

The Dart and Flutter port of [no-nepali-profanity](https://github.com/PG-Momik/no-nepali-profanity). It uses the same
word lists and matching rules as the JavaScript package, so a piece of text gets the same result in every language.
Pure Dart, so it runs on every Flutter platform and on the server.

**Documentation: [mukhxadnahunna.com/flutter](https://mukhxadnahunna.com/flutter/)**

## Install

```sh
dart pub add no_nepali_profanity     # or: flutter pub add no_nepali_profanity
```

```dart
import 'package:no_nepali_profanity/no_nepali_profanity.dart';
```

## Usage

```dart
containsProfanity('Great teacher!');    // false
containsProfanity('muji');              // true
containsProfanity('मुजीको कक्षा');       // true  (Devanagari + postposition)

findProfanity('f.u.c.k this sh1t');     // ['fuck', 'shit']
findProfanity('*ss teacher');           // ['*ss']
findProfanity('Randip Thapa');          // []

tokenize('Great teacher!');             // ['great', 'teacher']
```

### Censoring

```dart
censor('you muji');                                  // 'you ****'
censor('F.U.C.K this Sh1t!');                        // '******* this ****!'
censor('you muji', mask: '#');                       // 'you ####'
censor('you muji', replace: (m) => '[censored]');    // 'you [censored]'
findProfanityMatches('you muji');
// [ProfanityMatch(text: muji, normalized: muji, start: 4, end: 8)]
```

`start` and `end` are UTF-16 indices, so `text.substring(m.start, m.end) == m.text`.

Check and censor in one pass:

```dart
final result = check('you muji');
result.hasProfanity;   // true
result.words;          // ['muji']
result.censor();       // 'you ****'
```

### Options

```dart
findProfanity('fuck muji मुजी', languages: [Language.romanized]);     // ['muji']
containsProfanity('you idiot', strictness: Strictness.lenient);      // false
findProfanity('terms and conditions', strictness: Strictness.strict); // ['conditions']

// Build a filter once for fixed options.
final filter = ProfanityFilter(languages: [Language.romanized], strictness: Strictness.lenient);
filter.censor('fuck muji');   // 'fuck ****'
```

- `languages`: any of `Language.english`, `Language.romanized`, `Language.devanagari`. Default: all three.
- `strictness`: `Strictness.lenient` (severe words only), `Strictness.standard` (the default; adds milder insults like
  `idiot`, `murkha`) or `Strictness.strict` (adds the stems `rand`, `cond`, `kand`, `lund`, which also hit words like
  `Randip` and `conditions`).

## API

| Function | Returns | Notes |
|---|---|---|
| `containsProfanity(text)` | `bool` | |
| `findProfanity(text)` | `List<String>` | Matching words, **normalized** (leet decoded, lower-cased) and deduplicated. |
| `findProfanityMatches(text)` | `List<ProfanityMatch>` | Every occurrence with its position, sorted by position. |
| `censor(text, {mask, replace})` | `String` | The text with each match masked. `mask` defaults to `'*'`. |
| `check(text)` | `ProfanityCheck` | Scans once: `text`, `hasProfanity`, `words`, `matches`, `censor()`. |
| `ProfanityFilter({languages, strictness})` | | A filter with the same methods, built once for fixed options. |
| `tokenize(text)` | `List<String>` | The tokens the matcher sees. Useful for debugging. |

Every function also takes `languages` and `strictness`. The word lists are in a separate library:

```dart
import 'package:no_nepali_profanity/lexicon.dart' as lexicon;

lexicon.words;         // tagged entries, also stems and phrases
lexicon.latinWords;    // flat lists by script: latinWords, devanagariWords…
```

## What it catches

- **Case and Unicode forms**: `IDIOT`, full-width letters.
- **Leetspeak**: `sh1t`, `@ss` (`0 1 3 4 5 7 @ $`).
- **`!` for `i` between letters**: `sh!t`, `b!tch`. Sentence-final `Great teacher!` is left alone.
- **`*` for a hidden letter**: `f*ck`, `sh*t`, `*ss`. Markdown emphasis like `*sh*t*` still reads as the word, while
  `*is*` stays clean.
- **Stretched letters**: `fuuuuck`, for words of 4+ letters.
- **Spelled-out letters**: `f.u.c.k`, `f u c k`.
- **Nepali postpositions and plurals glued on**: `mujiko`, `randiharu`, `मुजीको`, `…हरू`.
- **Devanagari spelling variants**: nukta, chandrabindu vs anusvara, zero-width joiners.
- **Stems** where no ordinary word starts the same way: `fucking`, `bitches`, `machiknee`.
- **Multi-word phrases**: `chaak ko pwal`, `pesa garne`, `sasto manche` (Latin and Devanagari).

## What it deliberately doesn't

- **Short words match exactly**, so `as`, `class`, `assignment` and `Assam` are fine.
- **Name collisions**: `shit` is a whole word only, because **Shitij / शितिज** is a name. Names like **Randip**,
  **Putali / पुतली** and **Asha** are checked in the test suite.
- **No caste names, surnames or ordinary words that are only offensive in context** (e.g. *kami*, *kukur*). A word
  list can't tell a slur from someone's name; that needs human moderation.
- **No judgement of context, sarcasm or meaning.** This is a first-pass filter, not a moderator.

## Development

```sh
dart pub get
dart test
dart analyze
```

The word lists live in `lib/src/lexicon.dart`, kept in step with `src/lexicon.ts` in the JavaScript package.
Native-speaker review of the Nepali lists is the most valuable contribution; please send word-list changes to the
[JavaScript repository](https://github.com/PG-Momik/no-nepali-profanity) so every port gets them.

## License

MIT
