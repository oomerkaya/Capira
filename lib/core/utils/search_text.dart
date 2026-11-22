/// Search that ignores case and Turkish letters, so "türk hava",
/// "TURK HAVA" and "Türk Hava" all find "TURK HAVA YOLLARI" (Bürküt sends
/// names both with and without Turkish letters).
library;

const Map<String, String> _fold = {
  'ç': 'c',
  'ğ': 'g',
  'ı': 'i',
  'ö': 'o',
  'ş': 's',
  'ü': 'u',
  'â': 'a',
  'î': 'i',
  'û': 'u',
};

/// Lower case, Turkish letters folded to ASCII, punctuation as spaces,
/// spaces collapsed.
String foldForSearch(String text) {
  // Turkish upper case first: İ → i, I → ı (then folded to i as well).
  final lower = text.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
  final buffer = StringBuffer();
  for (final rune in lower.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_fold[char] ?? char);
  }
  return buffer
      .toString()
      .replaceAll('̇', '') // combining dot left by some İ spellings
      .replaceAll(RegExp(r'[^\p{L}\p{N}]+', unicode: true), ' ')
      .trim();
}

/// Whether [query] matches an instrument: the code starts with it or the
/// name contains it, both compared with [foldForSearch].
bool matchesSearch(String query, {required String code, String? name}) {
  final q = foldForSearch(query);
  if (q.isEmpty) return true;
  return foldForSearch(code).startsWith(q) ||
      (name != null && foldForSearch(name).contains(q));
}
