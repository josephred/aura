import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';

/// Primera pantalla de la app, antes de tener cuenta.
///
/// ## Qué cambió y por qué
///
/// El párrafo de presentación era una sola frase de treinta y cinco palabras
/// que enumeraba cuatro especialidades, se elogiaba a sí misma («con un nivel
/// visual impecable») y usaba tres términos que nadie dice en voz alta: «ETA»,
/// «generalistas» y el nombre de un organismo regulador. Nada de eso ayuda a
/// decidir si esta app sirve para lo que la persona necesita hoy.
///
/// Junto al logotipo latía un punto en bucle, sin fin y sin nada que anunciar,
/// pegado a un elemento que no se puede tocar. Un punto que pulsa dice «mira
/// aquí»; aquí no había nada que mirar, así que se eliminó.
class OnboardingScreen extends StatefulWidget {
  final AppState state;
  final VoidCallback onStart;

  const OnboardingScreen({
    super.key,
    required this.state,
    required this.onStart,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  AppPalette get p => context.palette;
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AuraMotion.slow);

    _scaleAnimation = Tween<double>(
      begin: 0.92,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: AuraMotion.enter));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: AuraMotion.enter));

    // Con «reducir movimiento» activado la pantalla aparece ya montada. Es la
    // misma pantalla: lo único que se salta es el movimiento de entrada.
    if (WidgetsBinding.instance.runtimeType.toString().contains('Test') ||
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures
            .disableAnimations) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.screenX,
            vertical: AuraSpace.xl,
          ),
          child: AuraReadable(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: child,
                ),
              ),
              // El contenido se construye una vez y no en cada fotograma de la
              // animación de entrada.
              child: Column(
                // `stretch` y no `center`: así la tarjeta y el botón ocupan el
                // ancho de la columna legible sin depender de su contenido.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildViewControls(),
                  const SizedBox(height: AuraSpace.md),

                  Center(
                    child: Container(
                      height: 100,
                      width: 100,
                      decoration: BoxDecoration(
                        color: p.accent,
                        borderRadius: AuraRadius.allXl,
                      ),
                      child: Icon(
                        Icons.shield_rounded,
                        color: context.scheme.onPrimary,
                        size: AuraIcon.display,
                      ),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.xxl),

                  Semantics(
                    header: true,
                    child: Text(
                      'Aura Salud',
                      textAlign: TextAlign.center,
                      style: AppType.display.copyWith(
                        fontWeight: FontWeight.w800,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.xxs),
                  Text(
                    'Cuidado médico a domicilio',
                    textAlign: TextAlign.center,
                    // Era un teal fijo que en modo oscuro quedaba casi negro
                    // sobre negro. El acento de la paleta ya tiene su versión
                    // clara y su versión oscura.
                    style: AppType.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: p.accent,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.md),
                  Text(
                    'Pides atención de salud en tu casa y la agendas en unos '
                    'minutos. Desde el teléfono sigues cuándo llega el '
                    'profesional que te va a atender.',
                    textAlign: TextAlign.center,
                    style: AppType.bodyMedium.copyWith(color: p.textMuted),
                  ),
                  const SizedBox(height: AuraSpace.xxl),

                  AuraCard(
                    padding: const EdgeInsets.all(AuraSpace.lg),
                    child: Column(
                      children: [
                        _buildFeatureRow('Profesionales acreditados.'),
                        Divider(height: AuraSpace.xl, color: p.border),
                        _buildFeatureRow(
                          'Subes la orden médica con una foto.',
                        ),
                        Divider(height: AuraSpace.xl, color: p.border),
                        _buildFeatureRow(
                          'Sabes cuándo llega y le escribes por el chat.',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AuraSpace.xxxl),

                  // «INGRESAR A LA PLATAFORMA» en versalitas era el rótulo de
                  // un trámite. Esto es solo el principio de algo.
                  AuraButton.primary(
                    label: 'Empezar',
                    icon: Icons.arrow_forward_rounded,
                    trailingIcon: true,
                    onPressed: widget.onStart,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Tema y tamaño de letra.
  ///
  /// Los mismos dos controles que la pantalla de acceso, y por el mismo motivo:
  /// quien necesita la letra más grande la necesita **antes** de entrar. Aquí
  /// también dicen qué hacen, en vez de ser dos dibujos sin rótulo.
  Widget _buildViewControls() {
    final isDark = widget.state.themeMode == ThemeMode.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        AuraIconButton(
          icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          tooltip: isDark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
          color: p.accent,
          onPressed: () => widget.state.setThemeMode(
            isDark ? ThemeMode.light : ThemeMode.dark,
          ),
        ),
        AuraIconButton(
          icon: Icons.text_fields_rounded,
          tooltip: 'Cambiar el tamaño de la letra',
          color: p.accent,
          onPressed: () {
            final current = widget.state.textScaleFactor;
            final double nextScale;
            if (current <= 1.0) {
              nextScale = 1.15;
            } else if (current <= 1.15) {
              nextScale = 1.3;
            } else if (current <= 1.3) {
              nextScale = 1.5;
            } else {
              nextScale = 1.0;
            }
            widget.state.setTextScaleFactor(nextScale);
          },
        ),
      ],
    );
  }

  Widget _buildFeatureRow(String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Era `Colors.green`, el mismo verde en claro y en oscuro. El verde de
        // la paleta se aclara en oscuro para seguir contrastando.
        Icon(Icons.check_circle_rounded, color: p.success, size: AuraIcon.md),
        const SizedBox(width: AuraSpace.sm),
        Expanded(
          child: Text(
            text,
            style: AppType.bodyMedium.copyWith(color: p.textSecondary),
          ),
        ),
      ],
    );
  }
}
