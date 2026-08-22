import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aura/widgets/booking_voucher_dialog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BookingVoucherData Tests', () {
    test('toShareableText genera un comprobante con todos los campos clínicos clave', () {
      final voucher = BookingVoucherData(
        folio: 'TEST789',
        serviceTitle: 'Atención Médica a Domicilio',
        serviceIcon: Icons.medical_services,
        patientName: 'Juan Pérez',
        relationship: 'Titular',
        address: 'Av. Providencia 1234, Santiago',
        symptomsOrReason: 'Fiebre alta y dolor de garganta',
        finalPrice: 46000,
        etaMinutes: 25,
        createdAt: DateTime(2026, 8, 22, 19, 30),
      );

      final text = voucher.toShareableText();

      expect(text, contains('COMPROBANTE DE ATENCIÓN - AURA SALUD'));
      expect(text, contains('#TEST789'));
      expect(text, contains('Atención Médica a Domicilio'));
      expect(text, contains('Juan Pérez'));
      expect(text, contains('Av. Providencia 1234, Santiago'));
      expect(text, contains('Fiebre alta y dolor de garganta'));
      expect(text, contains('46.000'));
      expect(text, contains('25 min'));
    });

    test('toShareableText maneja traslados en ambulancia con origen y destino', () {
      final voucher = BookingVoucherData(
        folio: 'AMB123',
        serviceTitle: 'Ambulancia de Emergencia',
        serviceIcon: Icons.emergency,
        patientName: 'Margarita Soto',
        relationship: 'Madre',
        address: 'Origen',
        originAddress: 'Calle Las Flores 450, Rancagua',
        destinationAddress: 'Hospital Regional de Rancagua',
        ambulanceType: 'Avanzada (con médico y reanimador)',
        symptomsOrReason: 'Dificultad respiratoria severa',
        finalPrice: 75000,
        etaMinutes: 12,
        createdAt: DateTime(2026, 8, 22, 20, 0),
      );

      final text = voucher.toShareableText();

      expect(text, contains('#AMB123'));
      expect(text, contains('*Origen:* Calle Las Flores 450, Rancagua'));
      expect(text, contains('*Destino:* Hospital Regional de Rancagua'));
      expect(text, contains('*Tipo de Traslado:* Avanzada (con médico y reanimador)'));
      expect(text, contains('75.000'));
    });
  });
}
