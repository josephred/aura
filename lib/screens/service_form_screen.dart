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
import '../utils/symptom_validation.dart';
import '../models/lab_models.dart';
import '../widgets/booking_voucher_dialog.dart';
import '../widgets/lab_slot_picker.dart';
import '../widgets/map_location_picker.dart';
import '../widgets/symptom_voice_input.dart';
import '../ui/aura.dart';
import '../ui/service_visuals.dart';

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

  // ------------------------------------------------------------ asistente
  //
  // El formulario dejó de ser una página con ocho bloques y pasó a ser una
  // pregunta por pantalla. Estos tres campos son todo lo que hace falta para
  // eso: en qué paso estamos, hacia dónde vamos (para la dirección de la
  // transición) y si ya se intentó avanzar (para no pintar errores en rojo
  // sobre campos que la persona todavía no ha tenido ocasión de rellenar).
  int _stepIndex = 0;
  bool _goingForward = true;
  final Set<int> _visited = {0};

  // Live zone demand / wait estimate
  ZoneEtaEstimate? _zoneEta;
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
      _warn('Necesitamos una foto de tu orden médica para poder atenderte.');
      return;
    }

    if (widget.service.id == 'ambulancia' &&
        _destinationAddressController.text.trim().isEmpty) {
      _warn('Falta indicar a dónde va el traslado.');
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
        _fail(symptomsError);
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
      _fail(error);
      return;
    }

    if (!mounted) return;

    // Obtener nombre del paciente para el voucher
    String patientName = widget.state.userName.isNotEmpty
        ? widget.state.userName
        : 'Paciente';
    String? rel;
    if (_patientType == 'dependent' && _selectedDependentId != null) {
      final dep = widget.dependents.firstWhere(
        (d) => d.id == _selectedDependentId,
        orElse: () => Dependent(
          id: '',
          name: 'Familiar',
          relationship: '',
          age: 0,
          healthInsurance: '',
          medicalConditions: '',
        ),
      );
      patientName = dep.name;
      rel = dep.relationship;
    }

    final activeReq = widget.state.currentRequest;
    final folio = activeReq?.id.toUpperCase().replaceAll('REQ_', '').replaceAll('-', '') ??
        DateTime.now().millisecondsSinceEpoch.toString().substring(7);

    final voucherData = BookingVoucherData(
      folio: folio,
      serviceTitle: widget.service.title,
      serviceIcon: _getServiceIcon(widget.service),
      patientName: patientName,
      patientType: _patientType,
      relationship: rel,
      address: finalAddress,
      originAddress: widget.service.id == 'ambulancia'
          ? _originAddressController.text
          : null,
      destinationAddress: widget.service.id == 'ambulancia'
          ? _destinationAddressController.text
          : null,
      ambulanceType: widget.service.id == 'ambulancia' ? _ambulanceType : null,
      symptomsOrReason: symptomsOrExam,
      finalPrice: price,
      etaMinutes: baseEtaMinutes,
      createdAt: DateTime.now(),
    );

    await showBookingVoucherDialog(
      context: context,
      voucher: voucherData,
      onTrack: () {
        widget.state.selectService(null);
        widget.state.setTab('appointments');
      },
    );

    widget.state.selectService(null);
    widget.state.setTab('appointments');
  }

  IconData _getServiceIcon(ClinicalService service) {
    switch (service.iconName) {
      case 'Activity':
        return Icons.local_hospital_rounded;
      case 'UserRoundPlus':
        return Icons.medical_services_rounded;
      case 'Footprints':
        return Icons.directions_walk_rounded;
      case 'Lungs':
        return Icons.air_rounded;
      case 'HeartHandshake':
        return Icons.favorite_rounded;
      case 'Truck':
        return Icons.emergency_rounded;
      case 'ScanFace':
        return Icons.medical_information_rounded;
      case 'FlaskConical':
        return Icons.biotech_rounded;
      case 'Heart':
        return Icons.monitor_heart_rounded;
      default:
        return Icons.health_and_safety_rounded;
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
        backgroundColor: context.palette.success,
      ),
    );

    // Obtener nombre del paciente para el voucher de laboratorio
    String patientName = widget.state.userName.isNotEmpty
        ? widget.state.userName
        : 'Paciente';
    String? rel;
    if (_patientType == 'dependent' && _selectedDependentId != null) {
      final dep = widget.dependents.firstWhere(
        (d) => d.id == _selectedDependentId,
        orElse: () => Dependent(
          id: '',
          name: 'Familiar',
          relationship: '',
          age: 0,
          healthInsurance: '',
          medicalConditions: '',
        ),
      );
      patientName = dep.name;
      rel = dep.relationship;
    }

    final folio = request.id.toUpperCase().replaceAll('REQ_', '').replaceAll('-', '');

    final voucherData = BookingVoucherData(
      folio: folio,
      serviceTitle: 'Toma de Muestras a Domicilio',
      serviceIcon: Icons.biotech_rounded,
      patientName: patientName,
      patientType: _patientType,
      relationship: rel,
      address: address,
      symptomsOrReason: _labNotesController.text.trim().isNotEmpty
          ? 'Exámenes: $exam • Indicaciones: ${_labNotesController.text.trim()}'
          : 'Exámenes: $exam',
      finalPrice: _calculatePrice(),
      etaMinutes: 0,
      createdAt: DateTime.now(),
    );

    await showBookingVoucherDialog(
      context: context,
      voucher: voucherData,
      onTrack: () {
        widget.state.setTab('appointments');
        widget.onBack();
      },
    );

    widget.state.setTab('appointments');
    widget.onBack();
  }

  /// Aviso de que falta algo. Ámbar del sistema, no un literal.
  void _warn(String message) {
    final c = auraToneColors(context, AuraTone.warning);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: TextStyle(color: c.onSurface)),
        backgroundColor: c.surface,
      ),
    );
  }

  /// Algo falló de verdad.
  void _fail(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: context.palette.error,
      ),
    );
  }

  // ========================================================================
  //  Presentación: un asistente de una pregunta por pantalla
  // ========================================================================
  //
  // Lo que había antes: un `SingleChildScrollView` con, de una sola vez, la
  // ficha del servicio, el estado de la zona, un atajo a agendar, un aviso
  // legal en ámbar, el selector de paciente, los síntomas, la carga de la
  // orden médica, la dirección, la tarjeta de precio y el botón. Y una
  // cabecera que decía «PASO 1 DE 2» mientras enseñaba las diez cosas.
  //
  // Lo que hay ahora: entre tres y cinco pasos, según el servicio, con una
  // pregunta cada uno. Ningún dato se ha dejado de pedir; lo que cambia es
  // cuándo se pide.
  //
  // Cada paso sabe tres cosas: qué pregunta, si se puede avanzar, y qué falta
  // si no se puede. Ese último punto es el que arregla el patrón viejo, donde
  // lo único que decía qué faltaba era el rótulo de un botón inhabilitado al
  // fondo de la página, lejos del campo sin rellenar.

  /// Los pasos de este servicio, en orden.
  ///
  /// Se calcula en cada `build` en vez de guardarse: depende del servicio, que
  /// no cambia, pero también de si hay familiares cargados, que sí puede
  /// cambiar mientras el asistente está abierto.
  List<_StepId> get _steps {
    final id = widget.service.id;
    return [
      _StepId.patient,
      if (id == 'medico') _StepId.symptoms,
      if (id == 'radiologia' || id == 'electrocardiograma') _StepId.exam,
      if (widget.service.requiresPrescription) _StepId.prescription,
      _StepId.location,
      if (id == 'ambulancia') _StepId.ambulanceType,
      if (_isScheduledLab) _StepId.labSlot,
      _StepId.confirm,
    ];
  }

  _StepId get _currentStep => _steps[_stepIndex.clamp(0, _steps.length - 1)];

  /// Qué impide avanzar desde el paso actual, en lenguaje corriente.
  ///
  /// Devuelve `null` cuando se puede seguir. El texto es el que se muestra
  /// junto al botón, así que está escrito para leerse, no para registrarse:
  /// «Elige el día y la hora», no «labSlot is required».
  String? _blockerFor(_StepId step) {
    switch (step) {
      case _StepId.patient:
        if (_patientType == 'dependent' && _selectedDependentId == null) {
          return 'Elige a la persona que necesita la atención.';
        }
        return null;

      case _StepId.symptoms:
        final text = _symptomsController.text.trim();
        if (text.isEmpty) return 'Cuéntanos qué le pasa para poder ayudarte.';
        // Se usa la misma regla que aplica el servidor, para que nadie llegue
        // al final del asistente y ahí descubra que el texto no vale.
        return validateSymptoms(text);

      case _StepId.exam:
        if (_examController.text.trim().isEmpty) {
          return 'Escribe qué examen necesitas, como aparece en tu orden.';
        }
        return null;

      case _StepId.prescription:
        if (_uploadedFileName == null) {
          return 'Adjunta una foto de tu orden médica para continuar.';
        }
        return null;

      case _StepId.location:
        if (widget.service.id == 'ambulancia') {
          if (_originAddressController.text.trim().isEmpty) {
            return 'Indica desde dónde sale el traslado.';
          }
          if (_destinationAddressController.text.trim().isEmpty) {
            return 'Indica a dónde va el traslado.';
          }
          return null;
        }
        if (_useCustomAddress && _customAddressController.text.trim().isEmpty) {
          return 'Escribe la dirección donde te atendemos.';
        }
        if (!_useCustomAddress && widget.addresses.isEmpty) {
          return 'Añade una dirección para continuar.';
        }
        return null;

      case _StepId.ambulanceType:
        return null;

      case _StepId.labSlot:
        if (_labSlot == null) return 'Elige el día y la hora de la toma.';
        if (_examController.text.trim().isEmpty) {
          return 'Escribe qué exámenes te indicaron.';
        }
        return null;

      case _StepId.confirm:
        if (_isRecordingVoice) {
          return 'Detén la grabación antes de enviar la solicitud.';
        }
        return null;
    }
  }

  void _next() {
    final blocker = _blockerFor(_currentStep);
    if (blocker != null) {
      // Marcar el paso como visitado hace que sus errores en línea aparezcan.
      // Antes de tocar «Continuar» no había ocurrido nada que justificara
      // pintar un campo en rojo.
      setState(() => _visited.add(_stepIndex));
      return;
    }
    if (_stepIndex >= _steps.length - 1) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _goingForward = true;
      _stepIndex++;
      _visited.add(_stepIndex);
    });
  }

  void _back() {
    if (_stepIndex == 0) {
      widget.onBack();
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _goingForward = false;
      _stepIndex--;
    });
  }

  /// Salta directamente a un paso. Lo usa el resumen final: cada línea del
  /// resumen es tocable y lleva al paso donde se decidió ese dato, que es más
  /// rápido que retroceder de uno en uno.
  void _jumpTo(_StepId step) {
    final index = _steps.indexOf(step);
    if (index < 0) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _goingForward = index > _stepIndex;
      _stepIndex = index;
      _visited.add(index);
    });
  }

  /// Confirmar sin salir del asistente si algo falta.
  Future<void> _confirmAndSubmit() async {
    final blocker = _blockerFor(_StepId.confirm);
    if (blocker != null) {
      _warn(blocker);
      return;
    }
    // Toda la lógica de envío —validaciones del servidor, el desvío del
    // laboratorio por su propio endpoint, el comprobante y la navegación al
    // seguimiento— sigue siendo la de antes, intacta.
    await _submitForm();
  }

  /// Dirección seleccionada, tal y como la verá el resumen.
  String get _resolvedAddress {
    if (widget.service.id == 'ambulancia') {
      return _originAddressController.text.trim();
    }
    if (_useCustomAddress) return _customAddressController.text.trim();
    if (widget.addresses.isEmpty) return '';
    return widget.addresses[_addressIndex].text;
  }

  /// Nombre de la persona atendida, para el resumen.
  String get _patientLabel {
    if (_patientType == 'self') {
      return widget.state.userName.trim().isEmpty
          ? 'Para mí'
          : widget.state.userName.trim();
    }
    final dep = widget.dependents
        .cast<Dependent?>()
        .firstWhere((d) => d?.id == _selectedDependentId, orElse: () => null);
    return dep?.name ?? 'Un familiar';
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final step = _currentStep;
    final blocker = _blockerFor(step);
    final isLast = step == _StepId.confirm;

    return PopScope(
      // Retroceder con el gesto del sistema retrocede un paso, no cierra el
      // asistente entero. Perder cuatro respuestas por un gesto involuntario
      // era el peor fallo posible de este flujo.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: p.background,
        body: SafeArea(
          child: Column(
            children: [
              AuraFlowHeader(
                step: _stepIndex,
                total: _steps.length,
                title: serviceShortName(
                  widget.service.id,
                  widget.service.shortTitle,
                ),
                onBack: _back,
                onClose: _stepIndex == 0 ? null : widget.onBack,
              ),
              Expanded(
                child: AuraStepTransition(
                  stepKey: step,
                  forward: _goingForward,
                  child: AuraFlowStep(
                    key: ValueKey(step),
                    question: _questionFor(step),
                    help: _helpFor(step),
                    primaryLabel: isLast ? _submitLabel() : 'Continuar',
                    primaryIcon: isLast ? null : Icons.arrow_forward_rounded,
                    onPrimary: blocker != null
                        ? null
                        : (isLast ? _confirmAndSubmit : _next),
                    primaryLoading: _submittingLab,
                    blockedReason: blocker,
                    secondaryLabel: _secondaryLabelFor(step),
                    onSecondary: _secondaryActionFor(step),
                    child: _bodyFor(step),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// La pregunta de cada paso. En segunda persona y sin vocabulario de ficha
  /// clínica: «¿Qué le pasa?» en vez de «Descripción de sintomatología».
  String _questionFor(_StepId step) => switch (step) {
    _StepId.patient => '¿Para quién es la atención?',
    _StepId.symptoms => '¿Qué le pasa?',
    _StepId.exam => '¿Qué examen necesitas?',
    _StepId.prescription => 'Adjunta la orden médica',
    _StepId.location => widget.service.id == 'ambulancia'
        ? '¿Desde dónde y hasta dónde?'
        : '¿Dónde te atendemos?',
    _StepId.ambulanceType => '¿Qué tipo de traslado?',
    _StepId.labSlot => '¿Cuándo tomamos la muestra?',
    _StepId.confirm => 'Revisa y confirma',
  };

  String? _helpFor(_StepId step) => switch (step) {
    _StepId.patient => null,
    _StepId.symptoms =>
      'Nombra al menos dos molestias. Con eso el médico llega sabiendo qué esperar.',
    _StepId.exam => 'Cópialo tal como está escrito en tu orden.',
    _StepId.prescription =>
      'Una foto legible basta. Puedes hacerla ahora mismo.',
    _StepId.location => widget.service.id == 'ambulancia'
        ? null
        : 'Puedes usar una dirección guardada o marcar el punto en el mapa.',
    _StepId.ambulanceType => null,
    _StepId.labSlot => 'Elige el bloque que te acomode.',
    _StepId.confirm => null,
  };

  /// El rótulo del botón dice qué va a pasar, no «Confirmar».
  String _submitLabel() => switch (widget.service.id) {
    'medico' => 'Pedir un médico',
    'enfermeria' => 'Pedir enfermería',
    'ambulancia' => 'Pedir el traslado',
    'laboratorio' => 'Reservar la toma',
    _ => 'Enviar solicitud',
  };

  String? _secondaryLabelFor(_StepId step) {
    if (step == _StepId.patient && widget.dependents.isEmpty) {
      return 'Añadir un familiar';
    }
    if (step == _StepId.location &&
        widget.service.id != 'ambulancia' &&
        !_useCustomAddress) {
      return 'Usar otra dirección';
    }
    return null;
  }

  VoidCallback? _secondaryActionFor(_StepId step) {
    if (step == _StepId.patient && widget.dependents.isEmpty) {
      return widget.onAddDependentRedirect;
    }
    if (step == _StepId.location &&
        widget.service.id != 'ambulancia' &&
        !_useCustomAddress) {
      return () => setState(() => _useCustomAddress = true);
    }
    return null;
  }

  Widget _bodyFor(_StepId step) => switch (step) {
    _StepId.patient => _patientStep(),
    _StepId.symptoms => _symptomsStep(),
    _StepId.exam => _examStep(),
    _StepId.prescription => _prescriptionStep(),
    _StepId.location => widget.service.id == 'ambulancia'
        ? _ambulanceLocationStep()
        : _locationStep(),
    _StepId.ambulanceType => _ambulanceTypeStep(),
    _StepId.labSlot => _labSlotStep(),
    _StepId.confirm => _confirmStep(),
  };

  // ------------------------------------------------------- paso: paciente

  /// Antes: dos recuadros con un círculo dentro que ponía «Yo», los rótulos
  /// «Paciente Principal» y «Carga Familiar», y un desplegable debajo. Ahora:
  /// dos opciones de 60 px y, si se elige familiar, la lista de personas.
  Widget _patientStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraChoiceTile(
          title: 'Para mí',
          subtitle: widget.state.userName.trim().isEmpty
              ? null
              : widget.state.userName.trim(),
          icon: Icons.person_rounded,
          selected: _patientType == 'self',
          onTap: () => setState(() => _patientType = 'self'),
        ),
        const SizedBox(height: AuraTap.gap),
        AuraChoiceTile(
          title: 'Para un familiar',
          subtitle: widget.dependents.isEmpty
              ? 'Aún no tienes familiares guardados'
              : '${widget.dependents.length} '
                  '${widget.dependents.length == 1 ? "persona guardada" : "personas guardadas"}',
          icon: Icons.family_restroom_rounded,
          selected: _patientType == 'dependent',
          onTap: () => setState(() => _patientType = 'dependent'),
        ),

        // La lista de familiares solo existe cuando hace falta: es progressive
        // disclosure aplicado al sitio donde más se nota.
        if (_patientType == 'dependent') ...[
          const SizedBox(height: AuraSpace.lg),
          if (widget.dependents.isEmpty)
            AuraEmptyState(
              icon: Icons.person_add_alt_1_rounded,
              title: 'Todavía no hay nadie guardado',
              message:
                  'Guarda a la persona una vez y ya no tendrás que volver a '
                  'escribir sus datos.',
              actionLabel: 'Añadir un familiar',
              onAction: widget.onAddDependentRedirect,
              compact: true,
            )
          else ...[
            Text(
              'Elige a la persona',
              style: AppType.bodySmall.copyWith(
                fontWeight: FontWeight.w700,
                color: p.textSecondary,
              ),
            ),
            const SizedBox(height: AuraSpace.xs),
            ...widget.dependents.map(
              (dep) => Padding(
                padding: const EdgeInsets.only(bottom: AuraTap.gap),
                child: AuraChoiceTile(
                  title: dep.name,
                  subtitle: '${dep.relationship} · ${dep.age} años',
                  icon: Icons.person_outline_rounded,
                  selected: _selectedDependentId == dep.id,
                  onTap: () => setState(() => _selectedDependentId = dep.id),
                ),
              ),
            ),
            AuraButton.tertiary(
              label: 'Añadir otro familiar',
              icon: Icons.add_rounded,
              onPressed: widget.onAddDependentRedirect,
            ),
          ],
        ],
      ],
    );
  }

  // ------------------------------------------------------- paso: síntomas

  Widget _symptomsStep() {
    final showError = _visited.contains(_stepIndex);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraField.multiline(
          label: 'Qué molestias tiene',
          hint: widget.service.placeholderText ??
              'Ej. fiebre desde ayer y dolor de garganta',
          controller: _symptomsController,
          maxLines: 5,
          maxLength: 500,
          errorText: showError ? _symptomsError : null,
          onChanged: (_) => setState(() => _symptomsError = null),
        ),
        const SizedBox(height: AuraSpace.md),

        // El dictado y la nota de voz se conservan tal cual: para una persona
        // mayor, hablar suele ser más fácil que escribir en un teclado táctil.
        SymptomVoiceInput(
          controller: _symptomsController,
          onAudioChanged: (path) => setState(() => _symptomAudioPath = path),
          onRecordingChanged: (rec) => setState(() => _isRecordingVoice = rec),
          onTextChanged: (_) => setState(() => _symptomsError = null),
        ),
      ],
    );
  }

  // ---------------------------------------------------------- paso: examen

  Widget _examStep() {
    return AuraField.multiline(
      label: 'Examen indicado',
      hint: widget.service.placeholderText ?? 'Ej. radiografía de tórax',
      help: 'Si son varios, escríbelos separados por comas.',
      controller: _examController,
      maxLines: 4,
      maxLength: 300,
      onChanged: (_) => setState(() {}),
    );
  }

  // ------------------------------------------------------ paso: orden médica

  /// La carga de la orden médica.
  ///
  /// Antes eran 335 líneas con dos botones, una vista previa, un aviso legal en
  /// ámbar y una explicación de por qué hace falta la orden. Aquí el porqué se
  /// dice en una línea, los dos botones son dos opciones grandes, y la vista
  /// previa aparece solo cuando hay algo que previsualizar.
  Widget _prescriptionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_uploadedFileName == null) ...[
          AuraChoiceTile(
            title: 'Hacer una foto',
            subtitle: 'Con la cámara del teléfono',
            icon: Icons.photo_camera_rounded,
            onTap: _isUploading ? null : () => _handleFileUpload('camera'),
            enabled: !_isUploading,
          ),
          const SizedBox(height: AuraTap.gap),
          AuraChoiceTile(
            title: 'Elegir de la galería',
            subtitle: 'Si ya le hiciste una foto',
            icon: Icons.photo_library_rounded,
            onTap: _isUploading ? null : () => _handleFileUpload('gallery'),
            enabled: !_isUploading,
          ),
          if (_isUploading) ...[
            const SizedBox(height: AuraSpace.md),
            const Center(child: AuraLoading(message: 'Abriendo…')),
          ],
        ] else
          _uploadedPreview(),

        const SizedBox(height: AuraSpace.lg),
        // El motivo, en una línea. El texto largo del catálogo
        // (`service.warningInfo`) queda plegado para quien quiera leerlo.
        AuraDisclosure(
          title: '¿Por qué necesito una orden médica?',
          icon: Icons.help_outline_rounded,
          child: Text(
            widget.service.warningInfo ??
                'Es un requisito clínico para poder realizar este procedimiento '
                    'en tu domicilio.',
            style: AppType.bodySmall.copyWith(color: p.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _uploadedPreview() {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 56,
                width: 56,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: p.successSurface,
                  borderRadius: AuraRadius.allSm,
                ),
                child: _uploadedFilePreview != null &&
                        File(_uploadedFilePreview!).existsSync()
                    ? Image.file(
                        File(_uploadedFilePreview!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Icon(
                          Icons.description_rounded,
                          color: p.onSuccessSurface,
                        ),
                      )
                    : Icon(
                        Icons.description_rounded,
                        color: p.onSuccessSurface,
                        size: AuraIcon.lg,
                      ),
              ),
              const SizedBox(width: AuraSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle_rounded,
                          size: AuraIcon.sm,
                          color: p.success,
                        ),
                        const SizedBox(width: AuraSpace.xxs),
                        Text(
                          'Orden adjunta',
                          style: AppType.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AuraSpace.xxxs),
                    Text(
                      _uploadedFileName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.bodySmall.copyWith(color: p.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.sm),
          AuraButton.tertiary(
            label: 'Cambiar la foto',
            icon: Icons.refresh_rounded,
            onPressed: () => setState(() {
              _uploadedFileName = null;
              _uploadedFilePreview = null;
            }),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------- paso: dirección

  Widget _locationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!_useCustomAddress && widget.addresses.isNotEmpty) ...[
          ...widget.addresses.asMap().entries.map((e) {
            final addr = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: AuraTap.gap),
              child: AuraChoiceTile(
                title: addr.label,
                subtitle: addr.text,
                icon: Icons.home_rounded,
                selected: _addressIndex == e.key,
                onTap: () {
                  setState(() => _addressIndex = e.key);
                  _refreshZoneEta();
                },
              ),
            );
          }),
        ] else ...[
          AuraField(
            label: 'Dirección',
            hint: 'Calle, número, depto y comuna',
            controller: _customAddressController,
            icon: Icons.place_rounded,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: AuraSpace.md),
          _mapCard(
            label: 'Marca el punto exacto',
            onChanged: (point, address) {
              setState(() {
                _locationLatLng = point;
                if (address != null && address.isNotEmpty) {
                  _customAddressController.text = address;
                }
              });
            },
          ),
          if (widget.addresses.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.sm),
            AuraButton.tertiary(
              label: 'Usar una dirección guardada',
              icon: Icons.bookmark_rounded,
              onPressed: () => setState(() => _useCustomAddress = false),
            ),
          ],
        ],

        const SizedBox(height: AuraSpace.md),
        _zoneWaitLine(),
      ],
    );
  }

  Widget _ambulanceLocationStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraField(
          label: 'Desde dónde sale',
          hint: 'Dirección de recogida',
          controller: _originAddressController,
          icon: Icons.trip_origin_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AuraSpace.xs),
        _mapCard(
          label: 'Punto de recogida',
          height: 180,
          onChanged: (point, address) {
            setState(() {
              _originLatLng = point;
              if (address != null && address.isNotEmpty) {
                _originAddressController.text = address;
              }
            });
            _updateTransportQuote();
          },
        ),
        const SizedBox(height: AuraSpace.lg),
        AuraField(
          label: 'A dónde va',
          hint: 'Clínica, hospital o domicilio de destino',
          controller: _destinationAddressController,
          icon: Icons.place_rounded,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AuraSpace.xs),
        _mapCard(
          label: 'Punto de destino',
          height: 180,
          onChanged: (point, address) {
            setState(() {
              _destinationLatLng = point;
              if (address != null && address.isNotEmpty) {
                _destinationAddressController.text = address;
              }
            });
            _updateTransportQuote();
          },
        ),
        if (_isQuotingTransport) ...[
          const SizedBox(height: AuraSpace.md),
          const AuraLoading(message: 'Calculando la distancia…'),
        ] else if (_quotedDistanceKm != null) ...[
          const SizedBox(height: AuraSpace.md),
          AuraBanner(
            tone: AuraTone.info,
            icon: Icons.route_rounded,
            message: _quotedTransportFee == null
                ? 'Son ${_quotedDistanceKm!.toStringAsFixed(1)} km de recorrido.'
                : 'Son ${_quotedDistanceKm!.toStringAsFixed(1)} km. '
                    'El traslado añade ${Money.format(_quotedTransportFee!)} al total.',
          ),
        ],
      ],
    );
  }

  Widget _mapCard({
    required String label,
    required void Function(LatLng, String?) onChanged,
    double height = 200,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppType.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            color: p.textSecondary,
          ),
        ),
        const SizedBox(height: AuraSpace.xs),
        ClipRRect(
          borderRadius: AuraRadius.allMd,
          child: MapLocationPicker(
            height: height,
            accentColor: p.accent,
            autoLocateOnInit: true,
            onLocationChanged: onChanged,
          ),
        ),
      ],
    );
  }

  /// La espera en la zona, en una línea.
  ///
  /// Antes era un bloque desplegable de 130 líneas con el número de pacientes
  /// en cola, los profesionales libres y una etiqueta de «nivel de demanda».
  /// Nada de eso ayuda a decidir: lo único accionable es cuánto se va a
  /// esperar. El detalle sigue disponible, plegado.
  Widget _zoneWaitLine() {
    if (_loadingZoneEta) {
      return Row(
        children: [
          SizedBox(
            width: AuraIcon.sm,
            height: AuraIcon.sm,
            child: CircularProgressIndicator(strokeWidth: 2, color: p.accent),
          ),
          const SizedBox(width: AuraSpace.xs),
          Text(
            'Calculando la espera…',
            style: AppType.bodySmall.copyWith(color: p.textMuted),
          ),
        ],
      );
    }

    final eta = _zoneEta;
    if (eta == null) return const SizedBox.shrink();

    return AuraCard(
      padding: const EdgeInsets.all(AuraSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.schedule_rounded, size: AuraIcon.md, color: p.accent),
              const SizedBox(width: AuraSpace.xs),
              Expanded(
                child: Text(
                  'Ahora en ${eta.zone}: unos ${eta.rangeLabel}',
                  style: AppType.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          if (eta.message.isNotEmpty) ...[
            const SizedBox(height: AuraSpace.xxs),
            Text(
              eta.message,
              style: AppType.bodySmall.copyWith(color: p.textMuted),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------- paso: tipo de traslado

  Widget _ambulanceTypeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraChoiceTile(
          title: 'Traslado básico',
          subtitle: 'Camilla y técnico paramédico',
          icon: Icons.airline_seat_flat_rounded,
          trailingText: Money.format(
            (_ambulanceBasicPrice * (1 + widget.commissionRate)).round(),
          ),
          selected: _ambulanceType == 'basic',
          onTap: () {
            setState(() => _ambulanceType = 'basic');
            _updateTransportQuote();
          },
        ),
        const SizedBox(height: AuraTap.gap),
        AuraChoiceTile(
          title: 'Traslado medicalizado',
          subtitle: 'Con enfermero y equipo de soporte',
          icon: Icons.monitor_heart_rounded,
          trailingText: Money.format(
            (_ambulanceMedicalizedPrice * (1 + widget.commissionRate)).round(),
          ),
          selected: _ambulanceType == 'medicalized',
          onTap: () {
            setState(() => _ambulanceType = 'medicalized');
            _updateTransportQuote();
          },
        ),
        const SizedBox(height: AuraSpace.lg),
        AuraBanner(
          tone: AuraTone.info,
          icon: Icons.info_outline_rounded,
          message:
              'Este servicio es para traslados programados. Si hay riesgo vital, '
              'llama al 131.',
        ),
      ],
    );
  }

  // ------------------------------------------------------------ paso: cupo

  Widget _labSlotStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LabSlotPicker(
          state: widget.state,
          zone: _zoneEta?.zone,
          onSlotSelected: (slot) => setState(() => _labSlot = slot),
        ),
        const SizedBox(height: AuraSpace.lg),
        AuraField.multiline(
          label: 'Qué exámenes te indicaron',
          hint: 'Ej. hemograma, perfil lipídico',
          controller: _examController,
          maxLines: 3,
          maxLength: 300,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: AuraSpace.md),
        AuraDisclosure(
          title: 'Añadir indicaciones para el laboratorista',
          icon: Icons.note_add_outlined,
          child: AuraField.multiline(
            label: 'Indicaciones (opcional)',
            hint: 'Ej. está en ayunas desde anoche',
            controller: _labNotesController,
            maxLines: 3,
            maxLength: 300,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------- paso: confirmar

  /// El resumen antes de enviar.
  ///
  /// Sustituye a la tarjeta de precio con degradado que decía «TARIFA COTIZADA
  /// ESTIMADA» y «Minutos de arribo». Aquí el importe es lo más grande de la
  /// pantalla porque es lo que se está aceptando, y cada dato del resumen es
  /// tocable: lleva al paso donde se decidió, en vez de obligar a retroceder de
  /// uno en uno.
  Widget _confirmStep() {
    final price = _calculatePrice();
    final eta = _zoneEta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AuraCard(
          emphasis: true,
          padding: const EdgeInsets.all(AuraSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Total a pagar',
                style: AppType.bodySmall.copyWith(
                  color: p.onBrandDeep.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: AuraSpace.xxs),
              Text(
                Money.format(price, withCode: true),
                style: AppType.display.copyWith(
                  fontWeight: FontWeight.w800,
                  color: p.onBrandDeep,
                ),
              ),
              const SizedBox(height: AuraSpace.xs),
              Row(
                children: [
                  Icon(
                    Icons.lock_rounded,
                    size: AuraIcon.sm,
                    color: p.onBrandDeep.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: AuraSpace.xxs),
                  Expanded(
                    child: Text(
                      'Pagas después de confirmar, en un sitio seguro.',
                      style: AppType.bodySmall.copyWith(
                        color: p.onBrandDeep.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: AuraSpace.lg),

        AuraCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.md,
            vertical: AuraSpace.xs,
          ),
          child: Column(
            children: [
              _summaryLine(
                icon: serviceIconFor(
                  widget.service.iconName,
                  serviceId: widget.service.id,
                ),
                label: 'Servicio',
                value: serviceShortName(
                  widget.service.id,
                  widget.service.shortTitle,
                ),
              ),
              _summaryLine(
                icon: Icons.person_rounded,
                label: 'Para',
                value: _patientLabel,
                onEdit: () => _jumpTo(_StepId.patient),
              ),
              if (widget.service.id == 'ambulancia') ...[
                _summaryLine(
                  icon: Icons.trip_origin_rounded,
                  label: 'Desde',
                  value: _originAddressController.text.trim(),
                  onEdit: () => _jumpTo(_StepId.location),
                ),
                _summaryLine(
                  icon: Icons.place_rounded,
                  label: 'Hasta',
                  value: _destinationAddressController.text.trim(),
                  onEdit: () => _jumpTo(_StepId.location),
                ),
                _summaryLine(
                  icon: Icons.local_shipping_rounded,
                  label: 'Traslado',
                  value: _ambulanceType == 'medicalized'
                      ? 'Medicalizado'
                      : 'Básico',
                  onEdit: () => _jumpTo(_StepId.ambulanceType),
                ),
              ] else
                _summaryLine(
                  icon: Icons.place_rounded,
                  label: 'Dónde',
                  value: _resolvedAddress,
                  onEdit: () => _jumpTo(_StepId.location),
                ),
              if (_isScheduledLab && _labSlot != null)
                _summaryLine(
                  icon: Icons.event_rounded,
                  label: 'Cuándo',
                  value: _labSlot!.label,
                  onEdit: () => _jumpTo(_StepId.labSlot),
                )
              else if (eta != null)
                _summaryLine(
                  icon: Icons.schedule_rounded,
                  label: 'Llegada',
                  value: 'En unos ${eta.rangeLabel}',
                ),
              if (widget.service.id == 'medico' &&
                  _symptomsController.text.trim().isNotEmpty)
                _summaryLine(
                  icon: Icons.notes_rounded,
                  label: 'Motivo',
                  value: _symptomsController.text.trim(),
                  onEdit: () => _jumpTo(_StepId.symptoms),
                ),
              if (_uploadedFileName != null)
                _summaryLine(
                  icon: Icons.description_rounded,
                  label: 'Orden médica',
                  value: 'Adjunta',
                  onEdit: () => _jumpTo(_StepId.prescription),
                ),
            ],
          ),
        ),

        const SizedBox(height: AuraSpace.md),
        Text(
          _isScheduledLab
              ? 'Guardamos tu hora y avisamos al laboratorista.'
              : 'Avisamos a los profesionales de tu zona y te confirmamos por el chat.',
          style: AppType.bodySmall.copyWith(color: p.textMuted),
        ),
      ],
    );
  }

  /// Una línea del resumen. Con lápiz cuando ese dato se puede cambiar.
  Widget _summaryLine({
    required IconData icon,
    required String label,
    required String value,
    VoidCallback? onEdit,
  }) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: AuraSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AuraIcon.md, color: p.textMuted),
          const SizedBox(width: AuraSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppType.bodySmall.copyWith(color: p.textMuted),
                ),
                const SizedBox(height: AuraSpace.xxxs),
                Text(
                  value.isEmpty ? '—' : value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: p.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null) ...[
            const SizedBox(width: AuraSpace.xs),
            Icon(Icons.edit_rounded, size: AuraIcon.sm, color: p.accent),
          ],
        ],
      ),
    );

    if (onEdit == null) return row;

    return Semantics(
      button: true,
      label: '$label: $value. Tocar para cambiar.',
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onEdit,
            borderRadius: AuraRadius.allSm,
            child: row,
          ),
        ),
      ),
    );
  }
}

/// Los pasos posibles del asistente.
///
/// No todos aparecen en todos los servicios: la lista real la arma
/// `_ServiceFormScreenState._steps` según lo que ese servicio necesite. Pedir
/// la orden médica a quien pide cuidados en casa, o los síntomas a quien pide
/// una radiografía, era parte de lo que hacía largo el formulario anterior.
enum _StepId {
  patient,
  symptoms,
  exam,
  prescription,
  location,
  ambulanceType,
  labSlot,
  confirm,
}
