import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../theme/app_theme.dart';
import '../ui/aura.dart';
import '../utils/money.dart';

/// Datos que alimentan el comprobante de la atención.
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

  /// Texto que se comparte por WhatsApp o correo.
  ///
  /// El formato está cubierto por pruebas y se envía fuera de la app, donde no
  /// hay tipografía ni color que ordenen la información: por eso aquí sí se
  /// usan mayúsculas y emojis, y por eso este método no cambia al migrar la
  /// pantalla.
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

/// Muestra el comprobante de la solicitud confirmada, con las opciones de
/// compartirlo, guardarlo y pasar al seguimiento.
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
        subject: 'Comprobante de atención Aura #${widget.voucher.folio}',
      ),
    );
  }

  Future<void> _downloadAndSaveVoucher() async {
    setState(() => _isSaving = true);
    try {
      final text = widget.voucher.toShareableText();

      // También al portapapeles: es la vía más rápida para pegarlo en un chat.
      await Clipboard.setData(ClipboardData(text: text));

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/Comprobante_AURA_${widget.voucher.folio}.txt');
      await file.writeAsString(text);

      if (mounted) {
        _showNotice(
          tone: AuraTone.success,
          icon: Icons.check_circle_outline_rounded,
          message: 'Guardamos el comprobante y lo copiamos para que puedas pegarlo.',
        );
      }
    } catch (e) {
      // El texto de la excepción se queda en el registro. Antes se le mostraba
      // tal cual a la persona: «No se pudo guardar el archivo: FileSystemException…»
      // no dice qué hacer y, en una pantalla de confirmación, asusta.
      debugPrint('No se pudo guardar el comprobante: $e');
      if (mounted) {
        _showNotice(
          tone: AuraTone.error,
          icon: Icons.error_outline_rounded,
          message: 'No pudimos guardar el archivo. Prueba a compartirlo.',
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showNotice({
    required String message,
    required AuraTone tone,
    required IconData icon,
  }) {
    final c = auraToneColors(context, tone);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: c.surface,
        content: Row(
          children: [
            Icon(icon, color: c.onSurface, size: AuraIcon.md),
            const SizedBox(width: AuraSpace.sm),
            Expanded(
              child: Text(
                message,
                style: AppType.bodySmall.copyWith(
                  color: c.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final v = widget.voucher;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(
        horizontal: AuraSpace.md,
        vertical: AuraSpace.xl,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: AuraRadius.allXl,
            boxShadow: AuraShadow.overlay(context.isDark),
          ),
          child: ClipRRect(
            borderRadius: AuraRadius.allXl,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _header(p, v),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AuraSpace.lg,
                      vertical: AuraSpace.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _serviceBlock(p, v),
                        const SizedBox(height: AuraSpace.sm),
                        ..._detailRows(v),
                        _ticketDivider(p),
                        AuraSummaryRow(
                          label: 'Total',
                          value: Money.format(v.finalPrice, withCode: true),
                          strong: true,
                        ),
                        // Mismo motivo que el arribo: sin traslado, la frase
                        // cobraba por algo que nadie hace.
                        if (v.etaMinutes > 0)
                          Text(
                            'El monto incluye los insumos y el traslado.',
                            style: AppType.bodySmall.copyWith(color: p.textMuted),
                          ),
                      ],
                    ),
                  ),
                ),
                Divider(height: 1, color: p.border),
                _actions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(AppPalette p, BookingVoucherData v) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.lg,
        AuraSpace.xl,
        AuraSpace.lg,
        AuraSpace.lg,
      ),
      color: p.brandDeep,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(AuraSpace.sm),
            decoration: BoxDecoration(
              color: p.onBrandDeep.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle_rounded,
              color: p.onBrandDeep,
              size: AuraIcon.display,
            ),
          ),
          const SizedBox(height: AuraSpace.sm),
          Semantics(
            header: true,
            child: Text(
              'Solicitud confirmada',
              textAlign: TextAlign.center,
              style: AppType.titleMedium.copyWith(
                color: p.onBrandDeep,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: AuraSpace.xxs),
          Text(
            'Este es tu comprobante. Puedes guardarlo o enviarlo.',
            textAlign: TextAlign.center,
            style: AppType.bodySmall.copyWith(
              color: p.onBrandDeep.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: AuraSpace.sm),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.sm,
              vertical: AuraSpace.xxs + 1,
            ),
            decoration: BoxDecoration(
              color: p.onBrandDeep.withValues(alpha: 0.16),
              borderRadius: AuraRadius.allPill,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tag_rounded, color: p.onBrandDeep, size: AuraIcon.sm),
                const SizedBox(width: AuraSpace.xxs),
                Flexible(
                  child: Text(
                    'Folio #${v.folio}',
                    style: AppType.label.copyWith(
                      color: p.onBrandDeep,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _serviceBlock(AppPalette p, BookingVoucherData v) {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.sm),
      decoration: BoxDecoration(
        color: p.accentSurface,
        borderRadius: AuraRadius.allMd,
        border: Border.all(color: p.accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: BoxDecoration(
              color: p.accent,
              borderRadius: AuraRadius.allSm,
            ),
            child: Icon(
              v.serviceIcon,
              color: context.scheme.onPrimary,
              size: AuraIcon.md,
            ),
          ),
          const SizedBox(width: AuraSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  v.serviceTitle,
                  style: AppType.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
                // El comprobante del laboratorio y el de la videoconsulta se
                // crean con `etaMinutes: 0` porque ahí nadie va en camino:
                // «Llega en unos 0 min» anunciaba una atención inmediata que
                // no existe.
                if (v.etaMinutes > 0) ...[
                  const SizedBox(height: AuraSpace.xxxs),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: AuraIcon.sm,
                        color: p.accentText,
                      ),
                      const SizedBox(width: AuraSpace.xxs),
                      Flexible(
                        child: Text(
                          'Llega en unos ${v.etaMinutes} min',
                          style: AppType.bodySmall.copyWith(
                            color: p.accentText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _detailRows(BookingVoucherData v) {
    String dateStr;
    try {
      dateStr = DateFormat("dd 'de' MMMM, HH:mm", 'es').format(v.createdAt);
    } catch (_) {
      dateStr = DateFormat('dd/MM/yyyy, HH:mm').format(v.createdAt);
    }

    final hasRoute = v.originAddress != null && v.originAddress!.isNotEmpty;

    return [
      AuraSummaryRow(
        icon: Icons.calendar_today_rounded,
        label: 'Fecha y hora',
        value: dateStr,
      ),
      AuraSummaryRow(
        icon: Icons.person_rounded,
        label: 'Paciente',
        value: v.patientName +
            (v.relationship != null ? ' (${v.relationship})' : ''),
      ),
      if (v.ambulanceType != null && v.ambulanceType!.isNotEmpty)
        AuraSummaryRow(
          icon: Icons.local_hospital_rounded,
          label: 'Tipo de traslado',
          value: v.ambulanceType!,
        ),
      if (hasRoute) ...[
        AuraSummaryRow(
          icon: Icons.trip_origin_rounded,
          label: 'Desde',
          value: v.originAddress!,
        ),
        if (v.destinationAddress != null && v.destinationAddress!.isNotEmpty)
          AuraSummaryRow(
            icon: Icons.flag_rounded,
            label: 'Hasta',
            value: v.destinationAddress!,
          ),
      ] else
        AuraSummaryRow(
          icon: Icons.location_on_rounded,
          label: 'Dirección',
          value: v.address,
        ),
      if (v.symptomsOrReason != null && v.symptomsOrReason!.trim().isNotEmpty)
        AuraSummaryRow(
          icon: Icons.healing_rounded,
          label: 'Motivo',
          value: v.symptomsOrReason!,
        ),
    ];
  }

  /// El borde troquelado que separa el detalle del importe. Es lo único de la
  /// tarjeta que sigue siendo decorativo, y por eso queda fuera de semántica.
  Widget _ticketDivider(AppPalette p) {
    return ExcludeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AuraSpace.xs),
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
    );
  }

  Widget _actions() {
    final canTrack = widget.onTrack != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.md,
        AuraSpace.sm,
        AuraSpace.md,
        AuraSpace.md,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: AuraButton.secondary(
                  label: 'Compartir',
                  icon: Icons.share_rounded,
                  size: AuraButtonSize.small,
                  onPressed: _shareVoucher,
                ),
              ),
              const SizedBox(width: AuraTap.gap),
              Expanded(
                child: AuraButton.secondary(
                  label: 'Guardar',
                  icon: Icons.download_rounded,
                  size: AuraButtonSize.small,
                  loading: _isSaving,
                  onPressed: _downloadAndSaveVoucher,
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.xs),
          AuraButton.primary(
            // Sin `onTrack` este botón solo cierra el comprobante, así que
            // prometer un seguimiento sería mentir sobre lo que hace.
            label: canTrack ? 'Ver el seguimiento en vivo' : 'Listo',
            icon: canTrack ? Icons.radar_rounded : Icons.check_rounded,
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              widget.onTrack?.call();
            },
          ),
        ],
      ),
    );
  }
}
