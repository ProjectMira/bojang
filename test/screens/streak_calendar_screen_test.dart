import 'package:bojang/screens/streak_calendar_screen.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  Future<void> pumpCalendar(WidgetTester tester, List<String> playDates) async {
    SharedPreferences.setMockInitialValues({'play_dates': playDates});
    final progress = ProgressService(
      isSignedIn: () => false,
      recordActivity: (_) async => null,
    );
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: progress,
        child: MaterialApp(
          home: StreakCalendarScreen(now: DateTime(2026, 11, 21, 15)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows flames for practiced days and ice for missed ones', (
    tester,
  ) async {
    await pumpCalendar(tester, [
      DateTime(2026, 11, 18).toIso8601String(),
      DateTime(2026, 11, 19).toIso8601String(),
    ]);

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('November 18, practiced'), findsOneWidget);
    expect(find.bySemanticsLabel('November 20, missed'), findsOneWidget);
    expect(
      find.bySemanticsLabel('November 21, today, not practiced yet'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('November 17, before you started'),
      findsOneWidget,
    );
    // Summary tiles: 2 practiced, 1 frozen (the 20th).
    expect(find.text('Days practiced'), findsOneWidget);
    expect(find.text('Day frozen'), findsOneWidget);
  });

  testWidgets('can page back to earlier months but not past the start', (
    tester,
  ) async {
    await pumpCalendar(tester, [DateTime(2026, 10, 30).toIso8601String()]);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('October 30, practiced'), findsOneWidget);
    expect(find.bySemanticsLabel('October 31, missed'), findsOneWidget);

    // October is the first month: going back further does nothing.
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
  });
}
