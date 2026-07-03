import 'package:flutter/material.dart';
import '../models/dependent.dart';
import '../models/saved_address.dart';
import '../state/app_state.dart';

class ProfileScreen extends StatefulWidget {
  final AppState state;

  const ProfileScreen({super.key, required this.state});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Add Dependent Form controllers
  bool _showAddDep = false;
  final TextEditingController _depNameController = TextEditingController();
  String _depRel = 'Madre';
  final TextEditingController _depAgeController = TextEditingController();
  final TextEditingController _depInsuranceController = TextEditingController(
    text: 'Isapre Colmena',
  );
  final TextEditingController _depObsController = TextEditingController();

  // Add Address Form controllers
  bool _showAddAddr = false;
  final TextEditingController _addrLabelController = TextEditingController();
  final TextEditingController _addrTextController = TextEditingController();

  @override
  void dispose() {
    _depNameController.dispose();
    _depAgeController.dispose();
    _depInsuranceController.dispose();
    _depObsController.dispose();
    _addrLabelController.dispose();
    _addrTextController.dispose();
    super.dispose();
  }

  void _createDependent() {
    final name = _depNameController.text.trim();
    final ageStr = _depAgeController.text.trim();
    if (name.isEmpty || ageStr.isEmpty) return;

    final age = int.tryParse(ageStr) ?? 40;

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

    // Reset Form
    _depNameController.clear();
    _depAgeController.clear();
    _depObsController.clear();
    setState(() {
      _showAddDep = false;
    });
  }

  void _createAddress() {
    final label = _addrLabelController.text.trim();
    final text = _addrTextController.text.trim();
    if (label.isEmpty || text.isEmpty) return;

    widget.state.addAddress(
      SavedAddress(
        id: 'addr_${DateTime.now().millisecondsSinceEpoch}',
        label: label,
        text: text,
      ),
    );

    // Reset Form
    _addrLabelController.clear();
    _addrTextController.clear();
    setState(() {
      _showAddAddr = false;
    });
  }

  @override
  Widget build(BuildContext context) {
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  height: 56,
                  width: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F6F4),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFCCFBF1)),
                  ),
                  child: const Icon(
                    Icons.person_pin,
                    color: Color(0xFF0D9488),
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
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        state.userEmail.isNotEmpty
                            ? state.userEmail
                            : 'Paciente Frecuente • Miembro VIP Aura',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F6F4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.shield_rounded,
                              color: Color(0xFF0D9488),
                              size: 12,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Plan Cobertura Preferencial Plus',
                              style: TextStyle(
                                color: Color(0xFF0D9488),
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
              gradient: const LinearGradient(
                colors: [
                  Color(0xFF0F172A),
                  Color(0xFF115E59),
                ], // brand-dark to teal-900
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
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
                        color: Color(0xFFCCFBF1),
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
                                  ? const Color(0xFF0D9488)
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
                                      ? const Color(0xFF0D9488)
                                      : const Color(0xFF0F172A),
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
                                                ? const Color(0xFF0F172A)
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
                                            ? const Color(0xFF64748B)
                                            : const Color(0xFF94A3B8),
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
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showAddDep = !_showAddDep),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F6F4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showAddDep ? Icons.close : Icons.add,
                              size: 12,
                              color: const Color(0xFF0D9488),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showAddDep ? 'Ocultar' : 'Agregar',
                              style: const TextStyle(
                                color: Color(0xFF0D9488),
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
                      color: const Color(0xFFE6F6F4).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCCFBF1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Registrar Nuevo Familiar Paciente',
                          style: TextStyle(
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
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFCBD5E1),
                                      ),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButtonFormField<String>(
                                        initialValue: _depRel,
                                        decoration: const InputDecoration(
                                          border: InputBorder.none,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF0F172A),
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
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Guardar Familiar Dependiente',
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
                const SizedBox(height: 12),
                Column(
                  children: state.dependents.map((dep) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
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
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${dep.relationship} • ${dep.age} años • ${dep.healthInsurance}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Color(0xFF64748B),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Obs: ${dep.medicalConditions}',
                                  style: const TextStyle(
                                    fontSize: 9,
                                    color: Color(0xFF0D9488),
                                    fontStyle: FontStyle.italic,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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
                          size: 18,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Direcciones Frecuentes',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showAddAddr = !_showAddAddr),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE6F6F4),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              _showAddAddr ? Icons.close : Icons.add,
                              size: 12,
                              color: const Color(0xFF0D9488),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _showAddAddr ? 'Cerrar' : 'Nueva',
                              style: const TextStyle(
                                color: Color(0xFF0D9488),
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
                      color: const Color(0xFFE6F6F4).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFCCFBF1)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
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
                              backgroundColor: const Color(0xFF0D9488),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: const Text(
                              'Agregar Dirección',
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
                const SizedBox(height: 12),
                Column(
                  children: state.addresses.map((addr) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: Color(0xFF0D9488),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  addr.label,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  addr.text,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF64748B),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.credit_card, color: Color(0xFF0284C7), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Medios de Pago Vinculados',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Column(
                  children: state.paymentMethods.map((pay) {
                    final isVisa = pay.type == 'visa';
                    final isMc = pay.type == 'mastercard';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFF1F5F9)),
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
                                    style: const TextStyle(
                                      color: Colors.white,
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
                                      style: const TextStyle(
                                        fontSize: 9.5,
                                        color: Color(0xFF94A3B8),
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                          const Text(
                            'PREDETERMINADO',
                            style: TextStyle(
                              color: Color(0xFF059669),
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
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
        style: const TextStyle(
          fontSize: 8,
          fontWeight: FontWeight.bold,
          color: Color(0xFF94A3B8),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFCBD5E1)),
      ),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: const TextStyle(
          fontSize: 12,
          color: Color(0xFF0F172A),
          fontWeight: FontWeight.bold,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(
            color: Color(0xFF94A3B8),
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
