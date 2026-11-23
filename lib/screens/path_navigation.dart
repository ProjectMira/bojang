import 'package:flutter/material.dart';

import '../models/learning_path.dart';
import '../models/level_models.dart';
import '../services/analytics.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_text_style.dart';
import '../widgets/content_width.dart';
import 'lesson_intro_screen.dart';
import 'quiz_screen.dart';
import 'script/script_course_screen.dart';
import 'script/script_gate_screen.dart';
import 'script/script_routes.dart';

/// Named routes that learning-path nodes open (`route` in GET /learn/path):
/// `/script` (the `alphabet` node) and `/script/gate` (the reading check)
/// open the script course screens in `lib/screens/script/`.
class PathRoutes {
  PathRoutes._();

  static const String script = ScriptRoutes.course;
  static const String scriptGate = ScriptRoutes.gate;

  static final Map<String, WidgetBuilder> builders = {
    script: (_) => const ScriptCourseScreen(source: 'path'),
    scriptGate: (_) => const ScriptGateScreen(source: 'path'),
  };

  /// For `MaterialApp.onGenerateRoute`.
  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    final builder = builders[settings.name];
    if (builder == null) return null;
    return MaterialPageRoute(builder: builder, settings: settings);
  }
}

/// Opens a reachable path step: its route, its review session or its
/// lesson. Completes when the learner comes back, so the path can refresh.
Future<void> openPathNode(
  BuildContext context,
  PathNode node, {
  required String source,
  PathUnit? unit,
}) async {
  Analytics.track('path_step_started', {
    'node_id': node.id,
    'type': node.type,
    'state': node.state.name,
    'unit': unit?.index,
    'session': node.finishedSessions + 1,
    'total_sessions': node.totalSessions,
    'source': source,
  });
  final route = node.route;
  if (route != null) {
    if (PathRoutes.builders.containsKey(route)) {
      await Navigator.of(
        context,
      ).push(PathRoutes.onGenerateRoute(RouteSettings(name: route))!);
    } else {
      await Navigator.of(context).pushNamed(route).catchError((_) => null);
    }
    return;
  }
  if (node.isReview) {
    await Navigator.push(
      context,
      screenRoute(
        'quiz',
        (context) => QuizScreen(
          topicFilePath: reviewTopicPath(node.id),
          title: node.title,
          source: source,
        ),
      ),
    );
    return;
  }
  final levelId = node.levelId;
  if (levelId == null) return;
  final sublevel = Sublevel(
    level: '',
    name: node.title,
    path: 'api://level/$levelId',
    hasLesson: node.hasLesson,
    wordCount: node.sessionWords ?? -1,
  );
  // openTopic pushes and returns at once; wait for the learner to come
  // back by pushing the same screens here.
  if (sublevel.hasLesson) {
    await Navigator.push(
      context,
      screenRoute(
        'lesson_intro',
        (context) => LessonIntroScreen(
          levelId: levelId,
          title: node.title,
          topicPath: sublevel.path,
          source: source,
        ),
      ),
    );
  } else {
    await Navigator.push(
      context,
      screenRoute(
        'quiz',
        (context) => QuizScreen(
          topicFilePath: sublevel.path,
          title: node.title,
          source: source,
        ),
      ),
    );
  }
}

/// Explains why a step is locked, in a small sheet with one way forward.
Future<void> showLockedNode(
  BuildContext context,
  LearningPath path,
  PathNode node, {
  required String source,
  VoidCallback? onGoToActive,
}) {
  final reason = path.lockedReason(node);
  Analytics.track('path_locked_tapped', {
    'node_id': node.id,
    'type': node.type,
    'active_node_id': path.activeNodeId,
    'source': source,
  });
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: AppTokens.surface(context),
    builder:
        (context) => SafeArea(
          child: ContentWidth(
            maxWidth: ContentWidth.reading,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        color: AppTokens.inkSoft(context),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          node.title,
                          style: AppTextStyles.title(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(reason, style: AppTextStyles.body(context)),
                  if (onGoToActive != null && path.activeNode != null) ...[
                    const SizedBox(height: 20),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        backgroundColor: AppColors.primary,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        onGoToActive();
                      },
                      child: Text(
                        'Go to "${path.activeNode!.title}"',
                        style: AppTextStyles.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
  );
}
