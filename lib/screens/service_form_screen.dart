import 'dart:async';
import 'package:aura/theme/app_theme.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import '../utils/money.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../models/clinical_service.dart';
import '../models/dependent.dart';
import '../models/saved_address.dart';
import '../models/zone_eta_estimate.dart';
import '../state/app_state.dart';
import '../utils/service_specialties.dart';
import '../utils/symptom_validation.dart';
import '../models/lab_models.dart';
import '../widgets/lab_slot_picker.dart';
import '../widgets/map_location_picker.dart';
import '../widgets/symptom_voice_input.dart';
import 'book_appointment_screen.dart';

class ServiceFormScreen extends StatefulWidget {
  final AppState state;
  final ClinicalService service;
  final List<Dependent> dependents;
  final List<SavedAddress> addresses;
  final VoidCallback onAddDependentRedirect;
  final VoidCallback onBack;
  final double commissionRate;
  final Function({
    required String patientType,
    String? dependentId,
    required String addressText,
    String? originAddress,
    String? destinationAddress,
    String? ambulanceType,
    double? patientLat,
    double? patientLng,
    double? destinationLat,
    double? destinationLng,
    String? symptomsDescription,
    String? symptomAudioPath,
    String? prescriptionName,
    String? prescriptionPreview,
    required int finalPrice,
    required int etaMinutes,
  })
  onConfirmRequest;

  const ServiceFormScreen({
    super.key,
    required this.state,
    required this.service,
    required this.dependents,
    required this.addresses,
    required this.onAddDependentRedirect,
    required this.onConfirmRequest,
    required this.onBack,
    required this.commissionRate,
  });

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
  AppPalette get p => context.palette;
  String _patientType = 'self';
  String? _selectedDependentId;
  int _addressIndex = 0;
  final TextEditingController _customAddressController =
      TextEditingController();
  bool _useCustomAddress = false;

  // Custom states per service
  final TextEditingController _symptomsController = TextEditingController();

  /// Local path of the optional voice note describing the symptoms.
  String? _symptomAudioPath;
  bool _isRecordingVoice = false;

  /// Inline message when the consultation reason does not name two symptoms.
  String? _symptomsError;
  String? _uploadedFileName;
  String? _uploadedFilePreview;
  bool _isUploading = false;

  // Real map coordinates picked by the user (replaces the old mock canvas)
  LatLng? _locationLatLng; // standard services: the attention location
  LatLng? _originLatLng; // ambulance pickup
  LatLng? _destinationLatLng; // ambulance destination (REQ-11)
  double? _quotedDistanceKm;
  int? _quotedTransportFee;
  int? _quotedFinalPrice;
  bool _isQuotingTransport = false;

  // Ambulance specific
  late TextEditingController _originAddressController;
  final TextEditingController _destinationAddressController =
      TextEditingController();
  String _ambulanceType = 'basic';

  // Labs / Imaging
  final TextEditingController _examController = TextEditingController();

  // Laboratorio (Módulo E): la toma de muestras se agenda contra un cupo
  // publicado, no se despacha como urgencia.
  LabSlot? _labSlot;
  final TextEditingController _labNotesController = TextEditingController();
  bool _submittingLab = false;

  /// True cuando el servicio se agenda en vez de despacharse de inmediato.
  bool get _isScheduledLab => widget.service.id == 'laboratorio';

  // Tarifas base del traslado. Viven aquí y no repetidas en los rótulos para
  // que el precio que se anuncia y el que se cobra no puedan divergir.
  static const int _ambulanceBasicPrice = 18500;
  static const int _ambulanceMedicalizedPrice = 28500;

  // Live zone demand / wait estimate
  ZoneEtaEstimate? _zoneEta;
  bool _zoneEtaExpanded = false;
  bool _loadingZoneEta = false;
  Timer? _zoneEtaDebounce;

  @override
  void initState() {
    super.initState();
    if (widget.dependents.isNotEmpty) {
      _selectedDependentId = widget.dependents.first.id;
    }
    _originAddressController = TextEditingController(
      text: widget.addresses.isNotEmpty ? widget.addresses.first.text : '',
    );

    // Changing the address changes the dispatch zone, and with it the wait.
    _customAddressController.addListener(_refreshZoneEta);
    _originAddressController.addListener(_refreshZoneEta);

    _refreshZoneEta();
  }

  /// Address currently selected in the form — the input for the zone lookup.
  String get _currentAddressText {
    if (widget.service.id == 'ambulancia') {
      return _originAddressController.text.trim();
    }
    if (_useCustomAddress) {
      return _customAddressController.text.trim();
    }
    return widget.addresses.isNotEmpty
        ? widget.addresses[_addressIndex].text
        : '';
  }

  /// Asks the backend how long this service is taking right now in the zone
  /// of the selected address. Debounced so typing an address doesn't spam it.
  void _refreshZoneEta() {
    _zoneEtaDebounce?.cancel();
    _zoneEtaDebounce = Timer(const Duration(milliseconds: 400), () async {
      if (!mounted) return;
      setState(() => _loadingZoneEta = true);

      final estimate = await widget.state.fetchZoneEta(
        serviceId: widget.service.id,
        address: _currentAddressText,
      );

      if (!mounted) return;
      setState(() {
        _zoneEta = estimate;
        _loadingZoneEta = false;
      });
    });
  }

  @override
  void dispose() {
    _zoneEtaDebounce?.cancel();
    _customAddressController.dispose();
    _symptomsController.dispose();
    _originAddressController.dispose();
    _destinationAddressController.dispose();
    _examController.dispose();
    _labNotesController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, CameraDevice? preferredCamera) async {
    setState(() {
      _isUploading = true;
    });

    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        preferredCameraDevice: preferredCamera ?? CameraDevice.rear,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (file != null) {
        setState(() {
          _uploadedFileName = file.name;
          _uploadedFilePreview = file.path;
        });
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al acceder a la cámara o galería: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showCameraSelectionDialog() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Seleccionar Cámara',
                  style: AppType.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Icon(Icons.camera_rear_outlined, color: p.accent),
                  title: const Text('Cámara Trasera (Recomendado)'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera, CameraDevice.rear);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.camera_front_outlined, color: p.accent),
                  title: const Text('Cámara Frontal'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera, CameraDevice.front);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Handle upload trigger
  void _handleFileUpload(String mode) {
    if (mode == 'camera') {
      _showCameraSelectionDialog();
    } else {
      _pickImage(ImageSource.gallery, null);
    }
  }

  int _calculatePrice() {
    if (widget.service.id == 'ambulancia') {
      if (_quotedFinalPrice != null) {
        return _quotedFinalPrice!;
      }
      final base = _ambulanceType == 'medicalized'
          ? _ambulanceMedicalizedPrice
          : _ambulanceBasicPrice;
      return (base * (1.0 + widget.commissionRate)).round();
    }
    return (widget.service.basePrice * (1.0 + widget.commissionRate)).round();
  }

  Future<void> _updateTransportQuote() async {
    if (widget.service.id != 'ambulancia') return;
    final origin = _originLatLng;
    final dest = _destinationLatLng;
    if (origin == null || dest == null) return;

    setState(() {
      _isQuotingTransport = true;
    });

    final quote = await widget.state.quoteTransport(
      originLat: origin.latitude,
      originLng: origin.longitude,
      destinationLat: dest.latitude,
      destinationLng: dest.longitude,
      ambulanceType: _ambulanceType,
    );

    if (mounted && quote != null) {
      setState(() {
        _isQuotingTransport = false;
        _quotedDistanceKm = (quote['distance_km'] as num?)?.toDouble();
        _quotedTransportFee = (quote['transport_fee'] as num?)?.toInt();
        _quotedFinalPrice = (quote['final_price'] as num?)?.toInt();
      });
    } else if (mounted) {
      setState(() {
        _isQuotingTransport = false;
      });
    }
  }

  Future<void> _submitForm() async {
    if (widget.service.requiresPrescription && _uploadedFileName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Toda prestación clínica de enfermería/estudios requiere cargar un pedido u orden médica.',
          ),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    if (widget.service.id == 'ambulancia' &&
        _destinationAddressController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Por favor ingrese el lugar de llegada (destino) del traslado.',
          ),
          backgroundColor: Colors.amber,
        ),
      );
      return;
    }

    if (_isRecordingVoice) {
      _warn('Detén la grabación de la nota de voz antes de confirmar la solicitud.');
      return;
    }

    String finalAddress = 'Ubicación seleccionada';
    if (widget.service.id == 'ambulancia') {
      finalAddress = _originAddressController.text;
    } else {
      finalAddress = _useCustomAddress
          ? _customAddressController.text
          : (widget.addresses.isNotEmpty
                ? widget.addresses[_addressIndex].text
                : 'Sin dirección');
    }

    // La toma de muestras no entra en la cola de despacho inmediato: va contra
    // un cupo publicado y por su propio endpoint.
    if (_isScheduledLab) {
      _submitLabRequest(finalAddress);
      return;
    }

    String? symptomsOrExam;
    if (widget.service.id == 'medico') {
      symptomsOrExam = _symptomsController.text.trim();
    } else if (widget.service.id == 'laboratorio' ||
        widget.service.id == 'radiologia' ||
        widget.service.id == 'electrocardiograma') {
      symptomsOrExam = _examController.text.trim();
    }

    // The clinical history is opened from this text: block the request until
    // the patient names at least two symptoms. Mirrors the server rule.
    if (widget.service.id == 'medico') {
      final symptomsError = validateSymptoms(symptomsOrExam);
      if (symptomsError != null) {
        setState(() => _symptomsError = symptomsError);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(symptomsError),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
        return;
      }
      setState(() => _symptomsError = null);
    }

    final price = _calculatePrice();
    // Prefer the live zone estimate over the static catalog range.
    final baseEtaMinutes = _zoneEta?.etaMinMinutes ??
        (int.tryParse(widget.service.baseEta.split('-')[0].trim()) ?? 30);

    // The patient coordinates are the attention location — for an ambulance
    // that is the pickup (origin), otherwise the picked service location.
    final LatLng? patientPoint =
        widget.service.id == 'ambulancia' ? _originLatLng : _locationLatLng;

    final error = await widget.onConfirmRequest(
      patientType: _patientType,
      dependentId: _patientType == 'dependent' ? _selectedDependentId : null,
      addressText: finalAddress,
      originAddress: widget.service.id == 'ambulancia'
          ? _originAddressController.text
          : null,
      destinationAddress: widget.service.id == 'ambulancia'
          ? _destinationAddressController.text
          : null,
      ambulanceType: widget.service.id == 'ambulancia' ? _ambulanceType : null,
      patientLat: patientPoint?.latitude,
      patientLng: patientPoint?.longitude,
      destinationLat: widget.service.id == 'ambulancia' ? _destinationLatLng?.latitude : null,
      destinationLng: widget.service.id == 'ambulancia' ? _destinationLatLng?.longitude : null,
      symptomsDescription: symptomsOrExam,
      symptomAudioPath: _symptomAudioPath,
      prescriptionName: _uploadedFileName,
      prescriptionPreview: _uploadedFilePreview,
      finalPrice: price,
      etaMinutes: baseEtaMinutes,
    );

    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: const Color(0xFFDC2626),
        ),
      );
    }
  }

  /// E.1 — agenda la toma de muestras en el cupo elegido.
  ///
  /// No hay respaldo local: si el servidor no confirma la reserva, no hay
  /// reserva. Mostrar "agendado" sin que el laboratorista lo sepa dejaría al
  /// paciente esperando a alguien que nunca fue avisado.
  Future<void> _submitLabRequest(String address) async {
    final exam = _examController.text.trim();

    if (_labSlot == null) {
      _warn('Elige el día y el bloque horario para la toma de muestras.');
      return;
    }
    if (exam.isEmpty) {
      _warn('Indica qué exámenes necesitas (ej. hemograma, perfil lipídico).');
      return;
    }

    setState(() => _submittingLab = true);

    final (request, error) = await widget.state.createLabRequest(
      slot: _labSlot!,
      patientType: _patientType,
      dependentId: _patientType == 'dependent' ? _selectedDependentId : null,
      addressText: address,
      patientLat: _locationLatLng?.latitude,
      patientLng: _locationLatLng?.longitude,
      examRequired: exam,
      clinicalNotes: _labNotesController.text.trim(),
      prescriptionName: _uploadedFileName,
      prescriptionPath: _uploadedFilePreview,
    );

    if (!mounted) return;
    setState(() => _submittingLab = false);

    if (error != null || request == null) {
      _warn(error ?? 'No se pudo agendar la toma de muestras.');
      // El cupo pudo haberse ocupado mientras el paciente llenaba el resto del
      // formulario: obligar a elegir de nuevo evita reintentar contra un
      // horario que ya no existe.
      setState(() => _labSlot = null);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          request.awaitsPayment
              ? 'Cupo reservado. Confirma el pago para dejarla agendada.'
              : 'Toma de muestras agendada para ${request.scheduledLabel ?? 'la fecha elegida'}.',
        ),
        backgroundColor: const Color(0xFF0F766E),
      ),
    );

    widget.state.setTab('appointments');
    widget.onBack();
  }

  void _warn(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.amber),
    );
  }

  /// E.2 — comentarios e indicaciones clínicas para el laboratorista.
  Widget _buildLabIndicationsBlock() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assignment_outlined, color: p.accent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Comentarios e indicaciones',
                      style: AppType.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: p.textPrimary,
                      ),
                    ),
                    Text(
                      'Condiciones previas y para cuándo lo necesitas',
                      style: AppType.bodySmall.copyWith( color: p.textFaint,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: p.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: p.border),
            ),
            child: TextField(
              controller: _labNotesController,
              maxLines: 4,
              maxLength: 1000,
              style: AppType.bodySmall.copyWith(
                color: p.textPrimary,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText:
                    'Ej. Ayuno de 12 horas. Tengo la orden médica en papel. '
                    'Necesito el resultado antes del viernes.',
                hintStyle: AppType.bodySmall.copyWith(color: p.textFaint,
                ),
                border: InputBorder.none,
                counterStyle: AppType.bodySmall.copyWith( color: p.textFaint,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final service = widget.service;
    final price = _calculatePrice();

    return Scaffold(
      backgroundColor: p.background, // slate-50
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Back Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              color: Theme.of(context).cardColor,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: Row(
                      children: [
                        Icon(Icons.chevron_left, color: p.accent),
                        Text(
                          'Volver al inicio',
                          style: AppType.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: p.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Text(
                    'PASO 1 DE 2',
                    style: AppType.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: p.textFaint,
                    ),
                  ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Main Title
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: p.accentSurface,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'Solicitud de Prestación',
                        style: AppType.bodySmall.copyWith(
                          color: p.accent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.title,
                      style: AppType.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.subtitle,
                      style: AppType.bodySmall.copyWith(
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Live wait estimate for the patient's zone. A scheduled
                    // collection has no queue to wait in, so quoting a wait
                    // there would be meaningless.
                    if (!_isScheduledLab) ...[
                      _buildZoneEtaBlock(),
                      const SizedBox(height: 12),
                    ],

                    // Scheduled-appointment shortcut for this same discipline.
                    // Replaces the old global "Citas con especialistas" banner.
                    if (specialtyForService(service.id) != null) ...[
                      _buildSchedulingShortcut(service),
                      const SizedBox(height: 16),
                    ] else
                      const SizedBox(height: 4),

                    // Warning card if set
                    if (service.warningInfo != null) ...[
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB), // amber-50
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              color: Colors.amber,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'AVISO IMPORTANTE',
                                    style: AppType.bodySmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    service.warningInfo!,
                                    style: AppType.bodySmall.copyWith(
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Block 1: Patient selection
                    _buildPatientSelection(),
                    const SizedBox(height: 16),

                    // Block 2: Symptoms description (Medico only)
                    if (service.id == 'medico') ...[
                      _buildSymptomsBlock(),
                      const SizedBox(height: 16),
                    ],

                    // Block 3: Prescription Upload
                    if (service.requiresPrescription) ...[
                      _buildPrescriptionBlock(),
                      const SizedBox(height: 16),
                    ],

                    // Block 4: Ambulance coordinates & type selection
                    if (service.id == 'ambulancia') ...[
                      _buildAmbulanceLocationsBlock(),
                      const SizedBox(height: 16),
                      _buildAmbulanceTypeBlock(),
                      const SizedBox(height: 16),
                    ],

                    // Block 5: Standard Location Selection
                    if (service.id != 'ambulancia') ...[
                      _buildStandardLocationBlock(),
                      const SizedBox(height: 16),
                    ],

                    // Block 5b: Lab scheduling (Módulo E). The slot picker
                    // comes after the address because availability can be
                    // filtered by sector.
                    if (_isScheduledLab) ...[
                      LabSlotPicker(
                        state: widget.state,
                        zone: _zoneEta?.zone,
                        onSlotSelected: (slot) => setState(() => _labSlot = slot),
                      ),
                      const SizedBox(height: 16),
                      _buildLabIndicationsBlock(),
                      const SizedBox(height: 16),
                    ],

                    // Block 6: Pricing Card
                    _buildPricingCard(service, price),
                    const SizedBox(height: 24),

                    // Block 7: Submit Buttons
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submittingLab ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: p.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: _submittingLab
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                    switch (service.id) {
                                      'medico' => 'SOLICITAR MÉDICO',
                                      'laboratorio' => 'AGENDAR TOMA DE MUESTRAS',
                                      _ => 'CONFIRMAR SOLICITUD',
                                    },
                                    style: AppType.bodySmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(Icons.arrow_forward_rounded, size: 16),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          _isScheduledLab
                              ? 'La toma de muestras no es un servicio de urgencia: queda reservada '
                                  'en el horario que elegiste y el laboratorista recibe tus indicaciones. '
                                  'Pago online protegido.'
                              : 'Al confirmar, nuestro sistema conectará con el prestador clínico de guardia más cercano en base a su ubicación. Pago online protegido.',
                          textAlign: TextAlign.center,
                          style: AppType.bodySmall.copyWith(
                            color: p.textFaint,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientSelection() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                color: p.accent,
                size: 20,
              ),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                '¿Para quién es la atención?',
                style: AppType.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary,
                ),
              ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _patientType = 'self'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _patientType == 'self'
                          ? p.accentSurface
                          : p.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _patientType == 'self'
                            ? p.accent
                            : p.border,
                        width: _patientType == 'self' ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _patientType == 'self'
                                ? p.accent
                                : p.fill,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            'Yo',
                            style: AppType.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: _patientType == 'self'
                                  ? Colors.white
                                  : p.textMuted,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Paciente Principal',
                          style: AppType.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _patientType == 'self'
                                ? p.accent
                                : p.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _patientType = 'dependent');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: _patientType == 'dependent'
                          ? p.accentSurface
                          : p.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _patientType == 'dependent'
                            ? p.accent
                            : p.border,
                        width: _patientType == 'dependent' ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: _patientType == 'dependent'
                                ? p.accent
                                : p.fill,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add,
                            size: 13,
                            color: _patientType == 'dependent'
                                ? Colors.white
                                : p.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Familiar / Dependiente',
                          style: AppType.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _patientType == 'dependent'
                                ? p.accent
                                : p.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_patientType == 'dependent') ...[
            const SizedBox(height: 16),
            Text(
              'SELECCIONE FAMILIAR GUARDADO',
              style: AppType.label.copyWith(
                fontWeight: FontWeight.bold,
                color: p.textFaint,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.dependents.isEmpty) ...[
              Text(
                'No tienes familiares agregados.',
                style: AppType.bodySmall.copyWith( color: p.textMuted,
                ),
              ),
            ] else ...[
              Column(
                children: widget.dependents.map((dep) {
                  final isSel = _selectedDependentId == dep.id;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedDependentId = dep.id),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSel
                              ? p.accentSurface.withValues(alpha: 0.4)
                              : p.background,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel
                                ? p.accent
                                : p.border,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dep.name,
                                  style: AppType.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: p.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${dep.relationship} • ${dep.age} años • ${dep.healthInsurance}',
                                  style: AppType.bodySmall.copyWith(
                                    color: p.textMuted,
                                  ),
                                ),
                              ],
                            ),
                            if (isSel)
                              Icon(
                                Icons.check,
                                color: p.accent,
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton(
                onPressed: widget.onAddDependentRedirect,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: p.accentSurface),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: const Color(0x33E6F6F4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 14, color: p.accent),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                      'Agregar Nuevo Familiar Dependiente',
                      style: AppType.bodySmall.copyWith(
                        color: p.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Live "how long will this take right now" card.
  ///
  /// Instead of promising a fixed ETA, it reflects the professionals on duty
  /// and the requests already open in the patient's zone.
  /// Compact wait indicator.
  ///
  /// Deliberately one line: the previous version was a full paragraph card that
  /// dominated the form. The demand detail is still available, but folded away
  /// behind a tap so it does not compete with the actual request.
  Widget _buildZoneEtaBlock() {
    final estimate = _zoneEta;

    if (_loadingZoneEta && estimate == null) {
      return Row(
        children: [
          SizedBox(
            height: 12,
            width: 12,
            child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
            'Calculando demora…',
            style: AppType.bodySmall.copyWith( color: p.textMuted,
            ),
          ),
          ),
        ],
      );
    }

    if (estimate == null) {
      // Backend unreachable: fall back to the catalog range.
      return Row(
        children: [
          Icon(Icons.schedule, size: 14, color: p.textMuted),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
            'Demora referencial ${widget.service.baseEta} min',
            style: AppType.bodySmall.copyWith( color: p.textSecondary,
            ),
          ),
          ),
        ],
      );
    }

    final Color tone = switch (estimate.demandLevel) {
      'high' => const Color(0xFFB91C1C),
      'medium' => const Color(0xFF92400E),
      _ => const Color(0xFF047857),
    };

    return GestureDetector(
      onTap: () => setState(() => _zoneEtaExpanded = !_zoneEtaExpanded),
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule, size: 14, color: tone),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                'Llega en ${estimate.rangeLabel}',
                style: AppType.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: tone,
                ),
              ),
              ),
              if (estimate.demandLevel != 'low') ...[
                const SizedBox(width: 6),
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(color: tone, shape: BoxShape.circle),
                ),
                const SizedBox(width: 6),
                Text(
                  estimate.demandLevel == 'high' ? 'alta demanda' : 'demanda media',
                  style: AppType.bodySmall.copyWith( color: tone,
                  ),
                ),
              ],
              const Spacer(),
              if (_loadingZoneEta)
                SizedBox(
                  height: 11,
                  width: 11,
                  child: CircularProgressIndicator(strokeWidth: 2, color: tone),
                )
              else
                Icon(
                  _zoneEtaExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: p.textFaint,
                ),
            ],
          ),
          if (_zoneEtaExpanded) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: p.fill,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    estimate.message,
                    style: AppType.bodySmall.copyWith(
                      color: p.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Tu solicitud entra a la cola de '
                    '${estimate.zone == 'General' ? 'tu sector' : estimate.zone} '
                    'y la toma el próximo prestador en turno del área.',
                    style: AppType.bodySmall.copyWith(
                      color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "Prefer a scheduled visit?" strip shown inside every service that maps to
  /// a bookable discipline (médico, enfermería, kinesiología, cuidados).
  Widget _buildSchedulingShortcut(ClinicalService service) {
    final specialty = specialtyForService(service.id)!;
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookAppointmentScreen(
              state: widget.state,
              specialtyFilter: specialty.searchTerms,
              headerTitle: 'Agendar con ${specialty.label}',
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: p.accentSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: p.accent.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, color: p.accent, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '¿Prefieres agendar para otro día?',
                    style: AppType.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: p.accent,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Reserva hora con ${specialty.label} en el horario que te acomode.',
                    style: AppType.bodySmall.copyWith( color: p.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: p.accent, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildSymptomsBlock() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.favorite_outline, color: p.accent, size: 20),
              SizedBox(width: 8),
              Flexible(
                child: Text(
                'Describa Síntomas',
                style: AppType.bodySmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary,
                ),
              ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: p.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _symptomsError != null ? const Color(0xFFDC2626) : p.border,
              ),
            ),
            child: TextField(
              controller: _symptomsController,
              maxLines: 3,
              style: AppType.bodySmall.copyWith( color: p.textSecondary,
              ),
              // Re-validate while typing so the error clears as soon as the
              // second symptom appears, instead of waiting for another submit.
              onChanged: (value) {
                if (_symptomsError != null && hasTwoSymptoms(value)) {
                  setState(() => _symptomsError = null);
                }
              },
              decoration: InputDecoration(
                hintText: widget.service.placeholderText,
                hintStyle: AppType.bodySmall.copyWith(
                  color: p.textFaint,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                _symptomsError != null
                    ? Icons.error_outline
                    : Icons.info_outline,
                size: 13,
                color: _symptomsError != null
                    ? const Color(0xFFDC2626)
                    : p.textFaint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _symptomsError ??
                      'Indica al menos dos síntomas, separados por coma o «y». '
                          'Ayuda al profesional a llegar preparado.',
                  style: AppType.bodySmall.copyWith(
                    color: _symptomsError != null
                        ? const Color(0xFFDC2626)
                        : p.textFaint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Dictation + voice note. Both are optional: the field alone still
          // works exactly as before.
          SymptomVoiceInput(
            controller: _symptomsController,
            onAudioChanged: (path) => setState(() => _symptomAudioPath = path),
            onRecordingChanged: (recording) => setState(() => _isRecordingVoice = recording),
            onTextChanged: (text) {
              if (_symptomsError != null && hasTwoSymptoms(text)) {
                setState(() => _symptomsError = null);
              }
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children:
                  [
                    'Fiebre alta',
                    'Dificultad respiratoria leve',
                    'Dolor de cabeza severo',
                    'Infección urinaria',
                    'Malestar estomacal',
                  ].map((tag) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: ActionChip(
                        padding: const EdgeInsets.all(0),
                        label: Text(
                          tag,
                          style: AppType.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: p.textMuted,
                          ),
                        ),
                        backgroundColor: p.fill,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        onPressed: () {
                          final currentText = _symptomsController.text.trim();
                          setState(() {
                            if (currentText.isEmpty) {
                              _symptomsController.text = tag;
                            } else {
                              _symptomsController.text = '$currentText, $tag';
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrescriptionBlock() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.file_present_rounded,
                color: p.accent,
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ingrese el pedido médico',
                      style: AppType.bodySmall.copyWith(
                        fontWeight: FontWeight.bold,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Toda prestación clínica de ${widget.service.shortTitle} requiere orden',
                      style: AppType.bodySmall.copyWith(
                        color: p.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: p.background,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: p.border,
                style: BorderStyle.solid,
              ),
            ),
            child: _uploadedFileName == null
                ? Column(
                    children: [
                      const Icon(
                        Icons.cloud_upload_outlined,
                        color: Color(0xFF99F6E4),
                        size: 32,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Cargar Orden Médica Digital o Foto',
                        style: AppType.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: p.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Soporta formatos PDF, PNG o JPG desde su teléfono',
                        style: AppType.bodySmall.copyWith(
                          color: p.textFaint,
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_isUploading)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 12,
                              width: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: p.accent,
                              ),
                            ),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                              'PROCESANDO DOCUMENTO...',
                              style: AppType.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: p.accent,
                              ),
                            ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: ElevatedButton(
                                  onPressed: () => _handleFileUpload('file'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: p.card,
                                    foregroundColor: p.accent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: p.accentSurface,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.file_upload_outlined,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                        'Subir archivo',
                                        style: AppType.bodySmall.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: ElevatedButton(
                                  onPressed: () => _handleFileUpload('camera'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: p.accentSurface,
                                    foregroundColor: p.accent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: p.accentSurface,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt_outlined, size: 14),
                                      SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                        'Foto',
                                        style: AppType.bodySmall.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                    ],
                  )
                : Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.accentSurface.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: p.accent.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              height: 38,
                              width: 38,
                              decoration: BoxDecoration(
                                color: p.accentSurface,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: _uploadedFilePreview != null
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.file(
                                        File(_uploadedFilePreview!),
                                        fit: BoxFit.cover,
                                        width: 38,
                                        height: 38,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.image,
                                            color: p.accent,
                                            size: 18,
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      Icons.picture_as_pdf,
                                      color: p.accent,
                                      size: 18,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _uploadedFileName!,
                                  style: AppType.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: p.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Verificado exitosamente',
                                  style: AppType.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF10B981),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            if (_uploadedFilePreview != null) {
                              try {
                                final file = File(_uploadedFilePreview!);
                                if (file.existsSync()) {
                                  file.deleteSync();
                                }
                              } catch (e) {
                                debugPrint('Error deleting file: $e');
                              }
                            }
                            setState(() {
                              _uploadedFileName = null;
                              _uploadedFilePreview = null;
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: p.card,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                          child: Text(
                            'Borrar',
                            style: AppType.bodySmall.copyWith(
                              color: Color(0xFFF43F5E),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (widget.service.id == 'laboratorio' ||
              widget.service.id == 'radiologia' ||
              widget.service.id == 'electrocardiograma') ...[
            const SizedBox(height: 14),
            Text(
              'ESPECIFIQUE EXAMEN SOLICITADO',
              style: AppType.label.copyWith(
                fontWeight: FontWeight.bold,
                color: p.textFaint,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: p.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: p.border),
              ),
              child: TextField(
                controller: _examController,
                style: AppType.bodySmall.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: widget.service.placeholderText,
                  hintStyle: AppType.bodySmall.copyWith(
                    color: p.textFaint,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAmbulanceLocationsBlock() {
    final theme = Theme.of(context);
    return Column(
      children: [
        // From
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: Color(0xFFF43F5E),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Desde dónde',
                            style: AppType.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: p.textPrimary,
                            ),
                          ),
                          Text(
                            'Inicio del traslado',
                            style: AppType.bodySmall.copyWith(
                              color: p.textFaint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Icon(
                    Icons.local_shipping,
                    color: p.accent.withValues(alpha: 0.8),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MapLocationPicker(
                height: 150,
                accentColor: const Color(0xFFF43F5E),
                autoLocateOnInit: true,
                onLocationChanged: (point, address) {
                  setState(() {
                    _originLatLng = point;
                    if (address != null && address.isNotEmpty) {
                      _originAddressController.text = address;
                    }
                  });
                  _updateTransportQuote();
                },
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: p.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: TextField(
                  controller: _originAddressController,
                  style: AppType.bodySmall.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Dirección exacta de inicio',
                    hintStyle: AppType.bodySmall.copyWith(
                      color: p.textFaint,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        // To
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lugar de llegada',
                            style: AppType.bodySmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: p.textPrimary,
                            ),
                          ),
                          Text(
                            'Destino programado',
                            style: AppType.bodySmall.copyWith(
                              color: p.textFaint,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    height: 24,
                    width: 24,
                    decoration: BoxDecoration(
                      color: p.fill,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        'B',
                        style: AppType.bodySmall.copyWith(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              MapLocationPicker(
                height: 150,
                accentColor: Colors.blue,
                onLocationChanged: (point, address) {
                  setState(() {
                    _destinationLatLng = point;
                    if (address != null && address.isNotEmpty) {
                      _destinationAddressController.text = address;
                    }
                  });
                  _updateTransportQuote();
                },
              ),
              if (_isQuotingTransport || _quotedDistanceKm != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      if (_isQuotingTransport)
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF2563EB)),
                        )
                      else
                        const Icon(Icons.route, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isQuotingTransport
                                  ? 'Calculando distancia y tarifa...'
                                  : 'Distancia estimada: ${_quotedDistanceKm!.toStringAsFixed(1)} km',
                              style: AppType.bodySmall.copyWith(
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E40AF),
                              ),
                            ),
                            Text(
                              _quotedTransportFee != null
                                  ? 'Tarifa base + kilometraje: ${Money.format(_quotedTransportFee!)}'
                                  : 'Tarifa calculada dinámicamente según trayecto',
                              style: AppType.label.copyWith(color: const Color(0xFF3B82F6)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: p.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.border),
                ),
                child: TextField(
                  controller: _destinationAddressController,
                  style: AppType.bodySmall.copyWith(
                    color: p.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Dirección exacta de destino',
                    hintStyle: AppType.bodySmall.copyWith(
                      color: p.textFaint,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildAmbulanceTypeBlock() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TIPO DE AMBULANCIA',
            style: AppType.label.copyWith(
              fontWeight: FontWeight.bold,
              color: p.textFaint,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _ambulanceType = 'basic');
                    _updateTransportQuote();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _ambulanceType == 'basic'
                          ? p.accentSurface
                          : p.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _ambulanceType == 'basic'
                            ? p.accent
                            : p.border,
                        width: _ambulanceType == 'basic' ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Básica',
                          style: AppType.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _ambulanceType == 'basic' ? p.accent : p.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${Money.format(_ambulanceBasicPrice)} base',
                          style: AppType.bodySmall.copyWith(
                            color: p.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _ambulanceType = 'medicalized');
                    _updateTransportQuote();
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _ambulanceType == 'medicalized'
                          ? p.accentSurface
                          : p.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _ambulanceType == 'medicalized'
                            ? p.accent
                            : p.border,
                        width: _ambulanceType == 'medicalized' ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Medicalizada',
                          style: AppType.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                            color: _ambulanceType == 'medicalized' ? p.accent : p.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '${Money.format(_ambulanceMedicalizedPrice)} base',
                          style: AppType.bodySmall.copyWith(
                            color: p.accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Center(
            child: Text(
              'La Ambulancia Medicalizada incluye médico a bordo e instrumentación de cuidados intermedios/UTI.',
              textAlign: TextAlign.center,
              style: AppType.bodySmall.copyWith(
                color: p.textFaint,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStandardLocationBlock() {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: p.accent,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Lugar de la atención',
                        style: AppType.bodySmall.copyWith(
                          fontWeight: FontWeight.bold,
                          color: p.textPrimary,
                        ),
                      ),
                      Text(
                        '¿Dónde asistirá el personal clínico?',
                        style: AppType.bodySmall.copyWith( color: p.textFaint,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _useCustomAddress = !_useCustomAddress;
                  });
                  _refreshZoneEta();
                },
                child: Text(
                  _useCustomAddress ? 'Usar favoritas' : 'Nueva dirección',
                  style: AppType.bodySmall.copyWith(
                    fontWeight: FontWeight.bold,
                    color: p.accent,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_useCustomAddress) ...[
            if (widget.addresses.isEmpty) ...[
              Text(
                'No hay direcciones disponibles.',
                style: AppType.bodySmall.copyWith( color: p.textMuted,
                ),
              ),
            ] else ...[
              Column(
                children: List.generate(widget.addresses.length, (idx) {
                  final addr = widget.addresses[idx];
                  final isSel = _addressIndex == idx;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _addressIndex = idx);
                        _refreshZoneEta();
                      },
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSel
                              ? p.accentSurface.withValues(alpha: 0.4)
                              : p.card,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSel
                                ? p.accent
                                : p.border,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    addr.label,
                                    style: AppType.bodySmall.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: p.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    addr.text,
                                    style: AppType.bodySmall.copyWith(
                                      color: p.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSel)
                              Icon(
                                Icons.check,
                                color: p.accent,
                                size: 16,
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ],
          ] else ...[
            Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: p.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.border),
                  ),
                  child: TextField(
                    controller: _customAddressController,
                    style: AppType.bodySmall.copyWith(
                      color: p.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Ej: Calle Suecia 120, depto 201, Providencia, Santiago',
                      hintStyle: AppType.bodySmall.copyWith(
                        color: p.textFaint,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                MapLocationPicker(
                  height: 170,
                  autoLocateOnInit: true,
                  onLocationChanged: (point, address) {
                    setState(() {
                      _locationLatLng = point;
                      if (address != null && address.isNotEmpty) {
                        _customAddressController.text = address;
                      }
                    });
                  },
                ),
                const SizedBox(height: 6),
                Text(
                  'Mueva el mapa para ajustar el pin sobre la dirección exacta.',
                  style: AppType.bodySmall.copyWith( color: p.textFaint,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPricingCard(ClinicalService service, int calculatedPrice) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F172A),
            Color(0xFF115E59),
          ], // brand-dark to teal-800 (always dark in both themes)
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TARIFA COTIZADA ESTIMADA',
                  style: AppType.label.copyWith(
                    color: Color(0xFF2DD4BF),
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    text:
                        '${Money.format(calculatedPrice)} ',
                    style: AppType.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    children: [
                      TextSpan(
                        text: Money.code,
                        style: AppType.bodySmall.copyWith(
                          fontWeight: FontWeight.normal,
                          color: Color(0xFF99F6E4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Incluye insumos médicos clínicos y traslado profesional',
                  style: AppType.bodySmall.copyWith(
                    color: Color(0xFFCCFBF1),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0x990F766E),
              border: Border.all(color: const Color(0x4D0F766E)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.access_time,
                      color: Color(0xFF2DD4BF),
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      service.baseEta,
                      style: AppType.bodySmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Minutos de arribo',
                  style: AppType.bodySmall.copyWith(color: Color(0xFFCCFBF1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
