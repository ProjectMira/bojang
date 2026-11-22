import 'package:bojang/models/experiment_exposure.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('an arm is logged once per session', () {
    final log = ExposureLog();
    expect(log.firstExposure('s1', 'exp_home_cta', 'short'), isTrue);
    expect(log.firstExposure('s1', 'exp_home_cta', 'short'), isFalse);
    expect(log.firstExposure('s1', 'exp_home_cta', 'short'), isFalse);
  });

  test('another arm or experiment is a new exposure', () {
    final log = ExposureLog();
    expect(log.firstExposure('s1', 'exp_home_cta', 'short'), isTrue);
    expect(log.firstExposure('s1', 'exp_home_cta', 'control'), isTrue);
    expect(log.firstExposure('s1', 'exp_streak_copy', 'short'), isTrue);
  });

  test('a new session logs again', () {
    final log = ExposureLog();
    expect(log.firstExposure('s1', 'exp_home_cta', 'short'), isTrue);
    expect(log.firstExposure('s2', 'exp_home_cta', 'short'), isTrue);
    expect(log.firstExposure('s2', 'exp_home_cta', 'short'), isFalse);
    log.clear();
    expect(log.firstExposure('s2', 'exp_home_cta', 'short'), isTrue);
  });
}
