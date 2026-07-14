import 'dart:async';
import 'package:aura/theme/app_theme.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart' hide Path;
import '../models/clinical_service.dart';
import '../models/dependent.dart';
import '../models/saved_address.dart';
import '../widgets/map_location_picker.dart';

class ServiceFormScreen extends StatefulWidget {
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
    String? symptomsDescription,
    String? prescriptionName,
    String? prescriptionPreview,
    required int finalPrice,
    required int etaMinutes,
  })
  onConfirmRequest;

  const ServiceFormScreen({
    super.key,
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
  String? _uploadedFileName;
  String? _uploadedFilePreview;
  bool _isUploading = false;

  // Real map coordinates picked by the user (replaces the old mock canvas)
  LatLng? _locationLatLng; // standard services: the attention location
  LatLng? _originLatLng; // ambulance pickup

  // Ambulance specific
  late TextEditingController _originAddressController;
  final TextEditingController _destinationAddressController =
      TextEditingController();
  String _ambulanceType = 'basic';

  // Labs / Imaging
  final TextEditingController _examController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.dependents.isNotEmpty) {
      _selectedDependentId = widget.dependents.first.id;
    }
    _originAddressController = TextEditingController(
      text: widget.addresses.isNotEmpty ? widget.addresses.first.text : '',
    );
  }

  @override
  void dispose() {
    _customAddressController.dispose();
    _symptomsController.dispose();
    _originAddressController.dispose();
    _destinationAddressController.dispose();
    _examController.dispose();
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
                  style: TextStyle(
                    fontSize: 16,
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
      final base = _ambulanceType == 'medicalized' ? 28500 : 18500;
      return (base * (1.0 + widget.commissionRate)).round();
    }
    return (widget.service.basePrice * (1.0 + widget.commissionRate)).round();
  }

  void _submitForm() {
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

    String? symptomsOrExam;
    if (widget.service.id == 'medico') {
      symptomsOrExam = _symptomsController.text.trim();
    } else if (widget.service.id == 'laboratorio' ||
        widget.service.id == 'radiologia' ||
        widget.service.id == 'electrocardiograma') {
      symptomsOrExam = _examController.text.trim();
    }

    final price = _calculatePrice();
    final baseEtaMinutes =
        int.tryParse(widget.service.baseEta.split('-')[0].trim()) ?? 30;

    // The patient coordinates are the attention location — for an ambulance
    // that is the pickup (origin), otherwise the picked service location.
    final LatLng? patientPoint =
        widget.service.id == 'ambulancia' ? _originLatLng : _locationLatLng;

    widget.onConfirmRequest(
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
      symptomsDescription: symptomsOrExam,
      prescriptionName: _uploadedFileName,
      prescriptionPreview: _uploadedFilePreview,
      finalPrice: price,
      etaMinutes: baseEtaMinutes,
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
                          'Volver al catálogo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: p.accent,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'PASO 1 DE 2',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: p.textFaint,
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
                        style: TextStyle(
                          color: p.accent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: p.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),

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
                                  const Text(
                                    'AVISO IMPORTANTE',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF92400E),
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    service.warningInfo!,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF92400E),
                                      height: 1.4,
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

                    // Block 6: Pricing Card
                    _buildPricingCard(service, price),
                    const SizedBox(height: 24),

                    // Block 7: Submit Buttons
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: p.accent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              service.id == 'medico'
                                  ? 'SOLICITAR MÉDICO'
                                  : 'CONFIRMAR SOLICITUD',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
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
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Al confirmar, nuestro sistema conectará con el prestador clínico de guardia más cercano en base a su ubicación. Pago online protegido.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: p.textFaint,
                            height: 1.4,
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
              Text(
                '¿Para quién es la atención?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary,
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
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _patientType == 'self'
                            ? p.accent
                            : p.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: p.accentSurface,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            'Yo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: p.accent,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Paciente Principal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: p.textPrimary,
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
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _patientType == 'dependent'
                            ? p.accent
                            : p.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: p.accentSurface,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add,
                            size: 13,
                            color: p.accent,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Familiar / Dependiente',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: p.textPrimary,
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
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: p.textFaint,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.dependents.isEmpty) ...[
              Text(
                'No tienes familiares agregados.',
                style: TextStyle(fontSize: 11, color: p.textMuted),
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
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: p.textSecondary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${dep.relationship} • ${dep.age} años • ${dep.healthInsurance}',
                                  style: TextStyle(
                                    fontSize: 10,
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
                    Text(
                      'Agregar Nuevo Familiar Dependiente',
                      style: TextStyle(
                        color: p.accent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
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
              Text(
                'Describa Síntomas',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: p.textPrimary,
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
              border: Border.all(color: p.border),
            ),
            child: TextField(
              controller: _symptomsController,
              maxLines: 3,
              style: TextStyle(fontSize: 12, color: p.textSecondary),
              decoration: InputDecoration(
                hintText: widget.service.placeholderText,
                hintStyle: TextStyle(
                  color: p.textFaint,
                  fontSize: 11,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.all(10),
              ),
            ),
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
                          style: TextStyle(
                            fontSize: 9,
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
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: p.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Toda prestación clínica de ${widget.service.shortTitle} requiere orden',
                      style: TextStyle(
                        fontSize: 9,
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
                      const Text(
                        'Cargar Orden Médica Digital o Foto',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Soporta formatos PDF, PNG o JPG desde su teléfono',
                        style: TextStyle(
                          fontSize: 10,
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
                            Text(
                              'PROCESANDO DOCUMENTO...',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: p.accent,
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
                                    backgroundColor: Colors.white,
                                    foregroundColor: p.accent,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color: p.accentSurface,
                                      ),
                                    ),
                                  ),
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.file_upload_outlined,
                                        size: 14,
                                      ),
                                      SizedBox(width: 4),
                                      Text(
                                        'Subir archivo',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
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
                                  child: const Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.camera_alt_outlined, size: 14),
                                      SizedBox(width: 4),
                                      Text(
                                        'Foto',
                                        style: TextStyle(
                                          fontSize: 10,
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
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: p.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Verificado exitosamente',
                                  style: TextStyle(
                                    fontSize: 8,
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
                            backgroundColor: Colors.white,
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
                          child: const Text(
                            'Borrar',
                            style: TextStyle(
                              color: Color(0xFFF43F5E),
                              fontSize: 10,
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
              style: TextStyle(
                fontSize: 9,
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
                style: TextStyle(
                  fontSize: 12,
                  color: p.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: widget.service.placeholderText,
                  hintStyle: TextStyle(
                    color: p.textFaint,
                    fontSize: 11,
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
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: p.textPrimary,
                            ),
                          ),
                          Text(
                            'Inicio del traslado',
                            style: TextStyle(
                              fontSize: 9,
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
                  style: TextStyle(
                    fontSize: 12,
                    color: p.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Dirección exacta de inicio',
                    hintStyle: TextStyle(
                      color: p.textFaint,
                      fontSize: 11,
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
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: p.textPrimary,
                            ),
                          ),
                          Text(
                            'Destino programado',
                            style: TextStyle(
                              fontSize: 9,
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
                    child: const Center(
                      child: Text(
                        'B',
                        style: TextStyle(
                          color: Color(0xFF475569),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
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
                  if (address != null && address.isNotEmpty) {
                    setState(() {
                      _destinationAddressController.text = address;
                    });
                  }
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
                  controller: _destinationAddressController,
                  style: TextStyle(
                    fontSize: 12,
                    color: p.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Dirección exacta de destino',
                    hintStyle: TextStyle(
                      color: p.textFaint,
                      fontSize: 11,
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
            style: TextStyle(
              fontSize: 9,
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
                  onTap: () => setState(() => _ambulanceType = 'basic'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _ambulanceType == 'basic'
                          ? p.accentSurface
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _ambulanceType == 'basic'
                            ? p.accent
                            : p.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Básica',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: p.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '\$18,500 ARS Base',
                          style: TextStyle(
                            fontSize: 10,
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
                  onTap: () => setState(() => _ambulanceType = 'medicalized'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: _ambulanceType == 'medicalized'
                          ? p.accentSurface
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _ambulanceType == 'medicalized'
                            ? p.accent
                            : p.border,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'Medicalizada',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: p.textPrimary,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '\$28,500 ARS Base',
                          style: TextStyle(
                            fontSize: 10,
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
              style: TextStyle(
                fontSize: 10,
                color: p.textFaint,
                fontWeight: FontWeight.bold,
                height: 1.3,
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
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: p.textPrimary,
                        ),
                      ),
                      Text(
                        '¿Dónde asistirá el personal clínico?',
                        style: TextStyle(fontSize: 9, color: p.textFaint),
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
                },
                child: Text(
                  _useCustomAddress ? 'Usar favoritas' : 'Nueva dirección',
                  style: TextStyle(
                    fontSize: 10,
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
                style: TextStyle(fontSize: 11, color: p.textMuted),
              ),
            ] else ...[
              Column(
                children: List.generate(widget.addresses.length, (idx) {
                  final addr = widget.addresses[idx];
                  final isSel = _addressIndex == idx;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: GestureDetector(
                      onTap: () => setState(() => _addressIndex = idx),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isSel
                              ? p.accentSurface.withValues(alpha: 0.4)
                              : Colors.white,
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
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: p.accent,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    addr.text,
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: p.textSecondary,
                                      height: 1.3,
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
                    style: TextStyle(
                      fontSize: 12,
                      color: p.textPrimary,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Ej: Calle Suecia 120, depto 201, Providencia, Santiago',
                      hintStyle: TextStyle(
                        color: p.textFaint,
                        fontSize: 11,
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
                  style: TextStyle(fontSize: 9, color: p.textFaint),
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
        gradient: LinearGradient(
          colors: [
            p.textPrimary,
            Color(0xFF115E59),
          ], // brand-dark to teal-800
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: p.textPrimary.withValues(alpha: 0.15),
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
                const Text(
                  'TARIFA COTIZADA ESTIMADA',
                  style: TextStyle(
                    color: Color(0xFF2DD4BF),
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    text:
                        '\$${calculatedPrice.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]}.')} ',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: p.card,
                    ),
                    children: const [
                      TextSpan(
                        text: 'ARS',
                        style: TextStyle(
                          fontSize: 12,
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
                  style: TextStyle(
                    fontSize: 9,
                    color: p.accentSurface,
                    height: 1.2,
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
                      style: TextStyle(
                        color: p.card,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Minutos de arribo',
                  style: TextStyle(color: p.accentSurface, fontSize: 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
