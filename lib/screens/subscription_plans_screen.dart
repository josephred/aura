import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/subscription_models.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';

/// REQ-13 — Pantalla de visualización y contratación de planes de suscripción Aura.
class SubscriptionPlansScreen extends StatefulWidget {
  final AppState state;

  const SubscriptionPlansScreen({super.key, required this.state});

  @override
  State<SubscriptionPlansScreen> createState() => _SubscriptionPlansScreenState();
}

class _SubscriptionPlansScreenState extends State<SubscriptionPlansScreen> {
  AppPalette get p => context.palette;
  bool _subscribing = false;
  String? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    widget.state.fetchSubscriptionPlans();
    widget.state.fetchCurrentSubscription();
  }

  Future<void> _handleSubscribe(SubscriptionPlan plan) async {
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

    if (result != null) {
      final initPoint = result['init_point'] as String?;
      if (initPoint != null && initPoint.isNotEmpty) {
        final uri = Uri.parse(initPoint);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Suscripción activada con éxito!'),
            backgroundColor: Color(0xFF0F766E),
          ),
        );
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No fue posible procesar la suscripción. Intenta nuevamente.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _handleCancel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '¿Cancelar suscripción?',
          style: AppType.titleSmall.copyWith(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Mantendrás tus beneficios hasta el final del periodo facturado actual.',
          style: AppType.bodySmall,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Mantener plan'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar cancelación'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final success = await widget.state.cancelSubscription();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Suscripción cancelada.' : 'No se pudo cancelar.'),
          backgroundColor: success ? const Color(0xFF0F766E) : const Color(0xFFDC2626),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentSub = widget.state.subscriptionInfo;
    final plans = widget.state.subscriptionPlans;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        title: Text(
          'Planes de Suscripción Aura',
          style: AppType.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        backgroundColor: p.card,
        elevation: 0,
      ),
      body: widget.state.isLoadingSubscription && plans.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await widget.state.fetchSubscriptionPlans();
                await widget.state.fetchCurrentSubscription();
              },
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (currentSub != null && currentSub.hasSubscription)
                    _buildActiveSubscriptionBanner(currentSub)
                  else
                    _buildIntroBanner(),
                  const SizedBox(height: 20),
                  Text(
                    'Planes Disponibles',
                    style: AppType.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (plans.isEmpty)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Text(
                          'Cargando planes…',
                          style: AppType.bodySmall.copyWith(color: p.textMuted),
                        ),
                      ),
                    )
                  else
                    ...plans.map((plan) => _buildPlanCard(plan, currentSub)),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildIntroBanner() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [p.accent, const Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.workspace_premium_rounded, color: Colors.amber, size: 28),
              const SizedBox(width: 10),
              Text(
                'Beneficios Exclusivos Aura',
                style: AppType.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Suscríbete a un plan mensual y accede a consultas médicas a domicilio incluidas, descuentos en exámenes y atención prioritaria para ti y tu familia.',
            style: AppType.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.95)),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveSubscriptionBanner(UserSubscriptionInfo sub) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.accent, width: 1.5),
        boxShadow: [
          BoxFill.shadow(p.border),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_rounded, color: p.accent, size: 24),
                  const SizedBox(width: 8),
                  Text(
                    sub.plan?.name ?? 'Plan Activo',
                    style: AppType.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: p.textPrimary,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: p.accentSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Activo',
                  style: AppType.label.copyWith(
                    color: p.accentText,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Divider(color: p.border, height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  'Consultas restantes',
                  '${sub.remainingConsultations} de ${sub.includedConsultations}',
                  Icons.medical_services_outlined,
                ),
              ),
              Expanded(
                child: _buildMetricTile(
                  'Descuento en extras',
                  '${sub.discountPercentage}% OFF',
                  Icons.discount_outlined,
                ),
              ),
            ],
          ),
          if (sub.nextBillingDate != null) ...[
            const SizedBox(height: 12),
            Text(
              'Próxima renovación: ${sub.nextBillingDate!.day}/${sub.nextBillingDate!.month}/${sub.nextBillingDate!.year}',
              style: AppType.label.copyWith(color: p.textMuted),
            ),
          ],
          const SizedBox(height: 14),
          OutlinedButton(
            onPressed: _handleCancel,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFFDC2626),
              side: const BorderSide(color: Color(0xFFDC2626)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Cancelar renovación automática'),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: p.accent),
            const SizedBox(width: 4),
            Text(label, style: AppType.label.copyWith(color: p.textMuted)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppType.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: p.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildPlanCard(SubscriptionPlan plan, UserSubscriptionInfo? currentSub) {
    final isCurrent = currentSub?.hasSubscription == true && currentSub?.plan?.id == plan.id;
    final isSubscribingThis = _subscribing && _selectedPlanId == plan.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCurrent ? p.accent : p.border,
          width: isCurrent ? 2 : 1,
        ),
        boxShadow: [
          BoxFill.shadow(p.border),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  plan.name,
                  style: AppType.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: p.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: p.accentSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${plan.discountPercentage}% OFF',
                  style: AppType.label.copyWith(
                    fontWeight: FontWeight.bold,
                    color: p.accentText,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            plan.description,
            style: AppType.bodySmall.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                Money.format(plan.monthlyPrice),
                style: AppType.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                  color: p.accent,
                ),
              ),
              Text(
                ' / mes',
                style: AppType.bodySmall.copyWith(color: p.textMuted),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Divider(color: p.border, height: 1),
          const SizedBox(height: 14),
          ...plan.features.map((feature) => Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle_rounded, color: p.accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        feature,
                        style: AppType.bodySmall.copyWith(color: p.textSecondary),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: isCurrent
                ? OutlinedButton(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Plan Actual'),
                  )
                : FilledButton(
                    onPressed: _subscribing ? null : () => _handleSubscribe(plan),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.accent,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: isSubscribingThis
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Contratar Plan'),
                  ),
          ),
        ],
      ),
    );
  }
}

class BoxFill {
  static BoxShadow shadow(Color border) => BoxShadow(
        color: border.withValues(alpha: 0.25),
        blurRadius: 8,
        offset: const Offset(0, 2),
      );
}
