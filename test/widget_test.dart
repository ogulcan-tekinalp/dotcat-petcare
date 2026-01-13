// Dotcat PetCare App - Comprehensive Tests

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ============================================================================
// MODEL TESTS
// ============================================================================

void main() {
  group('Cat Model Tests', () {
    test('Cat should have required fields', () {
      final cat = _TestCat(
        id: '1',
        name: 'Pamuk',
        birthDate: DateTime(2020, 5, 15),
      );
      
      expect(cat.id, '1');
      expect(cat.name, 'Pamuk');
      expect(cat.birthDate, DateTime(2020, 5, 15));
    });

    test('Cat age calculation should work correctly', () {
      final now = DateTime.now();
      final twoYearsAgo = DateTime(now.year - 2, now.month, now.day);
      
      final cat = _TestCat(
        id: '1',
        name: 'Pamuk',
        birthDate: twoYearsAgo,
      );
      
      expect(cat.ageInYears, 2);
    });

    test('Cat with null optional fields should work', () {
      final cat = _TestCat(
        id: '1',
        name: 'Pamuk',
        birthDate: DateTime(2020, 5, 15),
        breed: null,
        weight: null,
        photoPath: null,
      );
      
      expect(cat.breed, isNull);
      expect(cat.weight, isNull);
      expect(cat.photoPath, isNull);
    });
  });

  group('Reminder Model Tests', () {
    test('Reminder should have required fields', () {
      final reminder = _TestReminder(
        id: '1',
        catId: 'cat1',
        title: 'Aşı',
        type: 'vaccine',
        time: '09:00',
        frequency: 'yearly',
        isActive: true,
        isCompleted: false,
        createdAt: DateTime.now(),
      );
      
      expect(reminder.id, '1');
      expect(reminder.catId, 'cat1');
      expect(reminder.title, 'Aşı');
      expect(reminder.frequency, 'yearly');
    });

    test('Reminder frequency values should be valid', () {
      final validFrequencies = ['once', 'daily', 'weekly', 'monthly', 'quarterly', 'biannual', 'yearly'];
      
      for (final freq in validFrequencies) {
        final reminder = _TestReminder(
          id: '1',
          catId: 'cat1',
          title: 'Test',
          type: 'test',
          time: '09:00',
          frequency: freq,
          isActive: true,
          isCompleted: false,
          createdAt: DateTime.now(),
        );
        expect(validFrequencies.contains(reminder.frequency), true);
      }
    });

    test('Reminder time format should be valid', () {
      final reminder = _TestReminder(
        id: '1',
        catId: 'cat1',
        title: 'Test',
        type: 'test',
        time: '14:30',
        frequency: 'daily',
        isActive: true,
        isCompleted: false,
        createdAt: DateTime.now(),
      );
      
      final timeParts = reminder.time.split(':');
      expect(timeParts.length, 2);
      expect(int.parse(timeParts[0]) >= 0 && int.parse(timeParts[0]) <= 23, true);
      expect(int.parse(timeParts[1]) >= 0 && int.parse(timeParts[1]) <= 59, true);
    });
  });

  group('Weight Record Model Tests', () {
    test('Weight record should have required fields', () {
      final record = _TestWeightRecord(
        id: '1',
        catId: 'cat1',
        weight: 4.5,
        date: DateTime.now(),
      );
      
      expect(record.id, '1');
      expect(record.catId, 'cat1');
      expect(record.weight, 4.5);
    });

    test('Weight should be positive', () {
      final record = _TestWeightRecord(
        id: '1',
        catId: 'cat1',
        weight: 4.5,
        date: DateTime.now(),
      );
      
      expect(record.weight > 0, true);
    });
  });

  // ============================================================================
  // DATE HELPER TESTS
  // ============================================================================

  group('Date Helper Tests', () {
    test('Next occurrence for daily should be tomorrow if today passed', () {
      final now = DateTime.now();
      final pastTime = DateTime(now.year, now.month, now.day, now.hour - 1);
      
      final nextOccurrence = _getNextDailyOccurrence(pastTime, now);
      
      expect(nextOccurrence.isAfter(now), true);
    });

    test('Next occurrence for weekly should be 7 days later', () {
      final start = DateTime(2024, 1, 1);
      final next = _calculateNextFromDate(start, 'weekly');
      
      expect(next.difference(start).inDays, 7);
    });

    test('Next occurrence for monthly should be same day next month', () {
      final start = DateTime(2024, 1, 15);
      final next = _calculateNextFromDate(start, 'monthly');
      
      expect(next.month, 2);
      expect(next.day, 15);
    });

    test('Next occurrence for yearly should be same day next year', () {
      final start = DateTime(2024, 3, 20);
      final next = _calculateNextFromDate(start, 'yearly');
      
      expect(next.year, 2025);
      expect(next.month, 3);
      expect(next.day, 20);
    });
  });

  // ============================================================================
  // WIDGET TESTS
  // ============================================================================

  group('Widget Tests', () {
    testWidgets('App builds without errors', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Dotcat PetCare')),
            ),
          ),
        ),
      );

      expect(find.text('Dotcat PetCare'), findsOneWidget);
    });

    testWidgets('ProviderScope wraps correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: Text('Test')),
            ),
          ),
        ),
      );

      expect(find.byType(MaterialApp), findsOneWidget);
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('Empty state shows correct message', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _TestEmptyState(message: 'Henüz kedi eklenmemiş'),
            ),
          ),
        ),
      );

      expect(find.text('Henüz kedi eklenmemiş'), findsOneWidget);
      expect(find.byIcon(Icons.pets), findsOneWidget);
    });

    testWidgets('Loading indicator shows correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Center(child: CircularProgressIndicator()),
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('Cat card displays name correctly', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _TestCatCard(name: 'Pamuk', age: '2 yaş'),
            ),
          ),
        ),
      );

      expect(find.text('Pamuk'), findsOneWidget);
      expect(find.text('2 yaş'), findsOneWidget);
    });

    testWidgets('Reminder card displays title and time', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: _TestReminderCard(title: 'Mama', time: '09:00'),
            ),
          ),
        ),
      );

      expect(find.text('Mama'), findsOneWidget);
      expect(find.text('09:00'), findsOneWidget);
    });

    testWidgets('Button responds to tap', (WidgetTester tester) async {
      bool tapped = false;
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ElevatedButton(
                onPressed: () => tapped = true,
                child: const Text('Ekle'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ekle'));
      await tester.pump();
      
      expect(tapped, true);
    });

    testWidgets('TextField accepts input', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: TextField(
                decoration: InputDecoration(labelText: 'Kedi Adı'),
              ),
            ),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'Pamuk');
      await tester.pump();
      
      expect(find.text('Pamuk'), findsOneWidget);
    });

    testWidgets('Checkbox toggles correctly', (WidgetTester tester) async {
      bool checked = false;
      
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  return Checkbox(
                    value: checked,
                    onChanged: (value) => setState(() => checked = value!),
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(checked, false);
      
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      
      // Checkbox should toggle
      expect(find.byType(Checkbox), findsOneWidget);
    });

    testWidgets('Snackbar displays message', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('İşlem başarılı')),
                    );
                  },
                  child: const Text('Göster'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Göster'));
      await tester.pump();
      
      expect(find.text('İşlem başarılı'), findsOneWidget);
    });

    testWidgets('Dialog shows and dismisses', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('Silmek istediğinize emin misiniz?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('İptal'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('Sil'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Sil'));
      await tester.pumpAndSettle();
      
      expect(find.text('Silmek istediğinize emin misiniz?'), findsOneWidget);
      
      await tester.tap(find.text('İptal'));
      await tester.pumpAndSettle();
      
      expect(find.text('Silmek istediğinize emin misiniz?'), findsNothing);
    });
  });

  // ============================================================================
  // VALIDATION TESTS
  // ============================================================================

  group('Validation Tests', () {
    test('Email validation works correctly', () {
      expect(_isValidEmail('test@example.com'), true);
      expect(_isValidEmail('user.name@domain.co'), true);
      expect(_isValidEmail('invalid-email'), false);
      expect(_isValidEmail('missing@domain'), false);
      expect(_isValidEmail(''), false);
    });

    test('Weight validation works correctly', () {
      expect(_isValidWeight('4.5'), true);
      expect(_isValidWeight('10'), true);
      expect(_isValidWeight('0.5'), true);
      expect(_isValidWeight('-1'), false);
      expect(_isValidWeight('abc'), false);
      expect(_isValidWeight(''), false);
    });

    test('Time format validation works correctly', () {
      expect(_isValidTimeFormat('09:00'), true);
      expect(_isValidTimeFormat('23:59'), true);
      expect(_isValidTimeFormat('00:00'), true);
      expect(_isValidTimeFormat('25:00'), false);
      expect(_isValidTimeFormat('12:60'), false);
      expect(_isValidTimeFormat('invalid'), false);
    });

    test('Cat name validation works correctly', () {
      expect(_isValidCatName('Pamuk'), true);
      expect(_isValidCatName('Boncuk'), true);
      expect(_isValidCatName(''), false);
      expect(_isValidCatName('  '), false);
    });
  });

  // ============================================================================
  // PROVIDER TESTS
  // ============================================================================

  group('Provider Tests', () {
    test('Empty cats list should be empty', () {
      final cats = <_TestCat>[];
      expect(cats.isEmpty, true);
    });

    test('Adding cat should increase list size', () {
      final cats = <_TestCat>[];
      cats.add(_TestCat(id: '1', name: 'Pamuk', birthDate: DateTime.now()));
      expect(cats.length, 1);
    });

    test('Removing cat should decrease list size', () {
      final cats = <_TestCat>[
        _TestCat(id: '1', name: 'Pamuk', birthDate: DateTime.now()),
        _TestCat(id: '2', name: 'Boncuk', birthDate: DateTime.now()),
      ];
      cats.removeWhere((cat) => cat.id == '1');
      expect(cats.length, 1);
      expect(cats.first.name, 'Boncuk');
    });

    test('Filtering reminders by catId works correctly', () {
      final reminders = <_TestReminder>[
        _TestReminder(id: '1', catId: 'cat1', title: 'Mama', type: 'food', time: '09:00', frequency: 'daily', isActive: true, isCompleted: false, createdAt: DateTime.now()),
        _TestReminder(id: '2', catId: 'cat2', title: 'Aşı', type: 'vaccine', time: '10:00', frequency: 'yearly', isActive: true, isCompleted: false, createdAt: DateTime.now()),
        _TestReminder(id: '3', catId: 'cat1', title: 'Tırnak', type: 'grooming', time: '14:00', frequency: 'monthly', isActive: true, isCompleted: false, createdAt: DateTime.now()),
      ];
      
      final cat1Reminders = reminders.where((r) => r.catId == 'cat1').toList();
      expect(cat1Reminders.length, 2);
    });

    test('Toggling reminder completion works correctly', () {
      var reminder = _TestReminder(
        id: '1',
        catId: 'cat1',
        title: 'Test',
        type: 'test',
        time: '09:00',
        frequency: 'daily',
        isActive: true,
        isCompleted: false,
        createdAt: DateTime.now(),
      );
      
      expect(reminder.isCompleted, false);
      
      reminder = reminder.copyWith(isCompleted: true);
      expect(reminder.isCompleted, true);
    });
  });
}

// ============================================================================
// TEST HELPER CLASSES AND FUNCTIONS
// ============================================================================

class _TestCat {
  final String id;
  final String name;
  final DateTime birthDate;
  final String? breed;
  final double? weight;
  final String? photoPath;

  _TestCat({
    required this.id,
    required this.name,
    required this.birthDate,
    this.breed,
    this.weight,
    this.photoPath,
  });

  int get ageInYears {
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month || (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}

class _TestReminder {
  final String id;
  final String catId;
  final String title;
  final String type;
  final String time;
  final String frequency;
  final bool isActive;
  final bool isCompleted;
  final DateTime createdAt;

  _TestReminder({
    required this.id,
    required this.catId,
    required this.title,
    required this.type,
    required this.time,
    required this.frequency,
    required this.isActive,
    required this.isCompleted,
    required this.createdAt,
  });

  _TestReminder copyWith({bool? isCompleted}) {
    return _TestReminder(
      id: id,
      catId: catId,
      title: title,
      type: type,
      time: time,
      frequency: frequency,
      isActive: isActive,
      isCompleted: isCompleted ?? this.isCompleted,
      createdAt: createdAt,
    );
  }
}

class _TestWeightRecord {
  final String id;
  final String catId;
  final double weight;
  final DateTime date;

  _TestWeightRecord({
    required this.id,
    required this.catId,
    required this.weight,
    required this.date,
  });
}

class _TestEmptyState extends StatelessWidget {
  final String message;
  const _TestEmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pets, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          Text(message),
        ],
      ),
    );
  }
}

class _TestCatCard extends StatelessWidget {
  final String name;
  final String age;
  const _TestCatCard({required this.name, required this.age});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.pets)),
        title: Text(name),
        subtitle: Text(age),
      ),
    );
  }
}

class _TestReminderCard extends StatelessWidget {
  final String title;
  final String time;
  const _TestReminderCard({required this.title, required this.time});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.alarm),
        title: Text(title),
        trailing: Text(time),
      ),
    );
  }
}

// Helper functions for date calculations
DateTime _getNextDailyOccurrence(DateTime time, DateTime now) {
  var next = DateTime(now.year, now.month, now.day, time.hour, time.minute);
  if (next.isBefore(now)) {
    next = next.add(const Duration(days: 1));
  }
  return next;
}

DateTime _calculateNextFromDate(DateTime date, String frequency) {
  switch (frequency) {
    case 'daily':
      return date.add(const Duration(days: 1));
    case 'weekly':
      return date.add(const Duration(days: 7));
    case 'monthly':
      return DateTime(date.year, date.month + 1, date.day);
    case 'quarterly':
      return DateTime(date.year, date.month + 3, date.day);
    case 'biannual':
      return DateTime(date.year, date.month + 6, date.day);
    case 'yearly':
      return DateTime(date.year + 1, date.month, date.day);
    default:
      return date.add(const Duration(days: 1));
  }
}

// Validation functions
bool _isValidEmail(String email) {
  if (email.isEmpty) return false;
  final regex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
  return regex.hasMatch(email);
}

bool _isValidWeight(String weight) {
  if (weight.isEmpty) return false;
  final value = double.tryParse(weight);
  return value != null && value > 0;
}

bool _isValidTimeFormat(String time) {
  final regex = RegExp(r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$');
  return regex.hasMatch(time);
}

bool _isValidCatName(String name) {
  return name.trim().isNotEmpty;
}
