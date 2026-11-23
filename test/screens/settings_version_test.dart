import 'package:bojang/screens/settings_screen.dart';
import 'package:bojang/services/api_service.dart';
import 'package:bojang/services/google_auth_service.dart';
import 'package:bojang/services/progress_service.dart';
import 'package:bojang/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _GuestAuth extends Fake implements GoogleAuthService {
  @override
  bool get isSignedIn => false;
}

class _NoApi extends Fake implements ApiService {}

void main() {
  group('versionLabel', () {
    PackageInfo info(String version, String build) => PackageInfo(
      appName: 'Bojang',
      packageName: 'com.bojang.app',
      version: version,
      buildNumber: build,
    );

    test('shows version and build number', () {
      expect(versionLabel(info('2.17.0', '22')), 'Version 2.17.0 (22)');
    });

    test('drops an empty build number', () {
      expect(versionLabel(info('2.17.0', '')), 'Version 2.17.0');
    });

    test('falls back to a bare label before the info loads', () {
      expect(versionLabel(null), 'Version');
      expect(versionLabel(info('', '')), 'Version');
    });
  });

  testWidgets('Settings shows the installed version, not a literal', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Bojang',
      packageName: 'com.bojang.app',
      version: '9.8.7',
      buildNumber: '654',
      buildSignature: '',
    );
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeService>.value(value: ThemeService()),
          ChangeNotifierProvider<ProgressService>.value(
            value: ProgressService(),
          ),
          Provider<GoogleAuthService>.value(value: _GuestAuth()),
          Provider<ApiService>.value(value: _NoApi()),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Version 2.0.0'), findsNothing);
    final label = find.text('Version 9.8.7 (654)');
    await tester.ensureVisible(label);
    expect(label, findsOneWidget);

    await tester.tap(find.text('About Bojang'));
    await tester.pumpAndSettle();
    expect(find.text('Version 9.8.7 (654)'), findsNWidgets(2));
  });
}
