import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/dependent.dart';
import '../models/saved_address.dart';
import '../models/saved_payment_method.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';
import '../widgets/video_onboarding_dialog.dart';
import 'preventive_health_screen.dart';
import 'subscription_plans_screen.dart';

/// Perfil.
///
/// ## Lo que estaba mal
///
/// El **simulador de roles** era el segundo bloque de la página, por encima de
/// los datos de la propia persona: una banda oscura titulada «Simulador de
/// Roles del Ecosistema Aura» con cinco tarjetas —«3. Profesional / Prestador»,
/// «4. Operador / Administrador»— que cambian por completo lo que la app
/// enseña. Es una herramienta de pruebas, y estaba a un toque de cualquier
/// paciente. Ahora solo existe en compilaciones de depuración.
///
/// Las **tres listas** (familiares, direcciones, medios de pago) eran tres
/// formularios plegables en la misma página, con sus campos, sus botones de
/// guardar y sus filas de edición y borrado, todo a la vez. Cada una pasa a su
/// propia pantalla: la página principal enseña cuántos hay y se entra a
/// gestionarlos.
///
/// Y faltaba lo básico: **ningún estado vacío** (una persona nueva veía tres
/// encabezados sobre la nada), **ninguna confirmación al borrar** —tocar la
/// papelera junto a un familiar lo eliminaba sin preguntar— y **ningún aviso
/// cuando guardar fallaba**, porque los formularios hacían `return` en silencio
/// con el campo vacío.
class ProfileScreen extends StatelessWidget {
  final AppState state;
  const ProfileScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AuraSpace.screenX,
        AuraSpace.md,
        AuraSpace.screenX,
        AuraSpace.navClearance,
      ),
      children: [
        AuraReadable(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _identity(context),
              const SizedBox(height: AuraSpace.xl),

              const AuraSectionHeader(title: 'Tus datos'),
              AuraCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.sm,
                  vertical: AuraSpace.xxs,
                ),
                child: Column(
                  children: [
                    AuraActionRow(
                      icon: Icons.family_restroom_rounded,
                      title: 'Familiares',
                      subtitle: _countLabel(
                        state.dependents.length,
                        'persona guardada',
                        'personas guardadas',
                      ),
                      onTap: () => _open(context, const _Section.dependents()),
                    ),
                    AuraActionRow(
                      icon: Icons.place_rounded,
                      title: 'Direcciones',
                      subtitle: _countLabel(
                        state.addresses.length,
                        'dirección guardada',
                        'direcciones guardadas',
                      ),
                      onTap: () => _open(context, const _Section.addresses()),
                    ),
                    AuraActionRow(
                      icon: Icons.credit_card_rounded,
                      title: 'Formas de pago',
                      subtitle: _countLabel(
                        state.paymentMethods.length,
                        'medio guardado',
                        'medios guardados',
                      ),
                      onTap: () => _open(context, const _Section.payments()),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AuraSpace.xl),
              const AuraSectionHeader(title: 'Cómo se ve la app'),
              _accessibilityCard(context),

              const SizedBox(height: AuraSpace.xl),
              const AuraSectionHeader(title: 'Más'),
              AuraCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AuraSpace.sm,
                  vertical: AuraSpace.xxs,
                ),
                child: Column(
                  children: [
                    AuraActionRow(
                      icon: Icons.workspace_premium_rounded,
                      title: 'Planes de Aura',
                      subtitle: state.hasActiveSubscription
                          ? 'Tienes un plan activo'
                          : 'Ahorra en atenciones frecuentes',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SubscriptionPlansScreen(state: state),
                        ),
                      ),
                    ),
                    AuraActionRow(
                      icon: Icons.favorite_rounded,
                      title: 'Salud preventiva',
                      subtitle: 'Controles según tu edad',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PreventiveHealthScreen(state: state),
                        ),
                      ),
                    ),
                    AuraActionRow(
                      icon: Icons.help_outline_rounded,
                      title: 'Cómo funciona Aura',
                      subtitle: 'Guía de primeros pasos',
                      onTap: () => VideoOnboardingDialog.show(context),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AuraSpace.xl),
              AuraButton.secondary(
                label: state.isDemoMode ? 'Salir del modo demo' : 'Cerrar sesión',
                icon: Icons.logout_rounded,
                onPressed: () => _confirmLogout(context),
              ),

              // Solo en depuración. Ver la nota de clase: cambia lo que la app
              // enseña por completo y no es una función del producto.
              if (kDebugMode) ...[
                const SizedBox(height: AuraSpace.xxl),
                _RoleSimulator(state: state),
              ],

              const SizedBox(height: AuraSpace.lg),
              Center(
                child: Text(
                  'Aura Salud',
                  style: AppType.label.copyWith(color: p.textMuted),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _countLabel(int n, String one, String many) =>
      n == 0 ? 'Aún no has guardado ninguna' : '$n ${n == 1 ? one : many}';

  void _open(BuildContext context, _Section section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _ManagedListScreen(state: state, section: section),
      ),
    );
  }

  Widget _identity(BuildContext context) {
    final p = context.palette;
    final name = state.userName.trim();
    final email = state.userEmail.trim();

    return Row(
      children: [
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: p.accentSurface,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              name.isEmpty ? '?' : name[0].toUpperCase(),
              style: AppType.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: p.accentText,
              ),
            ),
          ),
        ),
        const SizedBox(width: AuraSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(
                  name.isEmpty ? 'Tu perfil' : name,
                  style: AppType.titleLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    color: p.textPrimary,
                  ),
                ),
              ),
              if (email.isNotEmpty) ...[
                const SizedBox(height: AuraSpace.xxxs),
                Text(
                  email,
                  style: AppType.bodySmall.copyWith(color: p.textMuted),
                ),
              ],
              if (state.hasActiveSubscription &&
                  state.subscriptionInfo?.plan != null) ...[
                const SizedBox(height: AuraSpace.xs),
                AuraBadge(
                  label: state.subscriptionInfo!.plan!.name,
                  tone: AuraTone.success,
                  icon: Icons.workspace_premium_rounded,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Tamaño de letra y tema.
  ///
  /// Los dos ajustes que más importan a este público van juntos y en la página
  /// principal, no escondidos al fondo de un scroll de mil líneas.
  Widget _accessibilityCard(BuildContext context) {
    final p = context.palette;
    const steps = [
      (value: 1.0, label: 'Normal'),
      (value: 1.15, label: 'Grande'),
      (value: 1.3, label: 'Más grande'),
      (value: 1.5, label: 'Máximo'),
    ];
    final current = steps
        .map((s) => s.value)
        .reduce((a, b) => (a - state.textScaleFactor).abs() <
                (b - state.textScaleFactor).abs()
            ? a
            : b);

    return AuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AuraOptionGroup<double>(
            label: 'Tamaño del texto',
            selected: current,
            onSelect: state.setTextScaleFactor,
            options: steps
                .map((s) => (
                      value: s.value,
                      label: s.label,
                      icon: null as IconData?,
                    ))
                .toList(),
          ),
          const SizedBox(height: AuraSpace.lg),
          AuraOptionGroup<ThemeMode>(
            label: 'Apariencia',
            selected: state.themeMode,
            onSelect: state.setThemeMode,
            options: const [
              (value: ThemeMode.light, label: 'Clara', icon: Icons.light_mode_rounded),
              (value: ThemeMode.dark, label: 'Oscura', icon: Icons.dark_mode_rounded),
              (value: ThemeMode.system, label: 'Como el teléfono', icon: Icons.brightness_auto_rounded),
            ],
          ),
          if (state.safetyNoticeDismissed) ...[
            const SizedBox(height: AuraSpace.lg),
            Divider(color: p.border),
            const SizedBox(height: AuraSpace.xs),
            AuraButton.tertiary(
              label: 'Volver a mostrar el aviso de urgencias',
              icon: Icons.visibility_rounded,
              onPressed: state.restoreSafetyNotice,
              expand: true,
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final p = context.palette;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          state.isDemoMode ? '¿Salir del modo demo?' : '¿Cerrar sesión?',
        ),
        content: Text(
          state.isDemoMode
              ? 'Se borrarán los datos de prueba de este dispositivo.'
              : 'Tendrás que volver a escribir tu correo y contraseña para entrar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, quedarme'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: p.error),
            child: Text(state.isDemoMode ? 'Sí, salir' : 'Sí, cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmed == true) await state.logout();
  }
}

// ================================================================== secciones

/// Qué lista gestiona [_ManagedListScreen].
///
/// Las tres listas se comportan igual —ver, añadir, editar, borrar— así que
/// comparten pantalla en vez de tener tres copias del mismo código, que es lo
/// que había.
class _Section {
  final String kind;
  const _Section.dependents() : kind = 'dependents';
  const _Section.addresses() : kind = 'addresses';
  const _Section.payments() : kind = 'payments';

  String get title => switch (kind) {
    'dependents' => 'Familiares',
    'addresses' => 'Direcciones',
    _ => 'Formas de pago',
  };

  String get addLabel => switch (kind) {
    'dependents' => 'Añadir un familiar',
    'addresses' => 'Añadir una dirección',
    _ => 'Añadir una forma de pago',
  };

  IconData get icon => switch (kind) {
    'dependents' => Icons.family_restroom_rounded,
    'addresses' => Icons.place_rounded,
    _ => Icons.credit_card_rounded,
  };

  String get emptyTitle => switch (kind) {
    'dependents' => 'Aún no has guardado a nadie',
    'addresses' => 'Aún no tienes direcciones',
    _ => 'Aún no tienes formas de pago',
  };

  String get emptyMessage => switch (kind) {
    'dependents' =>
      'Guarda a la persona una vez y no tendrás que volver a escribir sus datos '
          'cada vez que pidas una atención para ella.',
    'addresses' =>
      'Guarda tu casa o la de un familiar y podrás elegirla con un toque.',
    _ => 'Guarda una tarjeta para pagar más rápido.',
  };
}

class _ManagedListScreen extends StatefulWidget {
  final AppState state;
  final _Section section;

  const _ManagedListScreen({required this.state, required this.section});

  @override
  State<_ManagedListScreen> createState() => _ManagedListScreenState();
}

class _ManagedListScreenState extends State<_ManagedListScreen> {
  AppPalette get p => context.palette;

  @override
  void initState() {
    super.initState();
    widget.state.addListener(_onChange);
  }

  @override
  void dispose() {
    widget.state.removeListener(_onChange);
    super.dispose();
  }

  void _onChange() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final section = widget.section;
    final items = _items();

    return Scaffold(
      appBar: AppBar(title: Text(section.title)),
      body: SafeArea(
        child: ListView(
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
                  if (items.isEmpty)
                    AuraEmptyState(
                      icon: section.icon,
                      title: section.emptyTitle,
                      message: section.emptyMessage,
                      actionLabel: section.addLabel,
                      onAction: () => _openEditor(null),
                    )
                  else ...[
                    ...items,
                    const SizedBox(height: AuraSpace.md),
                    AuraButton.secondary(
                      label: section.addLabel,
                      icon: Icons.add_rounded,
                      onPressed: () => _openEditor(null),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _items() {
    switch (widget.section.kind) {
      case 'dependents':
        return widget.state.dependents
            .map(
              (d) => _row(
                title: d.name,
                subtitle: '${d.relationship} · ${d.age} años'
                    '${d.healthInsurance.isEmpty ? "" : " · ${d.healthInsurance}"}',
                onEdit: () => _openEditor(d),
                onDelete: () => _confirmDelete(
                  d.name,
                  () => widget.state.deleteDependent(d.id),
                ),
              ),
            )
            .toList();

      case 'addresses':
        return widget.state.addresses
            .map(
              (a) => _row(
                title: a.label,
                subtitle: a.text,
                onEdit: () => _openEditor(a),
                onDelete: () => _confirmDelete(
                  a.label,
                  () => widget.state.deleteAddress(a.id),
                ),
              ),
            )
            .toList();

      default:
        return widget.state.paymentMethods
            .map(
              (m) => _row(
                title: switch (m.type) {
                  'mercadopago' => 'Mercado Pago',
                  'visa' => 'Visa',
                  'mastercard' => 'Mastercard',
                  _ => m.type,
                },
                subtitle: m.last4 == null || m.last4!.isEmpty
                    ? 'Cuenta vinculada'
                    : 'Termina en ${m.last4}',
                // Los medios de pago no se editan: se borran y se vuelven a
                // añadir. `AppState` nunca tuvo `updatePaymentMethod`, y el
                // lápiz de antes abría un formulario que creaba uno nuevo.
                onEdit: null,
                onDelete: () => _confirmDelete(
                  'esta forma de pago',
                  () => widget.state.deletePaymentMethod(m.id),
                ),
              ),
            )
            .toList();
    }
  }

  Widget _row({
    required String title,
    required String subtitle,
    required VoidCallback? onEdit,
    required VoidCallback onDelete,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.sm),
      child: AuraCard(
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppType.bodyLarge.copyWith(
                      fontWeight: FontWeight.w700,
                      color: p.textPrimary,
                    ),
                  ),
                  const SizedBox(height: AuraSpace.xxxs),
                  Text(
                    subtitle,
                    style: AppType.bodySmall.copyWith(color: p.textMuted),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              AuraIconButton(
                icon: Icons.edit_rounded,
                tooltip: 'Editar $title',
                onPressed: onEdit,
                color: p.accent,
              ),
            AuraIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Eliminar $title',
              onPressed: onDelete,
              color: p.error,
            ),
          ],
        ),
      ),
    );
  }

  /// Borrar pregunta antes.
  ///
  /// Antes no lo hacía: `onPressed: () => state.deleteDependent(...)` a secas.
  /// Junto a un botón de editar de 28 px, en una app cuyo público declarado
  /// falla el toque con frecuencia.
  Future<void> _confirmDelete(String what, Future<void> Function() run) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('¿Eliminar $what?'),
        content: const Text('Puedes volver a añadirlo cuando quieras.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No, conservarlo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: p.error),
            child: const Text('Sí, eliminar'),
          ),
        ],
      ),
    );
    if (confirmed == true) await run();
  }

  Future<void> _openEditor(Object? existing) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EditorSheet(
        state: widget.state,
        section: widget.section,
        existing: existing,
      ),
    );
  }
}

// =================================================================== editor

/// El formulario de alta y edición, en una hoja.
///
/// Un campo, una pregunta, rótulo siempre visible y teclado adecuado. Y valida:
/// los formularios anteriores hacían `return` en silencio cuando el nombre
/// estaba vacío, así que tocar «Guardar» no hacía absolutamente nada y no había
/// forma de saber por qué.
class _EditorSheet extends StatefulWidget {
  final AppState state;
  final _Section section;
  final Object? existing;

  const _EditorSheet({
    required this.state,
    required this.section,
    required this.existing,
  });

  @override
  State<_EditorSheet> createState() => _EditorSheetState();
}

class _EditorSheetState extends State<_EditorSheet> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  final _c = TextEditingController();
  final _d = TextEditingController();

  String _relationship = 'Madre';
  String _paymentType = 'visa';
  String? _errorA;
  String? _errorB;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e is Dependent) {
      _a.text = e.name;
      _b.text = e.age.toString();
      _c.text = e.healthInsurance;
      _d.text = e.medicalConditions;
      _relationship = e.relationship.isEmpty ? 'Madre' : e.relationship;
    } else if (e is SavedAddress) {
      _a.text = e.label;
      _b.text = e.text;
    } else if (e is SavedPaymentMethod) {
      _paymentType = e.type;
      _a.text = e.last4 ?? '';
    }
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    _c.dispose();
    _d.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isEdit = widget.existing != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AuraSpace.lg,
          AuraSpace.xs,
          AuraSpace.lg,
          AuraSpace.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text(
                isEdit ? 'Editar' : widget.section.addLabel,
                style: AppType.titleMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: p.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: AuraSpace.lg),
            ..._fields(),
            const SizedBox(height: AuraSpace.xl),
            AuraButton.primary(
              label: 'Guardar',
              loading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _fields() {
    switch (widget.section.kind) {
      case 'dependents':
        return [
          AuraField(
            label: 'Nombre y apellido',
            hint: 'Ej. Margarita Sotomayor',
            controller: _a,
            errorText: _errorA,
            autofocus: true,
            capitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _errorA = null),
          ),
          const SizedBox(height: AuraSpace.lg),
          AuraOptionGroup<String>(
            label: 'Qué es de ti',
            selected: _relationship,
            onSelect: (v) => setState(() => _relationship = v),
            options: const [
              (value: 'Madre', label: 'Madre', icon: null),
              (value: 'Padre', label: 'Padre', icon: null),
              (value: 'Hijo', label: 'Hijo o hija', icon: null),
              (value: 'Cónyuge', label: 'Pareja', icon: null),
              (value: 'Otro', label: 'Otro', icon: null),
            ],
          ),
          const SizedBox(height: AuraSpace.lg),
          AuraField.number(
            label: 'Edad',
            hint: 'En años',
            controller: _b,
            maxLength: 3,
            errorText: _errorB,
          ),
          const SizedBox(height: AuraSpace.lg),
          // Sin valor por defecto. Antes venía relleno con «Isapre Colmena»,
          // que se guardaba tal cual si nadie lo tocaba: un dato de seguro
          // médico inventado en la ficha de un paciente.
          AuraField(
            label: 'Previsión de salud (opcional)',
            hint: 'Ej. Fonasa B, Isapre Consalud',
            controller: _c,
          ),
          const SizedBox(height: AuraSpace.lg),
          AuraField.multiline(
            label: 'Algo que el profesional deba saber (opcional)',
            hint: 'Ej. es alérgica a la penicilina',
            controller: _d,
            maxLines: 3,
          ),
        ];

      case 'addresses':
        return [
          AuraField(
            label: 'Cómo quieres llamarla',
            hint: 'Ej. Mi casa, Casa de mamá',
            controller: _a,
            errorText: _errorA,
            autofocus: true,
            capitalization: TextCapitalization.words,
            onChanged: (_) => setState(() => _errorA = null),
          ),
          const SizedBox(height: AuraSpace.lg),
          AuraField(
            label: 'Dirección',
            hint: 'Calle, número, depto y comuna',
            controller: _b,
            errorText: _errorB,
            onChanged: (_) => setState(() => _errorB = null),
          ),
        ];

      default:
        return [
          AuraOptionGroup<String>(
            label: 'Tipo',
            selected: _paymentType,
            onSelect: (v) => setState(() => _paymentType = v),
            options: const [
              (value: 'visa', label: 'Visa', icon: Icons.credit_card_rounded),
              (value: 'mastercard', label: 'Mastercard', icon: Icons.credit_card_rounded),
              (value: 'mercadopago', label: 'Mercado Pago', icon: Icons.account_balance_wallet_rounded),
            ],
          ),
          if (_paymentType != 'mercadopago') ...[
            const SizedBox(height: AuraSpace.lg),
            AuraField.number(
              label: 'Últimos 4 dígitos',
              hint: '1234',
              controller: _a,
              maxLength: 4,
              errorText: _errorA,
            ),
          ],
        ];
    }
  }

  Future<void> _save() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    setState(() {
      _saving = true;
      _errorA = null;
      _errorB = null;
    });

    switch (widget.section.kind) {
      case 'dependents':
        final name = _a.text.trim();
        final age = int.tryParse(_b.text.trim());
        if (name.isEmpty) {
          setState(() {
            _saving = false;
            _errorA = 'Escribe el nombre de la persona.';
          });
          return;
        }
        if (age == null || age <= 0 || age > 120) {
          setState(() {
            _saving = false;
            _errorB = 'Escribe una edad entre 1 y 120.';
          });
          return;
        }
        final existing = widget.existing;
        final dep = Dependent(
          id: existing is Dependent ? existing.id : 'dep_$now',
          name: name,
          relationship: _relationship,
          age: age,
          healthInsurance: _c.text.trim(),
          medicalConditions: _d.text.trim(),
        );
        if (existing is Dependent) {
          await widget.state.updateDependent(dep);
        } else {
          await widget.state.addDependent(dep);
        }

      case 'addresses':
        final label = _a.text.trim();
        final text = _b.text.trim();
        if (label.isEmpty) {
          setState(() {
            _saving = false;
            _errorA = 'Ponle un nombre para reconocerla.';
          });
          return;
        }
        if (text.isEmpty) {
          setState(() {
            _saving = false;
            _errorB = 'Escribe la dirección completa.';
          });
          return;
        }
        final existing = widget.existing;
        final addr = SavedAddress(
          id: existing is SavedAddress ? existing.id : 'addr_$now',
          label: label,
          text: text,
        );
        if (existing is SavedAddress) {
          await widget.state.updateAddress(addr);
        } else {
          await widget.state.addAddress(addr);
        }

      default:
        final last4 = _a.text.trim();
        if (_paymentType != 'mercadopago' && last4.length != 4) {
          setState(() {
            _saving = false;
            _errorA = 'Escribe los 4 últimos dígitos de la tarjeta.';
          });
          return;
        }
        await widget.state.addPaymentMethod(
          SavedPaymentMethod(
            id: 'pay_$now',
            type: _paymentType,
            last4: _paymentType == 'mercadopago' ? null : last4,
          ),
        );
    }

    if (mounted) Navigator.pop(context);
  }
}

// ================================================== simulador (solo depuración)

/// Cambia el rol activo para poder recorrer la app como profesional, operador
/// o conductor sin tener cinco cuentas.
///
/// Solo se monta bajo `kDebugMode`. En una compilación de producción este
/// widget no aparece en ninguna parte.
class _RoleSimulator extends StatelessWidget {
  final AppState state;
  const _RoleSimulator({required this.state});

  static const _labels = {
    'patient': 'Paciente',
    'dependent_tutor': 'Familiar / Tutor',
    'doctor_provider': 'Profesional',
    'operator_admin': 'Operador',
    'ambulance_driver': 'Conductor',
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuraSectionHeader(title: 'Simulador de roles (depuración)'),
        AuraCard(
          outlined: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                state.serverAssignedRole == null
                    ? 'Esta cuenta no tiene rol asignado en el servidor.'
                    : 'Rol real de la cuenta: '
                        '${_labels[state.serverAssignedRole] ?? state.serverAssignedRole}',
                style: AppType.bodySmall.copyWith(color: p.textMuted),
              ),
              const SizedBox(height: AuraSpace.sm),
              AuraOptionGroup<String>(
                selected: state.currentRole,
                onSelect: state.setRole,
                options: AppState.knownRoles
                    .map((r) => (
                          value: r,
                          label: _labels[r] ?? r,
                          icon: null as IconData?,
                        ))
                    .toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
