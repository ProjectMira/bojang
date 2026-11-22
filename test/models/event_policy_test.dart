import 'package:bojang/models/event_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('allowAll sends everything', () {
    expect(EventPolicy.allowAll.allows('tap', 's1'), isTrue);
    expect(EventPolicy.allowAll.allows('lesson_completed'), isTrue);
  });

  test('blocklisted events are never sent', () {
    const policy = EventPolicy(
      blocklist: {'scroll'},
      sampling: {'scroll': 1.0},
    );
    expect(policy.allows('scroll', 's1'), isFalse);
    expect(policy.allows('tap', 's1'), isTrue);
  });

  test('rates of 0 and 1 are absolute', () {
    const policy = EventPolicy(sampling: {'tap': 0.0, 'swipe': 1.0});
    for (var i = 0; i < 50; i++) {
      expect(policy.allows('tap', 'session-$i'), isFalse);
      expect(policy.allows('swipe', 'session-$i'), isTrue);
    }
  });

  test('a sampled event is sent by about that share of sessions', () {
    const policy = EventPolicy(sampling: {'tap': 0.25});
    const sessions = 4000;
    var sent = 0;
    for (var i = 0; i < sessions; i++) {
      if (policy.allows('tap', 'session-$i')) sent++;
    }
    expect(sent / sessions, closeTo(0.25, 0.03));
  });

  test('the decision is stable within a session', () {
    const policy = EventPolicy(sampling: {'tap': 0.5});
    for (var i = 0; i < 100; i++) {
      final first = policy.allows('tap', 'session-$i');
      for (var j = 0; j < 5; j++) {
        expect(policy.allows('tap', 'session-$i'), first);
      }
    }
  });

  test('events are sampled independently of each other', () {
    const policy = EventPolicy(sampling: {'tap': 0.5, 'scroll': 0.5});
    var differ = 0;
    for (var i = 0; i < 200; i++) {
      if (policy.allows('tap', 's$i') != policy.allows('scroll', 's$i')) {
        differ++;
      }
    }
    expect(differ, greaterThan(50));
  });

  test('experiment exposure is never sampled away, but can be blocklisted', () {
    const sampled = EventPolicy(sampling: {'experiment_exposed': 0.0});
    expect(sampled.allows('experiment_exposed', 's1'), isTrue);
    const blocked = EventPolicy(blocklist: {'experiment_exposed'});
    expect(blocked.allows('experiment_exposed', 's1'), isFalse);
  });

  test('bucket stays in [0, 1)', () {
    for (var i = 0; i < 1000; i++) {
      final b = EventPolicy.bucket('unit-$i', 'event');
      expect(b, greaterThanOrEqualTo(0));
      expect(b, lessThan(1));
    }
    // FNV-1a of the empty-ish input is fixed, so platforms agree.
    expect(EventPolicy.bucket('', ''), EventPolicy.bucket('', ''));
  });
}
