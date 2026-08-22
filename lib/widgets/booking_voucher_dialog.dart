import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import '../utils/money.dart';

/// Datos que alimentan el voucher / comprobante de atención.
class BookingVoucherData {
  final String folio;
  final String serviceTitle;
  final IconData serviceIcon;
  final String patientName;
  final String? patientType; // 'self' | 'dependent'
  final String? relationship;
  final String address;
  final String? originAddress;
  final String? destinationAddress;
  final String? ambulanceType;
  final String? symptomsOrReason;
  final int finalPrice;
  final int etaMinutes;
  final DateTime createdAt;
  final String? paymentStatus;

  BookingVoucherData({
    required this.folio,
    required this.serviceTitle,
    required this.serviceIcon,
    required this.patientName,
    this.patientType,
    this.relationship,
    required this.address,
    this.originAddress,
    this.destinationAddress,
    this.ambulanceType,
    this.symptomsOrReason,
    required this.finalPrice,
    required this.etaMinutes,
    DateTime? createdAt,
    this.paymentStatus,
  }) : createdAt = createdAt ?? DateTime.now();

  String toShareableText() {
    final dateStr = DateFormat("dd/MM/yyyy 'a las' HH:mm").format(createdAt);
    final buffer = StringBuffer();
    buffer.writeln('📋 *COMPROBANTE DE ATENCIÓN - AURA SALUD*');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🔖 *Folio:* #$folio');
    buffer.writeln('📅 *Fecha y Hora:* $dateStr');
    buffer.writeln('🩺 *Servicio:* $serviceTitle');
    buffer.writeln('👤 *Paciente:* $patientName ${relationship != null ? "($relationship)" : ""}');
    if (ambulanceType != null && ambulanceType!.isNotEmpty) {
      buffer.writeln('🚑 *Tipo de Traslado:* $ambulanceType');
    }
    if (originAddress != null && originAddress!.isNotEmpty) {
      buffer.writeln('📍 *Origen:* $originAddress');
    }
    if (destinationAddress != null && destinationAddress!.isNotEmpty) {
      buffer.writeln('🏁 *Destino:* $destinationAddress');
    } else {
      buffer.writeln('📍 *Dirección:* $address');
    }
    if (symptomsOrReason != null && symptomsOrReason!.trim().isNotEmpty) {
      buffer.writeln('📝 *Motivo/Síntomas:* $symptomsOrReason');
    }
    buffer.writeln('⏱️ *Tiempo Estimado (ETA):* $etaMinutes min');
    buffer.writeln('💰 *Tarifa Cotizada:* ${Money.format(finalPrice)} ${Money.code}');
    buffer.writeln('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    buffer.writeln('🔒 _Atención confirmada y despachada por la red clínica de AURA Salud._');
    return buffer.toString();
  }
}

/// Muestra el modal de voucher de confirmación con opciones de compartir, descargar y continuar.
Future<void> showBookingVoucherDialog({
  required BuildContext context,
  required BookingVoucherData voucher,
  VoidCallback? onTrack,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return BookingVoucherDialog(
        voucher: voucher,
        onTrack: onTrack,
      );
    },
  );
}

class BookingVoucherDialog extends StatefulWidget {
  final BookingVoucherData voucher;
  final VoidCallback? onTrack;

  const BookingVoucherDialog({
    super.key,
    required this.voucher,
    this.onTrack,
  });

  @override
  State<BookingVoucherDialog> createState() => _BookingVoucherDialogState();
}

class _BookingVoucherDialogState extends State<BookingVoucherDialog> {
  bool _isSaving = false;

  Future<void> _shareVoucher() async {
    final text = widget.voucher.toShareableText();
    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Comprobante de Atención AURA #${widget.voucher.folio}',
      ),
    );
  }

  Future<void> _downloadAndSaveVoucher() async {
    setState(() => _isSaving = true);
    try {
      final text = widget.voucher.toShareableText();

      // Guardar también en el portapapeles para acceso inmediato
      await Clipboard.setData(ClipboardData(text: text));

      // Guardar archivo físico en el directorio de documentos o temporal
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Comprobante_AURA_${widget.voucher.folio}.txt');
      await file.writeAsString(text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F766E),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '¡Comprobante guardado y copiado al portapapeles!',
                    style: AppType.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFDC2626),
            content: Text('No se pudo guardar el archivo: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = context.isDark;
    final v = widget.voucher;
    String dateStr;
    try {
      dateStr = DateFormat("dd 'de' MMMM, HH:mm 'hrs'", 'es').format(v.createdAt);
    } catch (_) {
      dateStr = DateFormat("dd/MM/yyyy, HH:mm 'hrs'").format(v.createdAt);
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.2),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header con degradado médico y checkmark
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0F766E), // teal-700
                        Color(0xFF14B8A6), // teal-500
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.white,
                          size: 42,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '¡Solicitud Confirmada!',
                        textAlign: TextAlign.center,
                        style: AppType.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Comprobante Digital de Atención',
                        textAlign: TextAlign.center,
                        style: AppType.bodySmall.copyWith(
                          color: const Color(0xFFCCFBF1),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.tag_rounded,
                              color: Color(0xFF5EEAD4),
                              size: 15,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'FOLIO: #${v.folio}',
                              style: AppType.label.copyWith(
                                color: const Color(0xFFF0FDFA),
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Contenido del Ticket / Voucher con Scroll si es necesario
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Servicio + ETA
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: p.accentSurface.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: p.accentSurface),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: p.accent,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(
                                  v.serviceIcon,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      v.serviceTitle,
                                      style: AppType.bodyMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: p.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 13,
                                          color: p.accentText,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Arribo estimado: ${v.etaMinutes} min',
                                          style: AppType.bodySmall.copyWith(
                                            color: p.accentText,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Fila Fecha y Hora
                        _buildInfoRow(
                          p: p,
                          icon: Icons.calendar_today_rounded,
                          label: 'Fecha y Hora',
                          value: dateStr,
                        ),
                        const SizedBox(height: 10),

                        // Fila Paciente
                        _buildInfoRow(
                          p: p,
                          icon: Icons.person_rounded,
                          label: 'Paciente Beneficiario',
                          value: v.patientName + (v.relationship != null ? ' (${v.relationship})' : ''),
                        ),
                        const SizedBox(height: 10),

                        // Fila Dirección / Ruta
                        if (v.originAddress != null && v.originAddress!.isNotEmpty) ...[
                          _buildInfoRow(
                            p: p,
                            icon: Icons.trip_origin_rounded,
                            label: 'Origen del Traslado',
                            value: v.originAddress!,
                          ),
                          const SizedBox(height: 8),
                          if (v.destinationAddress != null && v.destinationAddress!.isNotEmpty)
                            _buildInfoRow(
                              p: p,
                              icon: Icons.flag_rounded,
                              label: 'Destino del Traslado',
                              value: v.destinationAddress!,
                            ),
                        ] else ...[
                          _buildInfoRow(
                            p: p,
                            icon: Icons.location_on_rounded,
                            label: 'Dirección de Atención',
                            value: v.address,
                          ),
                        ],
                        const SizedBox(height: 10),

                        // Fila Síntomas / Motivo
                        if (v.symptomsOrReason != null && v.symptomsOrReason!.trim().isNotEmpty) ...[
                          _buildInfoRow(
                            p: p,
                            icon: Icons.healing_rounded,
                            label: 'Síntomas / Motivo Clínico',
                            value: v.symptomsOrReason!,
                          ),
                          const SizedBox(height: 10),
                        ],

                        // Línea divisoria tipo Ticket
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: List.generate(
                              24,
                              (i) => Expanded(
                                child: Container(
                                  color: i.isEven ? p.border : Colors.transparent,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Fila Tarifa Total
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Cotizado',
                              style: AppType.bodySmall.copyWith(
                                color: p.textMuted,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            RichText(
                              text: TextSpan(
                                text: '${Money.format(v.finalPrice)} ',
                                style: AppType.titleMedium.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: p.textPrimary,
                                ),
                                children: [
                                  TextSpan(
                                    text: Money.code,
                                    style: AppType.label.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: p.accent,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: Text(
                            'Incluye insumos médicos clínicos y traslado',
                            style: AppType.label.copyWith(
                              color: p.textFaint,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Divisor inferior
                Divider(height: 1, color: p.fill),

                // Barra de Acciones (Compartir, Descargar, Continuar)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _shareVoucher,
                              icon: const Icon(Icons.share_rounded, size: 16),
                              label: Text(
                                'Compartir',
                                style: AppType.bodySmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                foregroundColor: p.accent,
                                side: BorderSide(color: p.accent),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _isSaving ? null : _downloadAndSaveVoucher,
                              icon: _isSaving
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(Icons.download_rounded, size: 16),
                              label: Text(
                                'Guardar',
                                style: AppType.bodySmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                foregroundColor: p.textPrimary,
                                side: BorderSide(color: p.border),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).pop();
                            if (widget.onTrack != null) {
                              widget.onTrack!();
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: p.accent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.radar_rounded, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Ver Seguimiento en Vivo',
                                style: AppType.button.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required AppPalette p,
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 15, color: p.textMuted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppType.label.copyWith(
                  color: p.textMuted,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                value,
                style: AppType.bodySmall.copyWith(
                  color: p.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
