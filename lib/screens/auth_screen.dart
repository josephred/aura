import 'package:flutter/material.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';

/// Seeded QA accounts, one per role (see `TestUsersSeeder` in the backend).
const String _testAccountPassword = 'aura1234';
const Map<String, String> _testAccounts = {
  '👤 Paciente': 'paciente@aura.cl',
  '👨‍👧 Tutor Familiar': 'tutor@aura.cl',
  '🩺 Dra. Camila (Médico)': 'camilarivera@aura.cl',
  '🩺 Dr. Sebastián (Médico)': 'sebastianleyton@aura.cl',
  '🏃 Klga. María José (Kine)': 'mariajosediaz@aura.cl',
  '💉 Enf. Patricia (Enfermera)': 'patriciajara@aura.cl',
  '🧪 Laboratorista': 'laboratorista@aura.cl',
  '🚑 Conductor Ambulancia': 'conductor@aura.cl',
  '🛡️ Operador / Admin': 'operador@aura.cl',
};

class AuthScreen extends StatefulWidget {
  final AppState state;

  const AuthScreen({super.key, required this.state});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  AppPalette get p => context.palette;
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isRegistering = false;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Accessibility & Theme controls row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: Icon(
                        widget.state.themeMode == ThemeMode.dark
                            ? Icons.light_mode_outlined
                            : Icons.dark_mode_outlined,
                        color: const Color(0xFF0F766E),
                      ),
                      tooltip: 'Alternar Tema',
                      onPressed: () {
                        final nextMode = widget.state.themeMode == ThemeMode.dark
                            ? ThemeMode.light
                            : ThemeMode.dark;
                        widget.state.setThemeMode(nextMode);
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.text_fields_rounded,
                        color: Color(0xFF0F766E),
                      ),
                      tooltip: 'Ajustar tamaño de letra',
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
                ),
                const SizedBox(height: 10),
                // Logo emblem
                Center(
                  child: Container(
                    height: 84,
                    width: 84,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF2DD4BF)],
                        begin: Alignment.bottomLeft,
                        end: Alignment.topRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F766E).withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.favorite_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  _isRegistering ? 'Crea tu cuenta' : 'Bienvenido de vuelta',
                  textAlign: TextAlign.center,
                  style: AppType.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isRegistering
                      ? 'Regístrate para solicitar atención clínica a domicilio.'
                      : 'Inicia sesión para continuar con tu atención de salud.',
                  textAlign: TextAlign.center,
                  style: AppType.bodyMedium.copyWith(color: p.textMuted),
                ),
                const SizedBox(height: 32),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (_isRegistering) ...[
                        _buildField(
                          controller: _nameController,
                          label: 'Nombre completo',
                          icon: Icons.person_outline_rounded,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Ingresa tu nombre'
                              : null,
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildField(
                        controller: _emailController,
                        label: 'Correo electrónico',
                        icon: Icons.mail_outline_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) {
                            return 'Ingresa tu correo';
                          }
                          if (!v.contains('@') || !v.contains('.')) {
                            return 'Correo inválido';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        controller: _passwordController,
                        label: 'Contraseña',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscurePassword,
                        suffix: IconButton(
                          tooltip: _obscurePassword
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: p.textFaint,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return 'Ingresa tu contraseña';
                          }
                          if (_isRegistering && v.length < 8) {
                            return 'Debe tener al menos 8 caracteres';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: Color(0xFFDC2626),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage!,
                            style: AppType.bodySmall.copyWith(
                              color: const Color(0xFFB91C1C),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0F766E),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : Text(
                            _isRegistering ? 'Crear cuenta' : 'Iniciar sesión',
                            style: AppType.button.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => setState(() {
                            _isRegistering = !_isRegistering;
                            _errorMessage = null;
                          }),
                  child: Text.rich(
                    TextSpan(
                      text: _isRegistering
                          ? '¿Ya tienes cuenta? '
                          : '¿No tienes cuenta? ',
                      style: AppType.bodyMedium.copyWith(
                        color: p.textMuted,
                      ),
                      children: [
                        TextSpan(
                          text: _isRegistering ? 'Inicia sesión' : 'Regístrate',
                          style: AppType.bodyMedium.copyWith(
                            color: const Color(0xFF0F766E),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: Divider(color: p.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        'o',
                        style: AppType.label.copyWith(
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ),
                    Expanded(child: Divider(color: p.border)),
                  ],
                ),
                const SizedBox(height: 14),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _handleGoogleLogin,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: p.card,
                      side: BorderSide(color: p.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Text(
                      'G',
                      style: TextStyle(
                        color: Color(0xFFEA4335),
                        fontWeight: FontWeight.w900,
                        fontSize: 18,
                      ),
                    ),
                    label: Text(
                      'Continuar con Google',
                      style: AppType.button.copyWith(
                        color: p.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: _isSubmitting ? null : _handleFacebookLogin,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFF1877F2),
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    icon: const Text(
                      'f',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 22,
                      ),
                    ),
                    label: Text(
                      'Continuar con Facebook',
                      style: AppType.button.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                TextButton.icon(
                  onPressed: _isSubmitting ? null : widget.state.enterDemoMode,
                  icon: Icon(
                    Icons.play_circle_outline_rounded,
                    size: 18,
                    color: p.textMuted,
                  ),
                  label: Text(
                    'Explorar en modo demo (sin cuenta)',
                    style: AppType.button.copyWith(
                      color: p.textMuted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildTestAccountsPanel(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Acceso rápido a cuentas QA sembradas en el backend (disponible para pruebas y revisiones).
  Widget _buildTestAccountsPanel() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.fill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: p.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 16, color: p.textMuted),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                'CUENTAS DE PRUEBA',
                style: AppType.label.copyWith(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: p.textMuted,
                ),
              ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Contraseña común: $_testAccountPassword',
            style: AppType.label.copyWith(color: p.textFaint),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
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
    });

    final error = await widget.state.login(email, _testAccountPassword);

    if (!mounted) return;
    setState(() {
      _isSubmitting = false;
      _errorMessage = error;
    });
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffix,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      validator: validator,
      style: AppType.bodyMedium.copyWith(color: p.textPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: AppType.bodySmall.copyWith(color: p.textFaint),
        prefixIcon: Icon(icon, color: p.textFaint, size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: p.card,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFF0F766E), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDC2626)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2),
        ),
      ),
    );
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
}
