import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/clinical_service.dart';
import '../models/service_request.dart';
import '../services/locality_service.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../ui/aura.dart';
import '../ui/service_visuals.dart';
import '../utils/service_specialties.dart';
import '../widgets/video_onboarding_dialog.dart';
import 'book_appointment_screen.dart';
import 'operations_dashboard.dart';
import 'staff_dashboard.dart';

/// Inicio.
///
/// ## Qué se quitó y por qué
///
/// La versión anterior apilaba, antes de llegar a un solo servicio: una
/// cabecera con degradado, el logotipo, una insignia «COBERTURA ACTIVA», la
/// comuna, una campana de notificaciones que no abría nada, una insignia
/// «Atención Domiciliaria Profesional», un saludo, un buscador, tres filtros
/// («Requiere Receta (6)», «Acceso Directo (3)»), un aviso de seguridad, un
/// enlace de ayuda y un rótulo «ESPECIALIDADES DISPONIBLES». Recién ahí venían
/// nueve tarjetas en vertical, cada una con **dos** acciones distintas: tocar
/// la tarjeta pedía el servicio ahora, y un botón dentro lo agendaba.
///
/// Nada de eso respondía a la pregunta con la que se abre esta app, que es
/// siempre la misma: *necesito algo, ¿dónde lo toco?*
///
/// - **El buscador se fue.** Con nueve servicios, buscar es más trabajo que
///   mirar. Sigue existiendo dentro de «Ver todos los servicios», que es donde
///   una lista larga sí lo justifica.
/// - **Los filtros se fueron.** «Requiere Receta» es una categoría del negocio,
///   no de la persona: nadie abre la app pensando «hoy quiero algo con receta».
///   El requisito de orden médica se avisa en la tarjeta del servicio y en el
///   paso donde hay que adjuntarla.
/// - **La campana se fue.** No abría nada.
/// - **La segunda acción de cada tarjeta se fue.** Agendar con un especialista
///   es una decisión distinta de pedir atención ahora, y vive en su propio sitio
///   («Agendar con un especialista»), no duplicada nueve veces.
/// - **Nueve tarjetas pasan a seis azulejos.** Los otros tres siguen a un toque.
///
/// ## Qué manda ahora
///
/// El orden es el de la intención: quién eres → qué tienes en curso → qué
/// necesitas → qué sueles pedir. La atención activa va arriba del todo porque
/// quien tiene un profesional en camino abre la app para eso y para nada más.
class HomeScreen extends StatelessWidget {
  final AppState state;
  final ValueChanged<ClinicalService> onSelectService;

  const HomeScreen({
    super.key,
    required this.state,
    required this.onSelectService,
  });

  @override
  Widget build(BuildContext context) {
    // Los roles internos tienen su propio espacio de trabajo, con datos reales.
    if (state.currentRole == 'doctor_provider') {
      return StaffDashboard(state: state);
    } else if (state.currentRole == 'ambulance_driver') {
      return StaffDashboard(state: state, ambulanceOnly: true);
    } else if (state.currentRole == 'operator_admin') {
      return OperationsDashboard(state: state);
    }

    final p = context.palette;

    return RefreshIndicator(
      color: p.accent,
      onRefresh: () async {
        await state.fetchActiveRequest();
        await state.fetchHistory();
      },
      child: ListView(
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
                _Greeting(state: state),
                const SizedBox(height: AuraSpace.lg),

                // 1 · Lo que ya está en marcha. Si hay algo, es lo primero.
                _ActiveCareSection(state: state),

                // 2 · La pregunta y la rejilla. El corazón de la pantalla.
                Semantics(
                  header: true,
                  child: Text(
                    '¿Qué necesitas?',
                    style: AppType.titleLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: p.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: AuraSpace.md),
                _ServiceGrid(state: state, onSelectService: onSelectService),
                const SizedBox(height: AuraSpace.sm),
                _AllServicesLink(state: state, onSelectService: onSelectService),

                // 3 · Atajos: repetir lo último, agendar, ver resultados.
                const SizedBox(height: AuraSpace.xl),
                _QuickActions(state: state, onSelectService: onSelectService),

                // 4 · El aviso de riesgo vital. Va aquí y no arriba: es
                //     importante, pero no es lo que la persona vino a hacer, y
                //     arriba obligaba a leerlo antes de poder tocar nada.
                if (!state.safetyNoticeDismissed) ...[
                  const SizedBox(height: AuraSpace.xl),
                  AuraBanner(
                    tone: AuraTone.warning,
                    icon: Icons.emergency_share_rounded,
                    title: 'Si hay riesgo vital, llama a urgencias',
                    message:
                        'Aura atiende en casa casos que pueden esperar unas horas. '
                        'Ante dolor de pecho, ahogo o pérdida de conciencia, llama al 131.',
                    onDismiss: state.dismissSafetyNotice,
                  ),
                ],

                const SizedBox(height: AuraSpace.md),
                Center(
                  child: AuraButton.tertiary(
                    label: '¿Cómo funciona Aura?',
                    icon: Icons.help_outline_rounded,
                    onPressed: () => VideoOnboardingDialog.show(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- saludo

/// Saludo y comuna.
///
/// Dos líneas donde antes había una cabecera de 220 px con degradado, logotipo,
/// dos insignias y una campana. El nombre de la app no hace falta en la app: ya
/// se sabe dónde se está.
class _Greeting extends StatelessWidget {
  final AppState state;
  const _Greeting({required this.state});

  String get _timeGreeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Buenos días';
    if (h < 20) return 'Buenas tardes';
    return 'Buenas noches';
  }

  /// Solo el nombre de pila. «Buenos días, Aaron» es un saludo; «Buenos días,
  /// Aaron José Redondo Sotomayor» es una ficha de registro.
  String get _firstName {
    final n = state.userName.trim();
    if (n.isEmpty) return '';
    return n.split(RegExp(r'\s+')).first;
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            _firstName.isEmpty ? _timeGreeting : '$_timeGreeting, $_firstName',
            style: AppType.display.copyWith(
              fontWeight: FontWeight.w800,
              color: p.textPrimary,
            ),
          ),
        ),
        const SizedBox(height: AuraSpace.xxs),
        _LocalityLine(state: state),
      ],
    );
  }
}

/// Comuna detectada, en una línea tocable.
///
/// Conserva por completo la lógica anterior —resolución al montar sin pedir
/// permiso, petición solo si la persona toca, salida a los ajustes cuando ya se
/// denegó para siempre— y no inventa una comuna en ningún estado. Lo que cambia
/// es que ya no es una píldora de 12 pt compitiendo con una campana.
class _LocalityLine extends StatefulWidget {
  final AppState state;
  const _LocalityLine({required this.state});

  @override
  State<_LocalityLine> createState() => _LocalityLineState();
}

class _LocalityLineState extends State<_LocalityLine> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.state.localityStatus == LocalityStatus.idle) {
        widget.state.resolveCurrentLocality();
      }
    });
  }

  ({String label, IconData icon, bool busy}) _display() {
    final state = widget.state;
    final known = state.currentLocality;

    switch (state.localityStatus) {
      case LocalityStatus.locating:
        return known != null
            ? (label: known, icon: Icons.place_rounded, busy: true)
            : (label: 'Buscando tu comuna…', icon: Icons.place_outlined, busy: true);
      case LocalityStatus.ready:
        return (
          label: known ?? 'Elegir dónde te atendemos',
          icon: Icons.place_rounded,
          busy: false,
        );
      case LocalityStatus.serviceDisabled:
        return (label: 'Activar el GPS', icon: Icons.location_disabled_rounded, busy: false);
      case LocalityStatus.denied:
      case LocalityStatus.deniedForever:
        return known != null
            ? (label: known, icon: Icons.place_outlined, busy: false)
            : (label: 'Activar ubicación', icon: Icons.location_disabled_rounded, busy: false);
      case LocalityStatus.failed:
        return known != null
            ? (label: known, icon: Icons.place_rounded, busy: false)
            : (label: 'Reintentar ubicación', icon: Icons.refresh_rounded, busy: false);
      case LocalityStatus.idle:
        return known != null
            ? (label: known, icon: Icons.place_rounded, busy: false)
            : (label: 'Buscando tu comuna…', icon: Icons.place_outlined, busy: true);
    }
  }

  Future<void> _onTap() async {
    final state = widget.state;
    if (state.localityStatus == LocalityStatus.deniedForever) {
      await Geolocator.openAppSettings();
      return;
    }
    if (state.localityStatus == LocalityStatus.serviceDisabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    await state.resolveCurrentLocality(askPermission: true);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final d = _display();
        return Semantics(
          button: true,
          label: 'Tu ubicación: ${d.label}. Tocar para actualizar.',
          child: ExcludeSemantics(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _onTap,
                borderRadius: AuraRadius.allXs,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AuraSpace.xs,
                    horizontal: AuraSpace.xxs,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (d.busy)
                        SizedBox(
                          width: AuraIcon.sm,
                          height: AuraIcon.sm,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: p.accent,
                          ),
                        )
                      else
                        Icon(d.icon, size: AuraIcon.sm, color: p.accent),
                      const SizedBox(width: AuraSpace.xxs),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 240),
                        child: Text(
                          d.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.bodyMedium.copyWith(
                            color: p.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------- atención en curso

/// La atención que está pasando ahora.
///
/// Antes era una franja verde clara de dos líneas con un botón «Ver Mapa». Ahora
/// es la tarjeta dominante de la pantalla, en el color profundo de marca, con el
/// estado real de la solicitud —`status.label`, no una frase fija— y una sola
/// acción. Si no hay nada activo, no ocupa nada.
class _ActiveCareSection extends StatelessWidget {
  final AppState state;
  const _ActiveCareSection({required this.state});

  @override
  Widget build(BuildContext context) {
    final active = state.activeRequests
        .where((r) =>
            r.status != RequestStatus.completed &&
            r.status != RequestStatus.cancelled)
        .toList();

    if (active.isEmpty) return const SizedBox.shrink();

    final p = context.palette;
    final first = active.first;
    final service = state.services.cast<ClinicalService?>().firstWhere(
          (s) => s?.id == first.serviceId,
          orElse: () => null,
        );
    final name = serviceShortName(first.serviceId, service?.shortTitle ?? 'Tu atención');
    final needsPayment = first.status == RequestStatus.pendingPayment;

    return Padding(
      padding: const EdgeInsets.only(bottom: AuraSpace.xl),
      child: AuraCard(
        emphasis: true,
        padding: const EdgeInsets.all(AuraSpace.md),
        onTap: () => state.setTab('appointments'),
        semanticLabel:
            '$name, ${first.status.label}. Tocar para ver el seguimiento.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  height: 48,
                  width: 48,
                  decoration: BoxDecoration(
                    color: p.onBrandDeep.withValues(alpha: 0.16),
                    borderRadius: AuraRadius.allSm,
                  ),
                  child: Icon(
                    serviceIconFor(service?.iconName ?? '', serviceId: first.serviceId),
                    color: p.onBrandDeep,
                    size: AuraIcon.lg,
                  ),
                ),
                const SizedBox(width: AuraSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AppType.titleSmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: p.onBrandDeep,
                        ),
                      ),
                      const SizedBox(height: AuraSpace.xxxs),
                      Row(
                        children: [
                          // El punto no es la única señal de estado: el texto
                          // lo dice completo al lado.
                          Container(
                            height: 8,
                            width: 8,
                            decoration: BoxDecoration(
                              color: needsPayment ? p.warning : p.accent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: AuraSpace.xxs),
                          Flexible(
                            child: Text(
                              first.status.label,
                              style: AppType.bodySmall.copyWith(
                                color: p.onBrandDeep.withValues(alpha: 0.85),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AuraSpace.md),
            AuraButton(
              label: needsPayment ? 'Completar el pago' : 'Ver el seguimiento',
              kind: AuraButtonKind.primary,
              size: AuraButtonSize.medium,
              icon: Icons.arrow_forward_rounded,
              trailingIcon: true,
              onPressed: () => state.setTab('appointments'),
            ),
            if (active.length > 1) ...[
              const SizedBox(height: AuraSpace.xs),
              Text(
                'Tienes ${active.length} atenciones en curso.',
                style: AppType.bodySmall.copyWith(
                  color: p.onBrandDeep.withValues(alpha: 0.8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------- rejilla

/// Seis azulejos. Uno por lo que la gente pide.
///
/// Vertical y no en fila horizontal: una lista de nueve filas obliga a leer
/// nueve subtítulos, y una rejilla de dos columnas se recorre con la mirada. El
/// número de columnas sube a tres o cuatro en tablet y escritorio, en vez de
/// estirar dos azulejos a lo ancho de la pantalla.
class _ServiceGrid extends StatelessWidget {
  final AppState state;
  final ValueChanged<ClinicalService> onSelectService;

  const _ServiceGrid({required this.state, required this.onSelectService});

  @override
  Widget build(BuildContext context) {
    final tiles = <Widget>[];

    for (final id in homeServiceIds) {
      final service = state.services.cast<ClinicalService?>().firstWhere(
            (s) => s?.id == id,
            orElse: () => null,
          );
      if (service == null) continue;

      tiles.add(
        AuraServiceTile(
          label: serviceShortName(service.id, service.shortTitle),
          hint: serviceOneLiner(service.id, service.subtitle),
          icon: serviceIconFor(service.iconName, serviceId: service.id),
          // La ambulancia domina sin ser roja: fondo de marca profundo. Un rojo
          // de alarma en el inicio de una app de salud produce ansiedad cada vez
          // que se abre, y el traslado programado no es una urgencia vital.
          emphasis: service.id == 'ambulancia',
          onTap: () => onSelectService(service),
        ),
      );
    }

    // Telemedicina. No está en el catálogo de servicios a domicilio porque no
    // es uno: es una cita por vídeo, y por eso lleva a agendar y no al
    // formulario de despacho.
    tiles.add(
      AuraServiceTile(
        label: 'Atención online',
        hint: 'Por videollamada',
        icon: Icons.videocam_rounded,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => BookAppointmentScreen(
              state: state,
              headerTitle: 'Atención online',
            ),
          ),
        ),
      ),
    );

    final columns = AuraBreak.serviceColumns(context);

    return GridView.count(
      crossAxisCount: columns,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AuraSpace.sm,
      crossAxisSpacing: AuraSpace.sm,
      // Alto fijo por azulejo en vez de proporción: con la letra al 200 % una
      // proporción hace que el azulejo crezca a lo ancho y rompa la rejilla,
      // mientras que un alto generoso simplemente deja el texto respirar.
      childAspectRatio: _aspectFor(context, columns),
      children: tiles,
    );
  }

  double _aspectFor(BuildContext context, int columns) {
    final scale = MediaQuery.textScalerOf(context).scale(1.0);
    final base = columns >= 4 ? 1.0 : (columns == 3 ? 0.95 : 0.92);
    // Al agrandar la letra el azulejo necesita más alto, no más ancho.
    return (base / scale.clamp(1.0, 1.6)).clamp(0.52, 1.1);
  }
}

/// Acceso a la lista completa, con buscador.
///
/// Aquí sí hay buscador: es el sitio donde una lista puede ser larga y donde
/// alguien llega con el nombre de un examen escrito en una orden médica.
class _AllServicesLink extends StatelessWidget {
  final AppState state;
  final ValueChanged<ClinicalService> onSelectService;

  const _AllServicesLink({required this.state, required this.onSelectService});

  @override
  Widget build(BuildContext context) {
    final hidden = state.services.length - homeServiceIds.length;
    if (hidden <= 0) return const SizedBox.shrink();

    return Center(
      child: AuraButton.tertiary(
        label: 'Ver todos los servicios',
        icon: Icons.grid_view_rounded,
        onPressed: () => showAllServicesSheet(
          context: context,
          state: state,
          onSelectService: onSelectService,
        ),
      ),
    );
  }
}

/// Hoja con el catálogo completo y su buscador.
///
/// El buscador se limpia al abrir y al cerrar: dejar escrito «kine» de la vez
/// anterior y mostrar un catálogo de dos elementos es cómo se fabrica un
/// «faltan servicios» que no es cierto.
Future<void> showAllServicesSheet({
  required BuildContext context,
  required AppState state,
  required ValueChanged<ClinicalService> onSelectService,
}) async {
  state.setSearchQuery('');
  state.setFilterCategory('all');

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => _AllServicesSheet(
      state: state,
      onSelectService: (service) {
        Navigator.pop(sheetContext);
        onSelectService(service);
      },
    ),
  );

  state.setSearchQuery('');
}

class _AllServicesSheet extends StatefulWidget {
  final AppState state;
  final ValueChanged<ClinicalService> onSelectService;

  const _AllServicesSheet({required this.state, required this.onSelectService});

  @override
  State<_AllServicesSheet> createState() => _AllServicesSheetState();
}

class _AllServicesSheetState extends State<_AllServicesSheet> {
  final _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return ListenableBuilder(
      listenable: widget.state,
      builder: (context, _) {
        final results = widget.state.filteredServices;
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.9,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) => Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AuraSpace.lg,
                    AuraSpace.xs,
                    AuraSpace.lg,
                    AuraSpace.sm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text(
                          'Todos los servicios',
                          style: AppType.titleMedium.copyWith(
                            fontWeight: FontWeight.w800,
                            color: p.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AuraSpace.sm),
                      AuraField(
                        label: 'Buscar',
                        hint: 'Ej. radiografía, curación, electro…',
                        controller: _search,
                        icon: Icons.search_rounded,
                        capitalization: TextCapitalization.none,
                        onChanged: widget.state.setSearchQuery,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: results.isEmpty
                      ? SingleChildScrollView(
                          controller: scrollController,
                          padding: const EdgeInsets.all(AuraSpace.lg),
                          child: AuraEmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No encontramos ese servicio',
                            message:
                                'Prueba con otra palabra, o escríbenos por el chat '
                                'y te orientamos.',
                            compact: true,
                          ),
                        )
                      : ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.fromLTRB(
                            AuraSpace.lg,
                            0,
                            AuraSpace.lg,
                            AuraSpace.xxl,
                          ),
                          itemCount: results.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: AuraSpace.xs),
                          itemBuilder: (context, i) {
                            final s = results[i];
                            return AuraChoiceTile(
                              title: serviceShortName(s.id, s.shortTitle),
                              subtitle: serviceOneLiner(s.id, s.subtitle),
                              icon: serviceIconFor(s.iconName, serviceId: s.id),
                              trailingText: etaHint(s.baseEta),
                              badge: s.requiresPrescription
                                  ? const AuraBadge(
                                      label: 'Necesitas una orden médica',
                                      tone: AuraTone.warning,
                                      icon: Icons.description_outlined,
                                    )
                                  : null,
                              onTap: () => widget.onSelectService(s),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------- atajos

/// Repetir lo último, agendar, ver exámenes.
///
/// La personalización que pedía el encargo, sin construir un sistema de
/// recomendación: si ya pediste algo, lo más probable que vuelvas a pedir es
/// eso mismo. Si no has pedido nada, esta sección no aparece a medias — se
/// queda solo con lo que sí tiene sentido ofrecer.
class _QuickActions extends StatelessWidget {
  final AppState state;
  final ValueChanged<ClinicalService> onSelectService;

  const _QuickActions({required this.state, required this.onSelectService});

  @override
  Widget build(BuildContext context) {
    final last = state.pastServices.isNotEmpty ? state.pastServices.first : null;
    final lastService = last == null
        ? null
        : state.services.cast<ClinicalService?>().firstWhere(
              (s) => s?.id == last.serviceId,
              orElse: () => null,
            );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AuraSectionHeader(title: 'Accesos rápidos'),
        AuraCard(
          padding: const EdgeInsets.symmetric(
            horizontal: AuraSpace.sm,
            vertical: AuraSpace.xxs,
          ),
          child: Column(
            children: [
              if (lastService != null)
                AuraActionRow(
                  icon: Icons.replay_rounded,
                  title: 'Pedir ${serviceShortName(lastService.id, lastService.shortTitle).toLowerCase()} otra vez',
                  subtitle: 'Lo último que solicitaste',
                  onTap: () => onSelectService(lastService),
                ),
              AuraActionRow(
                icon: Icons.event_available_rounded,
                title: 'Agendar con un especialista',
                subtitle: 'Elige profesional, día y hora',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookAppointmentScreen(state: state),
                  ),
                ),
              ),
              AuraActionRow(
                icon: Icons.history_rounded,
                title: 'Mis atenciones',
                subtitle: 'Historial, exámenes y recetas',
                onTap: () => state.setTab('appointments'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Abre el agendamiento acotado a la disciplina de [service].
///
/// Se conserva del diseño anterior porque la lógica es correcta: agendar
/// «kinesiología» sin filtrar mostraría también a los médicos. Lo que cambió es
/// desde dónde se llama — ya no desde un botón repetido en cada una de las nueve
/// tarjetas del inicio.
void openSchedulingForService(
  BuildContext context,
  AppState state,
  ClinicalService service,
) {
  final specialty = specialtyForService(service.id);
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => BookAppointmentScreen(
        state: state,
        specialtyFilter: specialty?.searchTerms,
        headerTitle: specialty == null
            ? 'Agendar cita'
            : 'Agendar con ${specialty.label}',
      ),
    ),
  );
}
