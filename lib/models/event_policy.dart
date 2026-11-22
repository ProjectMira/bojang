/// Which analytics events this app session sends, from the server config's
/// `analytics.blocklist` and `analytics.sampling` (plan item #20).
///
/// - A blocklisted event is never sent (PostHog or backend).
/// - A sampled event is sent by a fixed share of app sessions: the decision
///   hashes the session id with the event name, so within one session an
///   event is either always or never sent (funnels stay whole), and about
///   `rate` of sessions send it.
/// - [neverSampled] events ignore sampling (blocklisting still applies):
///   experiment analysis needs every exposure.
class EventPolicy {
  const EventPolicy({this.blocklist = const {}, this.sampling = const {}});

  /// Sends everything.
  static const EventPolicy allowAll = EventPolicy();

  static const Set<String> neverSampled = {'experiment_exposed'};

  final Set<String> blocklist;

  /// Event -> share of sessions that send it, 0.0 to 1.0.
  final Map<String, double> sampling;

  /// Whether [event] is sent. [unit] is what sampling is keyed by: the app
  /// session id.
  bool allows(String event, [String unit = '']) {
    if (blocklist.contains(event)) return false;
    if (neverSampled.contains(event)) return true;
    final rate = sampling[event];
    if (rate == null || rate >= 1.0) return true;
    if (rate <= 0.0) return false;
    return bucket(unit, event) < rate;
  }

  /// Stable position of (unit, event) in [0, 1), from 32-bit FNV-1a.
  static double bucket(String unit, String event) {
    var hash = 0x811c9dc5;
    for (final c in '$unit|$event'.codeUnits) {
      hash ^= c;
      // hash * 16777619 (the FNV prime, 2^24 + 403) mod 2^32, split so it
      // stays exact where ints are doubles (web).
      hash = (hash * 403 + ((hash << 24) & 0xffffffff)) & 0xffffffff;
    }
    return hash / 0x100000000;
  }
}
