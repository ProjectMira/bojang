import 'package:flutter/widgets.dart';

import 'script_course_screen.dart';
import 'script_gate_screen.dart';

/// Named routes of the script course, for `MaterialApp.routes`. The path's
/// `alphabet_gate` node opens `/script/gate`.
class ScriptRoutes {
  ScriptRoutes._();

  static const String course = '/script';
  static const String gate = '/script/gate';

  static final Map<String, WidgetBuilder> all = {
    course: (_) => const ScriptCourseScreen(source: 'route'),
    gate: (_) => const ScriptGateScreen(source: 'route'),
  };
}
