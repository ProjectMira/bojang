// Fastest check that the harness works: the app starts against the local
// backend, gets an anonymous emulator account and leaves the splash screen.
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'support/harness.dart';

void main() {
  initBinding();

  testWidgets('local backend, emulator and app start', (tester) async {
    expect(apiBase, isNot(contains('run.app')),
        reason: 'the suite must never point at the production backend');
    final health = await http.get(Uri.parse('$apiBase/e2e/health'));
    expect(health.statusCode, 200, reason: 'local backend not running');
    expect(jsonDecode(health.body)['ok'], true);

    await launchApp(tester);
    await waitForAny(tester, [find.byType(Scaffold)], timeout: 20);
    await wait(tester, 6);
    await shot('smoke-start');
    expect(FirebaseAuth.instance.currentUser, isNotNull,
        reason: 'anonymous account from the Auth emulator');
  });
}
