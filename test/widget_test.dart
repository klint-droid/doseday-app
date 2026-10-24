import 'package:flutter_test/flutter_test.dart';
import 'package:medication_reminder/models/medication.dart';
import 'package:medication_reminder/models/user_profile.dart';
import 'package:medication_reminder/utils/formatters.dart';

void main() {
  group('formatters', () {
    test('formatTime converts 24h to 12h', () {
      expect(formatTime('00:05'), '12:05 AM');
      expect(formatTime('08:30'), '8:30 AM');
      expect(formatTime('12:00'), '12:00 PM');
      expect(formatTime('21:45'), '9:45 PM');
    });

    test('dateKey pads values', () {
      expect(dateKey(DateTime(2026, 3, 7)), '2026-03-07');
    });
  });

  group('Medication', () {
    const med = Medication(
      id: 1,
      name: 'Amoxicillin',
      dosage: '2',
      dosageUnit: 'tablet(s)',
      startDate: '2026-10-01',
      endDate: '2026-10-10',
      stockQuantity: 5,
      refillThreshold: 5,
      times: ['08:00', '20:00'],
    );

    test('round-trips through a database map', () {
      final copy = Medication.fromMap(med.toMap());
      expect(copy.name, med.name);
      expect(copy.times, med.times);
      expect(copy.endDate, med.endDate);
    });

    test('needsRefill and unitsPerDose', () {
      expect(med.needsRefill, isTrue);
      expect(med.unitsPerDose, 2);
      expect(med.copyWith(dosageUnit: 'mg', dosage: '500').unitsPerDose, 1);
    });

    test('isScheduledOn respects start/end dates and active flag', () {
      expect(med.isScheduledOn('2026-09-30'), isFalse);
      expect(med.isScheduledOn('2026-10-05'), isTrue);
      expect(med.isScheduledOn('2026-10-11'), isFalse);
      expect(med.copyWith(isActive: false).isScheduledOn('2026-10-05'), isFalse);
    });
  });

  group('UserProfile', () {
    test('round-trips through map', () {
      const profile = UserProfile(
        name: 'Dr. John Doe',
        email: 'john@example.com',
        avatarPath: 'assets/images/app_logo.png',
        healthGoal: 'Build healthy routine & vitamins',
        wakeTime: '07:30 AM',
        bedtime: '11:00 PM',
        isSetupCompleted: true,
      );

      final map = profile.toMap();
      final restored = UserProfile.fromMap(map);

      expect(restored.name, 'Dr. John Doe');
      expect(restored.email, 'john@example.com');
      expect(restored.avatarPath, 'assets/images/app_logo.png');
      expect(restored.healthGoal, 'Build healthy routine & vitamins');
      expect(restored.wakeTime, '07:30 AM');
      expect(restored.bedtime, '11:00 PM');
      expect(restored.isSetupCompleted, isTrue);
    });
  });

  group('Weekly Schedule calculations', () {
    test('Monday is always start of week and Sunday is end of week', () {
      // Test Saturday Oct 24, 2026
      final sat = DateTime(2026, 10, 24);
      expect(sat.weekday, DateTime.saturday); // 6
      final monday = sat.subtract(Duration(days: sat.weekday - 1));
      expect(monday.weekday, DateTime.monday); // 1
      expect(monday.day, 19);

      final weekDays = List.generate(7, (i) => monday.add(Duration(days: i)));
      expect(weekDays.first.weekday, DateTime.monday);
      expect(weekDays.last.weekday, DateTime.sunday);
      expect(weekDays[5].day, 24); // Saturday is index 5
      expect(weekDays[6].day, 25); // Sunday is index 6

      // Next week (+1 offset)
      final nextMonday = monday.add(const Duration(days: 7));
      expect(nextMonday.weekday, DateTime.monday);
      expect(nextMonday.day, 26);
      final nextWeekDays = List.generate(7, (i) => nextMonday.add(Duration(days: i)));
      expect(nextWeekDays.first.weekday, DateTime.monday);
      expect(nextWeekDays.last.weekday, DateTime.sunday);
      expect(nextWeekDays.last.day, 1); // Nov 1
    });
  });
}
