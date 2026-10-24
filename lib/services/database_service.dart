import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/dose_log.dart';
import '../models/medication.dart';
import '../models/user_profile.dart';
import '../utils/formatters.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  /// Bumped after every write so screens can listen and reload.
  final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// How far back unrecorded doses are auto-marked as missed.
  static const _missedLookbackDays = 14;

  /// Grace period after a scheduled time before a dose counts as missed.
  static const missedGrace = Duration(minutes: 60);

  Future<Database>? _dbFuture;
  Future<Database> get database => _dbFuture ??= _open();

  void _notify() => changes.value++;

  Future<Database> _open() async {
    final base = await getDatabasesPath();
    return openDatabase(
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
            is_active INTEGER NOT NULL DEFAULT 1,
            tracking_since TEXT
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
        await db.execute('''
          CREATE TABLE user_profile (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            avatar_path TEXT NOT NULL,
            health_goal TEXT NOT NULL,
            wake_time TEXT NOT NULL,
            bedtime TEXT NOT NULL,
            sound_enabled INTEGER NOT NULL DEFAULT 1,
            vibration_enabled INTEGER NOT NULL DEFAULT 1,
            emergency_contact TEXT,
            is_setup_completed INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
      onOpen: (db) async {
        await db.execute('''
          CREATE TABLE IF NOT EXISTS user_profile (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            email TEXT NOT NULL,
            avatar_path TEXT NOT NULL,
            health_goal TEXT NOT NULL,
            wake_time TEXT NOT NULL,
            bedtime TEXT NOT NULL,
            sound_enabled INTEGER NOT NULL DEFAULT 1,
            vibration_enabled INTEGER NOT NULL DEFAULT 1,
            emergency_contact TEXT,
            is_setup_completed INTEGER NOT NULL DEFAULT 0
          )
        ''');
        try {
          await db.execute('ALTER TABLE user_profile ADD COLUMN is_setup_completed INTEGER NOT NULL DEFAULT 0');
        } catch (_) {}
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Medications
  // ---------------------------------------------------------------------------

  Future<List<Medication>> getMedications({bool activeOnly = false}) async {
    final db = await database;
    final rows = await db.query(
      'medications',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'is_active DESC, name COLLATE NOCASE ASC',
    );
    return rows.map(Medication.fromMap).toList();
  }

  /// Inserts or updates a medication. Returns the saved row with its id.
  Future<Medication> saveMedication(Medication medication) async {
    final db = await database;
    final toSave = medication.copyWith(trackingSince: DateTime.now().toIso8601String());
    if (toSave.id == null) {
      final id = await db.insert('medications', toSave.toMap()..remove('id'));
      _notify();
      return toSave.copyWith(id: id);
    }
    await db.update('medications', toSave.toMap(), where: 'id = ?', whereArgs: [toSave.id]);
    _notify();
    return toSave;
  }

  Future<void> setActive(int id, bool active) async {
    final db = await database;
    await db.update(
      'medications',
      {'is_active': active ? 1 : 0, 'tracking_since': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
    _notify();
  }

  Future<void> deleteMedication(int id) async {
    final db = await database;
    await db.delete('medications', where: 'id = ?', whereArgs: [id]);
    _notify();
  }

  Future<void> addRefill(int medicationId, int quantity) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.rawUpdate(
        'UPDATE medications SET stock_quantity = stock_quantity + ? WHERE id = ?',
        [quantity, medicationId],
      );
      await txn.insert('refill_logs', {
        'medication_id': medicationId,
        'quantity_added': quantity,
        'recorded_at': DateTime.now().toIso8601String(),
      });
    });
    _notify();
  }

  Future<int> getRefillCount() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT COUNT(*) AS count FROM medications WHERE is_active = 1 AND stock_quantity <= refill_threshold',
    );
    return Sqflite.firstIntValue(rows) ?? 0;
  }

  // ---------------------------------------------------------------------------
  // Dose logs
  // ---------------------------------------------------------------------------

  Future<List<DoseLog>> getLogsForDate(String date) async {
    final db = await database;
    final rows = await db.query('dose_logs', where: 'scheduled_date = ?', whereArgs: [date]);
    return rows.map(DoseLog.fromMap).toList();
  }

  Future<List<DoseLog>> getAllLogs() async {
    final db = await database;
    final rows = await db.query('dose_logs', orderBy: 'scheduled_date DESC, scheduled_time DESC');
    return rows.map(DoseLog.fromMap).toList();
  }

  /// Records a dose as taken/skipped. Stock is deducted when a dose becomes
  /// "taken" and restored if it is changed away from "taken".
  Future<void> recordDose({
    required Medication medication,
    required String date,
    required String time,
    required String status,
  }) async {
    final db = await database;
    final units = medication.unitsPerDose;
    await db.transaction((txn) async {
      final existing = await txn.query(
        'dose_logs',
        where: 'medication_id = ? AND scheduled_date = ? AND scheduled_time = ?',
        whereArgs: [medication.id, date, time],
        limit: 1,
      );
      final previousStatus = existing.isEmpty ? null : existing.first['status'] as String;
      if (previousStatus == status) return;

      if (previousStatus != DoseStatus.taken && status == DoseStatus.taken) {
        await txn.rawUpdate(
          'UPDATE medications SET stock_quantity = MAX(0, stock_quantity - ?) WHERE id = ?',
          [units, medication.id],
        );
      } else if (previousStatus == DoseStatus.taken && status != DoseStatus.taken) {
        await txn.rawUpdate(
          'UPDATE medications SET stock_quantity = stock_quantity + ? WHERE id = ?',
          [units, medication.id],
        );
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
        await txn.update('dose_logs', values, where: 'id = ?', whereArgs: [existing.first['id']]);
      }
    });
    _notify();
  }

  /// Marks unrecorded doses older than [missedGrace] as missed, looking back
  /// up to [_missedLookbackDays] days. Doses scheduled before a medication's
  /// last schedule change ([Medication.trackingSince]) are ignored.
  Future<void> markPastDosesMissed() async {
    final now = DateTime.now();
    final cutoff = now.subtract(missedGrace);
    final today = DateTime(now.year, now.month, now.day);
    final db = await database;
    final meds = await getMedications(activeOnly: true);
    var inserted = 0;

    await db.transaction((txn) async {
      for (final med in meds) {
        if (med.id == null) continue;
        final start = DateTime.tryParse(med.startDate);
        if (start == null) continue;
        final since = DateTime.tryParse(med.trackingSince ?? '') ?? now;

        var day = today.subtract(const Duration(days: _missedLookbackDays));
        if (start.isAfter(day)) day = start;

        while (!day.isAfter(today)) {
          final key = dateKey(day);
          if (med.isScheduledOn(key)) {
            for (final time in med.times) {
              final hm = parseTime(time);
              if (hm == null) continue;
              final scheduled = DateTime(day.year, day.month, day.day, hm.$1, hm.$2);
              if (!scheduled.isBefore(cutoff) || scheduled.isBefore(since)) continue;
              final existing = await txn.query(
                'dose_logs',
                columns: ['id'],
                where: 'medication_id = ? AND scheduled_date = ? AND scheduled_time = ?',
                whereArgs: [med.id, key, time],
                limit: 1,
              );
              if (existing.isEmpty) {
                await txn.insert('dose_logs', {
                  'medication_id': med.id,
                  'scheduled_date': key,
                  'scheduled_time': time,
                  'status': DoseStatus.missed,
                  'recorded_at': now.toIso8601String(),
                });
                inserted++;
              }
            }
          }
          day = DateTime(day.year, day.month, day.day + 1);
        }
      }
    });

    // Only notify when something changed, to avoid reload loops.
    if (inserted > 0) _notify();
  }

  // ---------------------------------------------------------------------------
  // User Profile
  // ---------------------------------------------------------------------------

  Future<UserProfile> getUserProfile() async {
    final db = await database;
    final rows = await db.query('user_profile', where: 'id = 1', limit: 1);
    if (rows.isNotEmpty) {
      return UserProfile.fromMap(rows.first);
    }
    return const UserProfile();
  }

  Future<void> saveUserProfile(UserProfile profile) async {
    final db = await database;
    await db.insert(
      'user_profile',
      profile.toMap()..['id'] = 1,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    _notify();
  }

  Future<bool> hasCompletedSetup() async {
    final db = await database;
    try {
      final rows = await db.query('user_profile', where: 'id = 1', limit: 1);
      if (rows.isEmpty) return false;
      return (rows.first['is_setup_completed'] as int? ?? 0) == 1;
    } catch (_) {
      return false;
    }
  }

  // ---------------------------------------------------------------------------
  // Maintenance
  // ---------------------------------------------------------------------------

  Future<void> deleteAllData() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('dose_logs');
      await txn.delete('refill_logs');
      await txn.delete('medications');
      await txn.delete('user_profile');
    });
    _notify();
  }
}
