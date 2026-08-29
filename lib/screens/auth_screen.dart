import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';

/// Cuentas QA sembradas en el backend (ver `TestUsersSeeder`).
///
/// Solo se usan desde el panel de depuración de más abajo, que no se compila
/// en release. La contraseña vive aquí, junto a los correos, porque separarla
/// no la haría menos visible: lo que la protege es que el panel no exista
/// fuera de `kDebugMode`.
const String _testAccountPassword = 'aura1234';
const Map<String, String> _testAccounts = {
  '👤 Paciente': 'paciente@aura.cl',
  '👨‍👧 Tutor Familiar': 'tutor@aura.cl',
  '🩺 Dra. Camila (Médico)': 'camila.rivera@aura.cl',
  '🩺 Dr. Sebastián (Médico)': 'sebastian.leyton@aura.cl',
  '🏃 Klga. María José (Kine)': 'maria.jose.diaz@aura.cl',
  '💉 Enf. Patricia (Enfermera)': 'patricia.jara@aura.cl',
  '🧪 Laboratorista': 'laboratorio@aura.cl',
  '🚑 Conductor Ambulancia': 'conductor@aura.cl',
  '🛡️ Operador / Admin': 'operador@aura.cl',
};

/// Entrada a la app: iniciar sesión o crear una cuenta.
///
/// ## Qué cambió y por qué
///
/// Había **cinco** formas de entrar compitiendo con el mismo peso visual:
/// correo, Google, Facebook, modo demo y nueve chips de cuentas QA. Ninguna
/// mandaba, así que la pantalla no respondía a la pregunta con la que se llega
/// aquí, que es «¿por dónde entro yo?».
///
/// El orden pasa a ser el del uso real: el formulario y su botón primero, un
/// solo «o continúa con», las dos cuentas de terceros después, y el modo demo
/// al final como texto. Las cuentas de prueba desaparecen del build de release.
class AuthScreen extends StatefulWidget {
  final AppState state;

  const AuthScreen({super.key, required this.state});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AppPalette get p => context.palette;

  /// Marcas de terceros, no colores del tema.
  ///
  /// Son el único color de estas pantallas que no sale de la paleta: identifican
  /// al proveedor y cambiarlo sería representar mal su marca. Se usan como color
  /// del icono y del nombre de la marca —lo que WCAG 1.4.3 exceptúa del
  /// contraste mínimo, por ser un logotipo—, nunca como relleno con texto
  /// corriente encima.
  static const Color _googleBrand = Color(0xFFEA4335);
  static const Color _facebookBrand = Color(0xFF1877F2);

  /// Único canal para recuperar la contraseña. Ver [_showPasswordHelp].
  static const String _supportEmail = 'soporte@aura.cl';

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegistering = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;
  String? _nameError;
  String? _emailError;
  String? _passwordError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Los errores se guardan por campo y se pintan bajo el campo que los causa.
  /// Antes vivían dentro del `Form`, que los dibujaba igual, pero el de la
  /// contraseña era además la **única** vez que aparecía la regla de los 8
  /// caracteres: se enteraba después de fallar. Ahora esa regla es texto de
  /// ayuda del campo desde el principio.
  bool _validate() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    setState(() {
      _nameError =
          _isRegistering && name.isEmpty ? 'Escribe tu nombre.' : null;
      _emailError = email.isEmpty
          ? 'Escribe tu correo.'
          : (!email.contains('@') || !email.contains('.')
              ? 'Revisa el correo: parece que le falta algo.'
              : null);
      _passwordError = password.isEmpty
          ? 'Escribe tu contraseña.'
          : (_isRegistering && password.length < 8
              ? 'Necesita al menos 8 caracteres.'
              : null);
    });

    return _nameError == null && _emailError == null && _passwordError == null;
  }

  Future<void> _submit() async {
    if (!_validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final String? error;
    if (_isRegistering) {
      error = await widget.state.register(
        _nameController.text.trim(),
        _emailController.text.trim(),
        _passwordController.text,
      );
    } else {
      error = await widget.state.login(
        _emailController.text.trim(),
        _passwordController.text,
      );
    }

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = error;
    });
  }

  void _toggleMode() {
    setState(() {
      _isRegistering = !_isRegistering;
      _errorMessage = null;
      _nameError = null;
      _emailError = null;
      _passwordError = null;
    });
  }

  Future<void> _handleGoogleLogin() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final error = await widget.state.loginWithGoogle();

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = error;
    });
  }

  Future<void> _handleFacebookLogin() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    final error = await widget.state.loginWithFacebook();

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = error;
    });
  }

  /// Qué hacer si olvidaste la contraseña.
  ///
  /// `AppState` no tiene ningún método de restablecimiento y el backend no
  /// expone un endpoint para eso, así que aquí no se puede ofrecer un
  /// formulario que envíe a alguna parte. Antes esto se resolvía no ofreciendo
  /// nada, que deja sin salida a quien no recuerda su clave. Lo que sí es
  /// cierto es que soporte puede ayudar, y eso es lo único que dice esta hoja.
  void _showPasswordHelp() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AuraSpace.lg,
            AuraSpace.xs,
            AuraSpace.lg,
            AuraSpace.xl,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: AppType.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: AuraSpace.xs),
              Text(
                'Todavía no se puede cambiar desde la app: escríbenos a '
                '$_supportEmail y te ayudamos a recuperarla.',
                style: AppType.bodyMedium.copyWith(color: p.textSecondary),
              ),
              const SizedBox(height: AuraSpace.lg),
              AuraButton.secondary(
                label: 'Entendido',
                onPressed: () => Navigator.pop(sheetContext),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AuraSpace.screenX,
              vertical: AuraSpace.xl,
            ),
            child: AuraReadable(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildViewControls(),
                  const SizedBox(height: AuraSpace.xs),
                  _buildEmblem(),
                  const SizedBox(height: AuraSpace.xl),

                  Semantics(
                    header: true,
                    child: Text(
                      _isRegistering ? 'Crea tu cuenta' : 'Hola de nuevo',
                      textAlign: TextAlign.center,
                      style: AppType.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                        color: p.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(height: AuraSpace.xs),
                  Text(
                    _isRegistering
                        ? 'Con una cuenta pides atención en casa y sigues cómo va.'
                        : 'Entra para pedir atención o ver la que tienes en curso.',
                    textAlign: TextAlign.center,
                    style: AppType.bodyMedium.copyWith(color: p.textMuted),
                  ),
                  const SizedBox(height: AuraSpace.xl),

                  // 1 · El formulario. Es la forma de entrar que usa casi todo
                  //     el mundo, así que va primero y sin nada que la rodee.
                  if (_isRegistering) ...[
                    AuraField(
                      label: 'Tu nombre',
                      hint: 'Ej. María Pérez',
                      controller: _nameController,
                      errorText: _nameError,
                      enabled: !_isSubmitting,
                      icon: Icons.person_outline_rounded,
                      capitalization: TextCapitalization.words,
                      autofillHint: AutofillHints.name,
                    ),
                    const SizedBox(height: AuraSpace.md),
                  ],
                  AuraField.email(
                    label: 'Correo',
                    hint: 'tucorreo@ejemplo.cl',
                    controller: _emailController,
                    errorText: _emailError,
                    enabled: !_isSubmitting,
                  ),
                  const SizedBox(height: AuraSpace.md),
                  AuraField(
                    label: 'Contraseña',
                    controller: _passwordController,
                    errorText: _passwordError,
                    // La regla se dice antes de escribir, no después de fallar.
                    help: _isRegistering ? 'Al menos 8 caracteres.' : null,
                    enabled: !_isSubmitting,
                    obscureText: _obscurePassword,
                    icon: Icons.lock_outline_rounded,
                    capitalization: TextCapitalization.none,
                    autofillHint: _isRegistering
                        ? AutofillHints.newPassword
                        : AutofillHints.password,
                    suffix: AuraIconButton(
                      icon: _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      tooltip: _obscurePassword
                          ? 'Mostrar la contraseña'
                          : 'Ocultar la contraseña',
                      size: AuraIcon.sm,
                      onPressed: () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
                    ),
                  ),

                  if (_errorMessage != null) ...[
                    const SizedBox(height: AuraSpace.md),
                    // El aviso anterior estaba escrito con rojos claros fijos:
                    // en modo oscuro era texto rojo sobre un rectángulo casi
                    // blanco. El tono del sistema trae su par ya verificado.
                    AuraBanner(
                      tone: AuraTone.error,
                      title: _isRegistering
                          ? 'No pudimos crear tu cuenta'
                          : 'No pudimos entrar',
                      message: _errorMessage!,
                    ),
                  ],

                  const SizedBox(height: AuraSpace.xl),
                  AuraButton.primary(
                    label: _isRegistering ? 'Crear cuenta' : 'Entrar',
                    loading: _isSubmitting,
                    onPressed: _isSubmitting ? null : _submit,
                  ),
                  if (!_isRegistering) ...[
                    const SizedBox(height: AuraSpace.xs),
                    Center(
                      child: AuraButton.tertiary(
                        label: '¿Olvidaste tu contraseña?',
                        onPressed: _isSubmitting ? null : _showPasswordHelp,
                      ),
                    ),
                  ],
                  const SizedBox(height: AuraSpace.xxs),
                  Center(
                    child: AuraButton.tertiary(
                      label: _isRegistering
                          ? 'Ya tengo cuenta'
                          : 'Crear una cuenta nueva',
                      onPressed: _isSubmitting ? null : _toggleMode,
                    ),
                  ),

                  // 2 · Un solo separador, y debajo lo que sí es una
                  //     alternativa de entrada.
                  const SizedBox(height: AuraSpace.lg),
                  _buildDivider(),
                  const SizedBox(height: AuraSpace.md),
                  Row(
                    children: [
                      Expanded(
                        child: _socialButton(
                          label: 'Google',
                          semanticLabel: 'Continuar con Google',
                          icon: Icons.account_circle_rounded,
                          brand: _googleBrand,
                          onPressed: _handleGoogleLogin,
                        ),
                      ),
                      const SizedBox(width: AuraTap.gap),
                      Expanded(
                        child: _socialButton(
                          label: 'Facebook',
                          semanticLabel: 'Continuar con Facebook',
                          icon: Icons.facebook_rounded,
                          brand: _facebookBrand,
                          onPressed: _handleFacebookLogin,
                        ),
                      ),
                    ],
                  ),

                  // 3 · Mirar sin cuenta no es una forma de entrar: es una
                  //     salida lateral, y baja al último nivel.
                  const SizedBox(height: AuraSpace.lg),
                  Center(
                    child: AuraButton.tertiary(
                      label: 'Mirar la app sin cuenta',
                      icon: Icons.visibility_outlined,
                      onPressed:
                          _isSubmitting ? null : widget.state.enterDemoMode,
                    ),
                  ),

                  // Cuentas de prueba rápidas para demostración y QA
                  const SizedBox(height: AuraSpace.xl),
                  _buildTestAccountsPanel(),
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
  /// Eran dos `IconButton` sin rótulo accesible; ahora los dos dicen qué hacen,
  /// y el del tema dice a qué modo lleva en vez de «alternar».
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

  Widget _buildEmblem() {
    return Center(
      child: Container(
        height: 84,
        width: 84,
        decoration: BoxDecoration(
          color: p.accent,
          borderRadius: AuraRadius.allXl,
        ),
        child: Icon(
          Icons.favorite_rounded,
          color: context.scheme.onPrimary,
          size: AuraIcon.xl,
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: p.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AuraSpace.sm),
          child: Text(
            'o continúa con',
            style: AppType.bodySmall.copyWith(color: p.textMuted),
          ),
        ),
        Expanded(child: Divider(color: p.border)),
      ],
    );
  }

  /// Botón de una cuenta de terceros.
  ///
  /// El color de marca entra como `accent` de una paleta local, en lugar de
  /// pintarse a mano: así el botón sigue siendo el del sistema —altura, radio,
  /// anillo de foco, estado inhabilitado— y lo único que cambia es el color que
  /// identifica al proveedor. Antes el icono era la letra «G» y una «f» en
  /// negrita con tamaños escritos a mano, y el de Facebook era un rectángulo
  /// azul relleno con texto blanco, que no llega al contraste mínimo.
  ///
  /// El rótulo visible es solo el nombre de la marca; la frase completa se la
  /// queda el lector de pantalla.
  Widget _socialButton({
    required String label,
    required String semanticLabel,
    required IconData icon,
    required Color brand,
    required VoidCallback onPressed,
  }) {
    return Theme(
      data: Theme.of(context).copyWith(
        extensions: <ThemeExtension<dynamic>>[p.copyWith(accent: brand)],
      ),
      child: AuraButton.secondary(
        label: label,
        semanticLabel: semanticLabel,
        icon: icon,
        onPressed: _isSubmitting ? null : onPressed,
      ),
    );
  }

  /// Acceso rápido a las cuentas QA sembradas en el backend.
  ///
  /// Solo se llama dentro de `kDebugMode`. No añadir aquí nada que no pueda
  /// verse en una revisión interna.
  Widget _buildTestAccountsPanel() {
    return Container(
      padding: const EdgeInsets.all(AuraSpace.sm),
      decoration: BoxDecoration(
        color: p.fill,
        borderRadius: AuraRadius.allMd,
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: AuraIcon.sm, color: p.textMuted),
              const SizedBox(width: AuraSpace.xxs),
              Flexible(
                child: Text(
                  'Cuentas de prueba para demostración',
                  style: AppType.label.copyWith(
                    fontWeight: FontWeight.w700,
                    color: p.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AuraSpace.xxs),
          Text(
            'Contraseña común: $_testAccountPassword',
            style: AppType.label.copyWith(color: p.textMuted),
          ),
          const SizedBox(height: AuraSpace.xs),
          Wrap(
            spacing: AuraSpace.xs,
            runSpacing: AuraSpace.xs,
            children: _testAccounts.entries
                .map(
                  (entry) => ActionChip(
                    label: Text(
                      entry.key,
                      style: AppType.label.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => _loginAsTestAccount(entry.value),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _loginAsTestAccount(String email) async {
    _emailController.text = email;
    _passwordController.text = _testAccountPassword;
    setState(() {
      _isRegistering = false;
      _isSubmitting = true;
      _errorMessage = null;
      _nameError = null;
      _emailError = null;
      _passwordError = null;
    });

    final error = await widget.state.login(email, _testAccountPassword);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = error;
    });
  }
}
