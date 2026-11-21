import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as timezone_data;
import 'package:timezone/timezone.dart' as timezone;

enum AppointmentReminderResult {
  scheduled,
  skipped,
  permissionDenied,
  unavailable,
}

class AppointmentNotificationService {
  AppointmentNotificationService._();

  static final AppointmentNotificationService instance =
      AppointmentNotificationService._();

  static const _channelId = 'recordatorios_citas';
  static const _channelName = 'Recordatorios de citas';
  static const _channelDescription =
      'Avisos locales antes de las citas médicas programadas.';
  static const _reminderLeadTime = Duration(minutes: 30);
  static const _maxNotificationId = 0x7fffffff;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (defaultTargetPlatform != TargetPlatform.android || _initialized) return;

    timezone_data.initializeTimeZones();
    try {
      final deviceTimezone = await FlutterTimezone.getLocalTimezone();
      timezone.setLocalLocation(
        timezone.getLocation(deviceTimezone.identifier),
      );
    } catch (error) {
      // TZDateTime.from still preserves the appointment's instant if the device
      // timezone cannot be read; the timezone package defaults to UTC.
      debugPrint('No se pudo leer la zona horaria del dispositivo: $error');
    }

    try {
      await _notifications.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        ),
      );
      _initialized = true;
    } catch (error) {
      // Notification setup should not prevent authentication or appointment
      // management from starting if the Android plugin is unavailable.
      debugPrint('No se pudo inicializar el servicio de notificaciones: $error');
    }
  }

  Future<AppointmentReminderResult> scheduleForAppointment({
    required String citaId,
    required String especialidad,
    required String medico,
    required DateTime fechaHora,
    required String estado,
  }) async {
    if (!_initialized || defaultTargetPlatform != TargetPlatform.android) {
      return AppointmentReminderResult.unavailable;
    }

    final scheduledAt = fechaHora.subtract(_reminderLeadTime);
    if (estado != 'programada' ||
        !fechaHora.isAfter(DateTime.now()) ||
        !scheduledAt.isAfter(DateTime.now())) {
      await cancelForAppointment(citaId);
      return AppointmentReminderResult.skipped;
    }

    try {
      final androidNotifications = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final permissionGranted =
          await androidNotifications?.requestNotificationsPermission() ?? false;
      if (!permissionGranted) {
        await cancelForAppointment(citaId);
        return AppointmentReminderResult.permissionDenied;
      }

      final pending = await _notifications.pendingNotificationRequests();
      final existing = pending.where((request) => request.payload == citaId);
      final notificationId = existing.isNotEmpty
          ? existing.first.id
          : _availableId(citaId, pending);

      final specialist = medico.trim().isEmpty
          ? 'tu profesional de salud'
          : medico.trim();
      await _notifications.zonedSchedule(
        id: notificationId,
        title: 'Cita médica próxima',
        body:
            'Tienes una cita próxima de ${especialidad.trim()} con $specialist.',
        scheduledDate: timezone.TZDateTime.from(scheduledAt, timezone.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            _channelId,
            _channelName,
            channelDescription: _channelDescription,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        payload: citaId,
      );
      return AppointmentReminderResult.scheduled;
    } catch (error) {
      debugPrint('No se pudo programar el recordatorio local: $error');
      return AppointmentReminderResult.unavailable;
    }
  }

  Future<bool> cancelForAppointment(String citaId) async {
    if (!_initialized || defaultTargetPlatform != TargetPlatform.android) {
      return false;
    }
    try {
      final pending = await _notifications.pendingNotificationRequests();
      final matching = pending.where((request) => request.payload == citaId);
      for (final request in matching) {
        await _notifications.cancel(id: request.id);
      }
      return true;
    } catch (error) {
      debugPrint('No se pudo cancelar el recordatorio local: $error');
      return false;
    }
  }

  int _availableId(String citaId, List<PendingNotificationRequest> pending) {
    final usedIds = pending.map((request) => request.id).toSet();
    var candidate = _stableId(citaId);
    while (usedIds.contains(candidate)) {
      candidate = candidate == _maxNotificationId ? 1 : candidate + 1;
    }
    return candidate;
  }

  int _stableId(String citaId) {
    var hash = 0x811c9dc5;
    for (final byte in utf8.encode(citaId)) {
      hash = ((hash ^ byte) * 0x01000193) & _maxNotificationId;
    }
    return hash == 0 ? 1 : hash;
  }
}
