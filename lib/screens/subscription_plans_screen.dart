import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';
import '../utils/money.dart';

/// REQ-13 — planes de Aura: qué trae cada uno, cuál tienes contratado y cómo
/// contratarlo o dejar de renovarlo.
///
/// ## Lo que estaba mal
///
/// Sin planes en la lista, la pantalla decía «Cargando planes…» **para
/// siempre**: `fetchSubscriptionPlans` se traga sus propios errores y devuelve
/// `void`, así que un fallo de red dejaba fijo un texto que prometía que algo
/// seguía ocurriendo. Ahora hay tres situaciones distinguidas —cargando, lista
/// cargada y no se pudo cargar— y la última ofrece reintentar.
///
/// Y cancelar el plan no refrescaba nada: `cancelSubscription` actualiza el
/// estado global, pero la pantalla no lo escuchaba, así que la tarjeta seguía
/// diciendo «Activo» justo después de dejarlo.
class SubscriptionPlansScreen extends StatefulWidget {
  final AppState state;

  const SubscriptionPlansScreen({super.key, required this.state});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  AppPalette get p => context.palette;

  bool _loading = true;
  bool _failed = false;
  bool _subscribing = false;
  String? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });

    try {
      await widget.state.fetchSubscriptionPlans();
      await widget.state.fetchCurrentSubscription();
    } catch (e) {
      // Los dos `fetch` se tragan hoy sus propios fallos y devuelven void; esto
      // recoge lo que se les escape (y lo que empiecen a propagar cuando dejen
      // de tragárselos).
      debugPrint('SubscriptionPlansScreen._load failed. Error: $e');
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
      // Un catálogo de planes vacío no es un estado del producto: siempre hay
      // planes que ofrecer. Si la lista llega vacía es que la carga falló, y
      // eso se dice como fallo, con su botón de reintentar, en vez de dejar a
      // la persona mirando una sección sin contenido.
      _failed = widget.state.subscriptionPlans.isEmpty;
    });
  }

  void _notify(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? p.error : null,
      ),
    );
  }

  Future<void> _handleSubscribe(SubscriptionPlan plan) async {
    final messenger = ScaffoldMessenger.of(context);
    final errorColor = p.error;

    setState(() {
      _subscribing = true;
      _selectedPlanId = plan.id;
    });

    final result = await widget.state.subscribeToPlan(plan.id);

    if (!mounted) return;

    setState(() {
      _subscribing = false;
      _selectedPlanId = null;
    });

    if (result == null) {
      _notify(
        'No pudimos contratar el plan. Revisa tu conexión e inténtalo de nuevo.',
        isError: true,
      );
      return;
    }

    final initPoint = result['init_point'] as String?;
    if (initPoint == null || initPoint.isEmpty) {
      _notify('Listo. Tu plan ya está activo.');
      return;
    }

    var opened = false;
    final uri = Uri.parse(initPoint);
    if (await canLaunchUrl(uri)) {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    }

    // Si el teléfono no podía abrir la pasarela, antes no pasaba absolutamente
    // nada: el botón dejaba de girar y la persona se quedaba en la misma
    // pantalla sin saber si había contratado el plan o no.
    if (!opened) {
      messenger.showSnackBar(
        SnackBar(
          content: const Text(
            'No pudimos abrir la página de pago. Vuelve a intentarlo en un '
            'momento.',
          ),
          backgroundColor: errorColor,
        ),
      );
    }
  }

  Future<void> _handleCancel() async {
    // Los dos botones dicen qué pasa al tocarlos. En un diálogo titulado
    // «¿Cancelar suscripción?», un botón «Cancelar» se lee igual de bien como
    // «sí» que como «no».
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('¿Dejar de renovar tu plan?'),
        content: const Text(
          'Conservas todo lo que incluye hasta que termine el mes que ya '
          'pagaste. Después deja de cobrarse y de renovarse.',
        ),
        actions: [
          AuraButton.tertiary(
            label: 'No, seguir con él',
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          const SizedBox(width: AuraSpace.xs),
          AuraButton.danger(
            label: 'Sí, dejarlo',
            expand: false,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final success = await widget.state.cancelSubscription();
    if (!mounted) return;
    _notify(
      success
          ? 'Tu plan no se renovará al terminar el mes.'
          : 'No pudimos cancelar la renovación. Inténtalo de nuevo.',
      isError: !success,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Contratar y cancelar actualizan el estado global; sin escucharlo, la
    // tarjeta de arriba seguiría mostrando el plan que la persona acaba de
    // dejar.
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) => _content(),
    );
  }

  Widget _content() {
    final currentSub = widget.state.subscriptionInfo;
    final plans = widget.state.subscriptionPlans;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: const Text('Planes de Aura')),
      body: _loading && plans.isEmpty
          ? Padding(
              padding: const EdgeInsets.fromLTRB(
                AuraSpace.screenX,
                AuraSpace.md,
                AuraSpace.screenX,
                0,
              ),
              child: AuraReadable(
                child: AuraSkeleton.list(count: 3, height: 220),
              ),
            )
          : RefreshIndicator(
              color: p.accent,
              onRefresh: _load,
              child: ListView(
                // Sin esto, tirar para refrescar no funciona justo cuando más
                // falta hace: con el error en pantalla la lista no desborda y
                // no acepta el gesto.
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AuraSpace.screenX,
                  AuraSpace.md,
                  AuraSpace.screenX,
                  AuraSpace.xxl,
                ),
                children: [
                  AuraReadable(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (currentSub != null && currentSub.hasSubscription)
                          _activePlanCard(currentSub)
                        else
                          _intro(),
                        const SizedBox(height: AuraSpace.xl),

                        if (_failed)
                          AuraErrorState(
                            title: 'No pudimos cargar los planes',
                            message:
                                'Revisa tu conexión e inténtalo de nuevo. No '
                                'se ha contratado ni cobrado nada.',
                            onRetry: _load,
                          )
                        else ...[
                          const AuraSectionHeader(title: 'Planes disponibles'),
                          for (final plan in plans) ...[
                            _planCard(plan, currentSub),
                            const SizedBox(height: AuraSpace.md),
                          ],
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  /// Portada para quien todavía no tiene plan.
  ///
  /// Era un degradado teal con un texto blanco encima. La tarjeta destacada del
  /// sistema hace el mismo trabajo con un color plano de la paleta, que sí
  /// tiene contraste comprobado en claro y en oscuro.
  Widget _intro() {
    return AuraCard(
      emphasis: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.workspace_premium_rounded,
                color: p.onBrandDeep,
                size: AuraIcon.lg,
              ),
              const SizedBox(width: AuraSpace.sm),
              Expanded(
                child: Text(
                  'Un plan mensual para toda tu familia',
                  style: AppType.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.onBrandDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.xs),
          Text(
            'Consultas médicas en casa incluidas, descuento en los exámenes y '
            'atención antes que el resto, para ti y para los tuyos.',
            style: AppType.bodySmall.copyWith(color: p.onBrandDeep),
          ),
        ],
      ),
    );
  }

  Widget _activePlanCard(UserSubscriptionInfo sub) {
    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_rounded, color: p.success, size: AuraIcon.md),
              const SizedBox(width: AuraSpace.xs),
              Expanded(
                child: Text(
                  sub.plan?.name ?? 'Tu plan',
                  style: AppType.titleSmall.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: AuraSpace.xs),
              const AuraBadge(label: 'Activo', tone: AuraTone.success),
            ],
          ),
          const SizedBox(height: AuraSpace.xs),
          const Divider(),
          AuraSummaryRow(
            icon: Icons.medical_services_outlined,
            label: 'Consultas que te quedan',
            value: '${sub.remainingConsultations} de ${sub.includedConsultations}',
            strong: true,
          ),
          AuraSummaryRow(
            icon: Icons.discount_outlined,
            label: 'Descuento en todo lo demás',
            value: '${sub.discountPercentage}%',
          ),
          if (sub.nextBillingDate != null)
            AuraSummaryRow(
              icon: Icons.event_rounded,
              label: 'Se renueva el',
              value: _dateLabel(sub.nextBillingDate!),
            ),
          const SizedBox(height: AuraSpace.md),
          AuraButton.secondary(
            label: 'Dejar de renovar el plan',
            onPressed: _handleCancel,
          ),
        ],
      ),
    );
  }

  Widget _planCard(SubscriptionPlan plan, UserSubscriptionInfo? currentSub) {
    final isCurrent =
        currentSub?.hasSubscription == true && currentSub?.plan?.id == plan.id;
    final isSubscribingThis = _subscribing && _selectedPlanId == plan.id;

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.name,
            style: AppType.titleSmall.copyWith(
              fontWeight: FontWeight.w800,
              color: p.textPrimary,
            ),
          ),
          // Un plan sin descuento anunciaba «0% OFF». Una insignia que promete
          // una rebaja de cero es peor que ninguna insignia.
          if (plan.discountPercentage > 0) ...[
            const SizedBox(height: AuraSpace.xs),
            AuraBadge(
              label: '${plan.discountPercentage}% de descuento',
              tone: AuraTone.success,
            ),
          ],
          const SizedBox(height: AuraSpace.xs),
          Text(
            plan.description,
            style: AppType.bodySmall.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: AuraSpace.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Money.format(plan.monthlyPrice),
                style: AppType.numeric.copyWith(
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
              const SizedBox(width: AuraSpace.xxs),
              Text(
                'al mes',
                style: AppType.bodySmall.copyWith(color: p.textMuted),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.sm),
          const Divider(),
          const SizedBox(height: AuraSpace.sm),
          for (final feature in plan.features)
            Padding(
              padding: const EdgeInsets.only(bottom: AuraSpace.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_rounded,
                    color: p.success,
                    size: AuraIcon.sm,
                  ),
                  const SizedBox(width: AuraSpace.xs),
                  Expanded(
                    child: Text(
                      feature,
                      style: AppType.bodySmall.copyWith(color: p.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AuraSpace.sm),

          // El plan contratado tenía aquí un botón inhabilitado que decía «Plan
          // Actual»: un no-botón con forma de botón, que invita a tocarlo para
          // averiguar que no hace nada. Es un dato, y se dice como dato.
          if (isCurrent)
            const AuraBanner(
              tone: AuraTone.success,
              message: 'Este es el plan que tienes contratado.',
            )
          else
            AuraButton(
              label: 'Contratar este plan',
              size: AuraButtonSize.medium,
              loading: isSubscribingThis,
              onPressed: _subscribing ? null : () => _handleSubscribe(plan),
            ),
        ],
      ),
    );
  }

  String _dateLabel(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}
