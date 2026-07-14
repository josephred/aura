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

  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          '¿Cancelar solicitud?',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Se descartará la solicitud pendiente de pago. Si ya pagaste, usa "Verificar pago" en su lugar.',
          style: TextStyle(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, cancelar'),
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
            'Pago pendiente',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: p.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Completa el pago en Mercado Pago para confirmar tu atención. El equipo clínico se asignará apenas se acredite.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: p.textMuted, height: 1.5),
          ),
          const SizedBox(height: 28),

          // Amount card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total a pagar',
                  style: TextStyle(fontSize: 13, color: p.textMuted),
                ),
                Text(
                  priceFormat.format(widget.request.finalPrice),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: p.accentText,
                  ),
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
              child: const Row(
                children: [
                  Icon(Icons.hourglass_top_rounded, color: Color(0xFFD97706), size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Aún no se registra el pago. Si acabas de pagar, espera unos segundos y verifica de nuevo.',
                      style: TextStyle(color: Color(0xFF92400E), fontSize: 12),
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
              onPressed: widget.state.launchPaymentCheckout,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF009EE3), // Mercado Pago blue
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text(
                'Pagar con Mercado Pago',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
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
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: p.accent,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _cancel,
            child: const Text(
              'Cancelar solicitud',
              style: TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
