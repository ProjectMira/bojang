// Profile, leaderboard, Settings and account journeys (see TESTING.md).
//
//   ci/scripts/e2e.sh integration_test/journeys_profile_test.dart
//
// Each journey starts as a fresh install with onboarding skipped, so the
// learner is on an anonymous Firebase (emulator) account.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_location.dart';
import 'support/harness.dart';

/// Fresh install, onboarding skipped, motion and sound effects off.
Future<void> _start(WidgetTester tester) async {
  installFakeLocation();
  await launchApp(
    tester,
    seed: (prefs) async {
      await prefs.setString('onboarding_status', 'skipped');
      await prefs.setString('animation_preference', 'off');
      await prefs.setBool('sound_effects_enabled', false);
    },
  );
  await waitFor(
    tester,
    find.text('Profile'),
    timeout: 30,
    reason: 'main navigation',
  );
  // The anonymous account reaches the backend during the splash screen.
  final end = DateTime.now().add(const Duration(seconds: 20));
  while (DateTime.now().isBefore(end)) {
    if (myUid() != null && await backendGetAsMe('auth/me') != null) return;
    await wait(tester, 0.5);
  }
  fail('anonymous emulator account never synced with the backend');
}

Future<void> _openProfileTab(WidgetTester tester) async {
  await tapIt(tester, find.text('Profile').last, settle: 1.5);
  await waitFor(
    tester,
    find.byKey(const Key('profile-header')),
    reason: 'profile header',
  );
}

Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();

/// Puts the keyboard away (it covers the bottom of sheets and forms).
Future<void> _hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await wait(tester, 0.8);
}

/// Taps [f] after scrolling it into view (tapIt needs it hit-testable).
Future<void> _tap(WidgetTester tester, Finder f, {double settle = 0.8}) async {
  await waitFor(tester, f, reason: '$f');
  await tester.ensureVisible(f.first);
  await wait(tester, 0.4);
  await tapIt(tester, f, settle: settle);
}

/// The switch in the Settings tile titled [title].
Finder _switchIn(String title) => find.descendant(
  of:
      find
          .ancestor(of: find.text(title), matching: find.byType(ListTile))
          .first,
  matching: find.byType(Switch),
);

bool _switchValue(WidgetTester tester, Finder f) =>
    tester.widget<Switch>(f.first).value;

Future<void> _scrollSettingsTo(WidgetTester tester, Finder f) => scrollTo(
  tester,
  f,
  scrollable: find.byType(Scrollable).hitTestable().first,
);

/// Closes a modal bottom sheet by tapping its barrier.
Future<void> _dismissSheet(WidgetTester tester) async {
  await tester.tapAt(const Offset(20, 80));
  await wait(tester, 0.8);
}

Future<void> _expectToast(WidgetTester tester, Pattern text) async {
  await waitFor(
    tester,
    find.descendant(
      of: find.byType(SnackBar),
      matching: find.textContaining(text),
    ),
    reason: 'toast "$text"',
  );
  ScaffoldMessenger.of(
    tester.element(find.byType(SnackBar).first),
  ).removeCurrentSnackBar();
  await wait(tester, 0.4);
}

void main() {
  initBinding();

  testWidgets('profile: name, drawn avatar, photo, city, leaderboard', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await preparePickedPhoto();
    await _start(tester);
    await _openProfileTab(tester);
    await shot('profile-start');

    // --- Name and drawn avatar --------------------------------------------
    await tapIt(tester, find.byTooltip('Edit name and picture'), settle: 1);
    await waitFor(
      tester,
      find.text('Make it yours'),
      reason: 'name and picture sheet',
    );
    await tester.enterText(
      find.byKey(const Key('profile-setup-name')),
      'Tenzin E2E',
    );
    await _hideKeyboard(tester);
    await _tap(tester, find.bySemanticsLabel('Proud yak'));
    await _tap(tester, find.bySemanticsLabel('green background'));
    await shot('profile-sheet-drawn');
    await _tap(tester, find.byKey(const Key('profile-setup-save')), settle: 2);
    await waitGone(tester, find.text('Make it yours'));
    var me = await backendGetAsMe('auth/me');
    expect(me?['display_name'], 'Tenzin E2E');
    expect(me?['avatar'], 'yak_proud:green');
    expect(find.text('Tenzin E2E'), findsWidgets);

    // --- Photo upload (mocked picker) and remove ----------------------------
    await tapIt(tester, find.byTooltip('Edit name and picture'), settle: 1);
    await waitFor(tester, find.text('Make it yours'));
    await tapIt(
      tester,
      find.byKey(const Key('profile-setup-photo')),
      settle: 1,
    );
    await waitFor(
      tester,
      find.text('Change photo'),
      timeout: 30,
      reason: 'photo uploaded',
    );
    expect(
      calledMethod(
        'dev.flutter.pigeon.image_picker_ios.ImagePickerApi.pickImage',
        'pickImage',
      ),
      isTrue,
      reason: 'the gallery picker was asked',
    );
    me = await backendGetAsMe('auth/me');
    expect(me?['photo_url'], isNotNull, reason: 'backend stored the photo');
    await shot('profile-sheet-photo');
    await tapIt(
      tester,
      find.byKey(const Key('profile-setup-photo-remove')),
      settle: 1,
    );
    await waitFor(tester, find.text('Upload a photo'), reason: 'photo removed');
    me = await backendGetAsMe('auth/me');
    expect(me?['photo_url'], isNull);

    // --- City on the leaderboard (opt-in) ---------------------------------
    final citySwitch = find.byKey(const Key('show-place-switch-profile_setup'));
    await scrollTo(
      tester,
      citySwitch,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      tester.widget<Switch>(citySwitch).value,
      isFalse,
      reason: 'the city line is off by default',
    );
    await tapIt(tester, citySwitch, settle: 1.5);
    await waitFor(
      tester,
      find.textContaining('Others see: Kathmandu'),
      reason: 'city subtitle',
    );
    me = await backendGetAsMe('auth/me');
    expect(me?['show_place'], isTrue);
    expect('${me?['place']}', contains('Kathmandu'));
    await shot('profile-sheet-city');
    await _tap(tester, find.byKey(const Key('profile-setup-save')), settle: 2);
    await waitGone(tester, find.text('Make it yours'));

    // --- Leaderboard card and full board ----------------------------------
    await grantXp(5);
    // Leave and come back so the card reloads with this week's XP.
    await tapIt(tester, find.text('Home').last, settle: 1);
    await _openProfileTab(tester);
    final card = find.byKey(const Key('profile-board-card'));
    await scrollTo(tester, card);
    await waitFor(
      tester,
      find.descendant(of: card, matching: find.textContaining('Rival One')),
      reason: 'top rows on the board card',
    );
    await shot('profile-board-card');
    await tapIt(tester, card, settle: 2);
    await waitFor(tester, find.text('This week'), reason: 'leaderboard screen');
    await waitFor(tester, find.text('Rival One'), reason: 'board rows');

    // Own row (rank 28, 5 XP) is below the fold: the pinned bar shows.
    final bar = find.byKey(const Key('board-my-rank-bar'));
    await waitFor(tester, bar, reason: 'pinned own-rank bar');
    expect(
      find.descendant(of: bar, matching: find.textContaining('Your rank #')),
      findsOneWidget,
    );
    await shot('board-pinned-row');
    await tapIt(tester, bar, settle: 1.5);
    await waitFor(
      tester,
      find.text('You').hitTestable(),
      reason: 'own row scrolled into view',
    );
    await shot('board-own-row');

    // Report a name (also hides them).
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 3000));
    await wait(tester, 1);
    await tapIt(tester, find.byTooltip('Report or hide'), settle: 1);
    await tapIt(tester, find.byKey(const Key('board-report-name')), settle: 1);
    await waitFor(tester, find.text("What's wrong with this name?"));
    await tapIt(tester, find.byKey(const Key('board-reason-spam')), settle: 1);
    await _expectToast(tester, 'Thanks for telling us');

    // Hide another learner.
    await tapIt(tester, find.byTooltip('Report or hide'), settle: 1);
    await tapIt(tester, find.byKey(const Key('board-hide')), settle: 1);
    await _expectToast(tester, 'is hidden from your board');

    // And show everyone again.
    final unhide = find.byKey(const Key('board-unhide-all'));
    await scrollTo(tester, unhide, scrollable: find.byType(Scrollable).first);
    await tapIt(tester, unhide, settle: 1);
    await _expectToast(tester, 'Showing everyone again.');
    await shot('board-after-unhide');
    semantics.dispose();
  });

  testWidgets('settings: every toggle and picker', (tester) async {
    await _start(tester);
    await _openProfileTab(tester);
    await tapIt(tester, find.byIcon(Icons.settings), settle: 1.5);
    await waitFor(tester, find.text('Appearance'), reason: 'settings screen');
    await shot('settings-top');
    final prefs = await _prefs();

    // Theme on and back.
    expect(_switchValue(tester, _switchIn('Theme')), isFalse);
    await tapIt(tester, _switchIn('Theme'), settle: 1);
    expect(prefs.getBool('app_theme'), isTrue);
    expect(find.text('Dark Mode'), findsOneWidget);
    await shot('settings-dark');
    await tapIt(tester, _switchIn('Theme'), settle: 1);
    expect(prefs.getBool('app_theme'), isFalse);

    // Animations picker.
    await tapText(tester, 'Animations', settle: 1);
    await waitFor(tester, find.text('Reduced'));
    await tapText(tester, 'Reduced', settle: 1);
    expect(prefs.getString('animation_preference'), 'reduced');
    if (find.text('Reduced').hitTestable().evaluate().isNotEmpty) {
      await tapText(tester, 'Off', settle: 1);
      await _dismissSheet(tester);
    } else {
      await tapText(tester, 'Animations', settle: 1);
      await tapText(tester, 'Off', settle: 1);
      if (find.text('Reduced').hitTestable().evaluate().isNotEmpty)
        await _dismissSheet(tester);
    }
    expect(prefs.getString('animation_preference'), 'off');

    // Language dialog, cancelled.
    await tapText(tester, 'Language', settle: 1);
    await waitFor(tester, find.text('Select Language'));
    await tapText(tester, 'Cancel');
    await waitGone(tester, find.text('Select Language'));

    // Lesson style.
    await _scrollSettingsTo(tester, find.text('Lesson Style'));
    await tapText(tester, 'Lesson Style', settle: 1);
    await waitFor(tester, find.text('Words'));
    await tapText(tester, 'Words', settle: 1);
    expect(prefs.getString('lesson_style'), 'words');
    if (find.text('Pictures').hitTestable().evaluate().isNotEmpty)
      await _dismissSheet(tester);
    await tapText(tester, 'Lesson Style', settle: 1);
    await tapText(tester, 'Mixed', settle: 1);
    if (find.text('Pictures').hitTestable().evaluate().isNotEmpty)
      await _dismissSheet(tester);
    expect(prefs.getString('lesson_style'), 'mixed');

    // Reading help: Wylie, then "new words only", then back.
    final before = prefs.getString('transliteration_mode');
    await _scrollSettingsTo(tester, find.text('Reading Help'));
    await tapText(tester, 'Reading Help', settle: 1);
    await waitFor(tester, find.text('Wylie'));
    await tapText(tester, 'Wylie', settle: 1);
    expect(prefs.getString('transliteration_mode'), 'wylie');
    await tapText(tester, 'Reading Help', settle: 1);
    final newOnly = find.byKey(const ValueKey('reading_help_new_words_only'));
    await waitFor(tester, newOnly);
    await tapIt(tester, newOnly, settle: 0.8);
    expect(prefs.getBool('reading_help_new_words_only'), isTrue);
    await tapIt(tester, newOnly, settle: 0.8);
    expect(prefs.getBool('reading_help_new_words_only'), isFalse);
    await tapText(tester, before == 'both' ? 'Both' : 'Phonetics', settle: 1);
    if (find.text('Wylie').hitTestable().evaluate().isNotEmpty)
      await _dismissSheet(tester);

    // Notifications: the 10 AM reminder and streak reminders.
    await _scrollSettingsTo(tester, find.text('Notifications'));
    await tapText(tester, 'Notifications', settle: 1.5);
    await waitFor(tester, find.text('Notification Settings'));
    final morning = find.widgetWithText(
      SwitchListTile,
      'Daily reminder (10 AM)',
    );
    final streak = find.widgetWithText(SwitchListTile, 'Streak reminders');
    await waitFor(tester, morning);
    expect(
      tester.widget<SwitchListTile>(morning).value,
      isTrue,
      reason: 'on by default',
    );
    await shot('settings-notifications');
    await tapIt(tester, morning, settle: 1.5);
    expect(prefs.getBool('push_morning_reminder'), isFalse);
    expect(tester.widget<SwitchListTile>(morning).value, isFalse);
    await tapIt(tester, morning, settle: 1.5);
    expect(prefs.getBool('push_morning_reminder'), isTrue);
    final streakWas = tester.widget<SwitchListTile>(streak).value;
    await tapIt(tester, streak, settle: 1.5);
    expect(tester.widget<SwitchListTile>(streak).value, !streakWas);
    expect(prefs.getBool('push_streak_reminders'), !streakWas);
    await tapIt(tester, streak, settle: 1.5);
    expect(tester.widget<SwitchListTile>(streak).value, streakWas);
    await tester.pageBack();
    await wait(tester, 1);

    // Audio settings: switches and the Amdo voice.
    await _scrollSettingsTo(tester, find.text('Audio Settings'));
    await tapText(tester, 'Audio Settings', settle: 1);
    final dialog = find.byType(AlertDialog);
    await waitFor(tester, dialog);
    final sfx = find.widgetWithText(SwitchListTile, 'Sound Effects');
    final sfxWas = tester.widget<SwitchListTile>(sfx).value;
    await tapIt(tester, sfx, settle: 0.6);
    expect(prefs.getBool('sound_effects_enabled'), !sfxWas);
    await tapIt(tester, sfx, settle: 0.6);
    final haptics = find.widgetWithText(SwitchListTile, 'Haptics');
    final hapticsWas = tester.widget<SwitchListTile>(haptics).value;
    await tapIt(tester, haptics, settle: 0.6);
    expect(prefs.getBool('haptics_enabled'), !hapticsWas);
    await tapIt(tester, haptics, settle: 0.6);
    // OutlinedButton.icon is a subclass, so match by type predicate.
    await _tap(
      tester,
      find.descendant(
        of: dialog,
        matching: find.byWidgetPredicate((w) => w is OutlinedButton),
      ),
      settle: 1,
    );
    await waitFor(tester, find.text('Pronunciation voice'));
    await tapIt(tester, find.text('Amdo · male'), settle: 1);
    expect(prefs.getString('pronunciation_voice'), 'amdo_male');
    if (find.text('Pronunciation voice').hitTestable().evaluate().isNotEmpty) {
      await _dismissSheet(tester);
    }
    await waitFor(
      tester,
      find.descendant(of: dialog, matching: find.textContaining('Amdo')),
      reason: 'voice button shows Amdo',
    );
    await shot('settings-audio-amdo');
    await tapIt(
      tester,
      find.descendant(of: dialog, matching: find.text('Done')),
      settle: 1,
    );

    // Learning goals and achievements.
    await _scrollSettingsTo(tester, find.text('Learning Goals'));
    await tapText(tester, 'Learning Goals', settle: 1);
    await waitFor(tester, find.text('Daily Quiz Target'));
    await tapIt(tester, find.text('Done').last, settle: 1);
    await _scrollSettingsTo(tester, find.text('View Achievements'));
    await tapText(tester, 'View Achievements', settle: 1);
    await waitFor(tester, find.text('Achievements'));
    await tapIt(tester, find.text('Close').last, settle: 1);

    // Privacy: analytics off and on; location; leaderboard visibility.
    await _scrollSettingsTo(tester, find.text('Share usage analytics'));
    final analytics = _switchIn('Share usage analytics');
    expect(_switchValue(tester, analytics), isTrue);
    await tapIt(tester, analytics, settle: 1);
    expect(prefs.getBool('analytics_opt_out'), isTrue);
    expect(
      find.text('Off: nothing about how you use Bojang is sent'),
      findsOneWidget,
    );
    expect(find.text('Needs usage analytics to be on'), findsOneWidget);
    await shot('settings-analytics-off');
    await tapIt(tester, analytics, settle: 1);
    expect(prefs.getBool('analytics_opt_out'), isFalse);

    final location = _switchIn('Share approximate location');
    final locationWas = _switchValue(tester, location);
    locationCalls.clear();
    await tapIt(tester, location, settle: 2);
    expect(_switchValue(tester, location), !locationWas);
    if (!locationWas) expect(locationCalls, contains('getCurrentPosition'));
    await tapIt(tester, location, settle: 1.5);
    expect(_switchValue(tester, location), locationWas);

    await _scrollSettingsTo(tester, find.text('Show me on the leaderboard'));
    final visible = _switchIn('Show me on the leaderboard');
    expect(_switchValue(tester, visible), isTrue);
    await tapIt(tester, visible, settle: 2);
    expect(_switchValue(tester, visible), isFalse);
    var board = await backendGetAsMe('v1/leaderboard/weekly');
    expect(
      (board?['me'] as Map?)?['visible'],
      isFalse,
      reason: 'PUT visibility reached the server',
    );
    await tapIt(tester, visible, settle: 2);
    board = await backendGetAsMe('v1/leaderboard/weekly');
    expect((board?['me'] as Map?)?['visible'], isTrue);

    // About, privacy policy (no external links opened), rate app.
    await _scrollSettingsTo(tester, find.text('About Bojang'));
    await tapText(tester, 'About Bojang', settle: 1);
    await tapIt(tester, find.text('Close').last, settle: 1);
    await _scrollSettingsTo(tester, find.text('Privacy Policy'));
    await tapText(tester, 'Privacy Policy', settle: 1);
    await waitFor(tester, find.text('Full policy'));
    await tapIt(tester, find.text('Close').last, settle: 1);
    await _scrollSettingsTo(tester, find.text('Rate App'));
    await tapText(tester, 'Rate App', settle: 0.5);
    await _expectToast(tester, 'App store rating coming soon');
    await shot('settings-bottom');
  });

  testWidgets('account: create (upgrade), sign out, sign in, delete', (
    tester,
  ) async {
    await _start(tester);
    final anonUid = myUid();
    expect(FirebaseAuth.instance.currentUser?.isAnonymous, isTrue);
    await _openProfileTab(tester);

    final email = 'e2e-${DateTime.now().millisecondsSinceEpoch}@bojang.test';
    const password = 'e2e-pass-123';

    await tapText(tester, 'Create an account or sign in', settle: 2);
    await waitFor(
      tester,
      find.byKey(const Key('emailField')),
      reason: 'auth screen',
    );
    await shot('auth-sign-in');
    await tapIt(
      tester,
      find.byKey(const Key('toggleAuthModeButton')),
      settle: 0.8,
    );
    await waitFor(
      tester,
      find.byKey(const Key('nameField')),
      reason: 'create-account mode',
    );
    await tester.enterText(find.byKey(const Key('nameField')), 'Dolma E2E');
    await tester.enterText(find.byKey(const Key('emailField')), email);
    await tester.enterText(find.byKey(const Key('passwordField')), password);
    await wait(tester, 0.5);
    await shot('auth-create');
    await _hideKeyboard(tester);
    await _tap(tester, find.byKey(const Key('emailSubmitButton')), settle: 1);
    await waitFor(
      tester,
      find.text('Profile'),
      timeout: 30,
      reason: 'back in the app',
    );
    final user = FirebaseAuth.instance.currentUser;
    expect(user?.email, email);
    expect(user?.isAnonymous, isFalse);
    expect(
      user?.uid,
      anonUid,
      reason: 'the anonymous account was upgraded, not replaced',
    );

    await _openProfileTab(tester);
    await waitFor(tester, find.text('Email Account'), reason: 'provider pill');
    await shot('profile-email-account');
    final me = await backendGetAsMe('auth/me');
    expect(me?['uid'], anonUid);

    // Sign out, then back in with the same credentials.
    await tapIt(tester, find.byIcon(Icons.logout), settle: 1);
    await waitFor(tester, find.text('Are you sure you want to sign out?'));
    await tapIt(tester, find.text('Sign Out').last, settle: 2);
    await waitFor(
      tester,
      find.byKey(const Key('emailField')),
      timeout: 20,
      reason: 'auth after sign-out',
    );
    expect(FirebaseAuth.instance.currentUser, isNull);
    if (find.byKey(const Key('nameField')).evaluate().isNotEmpty) {
      await tapIt(
        tester,
        find.byKey(const Key('toggleAuthModeButton')),
        settle: 0.8,
      );
    }
    await tester.enterText(find.byKey(const Key('emailField')), email);
    await tester.enterText(find.byKey(const Key('passwordField')), password);
    await wait(tester, 0.5);
    await _hideKeyboard(tester);
    await _tap(tester, find.byKey(const Key('emailSubmitButton')), settle: 1);
    await waitFor(
      tester,
      find.text('Profile'),
      timeout: 30,
      reason: 'signed back in',
    );
    expect(FirebaseAuth.instance.currentUser?.uid, anonUid);

    // Delete the account from Settings.
    await _openProfileTab(tester);
    final token = await FirebaseAuth.instance.currentUser!.getIdToken();
    await tapIt(tester, find.byIcon(Icons.settings), settle: 1.5);
    await _scrollSettingsTo(tester, find.text('Delete Account'));
    await tapText(tester, 'Delete Account', settle: 1);
    await waitFor(tester, find.text('Delete Account?'));
    await tapText(tester, 'Continue', settle: 1);
    await waitFor(tester, find.text('Are you sure?'));
    await shot('delete-confirm');
    await tapText(tester, 'Delete My Account', settle: 1);
    await waitFor(tester, find.text('Account Deleted'), timeout: 20);
    await tapText(tester, 'OK', settle: 2);
    await waitFor(
      tester,
      find.byKey(const Key('emailField')),
      reason: 'auth after delete',
    );
    await shot('after-delete');
    expect(FirebaseAuth.instance.currentUser, isNull);

    final res = await http.get(
      Uri.parse('$apiBase/auth/me'),
      headers: {'Authorization': 'Bearer $token'},
    );
    expect(
      res.statusCode,
      isNot(200),
      reason: 'the backend no longer knows the deleted learner',
    );
  });
}
