/// Helpers to make free-text search tolerant to the way people actually type:
/// mixed case, missing accents ("medico" vs "médico"), stray punctuation and
/// extra whitespace.
library;

const Map<String, String> _diacriticsMap = {
  'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
  'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
  'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
  'ñ': 'n', 'ç': 'c',
  'Á': 'a', 'À': 'a', 'Ä': 'a', 'Â': 'a', 'Ã': 'a', 'Å': 'a',
  'É': 'e', 'È': 'e', 'Ë': 'e', 'Ê': 'e',
  'Í': 'i', 'Ì': 'i', 'Ï': 'i', 'Î': 'i',
  'Ó': 'o', 'Ò': 'o', 'Ö': 'o', 'Ô': 'o', 'Õ': 'o',
  'Ú': 'u', 'Ù': 'u', 'Ü': 'u', 'Û': 'u',
  'Ñ': 'n', 'Ç': 'c',
};

/// Lowercases [input], strips accents/diacritics and collapses any run of
/// non-alphanumeric characters into a single space.
///
/// `normalizeForSearch('Kinesiología Respiratoria')` -> `'kinesiologia respiratoria'`
String normalizeForSearch(String input) {
  final buffer = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final char = input[i];
    buffer.write(_diacriticsMap[char] ?? char);
  }

  return buffer
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();
}

/// True when every word typed in [query] starts some word of [haystack].
///
/// Both sides are normalized first, so "medico" matches "Médico" and
/// "kine respi" matches "Kinesiología Respiratoria".
///
/// Matching is anchored at word starts rather than anywhere in the text: a
/// plain `contains` would make "medico" match "paramédico" and return the
/// ambulance service, which is not what the person asked for. Prefixes are
/// still allowed so results narrow down while typing ("med" → "médico").
bool matchesSearch(String query, Iterable<String?> haystack) {
  final normalizedQuery = normalizeForSearch(query);
  if (normalizedQuery.isEmpty) return true;

  final words = haystack
      .where((value) => value != null && value.isNotEmpty)
      .map((value) => normalizeForSearch(value!))
      .join(' ')
      .split(' ');

  return normalizedQuery
      .split(' ')
      .every((term) => words.any((word) => word.startsWith(term)));
}

/// Extra words people commonly type that don't literally appear in a service's
/// title or subtitle. Keyed by clinical service id.
const Map<String, List<String>> serviceSearchAliases = {
  'enfermeria': ['enfermera', 'enfermero', 'inyeccion', 'curacion', 'suero', 'sonda'],
  'medico': ['doctor', 'doctora', 'consulta', 'medicina general', 'generalista', 'md'],
  'kine_motora': ['kine', 'kinesiologo', 'kinesiologa', 'fisioterapia', 'rehabilitacion', 'masaje'],
  'kine_respiratoria': ['kine', 'kinesiologo', 'kinesiologa', 'ktr', 'bronquial', 'nebulizacion'],
  'cuidados': ['cuidador', 'cuidadora', 'acompanamiento', 'compania'],
  'ambulancia': ['traslado', 'camilla', 'paramedico', 'movil'],
  'radiologia': ['rayos x', 'radiografia', 'imagenologia', 'ecografia'],
  'laboratorio': ['examen', 'examenes', 'sangre', 'muestra', 'hemograma'],
  'electrocardiograma': ['ecg', 'egc', 'electro', 'cardiologia', 'corazon'],
};
