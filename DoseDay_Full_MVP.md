# DoseDay — Full Flutter Medication Reminder MVP

A local-first Flutter MVP for Android and iOS using Dart, SQLite, and local notifications. No backend or cloud database is required.

## Features

- Add, edit, and delete medications
- Configure multiple daily reminder times, start/end dates, instructions, and stock thresholds
- Persist medications, dose logs, and refill logs in SQLite
- Schedule recurring local notifications
- Record doses as taken or skipped; unrecorded past doses are marked missed when the app opens
- Update stock when doses are marked taken
- View adherence summaries and low-stock warnings
- Bottom navigation for Home, Medicines, Insights, and Settings

## Setup

1. Create a Flutter project: `flutter create medication_reminder`
2. Replace the generated `pubspec.yaml` with the one below.
3. Create the folders and files shown in the source sections and paste each code block into its named file.
4. Run `flutter pub get`, then `flutter run`.
5. Use an Android phone or emulator for testing. Building for iOS requires macOS and Xcode.

## Android notification setup

Open `android/app/src/main/AndroidManifest.xml`. Add this permission inside `<manifest>` and outside `<application>`:

```xml
<uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />
```

Add these receivers inside the existing `<application>` element if they are not already present:

```xml
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver" />
<receiver android:exported="false" android:name="com.dexterous.flutterlocalnotifications.ScheduledNotificationBootReceiver">
    <intent-filter>
        <action android:name="android.intent.action.BOOT_COMPLETED" />
        <action android:name="android.intent.action.MY_PACKAGE_REPLACED" />
        <action android:name="android.intent.action.QUICKBOOT_POWERON" />
        <action android:name="com.htc.intent.action.QUICKBOOT_POWERON" />
    </intent-filter>
</receiver>
```

The notification package may also require Android compile SDK 35+ and Java desugaring depending on its version. See the [official package setup guide](https://pub.dev/packages/flutter_local_notifications#android-setup) if Gradle reports related errors.

## `pubspec.yaml`

```yaml
name: medication_reminder
description: A local-first medication reminder MVP built with Flutter and SQLite.
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.3.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  sqflite: ^2.4.2
  path: ^1.9.1
  flutter_local_notifications: ^19.4.0
  timezone: ^0.10.1
  flutter_timezone: ^5.1.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^5.0.0

flutter:
  uses-material-design: true
```

## `lib/models/medication.dart`

```dart
import 'dart:convert';

class Medication {
  const Medication({
    this.id,
    required this.name,
    required this.dosage,
    required this.dosageUnit,
    this.instructions = '',
    required this.startDate,
    this.endDate,
    required this.stockQuantity,
    required this.refillThreshold,
    required this.times,
    this.isActive = true,
  });

  final int? id;
  final String name;
  final String dosage;
  final String dosageUnit;
  final String instructions;
  final String startDate; // yyyy-MM-dd
  final String? endDate;
  final int stockQuantity;
  final int refillThreshold;
  final List<String> times; // HH:mm local times
  final bool isActive;

  bool get needsRefill => stockQuantity <= refillThreshold;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'dosage': dosage,
        'dosage_unit': dosageUnit,
        'instructions': instructions,
        'start_date': startDate,
        'end_date': endDate,
        'stock_quantity': stockQuantity,
        'refill_threshold': refillThreshold,
        'times_json': jsonEncode(times),
        'is_active': isActive ? 1 : 0,
      };

  factory Medication.fromMap(Map<String, Object?> map) => Medication(
        id: map['id'] as int?,
        name: map['name'] as String,
        dosage: map['dosage'] as String,
        dosageUnit: map['dosage_unit'] as String,
        instructions: (map['instructions'] as String?) ?? '',
        startDate: map['start_date'] as String,
        endDate: map['end_date'] as String?,
        stockQuantity: (map['stock_quantity'] as int?) ?? 0,
        refillThreshold: (map['refill_threshold'] as int?) ?? 0,
        times: (jsonDecode((map['times_json'] as String?) ?? '[]') as List)
            .map((e) => e.toString())
            .toList(),
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );

  Medication copyWith({
    int? id,
    String? name,
    String? dosage,
    String? dosageUnit,
    String? instructions,
    String? startDate,
    String? endDate,
    int? stockQuantity,
    int? refillThreshold,
    List<String>? times,
    bool? isActive,
    bool clearEndDate = false,
  }) =>
      Medication(
        id: id ?? this.id,
        name: name ?? this.name,
        dosage: dosage ?? this.dosage,
        dosageUnit: dosageUnit ?? this.dosageUnit,
        instructions: instructions ?? this.instructions,
        startDate: startDate ?? this.startDate,
        endDate: clearEndDate ? null : (endDate ?? this.endDate),
        stockQuantity: stockQuantity ?? this.stockQuantity,
        refillThreshold: refillThreshold ?? this.refillThreshold,
        times: times ?? this.times,
        isActive: isActive ?? this.isActive,
      );
}
```

## `lib/services/database_service.dart`

```dart
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/medication.dart';

class DoseLog {
  const DoseLog({
    required this.id,
    required this.medicationId,
    required this.scheduledDate,
    required this.scheduledTime,
    required this.status,
    required this.recordedAt,
  });
  final int id;
  final int medicationId;
  final String scheduledDate;
  final String scheduledTime;
  final String status;
  final String recordedAt;

  factory DoseLog.fromMap(Map<String, Object?> m) => DoseLog(
        id: m['id'] as int,
        medicationId: m['medication_id'] as int,
        scheduledDate: m['scheduled_date'] as String,
        scheduledTime: m['scheduled_time'] as String,
        status: m['status'] as String,
        recordedAt: m['recorded_at'] as String,
      );
}

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();
  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    final base = await getDatabasesPath();
    _db = await openDatabase(
      p.join(base, 'medication_reminder.db'),
      version: 1,
      onConfigure: (db) async => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE medications (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            dosage TEXT NOT NULL,
            dosage_unit TEXT NOT NULL,
            instructions TEXT NOT NULL DEFAULT '',
            start_date TEXT NOT NULL,
            end_date TEXT,
            stock_quantity INTEGER NOT NULL DEFAULT 0,
            refill_threshold INTEGER NOT NULL DEFAULT 0,
            times_json TEXT NOT NULL,
            is_active INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('''
          CREATE TABLE dose_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            medication_id INTEGER NOT NULL,
            scheduled_date TEXT NOT NULL,
            scheduled_time TEXT NOT NULL,
            status TEXT NOT NULL,
            recorded_at TEXT NOT NULL,
            UNIQUE(medication_id, scheduled_date, scheduled_time),
            FOREIGN KEY(medication_id) REFERENCES medications(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('''
          CREATE TABLE refill_logs (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            medication_id INTEGER NOT NULL,
            quantity_added INTEGER NOT NULL,
            recorded_at TEXT NOT NULL,
            FOREIGN KEY(medication_id) REFERENCES medications(id) ON DELETE CASCADE
          )
        ''');
      },
    );
    return _db!;
  }

  Future<List<Medication>> getMedications({bool activeOnly = false}) async {
    final db = await database;
    final rows = await db.query('medications',
        where: activeOnly ? 'is_active = 1' : null,
        orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(Medication.fromMap).toList();
  }

  Future<int> saveMedication(Medication medication) async {
    final db = await database;
    if (medication.id == null) {
      return db.insert('medications', medication.toMap()..remove('id'));
    }
    await db.update('medications', medication.toMap(),
        where: 'id = ?', whereArgs: [medication.id]);
    return medication.id!;
  }

  Future<void> deleteMedication(int id) async {
    final db = await database;
    await db.delete('medications', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateStock(int medicationId, int newQuantity) async {
    final db = await database;
    await db.update('medications', {'stock_quantity': newQuantity},
        where: 'id = ?', whereArgs: [medicationId]);
  }

  Future<void> addRefill(int medicationId, int quantity) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
          'UPDATE medications SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [quantity, medicationId]);
      await txn.insert('refill_logs', {
        'medication_id': medicationId,
        'quantity_added': quantity,
        'recorded_at': DateTime.now().toIso8601String(),
      });
    });
  }

  Future<List<DoseLog>> getLogsForDate(String date) async {
    final db = await database;
    final rows = await db.query('dose_logs',
        where: 'scheduled_date = ?', whereArgs: [date]);
    return rows.map(DoseLog.fromMap).toList();
  }

  Future<List<DoseLog>> getAllLogs() async {
    final db = await database;
    final rows = await db.query('dose_logs', orderBy: 'scheduled_date DESC');
    return rows.map(DoseLog.fromMap).toList();
  }

  Future<void> recordDose({
    required Medication medication,
    required String date,
    required String time,
    required String status,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final existing = await txn.query('dose_logs',
          where: 'medication_id = ? AND scheduled_date = ? AND scheduled_time = ?',
          whereArgs: [medication.id, date, time], limit: 1);
      final previousStatus = existing.isEmpty ? null : existing.first['status'] as String;
      if (previousStatus == status) return;

      // Keep stock accurate when a dose is changed to or from "taken".
      if (previousStatus != 'taken' && status == 'taken') {
        await txn.rawUpdate(
            'UPDATE medications SET stock_quantity = MAX(0, stock_quantity - 1) WHERE id = ?',
            [medication.id]);
      } else if (previousStatus == 'taken' && status != 'taken') {
        await txn.rawUpdate(
            'UPDATE medications SET stock_quantity = stock_quantity + 1 WHERE id = ?',
            [medication.id]);
      }

      final values = {
        'medication_id': medication.id,
        'scheduled_date': date,
        'scheduled_time': time,
        'status': status,
        'recorded_at': DateTime.now().toIso8601String(),
      };
      if (existing.isEmpty) {
        await txn.insert('dose_logs', values);
      } else {
        await txn.update('dose_logs', values,
            where: 'id = ?', whereArgs: [existing.first['id']]);
      }
    });
  }

  Future<void> markPastDosesMissed() async {
    final now = DateTime.now();
    final today = _dateKey(now);
    final db = await database;
    final meds = await getMedications(activeOnly: true);
    for (final med in meds) {
      if (med.id == null || med.startDate.compareTo(today) > 0) continue;
      if (med.endDate != null && med.endDate!.compareTo(today) < 0) continue;
      for (final time in med.times) {
        final parts = time.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        final scheduled = DateTime(now.year, now.month, now.day, hour, minute);
        if (scheduled.isBefore(now.subtract(const Duration(minutes: 60)))) {
          final existing = await db.query('dose_logs',
              where: 'medication_id = ? AND scheduled_date = ? AND scheduled_time = ?',
              whereArgs: [med.id, today, time], limit: 1);
          if (existing.isEmpty) {
            await db.insert('dose_logs', {
              'medication_id': med.id,
              'scheduled_date': today,
              'scheduled_time': time,
              'status': 'missed',
              'recorded_at': now.toIso8601String(),
            });
          }
        }
      }
    }
  }

  Future<int> getRefillCount() async {
    final db = await database;
    final rows = await db.rawQuery(
        'SELECT COUNT(*) AS count FROM medications WHERE is_active = 1 AND stock_quantity <= refill_threshold');
    return Sqflite.firstIntValue(rows) ?? 0;
  }
}

String dateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
String _dateKey(DateTime date) => dateKey(date);
```

## `lib/services/notification_service.dart`

```dart
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/medication.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    tzdata.initializeTimeZones();
    try {
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      final zoneName = timezoneInfo.identifier;
      tz.setLocalLocation(tz.getLocation(zoneName));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Asia/Manila'));
    }

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(),
    );
    await _plugin.initialize(settings);
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  Future<void> scheduleMedication(Medication medication) async {
    if (medication.id == null || !medication.isActive) return;
    await cancelMedication(medication.id!);
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'medication_reminders',
        'Medication reminders',
        channelDescription: 'Reminders for scheduled medication doses',
        importance: Importance.max,
        priority: Priority.high,
        category: AndroidNotificationCategory.reminder,
      ),
      iOS: DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
    );

    for (var i = 0; i < medication.times.length; i++) {
      final time = medication.times[i].split(':');
      if (time.length != 2) continue;
      final hour = int.tryParse(time[0]);
      final minute = int.tryParse(time[1]);
      if (hour == null || minute == null) continue;
      final now = tz.TZDateTime.now(tz.local);
      var next = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
      if (!next.isAfter(now)) {
        next = next.add(const Duration(days: 1));
      }
      final id = medication.id! * 100 + i;
      await _plugin.zonedSchedule(
        id,
        'Time to take ${medication.name}',
        '${medication.dosage} ${medication.dosageUnit}${medication.instructions.isNotEmpty ? ' • ${medication.instructions}' : ''}',
        next,
        details,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: '${medication.id}|${medication.times[i]}',
      );
    }
  }

  Future<void> cancelMedication(int medicationId) async {
    // One medication can have up to 99 daily reminder times in this MVP.
    for (var i = 0; i < 100; i++) {
      await _plugin.cancel(medicationId * 100 + i);
    }
  }

  Future<void> cancelAll() => _plugin.cancelAll();
}
```

## `lib/main.dart`

```dart
import 'package:flutter/material.dart';
import 'models/medication.dart';
import 'services/database_service.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await DatabaseService.instance.markPastDosesMissed();
  final savedMedications = await DatabaseService.instance.getMedications(activeOnly: true);
  for (final medication in savedMedications) {
    await NotificationService.instance.scheduleMedication(medication);
  }
  runApp(const MedicationReminderApp());
}

class MedicationReminderApp extends StatelessWidget {
  const MedicationReminderApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'DoseDay',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0D9488)),
          scaffoldBackgroundColor: const Color(0xFFF7F9FC),
          appBarTheme: const AppBarTheme(backgroundColor: Color(0xFFF7F9FC)),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFE3E8EF))),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF0D9488), width: 1.5)),
          ),
        ),
        home: const AppShell(),
      );
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  int _refresh = 0;
  void refresh() => setState(() => _refresh++);
  @override
  Widget build(BuildContext context) {
    final pages = [
      HomeScreen(key: ValueKey('home$_refresh'), onRefresh: refresh, onOpenMedications: () => setState(() => _index = 1)),
      MedicationsScreen(key: ValueKey('meds$_refresh'), onRefresh: refresh),
      InsightsScreen(key: ValueKey('insights$_refresh')),
      SettingsScreen(key: ValueKey('settings$_refresh')),
    ];
    return Scaffold(
      body: SafeArea(child: IndexedStack(index: _index, children: pages)),
      floatingActionButton: _index == 1
          ? FloatingActionButton.extended(
              onPressed: () async {
                final result = await showMedicationForm(context);
                if (result != null) refresh();
              },
              icon: const Icon(Icons.add), label: const Text('Add medicine'))
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (v) => setState(() => _index = v),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.medication_outlined), selectedIcon: Icon(Icons.medication), label: 'Medicines'),
          NavigationDestination(icon: Icon(Icons.insights_outlined), selectedIcon: Icon(Icons.insights), label: 'Insights'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onRefresh, required this.onOpenMedications});
  final VoidCallback onRefresh;
  final VoidCallback onOpenMedications;
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _busy = true;
  List<Medication> _medications = [];
  List<DoseLog> _logs = [];
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    await DatabaseService.instance.markPastDosesMissed();
    final meds = await DatabaseService.instance.getMedications(activeOnly: true);
    final logs = await DatabaseService.instance.getLogsForDate(dateKey(DateTime.now()));
    if (mounted) setState(() { _medications = meds; _logs = logs; _busy = false; });
  }
  DoseLog? _logFor(Medication m, String time) {
    for (final l in _logs) { if (l.medicationId == m.id && l.scheduledTime == time) return l; }
    return null;
  }
  Future<void> _mark(Medication med, String time, String status) async {
    await DatabaseService.instance.recordDose(medication: med, date: dateKey(DateTime.now()), time: time, status: status);
    await _load(); widget.onRefresh();
  }
  @override
  Widget build(BuildContext context) {
    final allSlots = <MapEntry<Medication, String>>[];
    final today = dateKey(DateTime.now());
    for (final m in _medications) {
      if (m.startDate.compareTo(today) <= 0 && (m.endDate == null || m.endDate!.compareTo(today) >= 0)) {
        for (final t in m.times) { allSlots.add(MapEntry(m, t)); }
      }
    }
    allSlots.sort((a,b) => a.value.compareTo(b.value));
    final taken = allSlots.where((s) => _logFor(s.key, s.value)?.status == 'taken').length;
    final pending = allSlots.where((s) => _logFor(s.key, s.value) == null).length;
    final next = allSlots.where((s) => _logFor(s.key, s.value) == null && s.value.compareTo(_timeKey(DateTime.now())) >= 0).firstOrNull;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.fromLTRB(20, 14, 20, 28), children: [
        Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFDDF7F1), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.health_and_safety, color: Color(0xFF0D9488), size: 28)),
          const SizedBox(width: 12), const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('DoseDay', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)), Text('Your daily medication companion', style: TextStyle(color: Colors.black54))])),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
        ]),
        const SizedBox(height: 24),
        Text(_friendlyDate(DateTime.now()), style: const TextStyle(fontSize: 15, color: Colors.black54, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6), const Text('Stay on top of your health.', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
        const SizedBox(height: 18),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF087E8B)]), borderRadius: BorderRadius.circular(24)), child: _busy ? const LinearProgressIndicator() : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text("TODAY'S PROGRESS", style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700, letterSpacing: 1.1, fontSize: 12)),
          const SizedBox(height: 10), Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('$taken', style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800)), Text(' / ${allSlots.length} doses taken', style: const TextStyle(color: Colors.white, fontSize: 15)), const Spacer(), Icon(Icons.check_circle, color: Colors.white.withValues(alpha: .9), size: 30)]),
          const SizedBox(height: 14), ClipRRect(borderRadius: BorderRadius.circular(20), child: LinearProgressIndicator(value: allSlots.isEmpty ? 0 : taken / allSlots.length, minHeight: 8, backgroundColor: Colors.white24, valueColor: const AlwaysStoppedAnimation(Colors.white))),
          const SizedBox(height: 10), Text(allSlots.isEmpty ? 'Add your first medication to get started.' : '$pending doses still need attention today.', style: const TextStyle(color: Colors.white)),
        ])),
        const SizedBox(height: 24),
        Row(children: [const Expanded(child: Text('Next reminder', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800))), TextButton(onPressed: widget.onOpenMedications, child: const Text('All medicines'))]),
        if (_busy) const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()))
        else if (next == null) _emptyCard('You are all caught up', allSlots.isEmpty ? 'Add a medication and set its reminder times.' : 'No upcoming doses. You can review today’s schedule below.', Icons.check_circle_outline)
        else _nextCard(next.key, next.value),
        const SizedBox(height: 20),
        const Text("Today's schedule", style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        if (!_busy && allSlots.isEmpty) _emptyCard('No medicines yet', 'Add a medicine to create your daily schedule.', Icons.medication_outlined)
        else ...allSlots.map((s) => _doseCard(s.key, s.value)),
        const SizedBox(height: 18),
        FutureBuilder<int>(future: DatabaseService.instance.getRefillCount(), builder: (context, snap) {
          if (!snap.hasData || snap.data == 0) return const SizedBox.shrink();
          return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: const Color(0xFFFFF3D8), borderRadius: BorderRadius.circular(18)), child: Row(children: [const Icon(Icons.inventory_2_outlined, color: Color(0xFF9A6700)), const SizedBox(width: 12), Expanded(child: Text('${snap.data} medication(s) are at or below the refill threshold.', style: const TextStyle(fontWeight: FontWeight.w600))), const Icon(Icons.chevron_right)]));
        }),
      ]),
    );
  }
  Widget _nextCard(Medication med, String time) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE4EAF0))), child: Row(children: [Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFE2F6F1), borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.medication, color: Color(0xFF0D9488), size: 27)), const SizedBox(width: 13), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(med.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)), Text('${med.dosage} ${med.dosageUnit} • ${_formatTime(time)}', style: const TextStyle(color: Colors.black54)), if (med.instructions.isNotEmpty) Text(med.instructions, style: const TextStyle(color: Colors.black45, fontSize: 12))])), IconButton(onPressed: () => _mark(med, time, 'taken'), icon: const Icon(Icons.check_circle_outline, color: Color(0xFF0D9488), size: 29), tooltip: 'Mark taken') ]));
  Widget _doseCard(Medication med, String time) {
    final log = _logFor(med, time);
    final status = log?.status;
    final color = status == 'taken' ? const Color(0xFF0D9488) : status == 'missed' ? Colors.redAccent : status == 'skipped' ? Colors.orange : Colors.blueGrey;
    return Container(margin: const EdgeInsets.only(bottom: 9), padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFFE9EDF2))), child: Row(children: [Container(width: 42, height: 42, alignment: Alignment.center, decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(13)), child: Icon(status == 'taken' ? Icons.check : status == 'missed' ? Icons.error_outline : Icons.medication_outlined, color: color)), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(med.name, style: const TextStyle(fontWeight: FontWeight.w700)), Text('${_formatTime(time)} • ${med.dosage} ${med.dosageUnit}', style: const TextStyle(fontSize: 12, color: Colors.black54))])), if (status == null) PopupMenuButton<String>(tooltip: 'Record dose', onSelected: (v) => _mark(med, time, v), itemBuilder: (_) => const [PopupMenuItem(value: 'taken', child: Text('Mark as taken')), PopupMenuItem(value: 'skipped', child: Text('Mark as skipped'))], child: const Icon(Icons.more_horiz)) else Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withValues(alpha: .1), borderRadius: BorderRadius.circular(20)), child: Text(status.toUpperCase(), style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: color))) ]));
  }
}

class MedicationsScreen extends StatefulWidget {
  const MedicationsScreen({super.key, required this.onRefresh});
  final VoidCallback onRefresh;
  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}
class _MedicationsScreenState extends State<MedicationsScreen> {
  late Future<List<Medication>> _future;
  @override
  void initState() { super.initState(); _future = DatabaseService.instance.getMedications(); }
  void _reload() => setState(() => _future = DatabaseService.instance.getMedications());
  Future<void> _edit(Medication med) async {
    final updated = await showMedicationForm(context, medication: med);
    if (updated != null && mounted) { await NotificationService.instance.scheduleMedication(updated); _reload(); widget.onRefresh(); }
  }
  Future<void> _delete(Medication med) async {
    final yes = await showDialog<bool>(context: context, builder: (c) => AlertDialog(title: const Text('Delete medication?'), content: Text('Delete ${med.name} and its dose history?'), actions: [TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Delete'))]));
    if (yes == true && med.id != null) { await NotificationService.instance.cancelMedication(med.id!); await DatabaseService.instance.deleteMedication(med.id!); _reload(); widget.onRefresh(); }
  }
  Future<void> _refill(Medication med) async {
    final controller = TextEditingController(text: '30');
    final amount = await showDialog<int>(context: context, builder: (c) => AlertDialog(title: Text('Restock ${med.name}'), content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Units added', hintText: 'e.g. 30')), actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')), FilledButton(onPressed: () => Navigator.pop(c, int.tryParse(controller.text)), child: const Text('Add stock'))]));
    if (amount != null && amount > 0 && med.id != null) { await DatabaseService.instance.addRefill(med.id!, amount); _reload(); widget.onRefresh(); }
  }
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 100), children: [const Text('Your medicines', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)), const SizedBox(height: 5), const Text('Manage your medication details and reminders.', style: TextStyle(color: Colors.black54)), const SizedBox(height: 22), FutureBuilder<List<Medication>>(future: _future, builder: (context, snap) {
    if (snap.connectionState != ConnectionState.done) return const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator()));
    final meds = snap.data ?? [];
    if (meds.isEmpty) return _emptyCard('Your medicine list is empty', 'Tap “Add medicine” to create your first reminder.', Icons.medication_outlined);
    return Column(children: meds.map((m) => Container(margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE4EAF0))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: const Color(0xFFE2F6F1), borderRadius: BorderRadius.circular(13)), child: const Icon(Icons.medication, color: Color(0xFF0D9488))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(m.name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), Text('${m.dosage} ${m.dosageUnit}', style: const TextStyle(color: Colors.black54))])), PopupMenuButton<String>(onSelected: (v) { if (v == 'edit') _edit(m); if (v == 'delete') _delete(m); if (v == 'refill') _refill(m); }, itemBuilder: (_) => const [PopupMenuItem(value: 'edit', child: Text('Edit')), PopupMenuItem(value: 'refill', child: Text('Add refill stock')), PopupMenuItem(value: 'delete', child: Text('Delete'))])]), const SizedBox(height: 12), Wrap(spacing: 7, runSpacing: 7, children: m.times.map((t) => Chip(avatar: const Icon(Icons.alarm, size: 15), label: Text(_formatTime(t)), visualDensity: VisualDensity.compact, side: BorderSide.none, backgroundColor: const Color(0xFFF1F5F9))).toList()), const SizedBox(height: 4), Row(children: [Icon(Icons.inventory_2_outlined, size: 16, color: m.needsRefill ? Colors.orange : Colors.blueGrey), const SizedBox(width: 5), Text('${m.stockQuantity} units left', style: TextStyle(fontSize: 12, color: m.needsRefill ? Colors.orange.shade800 : Colors.black54, fontWeight: m.needsRefill ? FontWeight.w700 : FontWeight.normal)), const Spacer(), if (m.needsRefill) const Text('REFILL SOON', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w800, fontSize: 10))]), if (m.instructions.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 9), child: Text(m.instructions, style: const TextStyle(color: Colors.black54, fontSize: 12))) ]))).toList());
  })]);
}

class InsightsScreen extends StatefulWidget { const InsightsScreen({super.key}); @override State<InsightsScreen> createState() => _InsightsScreenState(); }
class _InsightsScreenState extends State<InsightsScreen> {
  @override Widget build(BuildContext context) => FutureBuilder<List<Object>>(future: Future.wait<Object>([DatabaseService.instance.getMedications(), DatabaseService.instance.getAllLogs()]), builder: (context, snap) {
    if (!snap.hasData) return const Center(child: CircularProgressIndicator());
    final meds = snap.data![0] as List<Medication>; final logs = snap.data![1] as List<DoseLog>;
    final today = dateKey(DateTime.now()); final todayLogs = logs.where((l) => l.scheduledDate == today).toList();
    final taken = logs.where((l) => l.status == 'taken').length; final skipped = logs.where((l) => l.status == 'skipped').length; final missed = logs.where((l) => l.status == 'missed').length;
    final recorded = taken + skipped + missed; final rate = recorded == 0 ? 0.0 : taken / recorded;
    final refill = meds.where((m) => m.isActive && m.needsRefill).length;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 28), children: [const Text('Your insights', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)), const SizedBox(height: 5), const Text('A simple view of your medication routine.', style: TextStyle(color: Colors.black54)), const SizedBox(height: 22), Row(children: [Expanded(child: _statCard('Taken', '$taken', Icons.check_circle_outline, const Color(0xFF0D9488))), const SizedBox(width: 10), Expanded(child: _statCard('Missed', '$missed', Icons.error_outline, Colors.redAccent))]), const SizedBox(height: 10), Row(children: [Expanded(child: _statCard('Skipped', '$skipped', Icons.remove_circle_outline, Colors.orange)), const SizedBox(width: 10), Expanded(child: _statCard('Refills needed', '$refill', Icons.inventory_2_outlined, Colors.blueGrey))]), const SizedBox(height: 20), Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE4EAF0))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Recorded-dose adherence', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 6), Text('${(rate * 100).round()}%', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, color: Color(0xFF0D9488))), const SizedBox(height: 10), ClipRRect(borderRadius: BorderRadius.circular(12), child: LinearProgressIndicator(value: rate, minHeight: 9, backgroundColor: const Color(0xFFE8EEF3))), const SizedBox(height: 8), Text(recorded == 0 ? 'Your statistics will appear after you record doses.' : 'Based on $recorded doses recorded in this app. Skipped and missed doses are not counted as taken.', style: const TextStyle(color: Colors.black54, fontSize: 12))])), const SizedBox(height: 18), Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(22), border: Border.all(color: const Color(0xFFE4EAF0))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Today's activity", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 12), if (todayLogs.isEmpty) const Text('No doses have been recorded today.', style: TextStyle(color: Colors.black54)) else ...todayLogs.map((l) { final med = meds.where((m) => m.id == l.medicationId).firstOrNull; return ListTile(contentPadding: EdgeInsets.zero, leading: Icon(l.status == 'taken' ? Icons.check_circle : l.status == 'missed' ? Icons.error_outline : Icons.remove_circle_outline, color: l.status == 'taken' ? const Color(0xFF0D9488) : l.status == 'missed' ? Colors.redAccent : Colors.orange), title: Text(med?.name ?? 'Medication'), subtitle: Text('${_formatTime(l.scheduledTime)} • ${l.status}'), dense: true); })]))]);
  });
}

class SettingsScreen extends StatelessWidget { const SettingsScreen({super.key}); @override Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [const Text('Settings', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w800)), const SizedBox(height: 5), const Text('Your app preferences and data.', style: TextStyle(color: Colors.black54)), const SizedBox(height: 20), Container(padding: const EdgeInsets.all(17), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE4EAF0))), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(Icons.phone_android, color: Color(0xFF0D9488)), SizedBox(width: 10), Text('Local-first privacy', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]), SizedBox(height: 8), Text('Your medication details and dose history are stored on this device using SQLite. This MVP does not upload your information to a server.'), SizedBox(height: 16), Row(children: [Icon(Icons.notifications_active_outlined, color: Color(0xFF0D9488)), SizedBox(width: 10), Text('Notifications', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]), SizedBox(height: 8), Text('Allow notifications in your device settings. Delivery timing can vary due to operating-system and battery restrictions.'), SizedBox(height: 16), Row(children: [Icon(Icons.health_and_safety_outlined, color: Color(0xFF0D9488)), SizedBox(width: 10), Text('Health disclaimer', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))]), SizedBox(height: 8), Text('This app is a reminder and tracking tool, not medical advice. Follow the instructions from your healthcare professional or medication label.')]))]); }

Future<Medication?> showMedicationForm(BuildContext context, {Medication? medication}) async => showModalBottomSheet<Medication>(context: context, isScrollControlled: true, useSafeArea: true, backgroundColor: const Color(0xFFF7F9FC), builder: (_) => MedicationForm(medication: medication));

class MedicationForm extends StatefulWidget { const MedicationForm({super.key, this.medication}); final Medication? medication; @override State<MedicationForm> createState() => _MedicationFormState(); }
class _MedicationFormState extends State<MedicationForm> {
  final _formKey = GlobalKey<FormState>(); late final TextEditingController _name; late final TextEditingController _dosage; late final TextEditingController _instructions; late final TextEditingController _stock; late final TextEditingController _threshold;
  late String _unit; late DateTime _start; DateTime? _end; late List<String> _times; bool _saving = false;
  @override void initState() { super.initState(); final m = widget.medication; _name = TextEditingController(text: m?.name ?? ''); _dosage = TextEditingController(text: m?.dosage ?? '1'); _instructions = TextEditingController(text: m?.instructions ?? ''); _stock = TextEditingController(text: '${m?.stockQuantity ?? 30}'); _threshold = TextEditingController(text: '${m?.refillThreshold ?? 5}'); _unit = m?.dosageUnit ?? 'tablet(s)'; _start = DateTime.tryParse(m?.startDate ?? '') ?? DateTime.now(); _end = m?.endDate == null ? null : DateTime.tryParse(m!.endDate!); _times = [...(m?.times ?? ['08:00'])]; }
  @override void dispose() { _name.dispose(); _dosage.dispose(); _instructions.dispose(); _stock.dispose(); _threshold.dispose(); super.dispose(); }
  Future<void> _addTime() async { final picked = await showTimePicker(context: context, initialTime: const TimeOfDay(hour: 8, minute: 0)); if (picked != null) { final t = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}'; if (!_times.contains(t)) setState(() { _times.add(t); _times.sort(); }); } }
  Future<void> _pickDate({required bool start}) async { final now = DateTime.now(); final selected = await showDatePicker(context: context, initialDate: start ? _start : (_end ?? _start), firstDate: DateTime(now.year - 5), lastDate: DateTime(now.year + 20)); if (selected != null) setState(() { if (start) _start = selected; else _end = selected; }); }
  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _times.isEmpty) { if (_times.isEmpty) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one reminder time.'))); return; }
    if (_end != null && _end!.isBefore(_start)) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date must be on or after the start date.'))); return; }
    setState(() => _saving = true);
    try {
      final old = widget.medication;
      final med = Medication(id: old?.id, name: _name.text.trim(), dosage: _dosage.text.trim(), dosageUnit: _unit, instructions: _instructions.text.trim(), startDate: dateKey(_start), endDate: _end == null ? null : dateKey(_end!), stockQuantity: int.parse(_stock.text), refillThreshold: int.parse(_threshold.text), times: [..._times], isActive: old?.isActive ?? true);
      final id = await DatabaseService.instance.saveMedication(med);
      final saved = med.copyWith(id: id);
      await NotificationService.instance.scheduleMedication(saved);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save medication: $e'))); }
    finally { if (mounted) setState(() => _saving = false); }
  }
  @override Widget build(BuildContext context) => Padding(padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 20), child: Form(key: _formKey, child: SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Center(child: Container(width: 42, height: 4, decoration: BoxDecoration(color: Colors.black26, borderRadius: BorderRadius.circular(8)))), const SizedBox(height: 18), Text(widget.medication == null ? 'Add medication' : 'Edit medication', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)), const SizedBox(height: 18), TextFormField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Medicine name', prefixIcon: Icon(Icons.medication_outlined)), validator: (v) => v == null || v.trim().isEmpty ? 'Enter a medicine name' : null), const SizedBox(height: 12), Row(children: [Expanded(child: TextFormField(controller: _dosage, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Dose amount', hintText: 'e.g. 1 or 5'), validator: (v) { final n = double.tryParse(v ?? ''); return n == null || n <= 0 ? 'Enter a valid dose' : null; })), const SizedBox(width: 10), Expanded(child: DropdownButtonFormField<String>(value: _unit, decoration: const InputDecoration(labelText: 'Dose unit'), items: const ['tablet(s)', 'capsule(s)', 'mg', 'mL', 'drop(s)', 'puff(s)', 'other'].map((u) => DropdownMenuItem(value: u, child: Text(u, overflow: TextOverflow.ellipsis))).toList(), onChanged: (v) { if (v != null) setState(() => _unit = v); }))]), const SizedBox(height: 12), TextFormField(controller: _instructions, decoration: const InputDecoration(labelText: 'Instructions (optional)', hintText: 'e.g. Take with food'), maxLines: 2), const SizedBox(height: 16), const Text('Reminder times', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8), Wrap(spacing: 8, runSpacing: 4, children: [..._times.map((t) => InputChip(label: Text(_formatTime(t)), onDeleted: _times.length == 1 ? null : () => setState(() => _times.remove(t)), avatar: const Icon(Icons.alarm, size: 16))), ActionChip(avatar: const Icon(Icons.add, size: 16), label: const Text('Add time'), onPressed: _addTime)]), const SizedBox(height: 16), const Text('Medication dates', style: TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 8), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(start: true), icon: const Icon(Icons.calendar_today), label: Text('Starts ${dateKey(_start)}'))), const SizedBox(width: 8), Expanded(child: OutlinedButton.icon(onPressed: () => _pickDate(start: false), icon: const Icon(Icons.event), label: Text(_end == null ? 'No end date' : 'Ends ${dateKey(_end!)}')))]), if (_end != null) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => setState(() => _end = null), child: const Text('Clear end date'))), const SizedBox(height: 16), Row(children: [Expanded(child: TextFormField(controller: _stock, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Current stock'), validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 0 ? 'Use 0 or more' : null)), const SizedBox(width: 10), Expanded(child: TextFormField(controller: _threshold, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Refill alert at'), validator: (v) => int.tryParse(v ?? '') == null || int.parse(v!) < 0 ? 'Use 0 or more' : null))]), const SizedBox(height: 22), SizedBox(width: double.infinity, child: FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: Text(_saving ? 'Saving...' : 'Save medication'), style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 15))))]))));
}

Widget _emptyCard(String title, String subtitle, IconData icon) => Container(width: double.infinity, padding: const EdgeInsets.all(24), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE4EAF0))), child: Column(children: [Icon(icon, size: 36, color: const Color(0xFF0D9488)), const SizedBox(height: 10), Text(title, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54))]));
Widget _statCard(String title, String value, IconData icon, Color color) => Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(19), border: Border.all(color: const Color(0xFFE4EAF0))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), const SizedBox(height: 12), Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), Text(title, style: const TextStyle(color: Colors.black54, fontSize: 12))]));
String _formatTime(String time) { final p = time.split(':'); if (p.length != 2) return time; final h = int.tryParse(p[0]) ?? 0; final m = int.tryParse(p[1]) ?? 0; final hour = h % 12 == 0 ? 12 : h % 12; return '$hour:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}'; }
String _timeKey(DateTime date) => '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String _friendlyDate(DateTime d) { const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday']; const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December']; return '${days[d.weekday - 1]}, ${months[d.month - 1]} ${d.day}'; }
extension<T> on Iterable<T> { T? get firstOrNull { final i = iterator; return i.moveNext() ? i.current : null; } }
```

## Important notes

- All data is stored on the device. There is no cloud sync or automatic backup in this MVP.
- Notifications are scheduled as repeating local notifications; Android battery policies and OS behavior can affect delivery timing. Test on real devices.
- This is a reminder and tracking aid, not medical advice. Users should follow their prescription label and healthcare professional’s instructions. Stock tracking is a simple unit count, not clinical dosing validation.
