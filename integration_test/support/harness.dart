// Shared set-up for the end-to-end suite (see TESTING.md).
//
// The suite runs the real app (lib/main.dart's initServices + MyApp) on the
// iOS Simulator against a local backend and the Firebase Auth emulator,
// started by ci/scripts/e2e.sh. Native permission prompts never appear:
// the notification, messaging, image picker and location plugins' platform
// channels are answered by spies here, which also record what the app asked
// for (e.g. "no notification prompt during onboarding").

import 'dart:convert';
import 'dart:io';

import 'package:bojang/main.dart' as app;
import 'package:bojang/services/api_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

/// Where the app's API points (BOJANG_API_BASE_URL).
const String apiBase = ApiService.baseUrl;

late IntegrationTestWidgetsFlutterBinding binding;
bool _servicesReady = false;

/// Platform calls the app made, by channel, since the last [resetSpies].
final Map<String, List<MethodCall>> channelCalls = {};

/// Bytes returned by the mocked photo picker (a 2x2 PNG).
final Uint8List fakePhotoPng = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00, 0x02,
  0x08, 0x02, 0x00, 0x00, 0x00, 0xFD, 0xD4, 0x9A, 0x73, 0x00, 0x00, 0x00,
  0x16, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x62, 0xF8, 0xCF, 0xC0, 0xF0,
  0x9F, 0x81, 0xE1, 0x3F, 0x03, 0x03, 0x00, 0x00, 0x00, 0xFF, 0xFF, 0x03,
  0x00, 0x27, 0xFC, 0x05, 0xFB, 0x8E, 0xD6, 0x16, 0x86, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

IntegrationTestWidgetsFlutterBinding initBinding() {
  binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // Timers, network and animations run in real time.
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;
  return binding;
}

bool calledMethod(String channel, String method) =>
    (channelCalls[channel] ?? const []).any((c) => c.method == method);

void resetSpies() => channelCalls.clear();

const _notifications = 'dexterous.com/flutter/local_notifications';
const _messaging = 'plugins.flutter.io/firebase_messaging';
const _geolocators = [
  'flutter.baseflow.com/geolocator',
  'flutter.baseflow.com/geolocator_apple',
];
const _geocoding = 'flutter.baseflow.com/geocoding';
const _imagePickerPigeon =
    'dev.flutter.pigeon.image_picker_ios.ImagePickerApi.pickImage';
const _imagePickerLegacy = 'plugins.flutter.io/image_picker';

String? _pickedPhotoPath;

/// iOS notification authorization as firebase_messaging encodes it:
/// -1 not determined, 0 denied, 1 authorized, 2 provisional.
int pushStatus = -1;

/// Answers the permission-prompting plugins instead of iOS.
void installSpies() {
  final messenger = binding.defaultBinaryMessenger;
  void spy(String channel, Future<Object?>? Function(MethodCall) answer) {
    messenger.setMockMethodCallHandler(MethodChannel(channel), (call) {
      (channelCalls[channel] ??= []).add(call);
      return answer(call);
    });
  }

  spy(_notifications, (call) async {
    switch (call.method) {
      case 'initialize':
      case 'requestPermissions':
        return true;
      case 'checkPermissions':
        return {'isEnabled': true, 'isAlertEnabled': true};
      case 'pendingNotificationRequests':
      case 'getActiveNotifications':
        return <Object>[];
      case 'getNotificationAppLaunchDetails':
        return {'notificationLaunchedApp': false};
      default:
        return null;
    }
  });
  spy(_messaging, (call) async {
    switch (call.method) {
      case 'Messaging#requestPermission':
      case 'Messaging#getNotificationSettings':
        if (call.method == 'Messaging#requestPermission') {
          final provisional =
              call.arguments is Map && call.arguments['provisional'] == true;
          // A full request "shows the dialog" and the learner allows it.
          pushStatus = provisional && pushStatus != 1 ? 2 : 1;
        }
        return {
          'authorizationStatus': pushStatus,
          'alert': 1,
          'announcement': 0,
          'badge': 1,
          'carPlay': 0,
          'lockScreen': 1,
          'notificationCenter': 1,
          'showPreviews': 1,
          'sound': 1,
          'criticalAlert': 0,
          'providesAppNotificationSettings': 0,
          'timeSensitive': 0,
        };
      case 'Messaging#getToken':
        return {'token': 'e2e-fcm-token'};
      case 'Messaging#getAPNSToken':
        return {'token': 'e2e-apns-token'};
      case 'Messaging#getInitialMessage':
        return null;
      default:
        return null;
    }
  });
  for (final channel in _geolocators) {
    spy(channel, (call) async {
      switch (call.method) {
        case 'checkPermission':
        case 'requestPermission':
          return 3; // whileInUse
        case 'isLocationServiceEnabled':
          return true;
        case 'getCurrentPosition':
        case 'getLastKnownPosition':
          return {
            'latitude': 27.7172,
            'longitude': 85.3240,
            'timestamp': 0,
            'accuracy': 1000.0,
            'altitude': 0.0,
            'heading': 0.0,
            'speed': 0.0,
            'speed_accuracy': 0.0,
            'altitude_accuracy': 0.0,
            'heading_accuracy': 0.0,
            'is_mocked': true,
          };
        default:
          return null;
      }
    });
  }
  spy(_geocoding, (call) async {
    if (call.method == 'placemarkFromCoordinates') {
      return [
        {
          'locality': 'Kathmandu',
          'country': 'Nepal',
          'isoCountryCode': 'NP',
          'administrativeArea': 'Bagmati',
        },
      ];
    }
    return null;
  });
  spy(_imagePickerLegacy, (call) async => _pickedPhotoPath);
  // image_picker_ios speaks Pigeon: [result] or [code, message, details].
  messenger.setMockMessageHandler(_imagePickerPigeon, (message) async {
    (channelCalls[_imagePickerPigeon] ??= []).add(
      const MethodCall('pickImage'),
    );
    return const StandardMessageCodec().encodeMessage(<Object?>[
      _pickedPhotoPath,
    ]);
  });
}

/// Writes [fakePhotoPng] to a temp file the mocked picker returns.
Future<void> preparePickedPhoto() async {
  final dir = await getTemporaryDirectory();
  final file = File('${dir.path}/e2e_photo.png');
  await file.writeAsBytes(fakePhotoPng);
  _pickedPhotoPath = file.path;
}

/// A fresh install: no prefs, no Firebase user, no offline queue, no cache.
Future<void> wipeState() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();
  if (Firebase.apps.isNotEmpty) {
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }
  try {
    await deleteDatabase('offline_queue.db');
  } catch (_) {}
}

/// Starts the app as main() does. [fresh] wipes everything first.
Future<void> launchApp(
  WidgetTester tester, {
  bool fresh = true,
  Future<void> Function(SharedPreferences prefs)? seed,
}) async {
  installSpies();
  if (fresh) {
    await wipeState();
    pushStatus = -1;
  }
  if (seed != null) await seed(await SharedPreferences.getInstance());
  if (!_servicesReady) {
    await app.initServices();
    _servicesReady = true;
  }
  resetSpies();
  await tester.pumpWidget(app.MyApp(key: UniqueKey()));
  app.startBackgroundServices();
}

/// Pumps frames for [seconds] of real time.
Future<void> wait(WidgetTester tester, [double seconds = 1]) async {
  final end = DateTime.now().add(
    Duration(milliseconds: (seconds * 1000).round()),
  );
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

/// Pumps until [finder] finds something, or fails after [timeout] seconds.
Future<Finder> waitFor(
  WidgetTester tester,
  Finder finder, {
  double timeout = 15,
  String? reason,
}) async {
  final end = DateTime.now().add(
    Duration(milliseconds: (timeout * 1000).round()),
  );
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isNotEmpty) return finder;
  }
  await shot('timeout-${_slug(reason ?? finder.toString())}');
  fail('Timed out after ${timeout}s waiting for ${reason ?? finder}');
}

/// Pumps until any of [finders] matches; returns its index, or -1.
Future<int> waitForAny(
  WidgetTester tester,
  List<Finder> finders, {
  double timeout = 15,
}) async {
  final end = DateTime.now().add(
    Duration(milliseconds: (timeout * 1000).round()),
  );
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    for (var i = 0; i < finders.length; i++) {
      if (finders[i].evaluate().isNotEmpty) return i;
    }
  }
  return -1;
}

/// Pumps until [finder] is gone.
Future<void> waitGone(
  WidgetTester tester,
  Finder finder, {
  double timeout = 15,
}) async {
  final end = DateTime.now().add(
    Duration(milliseconds: (timeout * 1000).round()),
  );
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 100));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Timed out waiting for $finder to go away');
}

/// Taps the first hit-testable match of [finder] and pumps a little.
Future<void> tapIt(
  WidgetTester tester,
  Finder finder, {
  double settle = 0.6,
}) async {
  final target = finder.hitTestable();
  await waitFor(tester, target, reason: 'tappable $finder');
  await tester.ensureVisible(target.first);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(target.first, warnIfMissed: false);
  await wait(tester, settle);
}

Future<void> tapText(WidgetTester tester, String text, {double settle = 0.6}) =>
    tapIt(tester, find.text(text), settle: settle);

/// Scrolls the first Scrollable until [finder] is built, then shows it.
Future<void> scrollTo(
  WidgetTester tester,
  Finder finder, {
  Finder? scrollable,
}) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      250,
      scrollable: scrollable ?? find.byType(Scrollable).first,
      maxScrolls: 40,
    );
  }
  await tester.ensureVisible(finder.first);
  await wait(tester, 0.3);
}

String _slug(String s) => s
    .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
    .toLowerCase()
    .substring(0, s.length.clamp(0, 60));

/// Asks ci/scripts/e2e.sh to capture the simulator screen now.
/// The script watches the log for SHOT:name lines.
Future<void> shot(String name) async {
  debugPrint('SHOT:$name');
  await Future<void>.delayed(const Duration(milliseconds: 1500));
}

/// The current route's name (for "a route was pushed" checks).
String? topRouteName(WidgetTester tester) {
  String? name;
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  nav.popUntil((route) {
    name = route.settings.name;
    return true;
  });
  return name;
}

// --- local backend helpers (ci/e2e/local_backend.py) ----------------------

/// The signed-in Firebase uid (the anonymous emulator account by default).
String? myUid() =>
    Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.uid;

Future<Map<String, dynamic>> backendPost(
  String path,
  Map<String, Object?> body,
) async {
  final res = await http.post(
    Uri.parse('$apiBase$path'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  return jsonDecode(res.body) as Map<String, dynamic>;
}

/// Authenticated GET as the current learner; null on a non-200.
Future<Map<String, dynamic>?> backendGetAsMe(String path) async {
  final token = await FirebaseAuth.instance.currentUser?.getIdToken();
  final res = await http.get(
    Uri.parse('$apiBase/$path'),
    headers: {if (token != null) 'Authorization': 'Bearer $token'},
  );
  if (res.statusCode != 200) return null;
  return jsonDecode(res.body) as Map<String, dynamic>;
}

/// Gives the current learner [xp] this week (for leaderboard journeys).
Future<void> grantXp(int xp) async {
  final uid = myUid();
  if (uid == null) fail('no signed-in learner to give XP to');
  final r = await backendPost('/e2e/xp', {'uid': uid, 'xp': xp});
  if (r['ok'] != true) fail('grantXp: $r');
}

/// Makes the backend answer 503 to the current learner only (or everyone
/// with [everyone]), as if the server were unreachable.
Future<void> setOutage(bool on, {bool everyone = false}) =>
    backendPost('/e2e/outage', {'uid': everyone ? '*' : myUid(), 'on': on});
