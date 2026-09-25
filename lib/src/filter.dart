import 'package:unorm_dart/unorm_dart.dart' as unorm;

import 'lexicon.dart';
import 'types.dart';

const Map<String, String> _leet = {
  '0': 'o', '1': 'i', '3': 'e', '4': 'a', '5': 's', '7': 't', '@': 'a', r'$': 's', //
};

// Words shorter than this after collapsing repeated letters must match exactly, so "as" never matches "ass".
const int _minCollapse = 4;

final RegExp _devanagari = RegExp(r'[ऀ-ॿ]');
final RegExp _zeroWidth = RegExp(r'^[​-‍⁠﻿]$');
final RegExp _leetChar = RegExp(r'[0-9@$]');
// "!" stands for "i" only between two letters or digits, so a sentence-final "!" stays punctuation.
final RegExp _bangForI = RegExp(r'(?<=[\p{L}\p{N}])!+(?=[\p{L}\p{N}])', unicode: true);
final RegExp _tokenRun = RegExp(r'[\p{L}\p{M}*]+', unicode: true);
final RegExp _letter = RegExp(r'\p{L}', unicode: true);
final RegExp _repeated = RegExp(r'(.)\1+');
final RegExp _tripled = RegExp(r'(.)\1{2,}');
final RegExp _edgeStars = RegExp(r'^\*+|\*+$');
final RegExp _whitespace = RegExp(r'^\s+$');
final RegExp _graphemeExtend = RegExp(r'^[\p{Mn}\p{Mc}\p{Me}︀-️‌‍]$', unicode: true);
final RegExp _nonspacingMark = RegExp(r'^\p{Mn}$', unicode: true);

bool _isDevanagari(String s) => _devanagari.hasMatch(s);

String _collapse(String s) => s.replaceAllMapped(_repeated, (m) => m[1]!);

String _squeeze(String s) => s.replaceAllMapped(_tripled, (m) => '${m[1]}${m[1]}');

String _normalizeChar(String ch) {
  if (_zeroWidth.hasMatch(ch)) return '';
  if (_isDevanagari(ch)) {
    // Decompose so a precomposed nukta letter (ऩ) loses its nukta too, and fold chandrabindu into anusvara.
    return unorm.nfd(ch).replaceAll('़', '').replaceAll('ँ', 'ं');
  }
  return unorm.nfkc(ch).toLowerCase().replaceAllMapped(_leetChar, (m) => _leet[m[0]] ?? m[0]!);
}

/// Normalized text, plus the span of the original text that each normalized UTF-16 unit came from, so a match
/// found in the normalized text can be traced back to what the user typed.
class _Normalized {
  final String text;
  final List<int> starts;
  final List<int> ends;

  _Normalized(this.text, this.starts, this.ends);
}

_Normalized _normalize(String input) {
  final text = StringBuffer();
  final starts = <int>[];
  final ends = <int>[];
  var offset = 0;
  for (final rune in input.runes) {
    final ch = String.fromCharCode(rune);
    final out = _normalizeChar(ch);
    text.write(out);
    for (var k = 0; k < out.length; k++) {
      starts.add(offset);
      ends.add(offset + ch.length);
    }
    offset += ch.length;
  }

  // Replace each run of "!" between letters with one "i" spanning the whole run.
  final normalized = text.toString();
  final result = StringBuffer();
  final resultStarts = <int>[];
  final resultEnds = <int>[];
  var last = 0;
  for (final m in _bangForI.allMatches(normalized)) {
    result
      ..write(normalized.substring(last, m.start))
      ..write('i');
    resultStarts
      ..addAll(starts.sublist(last, m.start))
      ..add(starts[m.start]);
    resultEnds
      ..addAll(ends.sublist(last, m.start))
      ..add(ends[m.end - 1]);
    last = m.end;
  }
  if (last == 0) return _Normalized(normalized, starts, ends);
  result.write(normalized.substring(last));
  resultStarts.addAll(starts.sublist(last));
  resultEnds.addAll(ends.sublist(last));
  return _Normalized(result.toString(), resultStarts, resultEnds);
}

String _normalizeText(String s) => _normalize(s).text;

class _Tables {
  final Set<String> latinExact;
  final Set<String> latinCollapsed;
  final List<String> latinWords;
  final List<String> latinStems;
  final Set<String> devWords;
  final List<String> devStems;
  final List<RegExp> phrases;

  _Tables({
    required this.latinExact,
    required this.latinCollapsed,
    required this.latinWords,
    required this.latinStems,
    required this.devWords,
    required this.devStems,
    required this.phrases,
  });
}

_Tables _buildTables(Set<Language> languages, Strictness strictness) {
  List<String> active(List<LexiconEntry> entries, {required bool devanagari}) => [
        for (final e in entries)
          if (languages.contains(e.language) &&
              e.strictness.index <= strictness.index &&
              (e.language == Language.devanagari) == devanagari)
            _normalizeText(e.text),
      ];

  final latinWords = active(words, devanagari: false);

  return _Tables(
    latinExact: latinWords.map(_squeeze).toSet(),
    latinCollapsed: latinWords.map(_collapse).where((w) => w.length >= _minCollapse).toSet(),
    latinWords: latinWords.map(_squeeze).toList(),
    latinStems: active(stems, devanagari: false).map(_collapse).toList(),
    devWords: active(words, devanagari: true).toSet(),
    devStems: active(stems, devanagari: true),
    phrases: [...active(phrases, devanagari: false), ...active(phrases, devanagari: true)].map((p) {
      final body = p.trim().split(RegExp(r'\s+')).map(RegExp.escape).join(r'\s+');
      return RegExp('(?:^|[^\\p{L}\\p{N}])($body)(?![\\p{L}\\p{N}])', unicode: true, caseSensitive: false);
    }).toList(),
  );
}

// Whether pattern matches word, where each "*" in pattern stands for one hidden letter.
bool _wildcardEquals(String pattern, String word) {
  if (pattern.length != word.length) return false;
  for (var i = 0; i < pattern.length; i++) {
    if (pattern[i] != '*' && pattern[i] != word[i]) return false;
  }
  return true;
}

bool _wildcardTokenMatches(_Tables tables, String token) {
  if (!token.contains('*')) return false;

  final cleanToken = token.replaceAll(_edgeStars, '');
  if (!_letter.hasMatch(cleanToken)) return false;

  // "*" on both ends is markdown emphasis ("*sh*t*"). On one end only, it may also hide a first or last letter ("*ss").
  final emphasis = token.startsWith('*') && token.endsWith('*');
  final tokens = emphasis || cleanToken == token ? [cleanToken] : [cleanToken, token];
  final forms = [
    for (final t in tokens) ...[_squeeze(t), _collapse(t)]
  ];

  return forms.any((f) =>
      tables.latinWords.any((w) => _wildcardEquals(f, w)) ||
      tables.latinStems.any((stem) => f.length >= stem.length && _wildcardEquals(f.substring(0, stem.length), stem)));
}

bool _latinTokenMatches(_Tables tables, String token) {
  final candidates = [token];
  for (final s in latinSuffixes) {
    if (token.endsWith(s) && token.length - s.length >= 3) {
      candidates.add(token.substring(0, token.length - s.length));
      break;
    }
  }

  return candidates.any((t) {
    final squeezed = _squeeze(t);
    final collapsed = _collapse(t);
    return tables.latinExact.contains(squeezed) ||
        (collapsed.length >= _minCollapse && tables.latinCollapsed.contains(collapsed)) ||
        tables.latinStems.any(collapsed.startsWith) ||
        _wildcardTokenMatches(tables, t);
  });
}

bool _devanagariTokenMatches(_Tables tables, String token) {
  final candidates = [token];
  for (final s in devanagariSuffixes) {
    if (token.endsWith(s) && token.length > s.length + 1) {
      candidates.add(token.substring(0, token.length - s.length));
      break;
    }
  }

  return candidates.any((t) => tables.devWords.contains(t) || tables.devStems.any(t.startsWith));
}

/// A token with the span of the original text it came from.
class _Span {
  final String value;
  final int start;
  final int end;

  _Span(this.value, this.start, this.end);
}

List<_Span> _tokenSpans(_Normalized n) {
  final tokens = <_Span>[];
  var run = <_Span>[];

  // Three or more single letters in a row ("f.u.c.k", "f u c k") are read as one word.
  void flush() {
    if (run.length >= 3) {
      tokens.add(_Span(run.map((t) => t.value).join(), run.first.start, run.last.end));
    }
    run = [];
  }

  for (final m in _tokenRun.allMatches(n.text)) {
    final t = _Span(m[0]!, n.starts[m.start], n.ends[m.end - 1]);
    if (_isDevanagari(t.value)) {
      flush();
      tokens.add(t);
    } else if (t.value.length == 1) {
      run.add(t);
    } else {
      flush();
      tokens.add(t);
    }
  }
  flush();
  return tokens;
}

/// Every match, words first and then phrases, in the order found.
List<ProfanityMatch> _scan(_Tables tables, String text) {
  if (text.isEmpty) return [];

  final n = _normalize(text);
  ProfanityMatch match(String normalized, int start, int end) =>
      ProfanityMatch(text: text.substring(start, end), normalized: normalized, start: start, end: end);

  final found = <ProfanityMatch>[];

  for (final t in _tokenSpans(n)) {
    if (_isDevanagari(t.value) ? _devanagariTokenMatches(tables, t.value) : _latinTokenMatches(tables, t.value)) {
      found.add(match(t.value, t.start, t.end));
    }
  }

  for (final re in tables.phrases) {
    for (final m in re.allMatches(n.text)) {
      // The phrase is the last thing matched, since the check after it doesn't consume anything.
      final phrase = m[1]!;
      final from = m.end - phrase.length;
      found.add(match(phrase, n.starts[from], n.ends[m.end - 1]));
    }
  }

  return found;
}

List<String> _unique(List<ProfanityMatch> matches) => matches.map((m) => m.normalized).toSet().toList();

int _byPosition(ProfanityMatch a, ProfanityMatch b) => a.start != b.start ? a.start - b.start : b.end - a.end;

List<ProfanityMatch> _sorted(List<ProfanityMatch> matches) => _stableSort(matches, _byPosition);

// List.sort isn't guaranteed to be stable, and matches at the same position keep the order they were found in.
List<T> _stableSort<T>(List<T> items, int Function(T, T) compare) {
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];
  indexed.sort((a, b) {
    final c = compare(a.$2, b.$2);
    return c != 0 ? c : a.$1 - b.$1;
  });
  return [for (final e in indexed) e.$2];
}

// Viramas of the Indic scripts, which join the consonants on either side into one visible character.
const String _viramas = '्্੍્୍்్್്්';

// Whether a consonant joins this cluster: it ends in a virama, perhaps followed by other marks or a ZWJ, so a
// conjunct such as "ण्ड" masks as one visible character.
bool _endsWithVirama(String cluster) {
  for (final rune in cluster.runes.toList().reversed) {
    final ch = String.fromCharCode(rune);
    if (_viramas.contains(ch)) return true;
    if (ch != '‍' && !_nonspacingMark.hasMatch(ch)) return false;
  }
  return false;
}

// Splits text into visible characters: a letter with its combining marks, and an Indic conjunct, stay whole.
List<String> _graphemes(String s) {
  final clusters = <String>[];
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    if (clusters.isNotEmpty &&
        (_graphemeExtend.hasMatch(ch) || (_letter.hasMatch(ch) && _endsWithVirama(clusters.last)))) {
      clusters.last += ch;
    } else {
      clusters.add(ch);
    }
  }
  return clusters;
}

String _censorMatches(String text, List<ProfanityMatch> matches, String mask, Replacer? replace) {
  if (mask.isEmpty) throw ArgumentError.value(mask, 'mask', 'must be a non-empty string');

  // Merge overlapping matches, such as the word "chaak" inside the phrase "chaak ko pwal", into one.
  final merged = <ProfanityMatch>[];
  for (final m in _sorted(matches)) {
    if (merged.isNotEmpty && m.start < merged.last.end) {
      final prev = merged.last;
      if (m.end > prev.end) {
        merged.last = ProfanityMatch(
            text: text.substring(prev.start, m.end), normalized: prev.normalized, start: prev.start, end: m.end);
      }
    } else {
      merged.add(m);
    }
  }

  final out = StringBuffer();
  var last = 0;
  for (final m in merged) {
    out
      ..write(text.substring(last, m.start))
      ..write(replace != null ? replace(m) : _graphemes(m.text).map((g) => _whitespace.hasMatch(g) ? g : mask).join());
    last = m.end;
  }
  out.write(text.substring(last));
  return out.toString();
}

/// The result of scanning one text: inspect it, then censor it without scanning again.
class ProfanityCheck {
  /// The text that was checked.
  final String text;

  /// Whether any profanity was found.
  final bool hasProfanity;

  /// The normalized words found, without duplicates. The same as [findProfanity].
  final List<String> words;

  /// Every match with its position, sorted by position. The same as [findProfanityMatches].
  final List<ProfanityMatch> matches;

  final List<ProfanityMatch> _found;

  ProfanityCheck._(this.text, List<ProfanityMatch> found)
      : _found = found,
        hasProfanity = found.isNotEmpty,
        words = List.unmodifiable(_unique(found)),
        matches = List.unmodifiable(_sorted(found));

  /// The text with every match masked. [replace] returns the replacement for a whole match and takes precedence
  /// over [mask], which replaces each visible character except whitespace.
  String censor({String mask = '*', Replacer? replace}) => _censorMatches(text, _found, mask, replace);
}

/// Checks text against the word lists for one set of options. Build it once and reuse it rather than passing
/// options on every call.
class ProfanityFilter {
  final _Tables _tables;

  /// A filter for the given [languages] (all three by default) and [strictness].
  ProfanityFilter({Iterable<Language>? languages, Strictness strictness = Strictness.standard})
      : _tables = _buildTables((languages ?? Language.values).toSet(), strictness);

  /// Scans the text once. Use the result to check for profanity and to censor it, e.g. `check(text).censor()`.
  ProfanityCheck check(String text) => ProfanityCheck._(text, _scan(_tables, text));

  /// Whether the text contains any profanity.
  bool containsProfanity(String text) => _scan(_tables, text).isNotEmpty;

  /// The normalized words found, without duplicates, e.g. `['fuck', 'shit']` for "f.u.c.k sh1t".
  List<String> findProfanity(String text) => _unique(_scan(_tables, text));

  /// Every occurrence with its position in the input, sorted by position.
  List<ProfanityMatch> findProfanityMatches(String text) => _sorted(_scan(_tables, text));

  /// The text with every match masked, e.g. "you muji" → "you ****".
  String censor(String text, {String mask = '*', Replacer? replace}) =>
      _censorMatches(text, _scan(_tables, text), mask, replace);
}

final Map<String, ProfanityFilter> _filterCache = {};

ProfanityFilter _cachedFilter(Iterable<Language>? languages, Strictness strictness) {
  final langs = (languages ?? Language.values).map((l) => l.name).toSet().toList()..sort();
  return _filterCache.putIfAbsent(
      '${strictness.name}|${langs.join(',')}', () => ProfanityFilter(languages: languages, strictness: strictness));
}

/// Scans the text once. Use the result to check for profanity and to censor it, e.g. `check(text).censor()`.
ProfanityCheck check(String text, {Iterable<Language>? languages, Strictness strictness = Strictness.standard}) =>
    _cachedFilter(languages, strictness).check(text);

/// Whether the text contains any profanity.
bool containsProfanity(String text, {Iterable<Language>? languages, Strictness strictness = Strictness.standard}) =>
    _cachedFilter(languages, strictness).containsProfanity(text);

/// The normalized words found, without duplicates, e.g. `['fuck', 'shit']` for "f.u.c.k sh1t".
List<String> findProfanity(String text, {Iterable<Language>? languages, Strictness strictness = Strictness.standard}) =>
    _cachedFilter(languages, strictness).findProfanity(text);

/// Like [findProfanity], but returns every occurrence with its position in the input, sorted by position.
List<ProfanityMatch> findProfanityMatches(String text,
        {Iterable<Language>? languages, Strictness strictness = Strictness.standard}) =>
    _cachedFilter(languages, strictness).findProfanityMatches(text);

/// The text with every match masked, e.g. "you muji" → "you ****".
String censor(String text,
        {Iterable<Language>? languages,
        Strictness strictness = Strictness.standard,
        String mask = '*',
        Replacer? replace}) =>
    _cachedFilter(languages, strictness).censor(text, mask: mask, replace: replace);

/// The tokens the matcher sees. Useful for debugging why a word is or isn't caught.
List<String> tokenize(String text) => text.isEmpty ? [] : _tokenSpans(_normalize(text)).map((t) => t.value).toList();
