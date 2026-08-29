import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'aura_button.dart';
import 'aura_surface.dart';
import 'tokens.dart';

/// Estado vacío.
///
/// La auditoría encontró seis listas que, sin datos, dejaban un rótulo de
/// sección flotando sobre nada. Un vacío no es la ausencia de pantalla: es una
/// pantalla que dice qué falta y ofrece la salida.
class AuraEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  const AuraEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      container: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: AuraSpace.lg,
          vertical: compact ? AuraSpace.xl : AuraSpace.xxl,
        ),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: AuraRadius.allLg,
          border: Border.all(color: p.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: p.accentSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: AuraIcon.display - 8, color: p.accentText),
            ),
            const SizedBox(height: AuraSpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppType.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: AuraSpace.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.bodySmall.copyWith(color: p.textMuted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AuraSpace.lg),
              AuraButton.secondary(
                label: actionLabel!,
                onPressed: onAction,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Estado de error.
///
/// Responde a las tres preguntas, en este orden: qué pasó, por qué, y qué se
/// puede hacer. Sustituye a los «Error 422» y a los vacíos que en realidad eran
/// un fallo de red disfrazado de «no tienes nada».
class AuraErrorState extends StatelessWidget {
  /// Qué pasó, en lenguaje corriente. Sin códigos.
  final String title;

  /// Por qué, si se sabe.
  final String message;

  /// Cómo salir de aquí.
  final String retryLabel;
  final VoidCallback? onRetry;
  final bool compact;

  const AuraErrorState({
    super.key,
    required this.title,
    required this.message,
    this.retryLabel = 'Reintentar',
    this.onRetry,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: AuraSpace.lg,
          vertical: compact ? AuraSpace.lg : AuraSpace.xxl,
        ),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: AuraRadius.allLg,
          border: Border.all(color: p.error.withValues(alpha: 0.35)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 64,
              width: 64,
              decoration: BoxDecoration(
                color: p.errorSurface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                size: AuraIcon.xl - 4,
                color: p.onErrorSurface,
              ),
            ),
            const SizedBox(height: AuraSpace.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppType.titleSmall.copyWith(
                fontWeight: FontWeight.w700,
                color: p.textPrimary,
              ),
            ),
            const SizedBox(height: AuraSpace.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.bodySmall.copyWith(color: p.textSecondary),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AuraSpace.lg),
              AuraButton.secondary(
                label: retryLabel,
                icon: Icons.refresh_rounded,
                onPressed: onRetry,
                expand: false,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bloque gris que ocupa el sitio de un contenido que aún no llegó.
///
/// Se prefiere a una rueda centrada porque conserva la forma de la pantalla: la
/// composición no salta cuando entran los datos, y la persona ve *qué* está
/// cargando y no solo *que* algo carga.
class AuraSkeleton extends StatefulWidget {
  final double height;
  final double? width;
  final BorderRadius radius;

  const AuraSkeleton({
    super.key,
    required this.height,
    this.width,
    this.radius = AuraRadius.allXs,
  });

  /// Silueta de una tarjeta de lista completa.
  static Widget card({double height = 96}) => _SkeletonCard(height: height);

  /// Varias siluetas de tarjeta apiladas.
  static Widget list({int count = 3, double height = 96}) => Column(
    children: List.generate(
      count,
      (i) => Padding(
        padding: EdgeInsets.only(bottom: i == count - 1 ? 0 : AuraSpace.sm),
        child: _SkeletonCard(height: height),
      ),
    ),
  );

  @override
  State<AuraSkeleton> createState() => _AuraSkeletonState();
}

class _AuraSkeletonState extends State<AuraSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  @override
  void initState() {
    super.initState();
    // El latido se apaga si el sistema pide menos movimiento. Una animación
    // en bucle es exactamente lo que molesta a quien activa esa preferencia.
    if (!WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
        .disableAnimations) {
      _c.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          height: widget.height,
          width: widget.width,
          decoration: BoxDecoration(
            color: Color.lerp(p.fill, p.cardSubtle, _c.value),
            borderRadius: widget.radius,
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double height;
  const _SkeletonCard({required this.height});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: height,
      padding: const EdgeInsets.all(AuraSpace.md),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: AuraRadius.allLg,
        border: Border.all(color: p.border),
      ),
      child: Row(
        children: [
          const AuraSkeleton(height: 44, width: 44, radius: AuraRadius.allSm),
          const SizedBox(width: AuraSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AuraSkeleton(height: 14, width: 140),
                const SizedBox(height: AuraSpace.xs),
                AuraSkeleton(height: 12, width: 90),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Carga a pantalla completa, con un texto que dice qué se está esperando.
class AuraLoading extends StatelessWidget {
  final String message;
  const AuraLoading({super.key, this.message = 'Cargando…'});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      liveRegion: true,
      label: message,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 32,
              width: 32,
              child: CircularProgressIndicator(strokeWidth: 3, color: p.accent),
            ),
            const SizedBox(height: AuraSpace.md),
            Text(
              message,
              style: AppType.bodySmall.copyWith(color: p.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Confirmación de que algo salió bien.
class AuraSuccessState extends StatelessWidget {
  final String title;
  final String message;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const AuraSuccessState({
    super.key,
    required this.title,
    required this.message,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      container: true,
      liveRegion: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 88,
            width: 88,
            decoration: BoxDecoration(
              color: p.successSurface,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_rounded,
              size: AuraIcon.display,
              color: p.onSuccessSurface,
            ),
          ),
          const SizedBox(height: AuraSpace.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppType.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
              color: p.textPrimary,
            ),
          ),
          const SizedBox(height: AuraSpace.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.bodyMedium.copyWith(color: p.textSecondary),
          ),
          if (primaryLabel != null && onPrimary != null) ...[
            const SizedBox(height: AuraSpace.xl),
            AuraButton.primary(label: primaryLabel!, onPressed: onPrimary),
          ],
          if (secondaryLabel != null && onSecondary != null) ...[
            const SizedBox(height: AuraSpace.xs),
            AuraButton.tertiary(
              label: secondaryLabel!,
              onPressed: onSecondary,
              expand: true,
            ),
          ],
        ],
      ),
    );
  }
}

/// Aviso de que la app está trabajando sin conexión.
class AuraOfflineBar extends StatelessWidget {
  final VoidCallback? onRetry;
  const AuraOfflineBar({super.key, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return AuraBanner(
      tone: AuraTone.warning,
      icon: Icons.wifi_off_rounded,
      title: 'Sin conexión',
      message:
          'Guardamos lo que hagas y lo enviamos en cuanto vuelva la señal.',
      actionLabel: onRetry == null ? null : 'Reintentar',
      onAction: onRetry,
    );
  }
}
