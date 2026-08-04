import 'package:flutter/material.dart';

import '../models/professional.dart';

/// B.3 — ficha del profesional que va a atender: currículum, experiencia,
/// registro de la Superintendencia de Salud y evaluación.
///
/// Nada aquí tiene valor por defecto. Un número de registro, unos años de
/// experiencia o unas estrellas inventadas son exactamente el tipo de dato con
/// el que un paciente decide si deja entrar a alguien a su casa: si el servidor
/// no lo envía, la ficha dice que no está informado.
class DoctorProfileScreen extends StatelessWidget {
  final Professional professional;

  /// Teléfono de contacto. Solo llega cuando el profesional está asignado a una
  /// atención del paciente; no viaja en el catálogo público.
  final String? phone;

  const DoctorProfileScreen({
    super.key,
    required this.professional,
    this.phone,
  });

  static Future<void> showModal(
    BuildContext context,
    Professional professional, {
    String? phone,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DoctorProfileScreen(
        professional: professional,
        phone: phone,
      ),
    );
  }

  static const _accent = Color(0xFF0F766E);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.grey[400] : Colors.grey[600];

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
                _buildAvatar(),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        professional.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (professional.specialty.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          professional.specialty,
                          style: const TextStyle(
                            fontSize: 13,
                            color: _accent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 6),
                      _buildRating(muted),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Divider(),
            const SizedBox(height: 12),
            _buildSectionTitle('INFORMACIÓN PROFESIONAL Y REGISTRO'),
            const SizedBox(height: 12),
            _buildInfoRow(
              icon: Icons.verified_user_rounded,
              label: 'Registro Superintendencia de Salud',
              value: professional.registrationNumber ?? 'No informado',
              isDark: isDark,
            ),
            const SizedBox(height: 10),
            _buildInfoRow(
              icon: Icons.work_history_rounded,
              label: 'Experiencia clínica',
              value: professional.yearsOfExperience != null
                  ? '${professional.yearsOfExperience} años de práctica'
                  : 'No informada',
              isDark: isDark,
            ),
            if (phone != null && phone!.isNotEmpty) ...[
              const SizedBox(height: 10),
              _buildInfoRow(
                icon: Icons.phone_rounded,
                label: 'Contacto durante la atención',
                value: phone!,
                isDark: isDark,
              ),
            ],
            const SizedBox(height: 16),
            _buildSectionTitle('BIOGRAFÍA Y CURRÍCULUM'),
            const SizedBox(height: 8),
            Text(
              professional.bio?.trim().isNotEmpty == true
                  ? professional.bio!
                  : 'Este profesional todavía no ha publicado su reseña.',
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                fontStyle: professional.bio?.trim().isNotEmpty == true
                    ? FontStyle.normal
                    : FontStyle.italic,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cerrar perfil',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final photo = professional.photoUrl;

    return CircleAvatar(
      radius: 36,
      backgroundColor: _accent.withValues(alpha: 0.15),
      // `foregroundImage` deja el icono debajo como respaldo: si la foto no
      // carga, la ficha no queda con un hueco gris.
      foregroundImage: (photo != null && photo.isNotEmpty)
          ? NetworkImage(photo)
          : null,
      child: const Icon(Icons.person_rounded, size: 40, color: _accent),
    );
  }

  Widget _buildRating(Color? muted) {
    if (!professional.hasRating) {
      return Text(
        'Sin evaluaciones aún',
        style: TextStyle(fontSize: 12, color: muted, fontStyle: FontStyle.italic),
      );
    }

    final average = professional.ratingAvg!;
    final count = professional.ratingCount;

    return Row(
      children: [
        const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
          '${average.toStringAsFixed(1)} '
          '($count ${count == 1 ? 'evaluación' : 'evaluaciones'})',
          style: TextStyle(
            fontSize: 12,
            color: muted,
            fontWeight: FontWeight.bold,
          ),
        ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 0.8,
        color: _accent,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _accent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
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
        ),
      ],
    );
  }
}
