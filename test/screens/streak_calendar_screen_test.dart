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

  testWidgets('shows flames for practiced days and plain missed days', (
    tester,
  ) async {
    await pumpCalendar(tester, [
      DateTime(2026, 11, 18).toIso8601String(),
      DateTime(2026, 11, 19).toIso8601String(),
    ]);

    expect(find.text('November 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('November 18, practiced'), findsOneWidget);
    expect(find.bySemanticsLabel('November 20, not practiced'), findsOneWidget);
    expect(
      find.bySemanticsLabel('November 21, today, not practiced yet'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel('November 17, before you started'),
      findsOneWidget,
    );
    // Summary tiles: 2 days this month, 2 in total.
    expect(find.text('Days this month'), findsOneWidget);
    expect(find.text('Days in total'), findsOneWidget);
    // Ice only in the legend: a missed day without a freeze is not ice.
    expect(find.byIcon(Icons.ac_unit), findsOneWidget);
  });

  testWidgets('can page back to earlier months but not past the start', (
    tester,
  ) async {
    await pumpCalendar(tester, [DateTime(2026, 10, 30).toIso8601String()]);

    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);
    expect(find.bySemanticsLabel('October 30, practiced'), findsOneWidget);
    expect(find.bySemanticsLabel('October 31, not practiced'), findsOneWidget);

    // October is the first month: going back further does nothing.
    await tester.tap(find.byTooltip('Previous month'));
    await tester.pumpAndSettle();
    expect(find.text('October 2026'), findsOneWidget);

    await tester.tap(find.byTooltip('Next month'));
    await tester.pumpAndSettle();
    expect(find.text('November 2026'), findsOneWidget);
  });
}
