import 'package:flutter_test/flutter_test.dart';
import 'package:aura/utils/symptom_validation.dart';

void main() {
  group('SymptomValidation Unit Tests', () {
    final validCases = {
      'dos separados por y': 'dolor de cabeza y fiebre',
      'dos separados por coma': 'fiebre alta, tos seca',
      'punto y coma': 'tos; congestión nasal',
      'barra': 'dolor abdominal / náuseas',
      'salto de línea': 'dolor de cabeza\nmareos',
      'mayúsculas': 'Fiebre Alta Y Tos',
      'más de dos síntomas': 'fiebre, tos, dolor de garganta y malestar general',
      'separados por e': 'tos e irritación ocular',
    };

    final invalidCases = {
      'uno solo': 'dolor de cabeza',
      'una palabra': 'fiebre',
      'vacío': '',
      'solo espacios': '   ',
      'repetido no cuenta': 'fiebre y fiebre',
      'coma colgando': 'fiebre, ',
      'e interna no separa': 'cabeza',
    };

    for (final entry in validCases.entries) {
      test('Acepta: ${entry.key} («${entry.value}»)', () {
        expect(hasTwoSymptoms(entry.value), isTrue);
        expect(validateSymptoms(entry.value), isNull);
        expect(splitSymptoms(entry.value).length, greaterThanOrEqualTo(2));
      });
    }

    for (final entry in invalidCases.entries) {
      test('Rechaza: ${entry.key} («${entry.value}»)', () {
        expect(hasTwoSymptoms(entry.value), isFalse);
        expect(validateSymptoms(entry.value), isNotNull);
      });
    }

    test('validateSymptoms con null retorna mensaje de campo requerido', () {
      final result = validateSymptoms(null);
      expect(result, equals('Describe el motivo de consulta antes de continuar.'));
    });

    test('validateSymptoms con un solo síntoma retorna instrucción clara', () {
      final result = validateSymptoms('fiebre');
      expect(
        result,
        contains('Indica al menos dos síntomas, separados por coma o «y».'),
      );
    });
  });
}
