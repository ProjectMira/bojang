import 'package:bojang/services/experiments.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final sent = <Map<String, Object?>>[];
  var session = 's1';

  setUp(() {
    sent.clear();
    session = 's1';
    Experiments.debugReset();
    Experiments.send = (event, props) => sent.add({'event': event, ...props});
    Experiments.sessionId = () => session;
  });

  test('reading an arm logs nothing', () {
    expect(Experiments.arm('exp_home_cta'), 'control');
    expect(Experiments.arm('exp_home_cta', fallback: 'a'), 'a');
    expect(sent, isEmpty);
  });

  test('exposure is sent once per arm per session', () {
    Experiments.exposed('exp_home_cta', 'short', surface: 'home');
    Experiments.exposed('exp_home_cta', 'short', surface: 'home');
    expect(sent, [
      {
        'event': 'experiment_exposed',
        'experiment': 'exp_home_cta',
        'arm': 'short',
        'surface': 'home',
        'source': 'remote_config',
      },
    ]);
    session = 's2';
    Experiments.exposed('exp_home_cta', 'short', surface: 'home');
    expect(sent, hasLength(2));
  });

  testWidgets('ExperimentExposure logs when shown and when the arm changes', (
    tester,
  ) async {
    Widget build(String arm) => MaterialApp(
      home: ExperimentExposure(
        experiment: 'exp_home_cta',
        arm: arm,
        surface: 'home',
        child: Text(arm),
      ),
    );
    await tester.pumpWidget(build('short'));
    await tester.pumpWidget(build('short'));
    expect(sent, hasLength(1));
    await tester.pumpWidget(build('control'));
    expect(sent.map((e) => e['arm']), ['short', 'control']);
  });
}
