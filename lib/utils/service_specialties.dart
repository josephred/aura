/// Maps an on-demand clinical service to the professional discipline that can
/// also be booked as a scheduled appointment.
///
/// Services not listed here (ambulancia, radiología, laboratorio…) are
/// dispatch-only and don't expose a "schedule an appointment" entry point.
library;

class AppointmentSpecialty {
  final List<String> searchTerms;
  final String label;

  const AppointmentSpecialty({required this.searchTerms, required this.label});
}

const Map<String, AppointmentSpecialty> appointmentSpecialtyByService = {
  'medico': AppointmentSpecialty(
    searchTerms: ['medicina', 'medico', 'dr'],
    label: 'médico',
  ),
  'enfermeria': AppointmentSpecialty(
    searchTerms: ['enfermeria', 'enf'],
    label: 'enfermería',
  ),
  'kine_motora': AppointmentSpecialty(
    searchTerms: ['kinesiologia', 'klg'],
    label: 'kinesiología',
  ),
  'kine_respiratoria': AppointmentSpecialty(
    searchTerms: ['kinesiologia', 'klg'],
    label: 'kinesiología',
  ),
  'cuidados': AppointmentSpecialty(
    searchTerms: ['enfermeria', 'cuidados'],
    label: 'cuidados',
  ),
};

/// The specialty bookable for [serviceId], or null when the service is
/// dispatch-only.
AppointmentSpecialty? specialtyForService(String serviceId) =>
    appointmentSpecialtyByService[serviceId];
