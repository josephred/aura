import 'package:flutter/material.dart';
import 'package:aura/theme/app_theme.dart';
import 'package:intl/intl.dart';
import '../models/service_request.dart';
import '../state/app_state.dart';

class PaymentPendingScreen extends StatefulWidget {
  final AppState state;
  final ServiceRequest request;

  const PaymentPendingScreen({
    super.key,
    required this.state,
    required this.request,
  });

  @override
  State<PaymentPendingScreen> createState() => _PaymentPendingScreenState();
}

class _PaymentPendingScreenState extends State<PaymentPendingScreen> {
  AppPalette get p => context.palette;
  bool _isVerifying = false;
  bool _showNotApprovedYet = false;

  Future<void> _verify() async {
    setState(() {
      _isVerifying = true;
      _showNotApprovedYet = false;
    });

    final approved = await widget.state.verifyPayment();

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _showNotApprovedYet = !approved;
    });
  }

  /// Human-readable name of the requested service, falling back to its id.
  String get _serviceTitle {
    for (final service in widget.state.services) {
      if (service.id == widget.request.serviceId) return service.shortTitle;
    }
    return widget.request.serviceId;
  }

  Widget _summaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: AppType.bodySmall.copyWith(color: p.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppType.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: p.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Explicit acceptance of the amount. Only from here do we hand the user
  /// over to the Mercado Pago checkout.
  Future<void> _acceptAndPay() async {
    final priceFormat = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Confirmar el monto',
          style: AppType.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Se te cobrarán ${priceFormat.format(widget.request.finalPrice)} '
          'por $_serviceTitle. Te llevaremos a Mercado Pago para completar el pago.',
          style: AppType.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Volver', style: AppType.button),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF009EE3),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Aceptar y pagar', style: AppType.button),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.state.launchPaymentCheckout();
    }
  }

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Cancelar solicitud?',
          style: AppType.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Se descartará el pedido antes de pagar y no se te cobrará nada. Si ya pagaste, usa "Verificar pago" en su lugar.',
          style: AppType.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Volver', style: AppType.button),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Sí, cancelar', style: AppType.button),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await widget.state.cancelRequest();
      widget.state.completeSimulation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final priceFormat = NumberFormat.currency(
      locale: 'es_CL',
      symbol: '\$',
      decimalDigits: 0,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          // Payment icon emblem
          Center(
            child: Container(
              height: 88,
              width: 88,
              decoration: BoxDecoration(
                color: p.accentSurface,
                shape: BoxShape.circle,
                border: Border.all(color: p.accent.withValues(alpha: 0.25), width: 6),
              ),
              child: Icon(
                Icons.account_balance_wallet_rounded,
                color: p.accentText,
                size: 40,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Confirma tu solicitud',
            textAlign: TextAlign.center,
            style: AppType.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
              color: p.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Revisa el detalle y el monto. Nada se cobra hasta que aceptes: '
            'solo al tocar "Aceptar y pagar" se abrirá Mercado Pago.',
            textAlign: TextAlign.center,
            style: AppType.bodyMedium.copyWith(color: p.textMuted, height: 1.5),
          ),
          const SizedBox(height: 28),

          // Order summary + amount
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.border),
            ),
            child: Column(
              children: [
                _summaryRow('Servicio', _serviceTitle),
                if (widget.request.addressText.isNotEmpty)
                  _summaryRow('Dirección', widget.request.addressText),
                if (widget.request.etaMinutes > 0)
                  _summaryRow(
                    'Demora estimada',
                    '~${widget.request.etaMinutes} min',
                  ),
                Divider(height: 24, color: p.border),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                      'Total a pagar',
                      style: AppType.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: p.textSecondary,
                      ),
                    ),
                    ),
                    Flexible(
                      child: Text(
                      priceFormat.format(widget.request.finalPrice),
                      style: AppType.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: p.accentText,
                      ),
                    ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          if (_showNotApprovedYet) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aún no se registra el pago. Si acabas de pagar, espera unos segundos y verifica de nuevo.',
                      style: AppType.bodySmall.copyWith(color: const Color(0xFF92400E)),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: _acceptAndPay,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF009EE3), // Mercado Pago blue
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: Text(
                'Aceptar y pagar ${priceFormat.format(widget.request.finalPrice)}',
                style: AppType.button.copyWith(fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: OutlinedButton.icon(
              onPressed: _isVerifying ? null : _verify,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: p.accent),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: _isVerifying
                  ? SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: p.accent,
                      ),
                    )
                  : Icon(Icons.verified_rounded, size: 18, color: p.accent),
              label: Text(
                _isVerifying ? 'Verificando...' : 'Ya pagué — Verificar pago',
                style: AppType.button.copyWith(
                  fontWeight: FontWeight.bold,
                  color: p.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _cancel,
            child: Text(
              'Cancelar pedido',
              style: AppType.button.copyWith(
                color: const Color(0xFFDC2626),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
