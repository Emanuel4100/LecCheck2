/// Shorter forms of a course name, for week tiles too narrow for it when the
/// course has no short name of its own. Least shortened first:
///
/// 1. without parentheses and small words ("Introduction to Computer
///    Science" → "Introduction Computer Science");
/// 2. long words cut to 5, 4, then 3 letters: "Intr. Comp. Sci.", Hebrew
///    with a geresh ("אלג׳ לינ׳"). Latin cuts end on a consonant where they
///    can, as abbreviations usually do. Numbers, roman numerals, acronyms and
///    short words stay whole;
/// 3. initials, for three words or more: "ICS" (not in Hebrew, whose course
///    acronyms aren't regular enough to guess).
///
/// Every form is shorter than the one before; empty when the name can't
/// get any shorter.
List<String> autoShortNames(String name) {
  final all = name
      .replaceAll(RegExp(r'\s*\([^)]*\)'), ' ')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (all.isEmpty) return const [];
  final kept = all.where((w) => !_smallWords.contains(w.toLowerCase()));
  final main = kept.isEmpty ? all : kept.toList();
  final hebrew = _hebrew.hasMatch(name);
  final words = main.where(_isWord).length;

  final forms = <String>[
    main.join(' '),
    // A lone word cut to 3 letters reads as another word ("The.").
    for (final k in words > 1 ? const [5, 4, 3] : const [5, 4])
      [for (final w in main) _cut(w, k, hebrew: hebrew)].join(' '),
    if (words >= 3 && !hebrew) _initials(main),
  ];
  final result = <String>[];
  var shortest = name.trim().length;
  for (final form in forms) {
    if (form.length < shortest) {
      result.add(form);
      shortest = form.length;
    }
  }
  return result;
}

/// The form the course editor suggests as a short name: the first that's
/// at most 16 characters, else the shortest. Null when the name is short
/// enough already.
String? suggestedShortName(String name) {
  if (name.trim().length <= 16) return null;
  final forms = autoShortNames(name);
  if (forms.isEmpty) return null;
  return forms.firstWhere((f) => f.length <= 16, orElse: () => forms.last);
}

const _smallWords = {
  ...{'a', 'an', 'and', 'the', 'of', 'to', 'for', 'in', 'on', 'with'},
  ...{'into', '&', '-', '–'},
  ...{'של', 'על', 'עם', 'את', 'אל', 'ו'},
};

final _hebrew = RegExp(r'[֐-׿]');
final _roman = RegExp(r'^[IVX]+$');
final _letters = RegExp(r'^[^\d]+$');

/// A word that's shortened (not a number, roman numeral or acronym).
bool _isWord(String w) =>
    _letters.hasMatch(w) &&
    !_roman.hasMatch(w) &&
    !(w.length <= 4 && w == w.toUpperCase() && w != w.toLowerCase());

String _cut(String word, int k, {required bool hebrew}) {
  if (!_isWord(word)) return word;
  // Hebrew words are short: cutting saves at least one character. Latin cuts
  // must save two ("Line." for "Linear" doesn't help).
  if (hebrew || _hebrew.hasMatch(word)) {
    return word.length <= k + 1 ? word : '${word.substring(0, k)}׳';
  }
  if (word.length <= k + 2) return word;
  var end = k;
  // End on a consonant where it can: "Algebra" → "Alg.", not "Alge.".
  if (end > 3 && 'aeiouyAEIOUY'.contains(word[end - 1])) end--;
  return '${word.substring(0, end)}.';
}

String _initials(List<String> words) => [
  [
    for (final w in words)
      if (_isWord(w)) w[0],
  ].join().toUpperCase(),
  for (final w in words)
    if (!_isWord(w)) w,
].join(' ');
