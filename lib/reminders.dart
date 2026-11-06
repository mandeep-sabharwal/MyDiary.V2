import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'models.dart';
import 'notif_art.dart';
import 'utils.dart';

final Reminders reminders = Reminders();

/// Daily "Mochi misses you" notifications, styled like the design:
/// Mochi on a pastel tile, a pink accent, the full message and a "Write now" button.
///
/// The next 14 evenings are scheduled as one-off notifications and rebuilt whenever
/// the app opens or you save an entry. So a night you already wrote is skipped, the
/// streak number stays fresh, and "One year ago today" memories can appear.
class Reminders {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Whether Android lets the app fire reminders at the exact minute (null = not known yet).
  final ValueNotifier<bool?> exact = ValueNotifier<bool?>(null);

  /// The last error from the notification plugin (long-press "Daily reminder" in Settings).
  String? lastError;

  static const int _days = 14;

  AndroidNotificationDetails _details(String title, String body, Uint8List art) {
    return AndroidNotificationDetails(
      'pawsie_reminders_v3',
      'Daily reminder',
      channelDescription: 'A gentle nudge from Mochi to write in your diary',
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      color: const Color(0xFFF59BB0),
      largeIcon: ByteArrayAndroidBitmap(art),
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: 'Pawsie Diary',
      ),
      ticker: title,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction('write', 'Write now', showsUserInterface: true),
      ],
    );
  }

  Future<bool> init() async {
    if (_ready) return true;
    // Prefer Mochi's silhouette; fall back to the launcher icon if the setup step was skipped.
    for (final icon in ['ic_notification', '@mipmap/ic_launcher']) {
      try {
        await _plugin.initialize(
          settings: InitializationSettings(android: AndroidInitializationSettings(icon)),
        );
        _ready = true;
        return true;
      } catch (e) {
        lastError = 'initialize($icon): $e';
      }
    }
    return false;
  }

  /// Asks for the Android 13+ notification permission. True if allowed.
  Future<bool> requestPermission() async {
    if (!await init()) return false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      if (granted != true) lastError = 'Notification permission was not granted.';
      return granted ?? false;
    } catch (e) {
      lastError = 'permission: $e';
      return false;
    }
  }

  static const List<(String, String)> _lines = [
    ('Mochi misses you', 'A few quiet lines before bed? Your diary is waiting.'),
    ('How was your day?', 'Tell Mochi about it. One sentence is enough.'),
    ('Time to write', 'Your cosy corner is ready whenever you are.'),
    ('Mochi is curled up and waiting', 'What was the best part of today?'),
  ];

  /// One stable id per calendar day. Scheduling the same day again simply replaces
  /// that day's alarm, so nothing has to be cancelled (cancelling would also remove a
  /// reminder that is already showing in the notification shade).
  int _idFor(DateTime day) => 100000 + dayNum(day) % 100000;

  bool _legacyCleaned = false;

  /// Older versions used ids 100..113 and cancelled them on every app start.
  Future<void> _cleanLegacyIds() async {
    if (_legacyCleaned) return;
    _legacyCleaned = true;
    for (var i = 0; i < 14; i++) {
      await _plugin.cancel(id: 100 + i);
    }
  }

  /// An older entry written on the same calendar day, for "One year ago today".
  Entry? _memoryFor(DateTime day, List<Entry> entries) {
    Entry? best;
    for (final e in entries) {
      final c = e.createdAt;
      if (c.month == day.month && c.day == day.day && c.year < day.year) {
        if (best == null || c.year > best.createdAt.year) best = e;
      }
    }
    return best;
  }

  Future<AndroidScheduleMode> _mode() async {
    var canExact = false;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      canExact = await android?.canScheduleExactNotifications() == true;
    } catch (_) {}
    exact.value = canExact;
    return canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Opens Android's "Alarms & reminders" screen so the app may fire on the exact minute.
  Future<void> requestExact() async {
    if (!await init()) return;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestExactAlarmsPermission();
    } catch (e) {
      lastError = 'exact alarms: $e';
    }
  }

  Future<void> reschedule({
    required bool on,
    required int minutes,
    required bool wroteToday,
    required int streak,
    List<Entry> entries = const [],
  }) async {
    if (!await init()) return;
    try {
      await _cleanLegacyIds();
      final mode = on ? await _mode() : AndroidScheduleMode.inexactAllowWhileIdle;
      final now = DateTime.now();
      for (var d = 0; d < _days; d++) {
        final day = DateTime(now.year, now.month, now.day + d);
        final id = _idFor(day);
        final at = DateTime(day.year, day.month, day.day, minutes ~/ 60, minutes % 60);

        if (!on) {
          await _plugin.cancel(id: id); // reminders switched off
          continue;
        }
        if (d == 0 && wroteToday) {
          await _plugin.cancel(id: id); // already wrote today: no nudge
          continue;
        }
        // A time that has already passed has fired: leave its notification alone.
        if (!at.isAfter(now)) continue;

        var (title, body) = _lines[d % _lines.length];
        var art = kNotifHappy;
        final memory = _memoryFor(at, entries);
        if (memory != null) {
          final years = at.year - memory.createdAt.year;
          title = years == 1 ? 'One year ago today' : '$years years ago today';
          final topic = memory.title.trim().isNotEmpty ? memory.title.trim() : memory.plainBody;
          final short = topic.length > 60 ? '${topic.substring(0, 60)}...' : topic;
          body = short.isEmpty
              ? 'You wrote in your diary on this day. Come and read it.'
              : 'You wrote about "$short". Come and read it.';
          art = kNotifLoved;
        } else if (d <= 1 && streak > 0) {
          title = 'Mochi misses you';
          body = 'Your $streak-day streak is waiting. Write tonight?';
          art = kNotifExcited;
        }
        await _plugin.zonedSchedule(
          id: id,
          scheduledDate: tz.TZDateTime.from(at, tz.UTC),
          notificationDetails: NotificationDetails(android: _details(title, body, art)),
          androidScheduleMode: mode,
          title: title,
          body: body,
        );
      }
      lastError = null;
    } catch (e) {
      lastError = 'schedule: $e';
    }
  }

  // ---------- developer helpers ----------

  /// Shows a notification right now. Returns an error message, or null on success.
  Future<String?> showTestNow() async {
    if (!await init()) return lastError ?? 'Could not start notifications.';
    try {
      const title = 'Mochi misses you';
      const body = 'Your 12-day streak is waiting. Write tonight?';
      await _plugin.show(
        id: 98,
        title: title,
        body: body,
        notificationDetails: NotificationDetails(android: _details(title, body, kNotifExcited)),
      );
      return null;
    } catch (e) {
      return '$e';
    }
  }

  /// One-line status: permission, how many reminders are queued, last error.
  Future<String> diagnose() async {
    if (!await init()) return 'Not started: ${lastError ?? 'unknown error'}';
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final enabled = await android?.areNotificationsEnabled();
      final exact = await android?.canScheduleExactNotifications();
      final pending = await _plugin.pendingNotificationRequests();
      return 'Notifications ${enabled == true ? 'allowed' : 'BLOCKED in Android settings'}; '
          '${pending.length} queued; exact alarms ${exact == true ? 'on' : 'off (approximate timing)'}.'
          '${lastError == null ? '' : ' Last error: $lastError'}';
    } catch (e) {
      return 'Could not read status: $e';
    }
  }
}
