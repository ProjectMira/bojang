import 'package:bojang/utils/streak_rules.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final today = DateTime(2026, 11, 21, 15);
  DateTime ago(int days) => DateTime(2026, 11, 21 - days, 9);

  StreakUpdate apply(int streak, DateTime? last, {int freezes = 0}) =>
      StreakRules.apply(
        streak: streak,
        lastActive: last,
        freezes: freezes,
        today: today,
      );

  test('yesterday extends without spending a freeze', () {
    final u = apply(4, ago(1), freezes: 1);
    expect([u.streak, u.extended, u.freezes], [5, true, 1]);
    expect(u.frozenDays, isEmpty);
  });

  test('a freeze covers one missed day', () {
    final u = apply(4, ago(2), freezes: 1);
    expect([u.streak, u.freezes], [5, 0]);
    expect(u.frozenDays, [DateTime(2026, 11, 20)]);
  });

  test('two missed days need two freezes', () {
    final u = apply(10, ago(3), freezes: 2);
    expect([u.streak, u.freezes], [11, 0]);
    expect(u.frozenDays, [DateTime(2026, 11, 19), DateTime(2026, 11, 20)]);
  });

  test('too many missed days restarts and keeps the freezes', () {
    final u = apply(10, ago(4), freezes: 2);
    expect([u.streak, u.freezes], [1, 2]);
    expect(u.frozenDays, isEmpty);
  });

  test('a freeze is earned every 7th day, at most 2 held', () {
    expect(apply(6, ago(1)).freezeEarned, isTrue);
    expect(apply(6, ago(1)).freezes, 1);
    expect(apply(13, ago(1), freezes: 1).freezes, 2);
    final full = apply(20, ago(1), freezes: 2);
    expect([full.streak, full.freezes, full.freezeEarned], [21, 2, false]);
  });

  test('same day changes nothing', () {
    final u = apply(5, DateTime(2026, 11, 21, 7), freezes: 1);
    expect([u.streak, u.extended, u.freezes], [5, false, 1]);
  });

  test('first ever practice starts at 1', () {
    final u = apply(0, null);
    expect([u.streak, u.extended], [1, true]);
  });

  test('a lapsed streak of 0 is not revived by freezes', () {
    final u = apply(0, ago(2), freezes: 2);
    expect([u.streak, u.freezes], [1, 2]);
  });

  test('next goal steps up through the list', () {
    expect(StreakRules.nextGoal(7), 14);
    expect(StreakRules.nextGoal(30), 50);
    expect(StreakRules.nextGoal(365), isNull);
  });
}
