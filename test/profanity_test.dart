import 'package:no_nepali_profanity/lexicon.dart' as lexicon;
import 'package:no_nepali_profanity/no_nepali_profanity.dart';
import 'package:test/test.dart';

void main() {
  group('containsProfanity', () {
    const catches = {
      'English': 'what a bitch',
      'an inflected English word (stem)': 'fucking useless',
      'Romanized Nepali': 'muji teacher',
      'Romanized Nepali with a postposition': 'machikneko class',
      'Devanagari Nepali': 'यो मुजी हो',
      'Devanagari with a postposition': 'मुजीको कक्षा',
      'Devanagari with a nukta or zero-width joiner': 'मु‍जी',
      'leetspeak': 'sh1t lecturer',
      'leetspeak with @': '@ss',
      r'leetspeak with $': r'a$$',
      'dodging with ! for i inside a word': 'sh!t lecturer',
      'dodging with a wildcard for a hidden letter': 'f*ck this',
      'dodging with a wildcard for the hidden i': 'sh*t',
      'dodging with a wildcard for the hidden first letter': 'that *ss',
      'dodging with a wildcard for the hidden last letter': 'fuc* off',
      'markdown emphasis still reads the word': '*sh*t* is bad',
      'stretched letters': 'fuuuuck',
      'letters spelled out with dots': 'f.u.c.k',
      'letters spelled out with spaces': 'm u j i',
      'upper case': 'IDIOT',
      'full-width letters': 'ＦＵＣＫ',
      'Hindi slang common in Nepal': 'chutiya',
      'Romanized invective': 'murkha',
      'Dodged word stays caught with a suffix': 'gandako budi',
      'exact word, not a long place name': 'look at that gand',
      'stem catches the -ne inflected form': 'chodne manche',
      'Devanagari invective': 'मुर्ख',
      'Devanagari with a doubled consonant': 'थुक्क',
      'Devanagari slang': 'कमिना',
      'Devanagari vulgar term': 'लुंड',
      'multi-word phrase': 'chaak ko pwal',
      'multi-word phrase with leetspeak': 'p3sa g@rne taba',
      'multi-word phrase ending a sentence': 'thulo sasto manche!',
      'review-supplied term': 'chhakka lai hami mukhulla bhanchha',
      'short spelling': 'mji',
      'leet spelling': 'm00ji',
      'English leet spelling': 'f4ck off',
      'Devanagari spelling': 'राण्डी',
      'Latin phrase': 'khatako choro',
      'Devanagari phrase': 'राण्डीको बान',
      'spelling variant with -ey': 'yo khatey payment app kahiley chaley po',
    };
    catches.forEach((label, text) {
      test('catches $label', () => expect(containsProfanity(text), isTrue));
    });

    const clean = [
      // Ordinary words that contain or resemble a listed word
      'The class assignment was as hard as expected',
      'Computing and data structures',
      'Dickson explained Scunthorpe problems',
      'Assam and Gandaki are places',
      // Real Nepali names, in both scripts
      'Kshitij Shrestha',
      'Shitij Adhikari',
      'Putali Gurung',
      'पुतली गुरुङ',
      'Randip Thapa',
      'Asha Sharma',
      'Machindra Karki',
      'Harimaya Tamang',
      'सीता कार्की',
      'क्षितिज श्रेष्ठ',
      // Sentence punctuation
      'Great teacher!',
      "No way! That can't be right",
      'the starred items are on page 12*',
      'feed ** me ** the list',
      // Markdown emphasis around an ordinary word must not read the asterisks as hidden letters
      'this *is* good',
      '*and* then',
      '**hi** there',
      // Ordinary words that must not start matching the stems
      'chicken biryani is good',
      'the salaam greeting sounded nice',
      'Gandaki river is in Nepal',
      // Words separated so a phrase must not match
      'sasto ra manche duitai ho',
      // Ordinary words that the strict-only stems would catch
      'terms and conditions',
      'the conductor',
      'bhrastachar kanda',
      'Kandel sir',
      'Lundberg',
      // Ordinary words removed from the lexicon
      'fohor pani',
      'kano manche',
      'lato keta',
      'फोहोर पानी',
      'लाटो केटा',
    ];
    for (final text in clean) {
      test('does not flag "$text"', () => expect(findProfanity(text), isEmpty));
    }

    test('is false for an empty string', () => expect(containsProfanity(''), isFalse));
  });

  group('tokenize', () {
    test('joins letters spelled out one at a time, and keeps Devanagari words whole', () {
      expect(tokenize('f.u.c.k this'), ['fuck', 'this']);
      expect(tokenize('सीता कार्की'), ['सीता', 'कार्की']);
    });

    test('keeps a wildcard asterisk inside a word, and lets sentence-final ! stay a separator', () {
      expect(tokenize('f*ck this!'), ['f*ck', 'this']);
    });
  });

  group('languages option', () {
    test('checks only the languages turned on', () {
      const romanized = [Language.romanized];
      expect(containsProfanity('muji', languages: romanized), isTrue);
      expect(containsProfanity('fuck', languages: romanized), isFalse);
      expect(containsProfanity('मुजी', languages: romanized), isFalse);
      expect(containsProfanity('sasto manche', languages: romanized), isTrue);
    });

    test('keeps English and Devanagari separate from Romanized Nepali', () {
      expect(findProfanity('fuck muji मुजी', languages: [Language.english]), ['fuck']);
      expect(findProfanity('fuck muji मुजी', languages: [Language.devanagari]), ['मुजी']);
    });

    test('checks nothing when no language is turned on', () {
      expect(findProfanity('fuck muji मुजी', languages: []), isEmpty);
    });
  });

  group('strictness option', () {
    test('lenient skips milder insults but keeps severe profanity', () {
      expect(containsProfanity('idiot', strictness: Strictness.lenient), isFalse);
      expect(containsProfanity('murkha', strictness: Strictness.lenient), isFalse);
      expect(containsProfanity('sasto manche', strictness: Strictness.lenient), isFalse);
      expect(containsProfanity('muji', strictness: Strictness.lenient), isTrue);
    });

    test('standard is the default', () {
      expect(containsProfanity('idiot'), isTrue);
      expect(containsProfanity('idiot', strictness: Strictness.standard), isTrue);
      expect(containsProfanity('Randip Thapa'), isFalse);
    });

    test('strict adds the stems that also match ordinary words and names', () {
      expect(findProfanity('randikoban', strictness: Strictness.strict), ['randikoban']);
      expect(findProfanity('terms and conditions', strictness: Strictness.strict), ['conditions']);
      expect(findProfanity('Randip Thapa', strictness: Strictness.strict), ['randip']);
    });
  });

  group('ProfanityFilter', () {
    test('combines both options', () {
      final filter = ProfanityFilter(languages: [Language.romanized], strictness: Strictness.lenient);
      expect(filter.containsProfanity('muji'), isTrue);
      expect(filter.containsProfanity('murkha'), isFalse);
      expect(filter.findProfanity('fuck muji'), ['muji']);
    });
  });

  group('findProfanityMatches', () {
    test('returns every occurrence with its position in the original text', () {
      expect(findProfanityMatches('F.U.C.K this sh1t, muji. MUJI'), [
        const ProfanityMatch(text: 'F.U.C.K', normalized: 'fuck', start: 0, end: 7),
        const ProfanityMatch(text: 'sh1t', normalized: 'shit', start: 13, end: 17),
        const ProfanityMatch(text: 'muji', normalized: 'muji', start: 19, end: 23),
        const ProfanityMatch(text: 'MUJI', normalized: 'muji', start: 25, end: 29),
      ]);
    });

    test('returns a phrase before a word it contains', () {
      expect(findProfanityMatches('chaak ko pwal'), [
        const ProfanityMatch(text: 'chaak ko pwal', normalized: 'chaak ko pwal', start: 0, end: 13),
        const ProfanityMatch(text: 'chaak', normalized: 'chaak', start: 0, end: 5),
      ]);
    });

    test('gives the position of a phrase, not of the character before it', () {
      expect(findProfanityMatches('thulo sasto manche'), [
        const ProfanityMatch(text: 'sasto manche', normalized: 'sasto manche', start: 6, end: 18),
      ]);
    });

    test('is empty for clean text', () {
      expect(findProfanityMatches('Great teacher!'), isEmpty);
      expect(findProfanityMatches(''), isEmpty);
    });
  });

  group('censor', () {
    const masks = {
      'you muji': 'you ****',
      'F.U.C.K this Sh1t!': '******* this ****!',
      'sh!!t happens': '***** happens',
      'ＦＵＣＫ off': '**** off',
      'fuuuuck yeah': '******* yeah',
      'f*ck and *sh*t*': '**** and ******',
      'muji muji': '**** ****',
      'you 😀 muji 😀': 'you 😀 **** 😀',
    };
    masks.forEach((text, expected) {
      test('masks "$text"', () => expect(censor(text), expected));
    });

    test('masks Devanagari by visible character, not code unit', () {
      expect(censor('मुजीको कक्षा'), '*** कक्षा');
      expect(censor('गाण्ड'), '**');
    });

    test('keeps the spaces inside a phrase', () => expect(censor('sasto   manche'), '*****   ******'));

    test('merges a word with the phrase around it', () => expect(censor('chaak ko pwal'), '***** ** ****'));

    test('leaves clean text and names alone', () {
      expect(censor('Great teacher!'), 'Great teacher!');
      expect(censor('Shitij is great'), 'Shitij is great');
      expect(censor(''), '');
    });

    test('uses a custom mask character', () => expect(censor('you muji', mask: '#'), 'you ####'));

    test('uses a replace function over the mask', () {
      expect(censor('you muji fuck', mask: '#', replace: (_) => '[censored]'), 'you [censored] [censored]');
      expect(censor('you muji', replace: (m) => m.text[0] + '*' * (m.text.length - 1)), 'you m***');
    });

    test('respects the filter options', () {
      expect(censor('fuck muji', languages: [Language.romanized]), 'fuck ****');
      expect(censor('you idiot', strictness: Strictness.lenient), 'you idiot');
      expect(ProfanityFilter(strictness: Strictness.strict).censor('Randip Thapa'), '****** Thapa');
    });

    test('rejects an empty mask', () => expect(() => censor('muji', mask: ''), throwsArgumentError));
  });

  group('check', () {
    test('returns everything from one scan', () {
      final result = check('you muji, F.U.C.K');
      expect(result.text, 'you muji, F.U.C.K');
      expect(result.hasProfanity, isTrue);
      expect(result.words, ['muji', 'fuck']);
      expect(result.matches.map((m) => m.text), ['muji', 'F.U.C.K']);
      expect(result.censor(), 'you ****, *******');
      expect(result.censor(mask: '#'), 'you ####, #######');
    });

    test('chains straight into censor', () {
      expect(check('you muji').censor(), 'you ****');
      expect(check('Great teacher!').censor(), 'Great teacher!');
    });

    test('reports clean text', () {
      final result = check('Great teacher!');
      expect(result.hasProfanity, isFalse);
      expect(result.words, isEmpty);
      expect(result.matches, isEmpty);
    });

    test('respects the filter options', () {
      expect(check('fuck muji', languages: [Language.romanized]).censor(), 'fuck ****');
      expect(ProfanityFilter(strictness: Strictness.lenient).check('you idiot').hasProfanity, isFalse);
    });
  });

  group('lexicon', () {
    test('tags every entry and splits the flat lists by script', () {
      expect(lexicon.words.where((e) => e.text == 'muji').single.language, Language.romanized);
      expect(lexicon.latinWords, contains('muji'));
      expect(lexicon.devanagariWords, contains('मुजी'));
      expect(lexicon.latinWords.any((w) => RegExp(r'[ऀ-ॿ]').hasMatch(w)), isFalse);
      expect(lexicon.stems.where((e) => e.strictness == Strictness.strict).map((e) => e.text),
          containsAll(['rand', 'cond', 'kand', 'lund']));
    });
  });
}
