import 'package:aura/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/lab_models.dart';
import '../state/app_state.dart';

/// E.4 — "Mis Exámenes": tomas de muestra agendadas e informes descargables.
///
/// Reúne las dos mitades del flujo de laboratorio en una sola pantalla, porque
/// desde el punto de vista del paciente son lo mismo: lo que viene y lo que ya
/// tiene resultado.
class LabResultsScreen extends StatefulWidget {
  final AppState state;

  const LabResultsScreen({super.key, required this.state});

  @override
  State<LabResultsScreen> createState() => _LabResultsScreenState();
}

class _LabResultsScreenState extends State<LabResultsScreen> {
  AppPalette get p => context.palette;

  bool _loading = true;
  String? _openingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    await Future.wait([
      widget.state.fetchLabRequests(),
      widget.state.fetchLabResults(),
    ]);
    if (!mounted) return;
    setState(() => _loading = false);
  }

  Future<void> _open(LabResult result) async {
    setState(() => _openingId = result.id);
    final opened = await widget.state.openLabResult(result);
    if (!mounted) return;
    setState(() => _openingId = null);

    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No pudimos abrir el informe. Revisa tu conexión e inténtalo de nuevo.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _pay(LabRequest request) async {
    final url = request.paymentUrl;
    if (url == null || url.isEmpty) return;

    final opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );

    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No pudimos abrir la pasarela de pago. Inténtalo de nuevo.'),
        backgroundColor: Color(0xFFDC2626),
      ),
    );
  }

  Future<void> _verifyPayment(LabRequest request) async {
    final confirmed = await widget.state.verifyLabPayment(request.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          confirmed
              ? 'Pago confirmado. Tu toma de muestras quedó agendada.'
              : 'Todavía no vemos el pago acreditado. Si acabas de pagar, espera unos segundos.',
        ),
        backgroundColor:
            confirmed ? const Color(0xFF0F766E) : const Color(0xFFF59E0B),
      ),
    );
  }

  Future<void> _cancel(LabRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar toma de muestras'),
        content: Text(
          '¿Seguro que quieres cancelar la toma agendada para '
          '${request.scheduledLabel ?? 'la fecha seleccionada'}? '
          'El horario quedará disponible para otro paciente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Mantener'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Cancelar toma'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final error = await widget.state.cancelLabRequest(request.id);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'Toma de muestras cancelada.'),
        backgroundColor: error != null ? const Color(0xFFDC2626) : const Color(0xFF0F766E),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Cancelar o verificar un pago actualiza el estado global; sin escucharlo,
    // la lista seguiría mostrando la toma que el paciente acaba de cancelar.
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => _buildContent(),
    );
  }

  Widget _buildContent() {
    final requests = widget.state.labRequests;
    final results = widget.state.labResults;
    final upcoming = requests.where((r) => r.isCancellable).toList();

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: const Text('Mis Exámenes'),
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: p.textPrimary,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionTitle('TOMAS DE MUESTRA AGENDADAS', Icons.event_available_outlined),
                  const SizedBox(height: 10),
                  if (upcoming.isEmpty)
                    _emptyCard(
                      'No tienes tomas de muestra agendadas',
                      'Solicita "Toma de Muestras y Laboratorio" desde el catálogo para elegir un horario.',
                    )
                  else
                    ...upcoming.map(_requestCard),

                  const SizedBox(height: 24),
                  _sectionTitle('INFORMES DISPONIBLES', Icons.description_outlined),
                  const SizedBox(height: 10),
                  if (results.isEmpty)
                    _emptyCard(
                      'Aún no hay resultados',
                      'Cuando el laboratorio cargue tu informe, aparecerá aquí y también te llegará por correo.',
                    )
                  else
                    ...results.map(_resultCard),

                  const SizedBox(height: 24),
                  Text(
                    'Los informes son documentos clínicos: no reemplazan la interpretación de un '
                    'profesional. Si tienes dudas sobre lo que indican, agenda una consulta para revisarlos.',
                    style: TextStyle(fontSize: 12, color: p.textFaint, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: p.accent, size: 16),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: p.textFaint,
            letterSpacing: 0.5,
          ),
        ),
        ),
      ],
    );
  }

  Widget _emptyCard(String title, String subtitle) {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      child: Column(
        children: [
          Icon(Icons.science_outlined, color: p.accent.withValues(alpha: 0.3), size: 36),
          const SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: p.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: p.textFaint, height: 1.3),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(LabRequest request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  request.scheduledLabel ?? 'Fecha por confirmar',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: request.awaitsPayment
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFCCFBF1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  request.statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: request.awaitsPayment
                        ? const Color(0xFF92400E)
                        : const Color(0xFF0F766E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '📍 ${request.addressText}',
            style: TextStyle(fontSize: 12, color: p.textMuted, height: 1.4),
          ),
          if (request.professionalName != null)
            Text(
              '🧪 ${request.professionalName}',
              style: TextStyle(fontSize: 12, color: p.textMuted, height: 1.4),
            ),
          if (request.examRequired != null)
            Text(
              'Exámenes: ${request.examRequired}',
              style: TextStyle(fontSize: 12, color: p.textMuted, height: 1.4),
            ),
          if (request.clinicalNotes != null && request.clinicalNotes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Text(
                request.clinicalNotes!,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF92400E),
                  height: 1.4,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          // El pago no se abre solo: el paciente ve el monto y decide pagar o
          // cancelar. Redirigir automáticamente a la pasarela le quita ese paso.
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (request.awaitsPayment && request.paymentUrl != null)
                ElevatedButton(
                  onPressed: () => _pay(request),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    'Pagar \$${request.finalPrice}',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              if (request.awaitsPayment)
                TextButton(
                  onPressed: () => _verifyPayment(request),
                  child: const Text('Ya pagué', style: TextStyle(fontSize: 12)),
                ),
              TextButton(
                onPressed: () => _cancel(request),
                child: const Text(
                  'Cancelar',
                  style: TextStyle(fontSize: 12, color: Color(0xFFDC2626)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _resultCard(LabResult result) {
    final size = result.readableSize;
    final issued = result.issuedAt;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: p.accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.picture_as_pdf_outlined, color: p.accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (issued != null)
                      '${issued.day.toString().padLeft(2, '0')}/'
                          '${issued.month.toString().padLeft(2, '0')}/${issued.year}',
                    ?size,
                    if (result.emailedAt != null) 'enviado por correo',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: p.textFaint),
                ),
                if (result.notes != null && result.notes!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      result.notes!,
                      style: TextStyle(fontSize: 12, color: p.textMuted, height: 1.4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _openingId == result.id
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : IconButton(
                  onPressed: () => _open(result),
                  icon: Icon(Icons.download_rounded, color: p.accent, size: 20),
                  tooltip: 'Descargar informe',
                ),
        ],
      ),
    );
  }
}
