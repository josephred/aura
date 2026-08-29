import 'package:flutter/material.dart';

import '../models/service_request.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';
import '../ui/service_visuals.dart';
import '../utils/money.dart';

/// Resultado de la última comprobación del pago.
///
/// Antes era un solo booleano y el mismo aviso ámbar servía para dos cosas que
/// no se parecen: «el pago todavía no entra» —espera unos segundos— y «no
/// pudimos preguntar» —revisa la conexión—. `verifyPayment` sigue devolviendo
/// `false` en ambos casos, porque se traga sus propios errores de red; lo que
/// esta pantalla sí puede separar es la excepción que llega hasta aquí, y el
/// día que el estado informe el fallo, el mensaje ya está escrito.
enum _VerifyOutcome { none, notYet, failed }

/// Confirmación del monto antes de ir a pagar.
///
/// ## Qué cambió y por qué
///
/// El importe se formateaba **dos veces y de dos maneras**: esta pantalla
/// construía su propio `NumberFormat` mientras el resto de la app usa
/// [Money.format]. Dos formatos para la misma cifra en el paso donde la persona
/// acepta cuánto se le va a cobrar.
///
/// Además, el botón principal abría el navegador externo sin cambiar de
/// aspecto: en un teléfono lento la única lectura posible era volver a tocarlo.
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
  bool _isLaunching = false;
  _VerifyOutcome _outcome = _VerifyOutcome.none;

  /// Nombre hablado del servicio.
  ///
  /// El respaldo ya no es el identificador interno: quien no pagó todavía no
  /// tiene por qué leer `kine_respiratoria` en la fila que dice qué está
  /// comprando.
  String get _serviceTitle {
    for (final service in widget.state.services) {
      if (service.id == widget.request.serviceId) {
        return serviceShortName(service.id, service.shortTitle);
      }
    }
    return serviceShortName(widget.request.serviceId, 'Tu atención');
  }

  String get _formattedPrice => Money.format(widget.request.finalPrice);

  Future<void> _verify() async {
    setState(() {
      _isVerifying = true;
      _outcome = _VerifyOutcome.none;
    });

    _VerifyOutcome result;
    try {
      final approved = await widget.state.verifyPayment();
      result = approved ? _VerifyOutcome.none : _VerifyOutcome.notYet;
    } catch (_) {
      result = _VerifyOutcome.failed;
    }

    if (!mounted) return;
    setState(() {
      _isVerifying = false;
      _outcome = result;
    });
  }

  /// Aceptación explícita del monto. Solo desde aquí se sale al checkout de
  /// Mercado Pago: la confirmación es deliberada y no se puede saltar.
  Future<void> _acceptAndPay() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirma el monto'),
        content: Text(
          'Se te cobrarán $_formattedPrice por $_serviceTitle. '
          'Te llevamos a Mercado Pago para completar el pago.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Aceptar y pagar'),
          ),
        ],
      ),
    );

    if (!mounted || confirmed != true) return;

    // Abrir el navegador externo tarda, y sin este estado el botón se quedaba
    // idéntico mientras tanto. Dos toques seguidos abrían dos checkouts para el
    // mismo pedido.
    setState(() => _isLaunching = true);
    try {
      await widget.state.launchPaymentCheckout();
    } finally {
      if (mounted) setState(() => _isLaunching = false);
    }
  }

  /// Cancelar descarta el pedido y no se puede deshacer, así que pregunta
  /// primero. La limpieza local (`completeSimulation`) va detrás de
  /// `cancelRequest` porque esta pantalla deja de tener pedido que mostrar en
  /// cualquiera de los dos casos.
  Future<void> _cancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar el pedido?'),
        content: const Text(
          'Se descarta antes de pagar y no se te cobra nada. Si ya pagaste, '
          'cierra esto y comprueba el pago.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: p.error,
              foregroundColor: context.scheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await widget.state.cancelRequest();
    widget.state.completeSimulation();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.screenX,
        AuraSpace.xl,
        AuraSpace.screenX,
        AuraSpace.navClearance,
      ),
      child: AuraReadable(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                height: 88,
                width: 88,
                decoration: BoxDecoration(
                  color: p.accentSurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet_rounded,
                  color: p.accentText,
                  size: AuraIcon.display - 8,
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.lg),
            Semantics(
              header: true,
              child: Text(
                'Confirma tu solicitud',
                textAlign: TextAlign.center,
                style: AppType.titleLarge.copyWith(
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.xs),
            // Este párrafo citaba el rótulo del botón palabra por palabra, así
            // que cambiar el botón dejaba el texto mintiendo. Ahora dice lo que
            // pasa, no cómo se llama la acción.
            Text(
              'Revisa el detalle y el monto. No se cobra nada hasta que lo '
              'aceptes, y el pago se hace en Mercado Pago.',
              textAlign: TextAlign.center,
              style: AppType.bodyMedium.copyWith(color: p.textMuted),
            ),
            const SizedBox(height: AuraSpace.xl),

            AuraCard(
              padding: const EdgeInsets.all(AuraSpace.lg),
              child: Column(
                children: [
                  AuraSummaryRow(label: 'Servicio', value: _serviceTitle),
                  if (widget.request.addressText.isNotEmpty)
                    AuraSummaryRow(
                      label: 'Dirección',
                      value: widget.request.addressText,
                    ),
                  if (widget.request.etaMinutes > 0)
                    AuraSummaryRow(
                      label: 'Llegada estimada',
                      value: 'Unos ${widget.request.etaMinutes} min',
                    ),
                  Divider(height: AuraSpace.xl, color: p.border),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          'Total a pagar',
                          style: AppType.bodyMedium.copyWith(
                            fontWeight: FontWeight.w700,
                            color: p.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AuraSpace.sm),
                      Flexible(
                        child: Text(
                          _formattedPrice,
                          textAlign: TextAlign.end,
                          style: AppType.numeric.copyWith(
                            fontWeight: FontWeight.w800,
                            color: p.accentText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            if (_outcome == _VerifyOutcome.notYet) ...[
              const SizedBox(height: AuraSpace.md),
              const AuraBanner(
                tone: AuraTone.warning,
                icon: Icons.hourglass_top_rounded,
                title: 'Todavía no nos llega el pago',
                message:
                    'Si acabas de pagar, espera unos segundos y comprueba otra vez.',
              ),
            ],
            if (_outcome == _VerifyOutcome.failed) ...[
              const SizedBox(height: AuraSpace.md),
              AuraBanner(
                tone: AuraTone.error,
                title: 'No pudimos comprobar el pago',
                message:
                    'No es lo mismo que no haber pagado: no logramos preguntarlo. '
                    'Revisa tu conexión e inténtalo de nuevo.',
                actionLabel: 'Reintentar',
                onAction: _isVerifying ? null : _verify,
              ),
            ],

            const SizedBox(height: AuraSpace.xl),
            AuraButton.primary(
              label: 'Aceptar y pagar $_formattedPrice',
              icon: Icons.open_in_new_rounded,
              loading: _isLaunching,
              onPressed: _isLaunching ? null : _acceptAndPay,
            ),
            const SizedBox(height: AuraSpace.sm),
            // Dos ideas en un rótulo —«Ya pagué — Verificar pago»— con un icono
            // dentro de 52 px: en un teléfono estrecho se partía en dos líneas.
            // Lo que la persona quiere decir al tocar es solo lo primero.
            AuraButton.secondary(
              label: 'Ya pagué',
              icon: Icons.verified_rounded,
              loading: _isVerifying,
              onPressed: _isVerifying ? null : _verify,
            ),
            const SizedBox(height: AuraSpace.xs),
            // Salida en el nivel más bajo, y sin rojo: el rojo se reserva para
            // el botón que confirma dentro del diálogo, que es donde el pedido
            // se descarta de verdad.
            Center(
              child: AuraButton.tertiary(
                label: 'Cancelar el pedido',
                onPressed: _isLaunching ? null : _cancel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
