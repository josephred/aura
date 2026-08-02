/// Client-side mirror of the backend `AtLeastTwoSymptoms` rule.
///
/// Kept in one place so the app and the server agree on what counts as a
/// symptom. The server is still the authority; this only spares the patient a
/// round trip and an error banner.
library;

/// Minimum length for a fragment to count as a symptom rather than filler.
const int _minFragmentLength = 3;

/// Splits free text into the symptoms it names.
List<String> splitSymptoms(String value) {
  // "y"/"e" only separate when standing alone as words, so "dolor de cabeza"
  // is not chopped at the "e" inside "cabeza".
  final normalized = value.replaceAll(
    RegExp(r'\s+(y|e|más|mas|además|ademas)\s+', caseSensitive: false),
    ',',
  );

  final fragments = normalized
      .split(RegExp(r'[,;/+\n\r]+'))
      .map((fragment) => fragment.trim())
      .where((fragment) => fragment.length >= _minFragmentLength)
      .map((fragment) => fragment.toLowerCase());

  // Repeating the same complaint twice is not two symptoms.
  return fragments.toSet().toList();
}

/// True once the text names two or more distinct symptoms.
bool hasTwoSymptoms(String? value) =>
    value != null && splitSymptoms(value).length >= 2;

/// Validation message, or null when the text is acceptable.
String? validateSymptoms(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Describe el motivo de consulta antes de continuar.';
  }

  if (!hasTwoSymptoms(value)) {
    return 'Indica al menos dos síntomas, separados por coma o «y». '
        'Por ejemplo: «dolor de cabeza y fiebre».';
  }

  return null;
}
