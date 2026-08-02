import 'package:flutter/material.dart';

/// Screen / Modal displaying a doctor's full profile, curriculum, experience,
/// registration number (Superintendencia de Salud), and rating stars.
class DoctorProfileScreen extends StatelessWidget {
  final Map<String, dynamic> doctorData;

  const DoctorProfileScreen({super.key, required this.doctorData});

  static Future<void> showModal(BuildContext context, Map<String, dynamic> doctorData) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DoctorProfileScreen(doctorData: doctorData),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = doctorData['name'] ?? 'Profesional Clínico';
    final specialty = doctorData['specialty'] ?? 'Medicina General';
    final bio = doctorData['bio'] ??
        'Médico Cirujano titulado con amplia experiencia en atención domiciliaria, medicina preventiva y telemedicina.';
    final registration = doctorData['registration_number'] ?? 'SIS-492015';
    final years = doctorData['years_of_experience'] ?? 7;
    final rating = (doctorData['rating_avg'] ?? 4.9).toDouble();
    final ratingCount = doctorData['rating_count'] ?? 42;
    final phone = doctorData['phone'] ?? '+56 9 8765 4321';

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: const Color(0xFF0D9488).withValues(alpha: 0.15),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 40,
                    color: Color(0xFF0D9488),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialty,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF0D9488),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$rating ($ratingCount evaluaciones)',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            const Text(
              'INFORMACIÓN PROFESIONAL Y REGISTRO',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.verified_user_rounded,
              label: 'Registro Superintendencia de Salud',
              value: registration,
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              icon: Icons.work_history_rounded,
              label: 'Experiencia Clínica',
              value: '$years años de práctica médica',
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              icon: Icons.phone_rounded,
              label: 'Contacto de Emergencia',
              value: phone,
              isDark: isDark,
            ),
            const SizedBox(height: 16),
            const Text(
              'BIOGRAFÍA Y CURRÍCULUM',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.8,
                color: Color(0xFF0D9488),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              bio,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D9488),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cerrar Perfil',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 18, color: const Color(0xFF0D9488)),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
