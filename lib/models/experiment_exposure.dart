/// Remembers which experiment arms were exposed in the current app session,
/// so `experiment_exposed` goes out once per (experiment, arm) per session
/// (plan item #21). A new session id starts a fresh log.
class ExposureLog {
  String _session = '';
  final Set<String> _seen = {};

  /// True the first time [experiment]/[arm] is seen in [sessionId]; the
  /// caller then sends the event. Later calls in the same session are false.
  bool firstExposure(String sessionId, String experiment, String arm) {
    if (sessionId != _session) {
      _session = sessionId;
      _seen.clear();
    }
    return _seen.add('$experiment\u0000$arm');
  }

  void clear() {
    _session = '';
    _seen.clear();
  }
}
