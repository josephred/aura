import 'package:flutter/material.dart';
import 'package:aura/theme/app_theme.dart';
import '../models/dependent.dart';
import '../models/saved_address.dart';
import '../models/saved_payment_method.dart';
import '../state/app_state.dart';

class ProfileScreen extends StatefulWidget {
  final AppState state;

  const ProfileScreen({super.key, required this.state});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  AppPalette get p => context.palette;
  // Add Dependent Form controllers
  bool _showAddDep = false;
  Dependent? _editingDependent;
  final TextEditingController _depNameController = TextEditingController();
  String _depRel = 'Madre';
  final TextEditingController _depAgeController = TextEditingController();
  final TextEditingController _depInsuranceController = TextEditingController(
    text: 'Isapre Colmena',
  );
  final TextEditingController _depObsController = TextEditingController();

  // Add Address Form controllers
  bool _showAddAddr = false;
  SavedAddress? _editingAddress;
  final TextEditingController _addrLabelController = TextEditingController();
  final TextEditingController _addrTextController = TextEditingController();

  // Add Payment Method Form controllers
  bool _showAddPay = false;
  String _payType = 'visa';
  final TextEditingController _payLast4Controller = TextEditingController();

  @override
  void dispose() {
    _depNameController.dispose();
    _depAgeController.dispose();
    _depInsuranceController.dispose();
    _depObsController.dispose();
    _addrLabelController.dispose();
    _addrTextController.dispose();
    _payLast4Controller.dispose();
    super.dispose();
  }

  void _createDependent() {
    final name = _depNameController.text.trim();
    final ageStr = _depAgeController.text.trim();
    if (name.isEmpty || ageStr.isEmpty) return;

    final age = int.tryParse(ageStr) ?? 40;

    if (_editingDependent != null) {
      widget.state.updateDependent(
        _editingDependent!.copyWith(
          name: name,
          relationship: _depRel,
          age: age,
          healthInsurance: _depInsuranceController.text.trim(),
          medicalConditions: _depObsController.text.trim().isEmpty
              ? 'Ninguna condición declarada.'
              : _depObsController.text.trim(),
        ),
      );
    } else {
      widget.state.addDependent(
        Dependent(
          id: 'dep_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          relationship: _depRel,
          age: age,
          healthInsurance: _depInsuranceController.text.trim(),
          medicalConditions: _depObsController.text.trim().isEmpty
              ? 'Ninguna condición declarada.'
              : _depObsController.text.trim(),
        ),
      );
    }

    // Reset Form
    _depNameController.clear();
    _depAgeController.clear();
    _depObsController.clear();
    setState(() {
      _showAddDep = false;
      _editingDependent = null;
    });
  }

  void _createAddress() {
    final label = _addrLabelController.text.trim();
    final text = _addrTextController.text.trim();
    if (label.isEmpty || text.isEmpty) return;

    if (_editingAddress != null) {
      widget.state.updateAddress(
        _editingAddress!.copyWith(
          label: label,
          text: text,
        ),
      );
    } else {
      widget.state.addAddress(
        SavedAddress(
          id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
          label: label,
          text: text,
        ),
      );
    }

    // Reset Form
    _addrLabelController.clear();
    _addrTextController.clear();
    setState(() {
      _showAddAddr = false;
      _editingAddress = null;
    });
  }

  void _createPaymentMethod() {
    final last4 = _payLast4Controller.text.trim();
    if (_payType != 'mercadopago' && (last4.isEmpty || last4.length != 4)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, ingresa los últimos 4 dígitos de la tarjeta.')),
      );
      return;
    }

    widget.state.addPaymentMethod(
      SavedPaymentMethod(
        id: 'pay_${DateTime.now().millisecondsSinceEpoch}',
        type: _payType,
        last4: _payType == 'mercadopago' ? null : last4,
      ),
    );

    // Reset Form
    _payLast4Controller.clear();
    setState(() {
      _showAddPay = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = widget.state;

    final rolesSpecs = [
      {
        'id': 'patient',
        'label': '1. Paciente',
        'icon': Icons.person,
        'desc':
            'Solicita atenciones a domicilio, carga recetas, sigue ETA y paga de forma directa.',
      },
      {
        'id': 'dependent_tutor',
        'label': '2. Familiar / Tutor',
        'icon': Icons.people,
        'desc':
            'Gestiona servicios y monitorea el estado clínico en nombre de sus dependientes (ej: niños o ancianos).',
      },
      {
        'id': 'doctor_provider',
        'label': '3. Profesional / Prestador',
        'icon': Icons.work_history,
        'desc':
            'Recibe solicitudes clínicas del sector geográfico, visualiza órdenes y emite fichas de atención.',
      },
      {
        'id': 'operator_admin',
        'label': '4. Operador / Administrador',
        'icon': Icons.tune,
        'desc':
            'Monitorea el panel administrativo, asigna personal clínico de guardia y valida firmas de recetas médicas.',
      },
      {
        'id': 'ambulance_driver',
        'label': '5. Conductor de Ambulancia',
        'icon': Icons.local_shipping,
        'desc':
            'Visualiza la bitácora de traslados programados e interactúa con el GPS para marcar arribo clínico.',
      },
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Visual Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: p.accentSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.accentSurface),
                  ),
                  child: Icon(
                    Icons.person_pin,
                    color: p.accent,
                    size: 36,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.userName.isNotEmpty
                            ? state.userName
                            : 'Usuario Aura',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: p.textPrimary,
                        ),
                      ),
                      Text(
                        state.userEmail.isNotEmpty
                            ? state.userEmail
                            : 'Paciente Frecuente • Miembro VIP Aura',
                        style: TextStyle(
                          fontSize: 11,
                          color: p.textMuted,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: p.accentSurface,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              color: p.accent,
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Plan Cobertura Preferencial Plus',
                              style: TextStyle(
                                color: p.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Interactive Role Simulator Selector Banner
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  p.textPrimary,
                  Color(0xFF115E59),
                ], // brand-dark to teal-900
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.stars_rounded,
                      color: Color(0xFF2DD4BF),
                      size: 18,
                    ),
                    SizedBox(width: 6),
                    Text(
                      'Simulador de Roles del Ecosistema Aura',
                      style: TextStyle(
                        color: p.accentSurface,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'La plataforma Aura está diseñada para interactuar entre múltiples actores de salud. Alterne su rol en la simulación abajo para modelar la experiencia:',
                  style: TextStyle(
                    color: Color(0xFF99F6E4),
                    fontSize: 10.5,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 14),
                Column(
                  children: rolesSpecs.map((roleSpec) {
                    final roleId = roleSpec['id'] as String;
                    final isSel = state.currentRole == roleId;
                    final icon = roleSpec['icon'] as IconData;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: GestureDetector(
                        onTap: () => state.setRole(roleId),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSel
                                ? Colors.white
                                : const Color(
                                    0xFF1E293B,
                                  ).withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSel
                                  ? p.accent
                                  : const Color(
                                      0xFF334155,
                                    ).withValues(alpha: 0.5),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isSel
                                      ? p.accent
                                      : p.textPrimary,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  icon,
                                  color: isSel
                                      ? Colors.white
                                      : const Color(0xFF2DD4BF),
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          roleSpec['label'] as String,
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            fontWeight: FontWeight.bold,
                                            color: isSel
                                                ? p.textPrimary
                                                : Colors.white,
                                          ),
                                        ),
                                        if (isSel) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.all(2),
                                            decoration: const BoxDecoration(
                                              color: Color(0xFFD1FAE5),
                                              shape: BoxShape.circle,
                                            ),
                                            child: const Icon(
                                              Icons.check,
                                              color: Color(0xFF10B981),
                                              size: 10,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      roleSpec['desc'] as String,
                                      style: TextStyle(
                                        fontSize: 10,
                                        height: 1.3,
                                        color: isSel
                                            ? p.textMuted
                                            : p.textFaint,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Block 1: Dependents Management
          Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.favorite,
                          color: Color(0xFFF43F5E),
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Cargas y Familiares',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: p.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _showAddDep = !_showAddDep;
                        if (!_showAddDep) {
                          _editingDependent = null;
                          _depNameController.clear();
                          _depAgeController.clear();
                          _depObsController.clear();
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: p.accentSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showAddDep ? Icons.close : Icons.add,
                              size: 12,
                              color: p.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showAddDep ? 'Ocultar' : 'Agregar',
                              style: TextStyle(
                                color: p.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showAddDep) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.accentSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.accentSurface),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editingDependent != null ? 'Editar Familiar Paciente' : 'Registrar Nuevo Familiar Paciente',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(height: 10),
                        // Name
                        _buildLabel('Nombre Completo'),
                        _buildTextField(
                          _depNameController,
                          'Ej: Margarita Sotomayor',
                        ),
                        const SizedBox(height: 8),
                        // Relationship & Age
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Relación'),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: Theme.of(context).dividerColor.withValues(alpha: 0.2),
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _depRel,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                        ),
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: p.textPrimary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        items:
                                            [
                                              'Madre',
                                              'Padre',
                                              'Hijo',
                                              'Cónyuge',
                                              'Otro',
                                            ].map((rel) {
                                              return DropdownMenuItem(
                                                value: rel,
                                                child: Text(rel),
                                              );
                                            }).toList(),
                                        onChanged: (val) {
                                          if (val != null)
                                            setState(() => _depRel = val);
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel('Edad (Años)'),
                                  _buildTextField(
                                    _depAgeController,
                                    'Ej: 76',
                                    isNum: true,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // Insurance
                        _buildLabel('Aseguradora / Cobertura'),
                        _buildTextField(
                          _depInsuranceController,
                          'Ej: Isapre Colmena / Fonasa',
                        ),
                        const SizedBox(height: 8),
                        // Observations
                        _buildLabel('Observación médica o crónica'),
                        _buildTextField(
                          _depObsController,
                          'Ej: Hipertensión severa controlada...',
                          maxLines: 2,
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: ElevatedButton(
                            onPressed: _createDependent,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              _editingDependent != null ? 'Actualizar Familiar Dependiente' : 'Guardar Familiar Dependiente',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Column(
                  children: state.dependents.map((dep) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.fill),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  dep.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: p.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${dep.relationship} • ${dep.age} años • ${dep.healthInsurance}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: p.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Obs: ${dep.medicalConditions}',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: p.accent,
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _editingDependent = dep;
                                    _showAddDep = true;
                                    _depNameController.text = dep.name;
                                    _depAgeController.text = dep.age.toString();
                                    _depRel = dep.relationship;
                                    _depInsuranceController.text = dep.healthInsurance;
                                    _depObsController.text = dep.medicalConditions;
                                  });
                                },
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: p.accent,
                                  size: 18,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: p.accentSurface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                onPressed: () => state.deleteDependent(dep.id),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFF43F5E),
                                  size: 18,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFF1F2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Block 2: Saved Addresses
          Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          color: p.accent,
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Direcciones Frecuentes',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: p.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _showAddAddr = !_showAddAddr;
                        if (!_showAddAddr) {
                          _editingAddress = null;
                          _addrLabelController.clear();
                          _addrTextController.clear();
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: p.accentSurface,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showAddAddr ? Icons.close : Icons.add,
                              size: 12,
                              color: p.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showAddAddr ? 'Ocultar' : 'Agregar',
                              style: TextStyle(
                                color: p.accent,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showAddAddr) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: p.accentSurface.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: p.accentSurface),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editingAddress != null ? 'Editar Dirección Frecuente' : 'Registrar Nueva Dirección',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F766E),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildLabel('Etiqueta (ej: Oficina, Clínica)'),
                        _buildTextField(_addrLabelController, 'Ej: Oficina'),
                        const SizedBox(height: 8),
                        _buildLabel('Dirección Completa'),
                        _buildTextField(
                          _addrTextController,
                          'Ej: Av Providencia 5410, depto 11...',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: ElevatedButton(
                            onPressed: _createAddress,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: p.accent,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              _editingAddress != null ? 'Actualizar Dirección' : 'Agregar Dirección',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Column(
                  children: state.addresses.map((addr) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.fill),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.only(top: 2.0),
                            child: Icon(
                              Icons.location_on,
                              color: p.accent,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  addr.label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: p.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  addr.text,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: p.textMuted,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () {
                                  setState(() {
                                    _editingAddress = addr;
                                    _showAddAddr = true;
                                    _addrLabelController.text = addr.label;
                                    _addrTextController.text = addr.text;
                                  });
                                },
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: p.accent,
                                  size: 18,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: p.accentSurface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              IconButton(
                                onPressed: () => state.deleteAddress(addr.id),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFF43F5E),
                                  size: 18,
                                ),
                                style: IconButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFF1F2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Block 3: Payment Methods
          Container(
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.credit_card, color: Color(0xFF0284C7), size: 18),
                        SizedBox(width: 8),
                        Text(
                          'Medios de Pago Vinculados',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: p.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() {
                        _showAddPay = !_showAddPay;
                        if (!_showAddPay) {
                          _payLast4Controller.clear();
                        }
                      }),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE0F2FE),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showAddPay ? Icons.close : Icons.add,
                              size: 12,
                              color: const Color(0xFF0284C7),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showAddPay ? 'Ocultar' : 'Agregar',
                              style: const TextStyle(
                                color: Color(0xFF0284C7),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (_showAddPay) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE0F2FE).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBAE6FD)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Vincular Nuevo Medio de Pago',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0369A1),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _buildLabel('Tipo de Medio de Pago'),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButtonFormField<String>(
                              initialValue: _payType,
                              decoration: const InputDecoration(border: InputBorder.none),
                              style: TextStyle(
                                fontSize: 12,
                                color: p.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              items: const [
                                DropdownMenuItem(value: 'visa', child: Text('Visa')),
                                DropdownMenuItem(value: 'mastercard', child: Text('Mastercard')),
                                DropdownMenuItem(value: 'mercadopago', child: Text('Mercado Pago')),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _payType = val);
                                }
                              },
                            ),
                          ),
                        ),
                        if (_payType != 'mercadopago') ...[
                          const SizedBox(height: 8),
                          _buildLabel('Últimos 4 dígitos de la tarjeta'),
                          _buildTextField(
                            _payLast4Controller,
                            'Ej: 1234',
                            isNum: true,
                          ),
                        ],
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 38,
                          child: ElevatedButton(
                            onPressed: _createPaymentMethod,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0284C7),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Guardar Medio de Pago',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Column(
                  children: state.paymentMethods.map((pay) {
                    final isVisa = pay.type == 'visa';
                    final isMc = pay.type == 'mastercard';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.fill),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                height: 32,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: isVisa
                                      ? const Color(0xFF1E3A8A)
                                      : (isMc
                                            ? const Color(0xFF0C4A6E)
                                            : const Color(0xFF059669)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    pay.type == 'mercadopago'
                                        ? 'MP'
                                        : pay.type.toUpperCase(),
                                    style: TextStyle(
                                      color: p.card,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 10,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pay.type == 'mercadopago'
                                        ? 'Mercado Pago Protegido'
                                        : 'Tarjeta de Crédito / Débito',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  if (pay.last4 != null)
                                    Text(
                                      '•••• •••• •••• ${pay.last4}',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        color: p.textFaint,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'PREDETERMINADO',
                                style: TextStyle(
                                  color: Color(0xFF059669),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () => state.deletePaymentMethod(pay.id),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Color(0xFFF43F5E),
                                  size: 16,
                                ),
                                style: IconButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  minimumSize: const Size(28, 28),
                                  fixedSize: const Size(28, 28),
                                  backgroundColor: const Color(0xFFFFF1F2),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Theme Settings Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.palette_outlined, color: p.accent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Tema de la Aplicación',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Apariencia visual',
                      style: TextStyle(fontSize: 12, color: p.textMuted),
                    ),
                    SegmentedButton<ThemeMode>(
                      segments: const [
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.light,
                          icon: Icon(Icons.light_mode_outlined, size: 16),
                          label: Text('Claro', style: TextStyle(fontSize: 11)),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.dark,
                          icon: Icon(Icons.dark_mode_outlined, size: 16),
                          label: Text('Oscuro', style: TextStyle(fontSize: 11)),
                        ),
                        ButtonSegment<ThemeMode>(
                          value: ThemeMode.system,
                          icon: Icon(Icons.settings_suggest_outlined, size: 16),
                          label: Text('Sistema', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                      selected: {state.themeMode},
                      onSelectionChanged: (Set<ThemeMode> newSelection) {
                        state.setThemeMode(newSelection.first);
                      },
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        selectedBackgroundColor: p.accent.withValues(alpha: 0.15),
                        selectedForegroundColor: p.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Accessibility Settings Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.text_fields_rounded, color: p.accent, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Tamaño de Texto (Accesibilidad)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Escalar fuentes',
                      style: TextStyle(fontSize: 12, color: p.textMuted),
                    ),
                    SegmentedButton<double>(
                      segments: const [
                        ButtonSegment<double>(
                          value: 1.0,
                          label: Text('Normal', style: TextStyle(fontSize: 11)),
                        ),
                        ButtonSegment<double>(
                          value: 1.2,
                          label: Text('Grande', style: TextStyle(fontSize: 11)),
                        ),
                        ButtonSegment<double>(
                          value: 1.4,
                          label: Text('Muy Grande', style: TextStyle(fontSize: 11)),
                        ),
                      ],
                      selected: {state.textScaleFactor},
                      onSelectionChanged: (Set<double> newSelection) {
                        state.setTextScaleFactor(newSelection.first);
                      },
                      showSelectedIcon: false,
                      style: SegmentedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        selectedBackgroundColor: p.accent.withValues(alpha: 0.15),
                        selectedForegroundColor: p.accent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Logout button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => state.logout(),
              icon: const Icon(
                Icons.logout_rounded,
                size: 18,
                color: Color(0xFFDC2626),
              ),
              label: Text(
                state.isDemoMode ? 'Salir del modo demo' : 'Cerrar sesión',
                style: const TextStyle(
                  color: Color(0xFFDC2626),
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: Color(0xFFFECACA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: p.textFaint,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isNum = false,
    int maxLines = 1,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: TextStyle(
          fontSize: 12,
          color: Theme.of(context).colorScheme.onSurface,
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: p.textFaint,
            fontSize: 11,
            fontWeight: FontWeight.normal,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
        ),
      ),
    );
  }
}
