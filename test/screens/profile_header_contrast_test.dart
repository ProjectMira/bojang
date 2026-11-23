import 'package:bojang/screens/profile_screen.dart';
import 'package:bojang/services/google_auth_service.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/theme/app_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

class _GuestAuth extends Fake implements GoogleAuthService {
  @override
  get currentUser => null;
  @override
  bool get isSignedIn => false;
}

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('header pill text reads at 4.5:1 in ${brightness.name} mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const Scaffold(
            body: ProfileHeaderPill(text: 'Silver League • 120 XP'),
          ),
        ),
      );
      final box = tester.widget<Container>(
        find.descendant(
          of: find.byType(ProfileHeaderPill),
          matching: find.byType(Container),
        ),
      );
      final fill = (box.decoration! as BoxDecoration).color!;
      final text = tester.widget<Text>(find.text('Silver League • 120 XP'));
      final ratio = contrast(text.style!.color!, fill);
      expect(ratio, greaterThanOrEqualTo(4.5), reason: 'got $ratio');
    });
  }

  test('white header text on the solid blue reads at 4.5:1', () {
    expect(
      contrast(Colors.white, AppColors.primary),
      greaterThanOrEqualTo(4.5),
    );
  });

  testWidgets('league label sits in a pill on a solid blue header', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Bojang',
      packageName: 'com.bojang.app',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<GoogleAuthService>.value(value: _GuestAuth()),
          ChangeNotifierProvider<ProgressService>.value(
            value: ProgressService(),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pump();

    final header = tester.widget<Container>(
      find.byKey(const Key('profile-header')),
    );
    final decoration = header.decoration! as BoxDecoration;
    expect(decoration.color, AppColors.primary);
    expect(decoration.gradient, isNull);
    expect(
      find.descendant(
        of: find.byKey(const Key('profile-league-pill')),
        matching: find.textContaining('League'),
      ),
      findsOneWidget,
    );
  });
}
