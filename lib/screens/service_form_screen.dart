import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/clinical_service.dart';
import '../models/dependent.dart';
import '../models/saved_address.dart';

class ServiceFormScreen extends StatefulWidget {
  final ClinicalService service;
  final List<Dependent> dependents;
  final List<SavedAddress> addresses;
  final VoidCallback onAddDependentRedirect;
  final VoidCallback onBack;
  final Function({
    required String patientType,
    String? dependentId,
    required String addressText,
    String? originAddress,
    String? destinationAddress,
    String? ambulanceType,
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
  });

  @override
  State<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends State<ServiceFormScreen> {
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

  // Ambulance specific
  late TextEditingController _originAddressController;
  final TextEditingController _destinationAddressController =
      TextEditingController();
  String _ambulanceType = 'basic';

  // Labs / Imaging
  final TextEditingController _examController = TextEditingController();

  // Map simulated coordinate picking
  bool _mapPinned = false;

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
                const Text(
                  'Seleccionar Cámara',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.camera_rear_outlined, color: Color(0xFF0D9488)),
                  title: const Text('Cámara Trasera (Recomendado)'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera, CameraDevice.rear);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_front_outlined, color: Color(0xFF0D9488)),
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
      return _ambulanceType == 'medicalized' ? 28500 : 18500;
    }
    return widget.service.basePrice;
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
      symptomsDescription: symptomsOrExam,
      prescriptionName: _uploadedFileName,
      prescriptionPreview: _uploadedFilePreview,
      finalPrice: price,
      etaMinutes: baseEtaMinutes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.service;
    final price = _calculatePrice();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // slate-50
      body: SafeArea(
        child: Column(
          children: [
            // Sticky Back Header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 12.0,
              ),
              color: Colors.white,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: widget.onBack,
                    child: const Row(
                      children: [
                        Icon(Icons.chevron_left, color: Color(0xFF0D9488)),
                        Text(
                          'Volver al catálogo',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'PASO 1 DE 2',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF94A3B8),
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
                        color: const Color(0xFFE6F6F4),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Solicitud de Prestación',
                        style: TextStyle(
                          color: Color(0xFF0D9488),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      service.title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
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
                          backgroundColor: const Color(0xFF0D9488),
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
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'Al confirmar, nuestro sistema conectará con el prestador clínico de guardia más cercano en base a su ubicación. Pago online protegido.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF94A3B8),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.person_outline_rounded,
                color: Color(0xFF0D9488),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '¿Para quién es la atención?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
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
                          ? const Color(0xFFE6F6F4)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _patientType == 'self'
                            ? const Color(0xFF0D9488)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFCCFBF1),
                            shape: BoxShape.circle,
                          ),
                          child: const Text(
                            'Yo',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D9488),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Paciente Principal',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
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
                          ? const Color(0xFFE6F6F4)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _patientType == 'dependent'
                            ? const Color(0xFF0D9488)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFCCFBF1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            size: 13,
                            color: Color(0xFF0D9488),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Familiar / Dependiente',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
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
            const Text(
              'SELECCIONE FAMILIAR GUARDADO',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            if (widget.dependents.isEmpty) ...[
              const Text(
                'No tienes familiares agregados.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                              ? const Color(0xFFE6F6F4).withValues(alpha: 0.4)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSel
                                ? const Color(0xFF0D9488)
                                : const Color(0xFFE2E8F0),
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
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${dep.relationship} • ${dep.age} años • ${dep.healthInsurance}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                            if (isSel)
                              const Icon(
                                Icons.check,
                                color: Color(0xFF0D9488),
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
                  side: const BorderSide(color: Color(0xFFCCFBF1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: const Color(0x33E6F6F4),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, size: 14, color: Color(0xFF0D9488)),
                    SizedBox(width: 6),
                    Text(
                      'Agregar Nuevo Familiar Dependiente',
                      style: TextStyle(
                        color: Color(0xFF0D9488),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.favorite_outline, color: Color(0xFF0D9488), size: 20),
              SizedBox(width: 8),
              Text(
                'Describa Síntomas',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _symptomsController,
              maxLines: 3,
              style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
              decoration: InputDecoration(
                hintText: widget.service.placeholderText,
                hintStyle: const TextStyle(
                  color: Color(0xFF94A3B8),
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
                          style: const TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        backgroundColor: const Color(0xFFF1F5F9),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.file_present_rounded,
                color: Color(0xFF0D9488),
                size: 20,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ingrese el pedido médico',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Toda prestación clínica de ${widget.service.shortTitle} requiere orden',
                      style: const TextStyle(
                        fontSize: 9,
                        color: Color(0xFF0D9488),
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
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0xFFE2E8F0),
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
                      const Text(
                        'Soporta formatos PDF, PNG o JPG desde su teléfono',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_isUploading)
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              height: 12,
                              width: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFF0D9488),
                              ),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'PROCESANDO DOCUMENTO...',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D9488),
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
                                    foregroundColor: const Color(0xFF0D9488),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(
                                        color: Color(0xFFCCFBF1),
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
                                    backgroundColor: const Color(0xFFE6F6F4),
                                    foregroundColor: const Color(0xFF0D9488),
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: const BorderSide(
                                        color: Color(0xFFCCFBF1),
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
                      color: const Color(0xFFE6F6F4).withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF0D9488).withValues(alpha: 0.3),
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
                                color: const Color(0xFFE6F6F4),
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
                                          return const Icon(
                                            Icons.image,
                                            color: Color(0xFF0D9488),
                                            size: 18,
                                          );
                                        },
                                      ),
                                    )
                                  : const Icon(
                                      Icons.picture_as_pdf,
                                      color: Color(0xFF0D9488),
                                      size: 18,
                                    ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _uploadedFileName!,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
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
            const Text(
              'ESPECIFIQUE EXAMEN SOLICITADO',
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: Color(0xFF94A3B8),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _examController,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: widget.service.placeholderText,
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
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
    return Column(
      children: [
        // From
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
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
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            'Inicio del traslado',
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Icon(
                    Icons.local_shipping,
                    color: const Color(0xFF0D9488).withValues(alpha: 0.8),
                    size: 22,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Dummy Map
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: MockMapPainter(
                          markerColor: const Color(0xFFF43F5E),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        color: Colors.black45,
                        child: const Text(
                          'MAPA DE ORIGEN ACTIVO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 24,
                          width: 24,
                          decoration: const BoxDecoration(
                            color: Color(0xFFF43F5E),
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'A',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        Container(
                          height: 6,
                          width: 2,
                          color: const Color(0xFFF43F5E),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _originAddressController,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Dirección exacta de inicio',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
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
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
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
                          const Text(
                            'Lugar de llegada',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const Text(
                            'Destino programado',
                            style: TextStyle(
                              fontSize: 9,
                              color: Color(0xFF94A3B8),
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
                      color: const Color(0xFFF1F5F9),
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
              // Dummy Map
              Container(
                height: 110,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFCBD5E1)),
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: MockMapPainter(markerColor: Colors.blue),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 3,
                        ),
                        color: Colors.black45,
                        child: const Text(
                          'MAPA DE DESTINO ACTIVO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 24,
                          width: 24,
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                          child: const Center(
                            child: Text(
                              'B',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                        Container(height: 6, width: 2, color: Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _destinationAddressController,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF0F172A),
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: const InputDecoration(
                    hintText: 'Dirección exacta de destino',
                    hintStyle: TextStyle(
                      color: Color(0xFF94A3B8),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TIPO DE AMBULANCIA',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.bold,
              color: Color(0xFF94A3B8),
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
                          ? const Color(0xFFE6F6F4)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _ambulanceType == 'basic'
                            ? const Color(0xFF0D9488)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          'Básica',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '\$18,500 ARS Base',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF0D9488),
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
                          ? const Color(0xFFE6F6F4)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _ambulanceType == 'medicalized'
                            ? const Color(0xFF0D9488)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: const Column(
                      children: [
                        Text(
                          'Medicalizada',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          '\$28,500 ARS Base',
                          style: TextStyle(
                            fontSize: 10,
                            color: Color(0xFF0D9488),
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
          const Center(
            child: Text(
              'La Ambulancia Medicalizada incluye médico a bordo e instrumentación de cuidados intermedios/UTI.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                color: Color(0xFF94A3B8),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.location_on_outlined,
                    color: Color(0xFF0D9488),
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
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '¿Dónde asistirá el personal clínico?',
                        style: TextStyle(fontSize: 9, color: Color(0xFF94A3B8)),
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
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D9488),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!_useCustomAddress) ...[
            if (widget.addresses.isEmpty) ...[
              const Text(
                'No hay direcciones disponibles.',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
                              ? const Color(0xFFE6F6F4).withValues(alpha: 0.4)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSel
                                ? const Color(0xFF0D9488)
                                : const Color(0xFFE2E8F0),
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
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D9488),
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    addr.text,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF334155),
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSel)
                              const Icon(
                                Icons.check,
                                color: Color(0xFF0D9488),
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
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: TextField(
                    controller: _customAddressController,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF0F172A),
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: const InputDecoration(
                      hintText:
                          'Ej: Calle Suecia 120, depto 201, Providencia, Santiago',
                      hintStyle: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.all(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _mapPinned = true;
                        _customAddressController.text =
                            'Ubicación fijada en Google Maps (Providencia, Santiago)';
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFF0F9FF),
                      foregroundColor: const Color(0xFF0369A1),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Color(0xFFBAE6FD)),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _mapPinned ? '✓ UBICACIÓN FIJADA' : 'FIJAR EN GMAPS',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
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
          ], // brand-dark to teal-800
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
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
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
                const Text(
                  'Incluye insumos médicos clínicos y traslado profesional',
                  style: TextStyle(
                    fontSize: 9,
                    color: Color(0xFFCCFBF1),
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  'Minutos de arribo',
                  style: TextStyle(color: Color(0xFFCCFBF1), fontSize: 8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MockMapPainter extends CustomPainter {
  final Color markerColor;

  MockMapPainter({required this.markerColor});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // 1. Background Land (Slate-200 for good contrast with white streets)
    paint.color = const Color(0xFFE2E8F0);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);

    // 2. Draw coordinate grid lines (technical GPS mockup feel)
    paint.color = const Color(0xFFCBD5E1).withValues(alpha: 0.5);
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.0;
    for (double i = 20; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), paint);
    }
    for (double i = 15; i < size.height; i += 30) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), paint);
    }

    // 3. Draw Parks (Green zones with outlines)
    paint.color = const Color(0xFFD1FAE5); // Emerald-100
    paint.style = PaintingStyle.fill;
    final park1 = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.05,
        size.height * 0.08,
        size.width * 0.22,
        size.height * 0.45,
      ),
      const Radius.circular(10),
    );
    final park2 = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.72,
        size.height * 0.48,
        size.width * 0.23,
        size.height * 0.44,
      ),
      const Radius.circular(10),
    );
    canvas.drawRRect(park1, paint);
    canvas.drawRRect(park2, paint);

    // Park outlines
    paint.color = const Color(0xFFA7F3D0); // Emerald-200
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.5;
    canvas.drawRRect(park1, paint);
    canvas.drawRRect(park2, paint);

    // 4. Draw River (Sky Blue water path)
    paint.color = const Color(0xFFBAE6FD); // Sky-200
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 16.0;
    final riverPath = Path();
    riverPath.moveTo(0, size.height * 0.85);
    riverPath.quadraticBezierTo(
      size.width * 0.45,
      size.height * 0.5,
      size.width,
      size.height * 0.35,
    );
    canvas.drawPath(riverPath, paint);

    // River inner flow line
    paint.color = const Color(0xFF7DD3FC); // Sky-300
    paint.strokeWidth = 2.0;
    canvas.drawPath(riverPath, paint);

    // 5. Draw Streets (Double-line style: thick grey outline casing, thin white inline)
    final streets = [
      // Horizontal streets
      [Offset(0, size.height * 0.3), Offset(size.width, size.height * 0.3)],
      [Offset(0, size.height * 0.7), Offset(size.width, size.height * 0.7)],
      // Vertical streets
      [Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height)],
      [Offset(size.width * 0.65, 0), Offset(size.width * 0.65, size.height)],
    ];

    // Draw street casings (grey border)
    paint.color = const Color(0xFF94A3B8); // Slate-400
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 9.0;
    for (var street in streets) {
      canvas.drawLine(street[0], street[1], paint);
    }

    // Draw street inlines (white street surface)
    paint.color = Colors.white;
    paint.strokeWidth = 6.0;
    for (var street in streets) {
      canvas.drawLine(street[0], street[1], paint);
    }

    // 6. Draw Street and River Labels
    _drawText(
      canvas,
      "Río Mapocho",
      Offset(size.width * 0.42, size.height * 0.53),
      color: const Color(0xFF0369A1),
      size: 7.5,
      italic: true,
    );
    _drawText(
      canvas,
      "Av. Providencia",
      Offset(size.width * 0.05, size.height * 0.25),
      color: const Color(0xFF64748B),
      size: 7.0,
      bold: true,
    );
    _drawText(
      canvas,
      "Av. Andrés Bello",
      Offset(size.width * 0.05, size.height * 0.65),
      color: const Color(0xFF64748B),
      size: 7.0,
      bold: true,
    );
    _drawText(
      canvas,
      "Calle Lota",
      Offset(size.width * 0.22, size.height * 0.85),
      color: const Color(0xFF64748B),
      size: 6.5,
      bold: true,
      rotate90: true,
    );
    _drawText(
      canvas,
      "Av. Suecia",
      Offset(size.width * 0.58, size.height * 0.05),
      color: const Color(0xFF64748B),
      size: 6.5,
      bold: true,
      rotate90: true,
    );

    // Park label
    _drawText(
      canvas,
      "PARQUE DE LAS ESCULTURAS",
      Offset(size.width * 0.07, size.height * 0.15),
      color: const Color(0xFF047857),
      size: 5.5,
      bold: true,
    );
  }

  void _drawText(
    Canvas canvas,
    String text,
    Offset offset, {
    required Color color,
    double size = 7.0,
    bool bold = false,
    bool italic = false,
    bool rotate90 = false,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        fontStyle: italic ? FontStyle.italic : FontStyle.normal,
        letterSpacing: 0.3,
        fontFamily: 'Inter',
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();

    if (rotate90) {
      canvas.save();
      canvas.translate(offset.dx, offset.dy);
      canvas.rotate(1.5708); // 90 degrees in radians
      textPainter.paint(canvas, const Offset(0, 0));
      canvas.restore();
    } else {
      textPainter.paint(canvas, offset);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
