import 'package:flutter/material.dart';

import '../models/professional.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';

/// B.3 — ficha de la persona que va a atender: quién es, qué registro tiene y
/// cómo la han evaluado otros pacientes.
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
      // La hoja ya no se pinta a mano sobre un fondo transparente: el tema le
      // pone superficie, esquinas y tirador de arrastre. El tirador anterior
      // era un rectángulo de 40×4 dibujado a mano, sin gesto asociado ni
      // significado para un lector de pantalla.
      useSafeArea: true,
      builder: (context) => DoctorProfileScreen(
        professional: professional,
        phone: phone,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bio = professional.bio?.trim() ?? '';

    return Padding(
      padding: EdgeInsets.only(
        left: AuraSpace.screenX,
        right: AuraSpace.screenX,
        top: AuraSpace.xs,
        // `useSafeArea` esquiva la barra de estado y los lados, no el borde
        // inferior: ese lo reserva la hoja.
        bottom: MediaQuery.viewPaddingOf(context).bottom + AuraSpace.lg,
      ),
      child: SingleChildScrollView(
        child: AuraReadable(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _avatar(context),
                  const SizedBox(width: AuraSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          professional.name,
                          style: AppType.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                          ),
                        ),
                        if (professional.specialty.isNotEmpty) ...[
                          const SizedBox(height: AuraSpace.xxs),
                          Text(
                            professional.specialty,
                            style: AppType.bodySmall.copyWith(
                              color: p.accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                        const SizedBox(height: AuraSpace.xs),
                        _rating(context),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AuraSpace.xl),
              const AuraSectionHeader(title: 'Registro y experiencia'),
              AuraCard(
                child: Column(
                  children: [
                    AuraSummaryRow(
                      icon: Icons.verified_user_rounded,
                      label: 'Registro profesional',
                      value: professional.registrationNumber ?? 'No informado',
                    ),
                    AuraSummaryRow(
                      icon: Icons.work_history_rounded,
                      label: 'Años atendiendo',
                      value: _experienceLabel(),
                    ),
                    if (phone != null && phone!.isNotEmpty)
                      AuraSummaryRow(
                        icon: Icons.phone_rounded,
                        label: 'Teléfono durante la atención',
                        value: phone!,
                      ),
                  ],
                ),
              ),

              const SizedBox(height: AuraSpace.xl),
              const AuraSectionHeader(title: 'Quién es'),
              Text(
                bio.isNotEmpty
                    ? bio
                    : 'Todavía no ha escrito su presentación.',
                // La presentación ausente ya no va en cursiva: la cursiva es lo
                // que peor se lee en pantalla y aquí marcaba justo la línea que
                // más gente iba a encontrarse.
                style: AppType.bodyMedium.copyWith(
                  color: bio.isNotEmpty ? p.textSecondary : p.textMuted,
                ),
              ),

              const SizedBox(height: AuraSpace.xl),
              AuraButton.secondary(
                label: 'Cerrar',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _experienceLabel() {
    final years = professional.yearsOfExperience;
    if (years == null) return 'No informados';
    return years == 1 ? '1 año' : '$years años';
  }

  Widget _avatar(BuildContext context) {
    final p = context.palette;
    final photo = professional.photoUrl;

    return CircleAvatar(
      radius: 36,
      backgroundColor: p.accentSurface,
      // `foregroundImage` deja el icono debajo como respaldo: si la foto no
      // carga, la ficha no queda con un hueco gris.
      foregroundImage: (photo != null && photo.isNotEmpty)
          ? NetworkImage(photo)
          : null,
      child: Icon(Icons.person_rounded, size: AuraIcon.xl, color: p.accentText),
    );
  }

  Widget _rating(BuildContext context) {
    final p = context.palette;

    if (!professional.hasRating) {
      return Text(
        'Todavía no tiene evaluaciones',
        style: AppType.label.copyWith(color: p.textMuted),
      );
    }

    final average = professional.ratingAvg!;
    final count = professional.ratingCount;
    final noun = count == 1 ? 'evaluación' : 'evaluaciones';

    return Semantics(
      label: '${average.toStringAsFixed(1)} de 5, $count $noun',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Icon(Icons.star_rounded, size: AuraIcon.sm, color: p.warning),
            const SizedBox(width: AuraSpace.xxs),
            Flexible(
              child: Text(
                '${average.toStringAsFixed(1)} · $count $noun',
                style: AppType.label.copyWith(
                  color: p.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
