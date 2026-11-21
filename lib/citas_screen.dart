import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:material_ui/material_ui.dart';

import 'services/appointment_notification_service.dart';

/// Gestión de citas privadas del usuario autenticado.
class CitasScreen extends StatelessWidget {
  const CitasScreen({super.key});

  CollectionReference<Map<String, dynamic>> get _citas => FirebaseFirestore
      .instance
      .collection('usuarios')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .collection('citas');

  Future<void> _abrirFormulario(
    BuildContext context, {
    QueryDocumentSnapshot<Map<String, dynamic>>? cita,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _CitaDialog(citas: _citas, cita: cita),
    );
  }

  Future<void> _cancelar(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> cita,
  ) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Cancelar cita', style: TextStyle(fontSize: 24)),
        content: const Text(
          '¿Deseas cancelar esta cita médica?',
          style: TextStyle(fontSize: 19),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Volver', style: TextStyle(fontSize: 18)),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Sí, cancelar', style: TextStyle(fontSize: 18)),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    try {
      await _citas.doc(cita.id).update({
        'estado': 'cancelada',
        'actualizadaEn': FieldValue.serverTimestamp(),
      });
      final reminderCanceled = await AppointmentNotificationService.instance
          .cancelForAppointment(cita.id);
      if (context.mounted) {
        _mensaje(
          context,
          reminderCanceled ? 'La cita fue cancelada.' : 'La cita fue cancelada, pero no se pudo confirmar la cancelación del recordatorio.',
        );
      }
    } catch (_) {
      if (context.mounted) {
        _mensaje(context, 'No se pudo cancelar la cita. Inténtalo de nuevo.');
      }
    }
  }

  void _mensaje(BuildContext context, String texto) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(texto, style: const TextStyle(fontSize: 17))),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mis citas',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout, size: 28),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _citas.orderBy('fechaHora').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _EstadoCitas(
                icon: Icons.cloud_off,
                texto: 'No pudimos cargar tus citas. Revisa tu conexión e inténtalo de nuevo.',
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final citas = snapshot.data?.docs ?? [];
            if (citas.isEmpty) {
              return const _EstadoCitas(
                icon: Icons.event_available,
                texto:
                    'Todavía no tienes citas. Usa el botón para programar una.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              itemCount: citas.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final cita = citas[index];
                final datos = cita.data();
                final fecha = (datos['fechaHora'] as Timestamp?)?.toDate();
                final cancelada = datos['estado'] == 'cancelada';
                return Card(
                  color: cancelada ? Colors.grey.shade100 : Colors.white,
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${datos['especialidad'] ?? 'Cita médica'}',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (fecha != null)
                          Text(
                            _formatearFecha(fecha),
                            style: const TextStyle(fontSize: 19),
                          ),
                        if ((datos['medico'] as String? ?? '').isNotEmpty)
                          Text(
                            'Profesional: ${datos['medico']}',
                            style: const TextStyle(fontSize: 18),
                          ),
                        if ((datos['centro'] as String? ?? '').isNotEmpty)
                          Text(
                            'Centro médico: ${datos['centro']}',
                            style: const TextStyle(fontSize: 18),
                          ),
                        if ((datos['notas'] as String? ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              'Nota: ${datos['notas']}',
                              style: const TextStyle(fontSize: 18),
                            ),
                          ),
                        const SizedBox(height: 8),
                        Text(
                          cancelada
                              ? 'Estado: Cancelada'
                              : 'Estado: Programada',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: cancelada
                                ? Colors.black54
                                : Colors.teal.shade900,
                          ),
                        ),
                        if (!cancelada) ...[
                          const SizedBox(height: 8),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _AccionCitaButton(
                                icon: Icons.edit,
                                label: 'Editar',
                                onPressed: () =>
                                    _abrirFormulario(context, cita: cita),
                              ),
                              _AccionCitaButton(
                                icon: Icons.event_busy,
                                label: 'Cancelar cita',
                                onPressed: () => _cancelar(context, cita),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _abrirFormulario(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(64),
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add, size: 28),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      'Nueva cita',
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
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
  }
}

class _AccionCitaButton extends StatelessWidget {
  const _AccionCitaButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: onPressed,
    style: TextButton.styleFrom(
      alignment: Alignment.centerLeft,
      minimumSize: const Size.fromHeight(48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            softWrap: true,
            style: const TextStyle(fontSize: 17),
          ),
        ),
      ],
    ),
  );
}

class _EstadoCitas extends StatelessWidget {
  const _EstadoCitas({required this.icon, required this.texto});
  final IconData icon;
  final String texto;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 72, color: Colors.teal.shade800),
          const SizedBox(height: 18),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 21,
              height: 1.4,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    ),
  );
}

class _CitaDialog extends StatefulWidget {
  const _CitaDialog({required this.citas, this.cita});
  final CollectionReference<Map<String, dynamic>> citas;
  final QueryDocumentSnapshot<Map<String, dynamic>>? cita;

  @override
  State<_CitaDialog> createState() => _CitaDialogState();
}

class _CitaDialogState extends State<_CitaDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _especialidad;
  late final TextEditingController _medico;
  late final TextEditingController _centro;
  late final TextEditingController _notas;
  late DateTime _fechaHora;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    final datos = widget.cita?.data() ?? {};
    _especialidad = TextEditingController(
      text: datos['especialidad'] as String? ?? '',
    );
    _medico = TextEditingController(text: datos['medico'] as String? ?? '');
    _centro = TextEditingController(text: datos['centro'] as String? ?? '');
    _notas = TextEditingController(text: datos['notas'] as String? ?? '');
    _fechaHora =
        (datos['fechaHora'] as Timestamp?)?.toDate() ??
        DateTime.now().add(const Duration(days: 1));
  }

  @override
  void dispose() {
    _especialidad.dispose();
    _medico.dispose();
    _centro.dispose();
    _notas.dispose();
    super.dispose();
  }

  String _fechaTexto(DateTime fecha) =>
      '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}  ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

  Future<void> _elegirFecha() async {
    final fecha = await showDatePicker(
      context: context,
      initialDate: _fechaHora.isBefore(DateTime.now())
          ? DateTime.now()
          : _fechaHora,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
      helpText: 'Elige el día de tu cita',
      cancelText: 'Volver',
      confirmText: 'Continuar',
    );
    if (fecha == null || !mounted) return;
    final hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_fechaHora),
      helpText: 'Elige la hora de tu cita',
      cancelText: 'Volver',
      confirmText: 'Aceptar',
    );
    if (hora != null && mounted) {
      setState(
        () => _fechaHora = DateTime(
          fecha.year,
          fecha.month,
          fecha.day,
          hora.hour,
          hora.minute,
        ),
      );
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    if (_fechaHora.isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Elige una fecha y hora futuras.')),
      );
      return;
    }
    setState(() => _guardando = true);
    final messenger = ScaffoldMessenger.of(context);
    final datos = <String, dynamic>{
      'especialidad': _especialidad.text.trim(),
      'medico': _medico.text.trim(),
      'centro': _centro.text.trim(),
      'notas': _notas.text.trim(),
      'fechaHora': Timestamp.fromDate(_fechaHora),
      'estado': 'programada',
      'actualizadaEn': FieldValue.serverTimestamp(),
    };
    try {
      late final String citaId;
      if (widget.cita == null) {
        final document = await widget.citas.add({
          ...datos,
          'creadaEn': FieldValue.serverTimestamp(),
        });
        citaId = document.id;
      } else {
        citaId = widget.cita!.id;
        await widget.citas.doc(widget.cita!.id).update(datos);
      }
      final reminderResult = await AppointmentNotificationService.instance
          .scheduleForAppointment(
            citaId: citaId,
            especialidad: _especialidad.text.trim(),
            medico: _medico.text.trim(),
            fechaHora: _fechaHora,
            estado: 'programada',
          );
      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(content: Text(_mensajeRecordatorio(reminderResult))),
        );
      }
    } on FirebaseException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'No se pudo guardar la cita. ${error.message ?? 'Inténtalo de nuevo.'}',
              style: const TextStyle(fontSize: 17),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  String _mensajeRecordatorio(AppointmentReminderResult resultado) {
    return switch (resultado) {
      AppointmentReminderResult.scheduled =>
        'Cita guardada. Recordatorio programado para 30 minutos antes.',
      AppointmentReminderResult.skipped => 'Cita guardada. No se programó el recordatorio porque su hora ya pasó o está demasiado cerca.',
      AppointmentReminderResult.permissionDenied => 'Cita guardada. Activa las notificaciones de Citas Médicas en los ajustes de Android para recibir recordatorios.',
      AppointmentReminderResult.unavailable => 'Cita guardada, pero no fue posible programar el recordatorio en este dispositivo.',
    };
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.cita == null ? 'Programar una cita' : 'Editar cita',
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    ),
    content: SizedBox(
      width: 460,
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _especialidad,
                autofocus: true,
                style: const TextStyle(fontSize: 19),
                decoration: const InputDecoration(
                  labelText: 'Especialidad o motivo',
                  prefixIcon: Icon(Icons.medical_services),
                ),
                validator: (valor) => valor == null || valor.trim().isEmpty
                    ? 'Escribe la especialidad o motivo.'
                    : null,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _medico,
                style: const TextStyle(fontSize: 19),
                decoration: const InputDecoration(
                  labelText: 'Nombre del profesional',
                  prefixIcon: Icon(Icons.person),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _centro,
                style: const TextStyle(fontSize: 19),
                decoration: const InputDecoration(
                  labelText: 'Centro médico',
                  prefixIcon: Icon(Icons.local_hospital),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 58,
                child: OutlinedButton.icon(
                  onPressed: _elegirFecha,
                  icon: const Icon(Icons.calendar_month, size: 25),
                  label: Text(
                    _fechaTexto(_fechaHora),
                    style: const TextStyle(fontSize: 18),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _notas,
                maxLines: 2,
                style: const TextStyle(fontSize: 19),
                decoration: const InputDecoration(
                  labelText: 'Notas (opcional)',
                  prefixIcon: Icon(Icons.notes),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _guardando ? null : () => Navigator.pop(context),
        child: const Text('Volver', style: TextStyle(fontSize: 18)),
      ),
      SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  widget.cita == null ? 'Guardar cita' : 'Guardar cambios',
                  style: const TextStyle(fontSize: 18),
                ),
        ),
      ),
    ],
  );
}

String _formatearFecha(DateTime fecha) {
  const dias = [
    'lunes',
    'martes',
    'miércoles',
    'jueves',
    'viernes',
    'sábado',
    'domingo',
  ];
  const meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  final hora = fecha.hour.toString().padLeft(2, '0');
  final minuto = fecha.minute.toString().padLeft(2, '0');
  return '${dias[fecha.weekday - 1].toUpperCase()} ${fecha.day} de ${meses[fecha.month - 1]} · $hora:$minuto';
}
