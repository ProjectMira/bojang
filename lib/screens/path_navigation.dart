import 'package:flutter/material.dart';

import '../models/learning_path.dart';
import '../models/level_models.dart';
import '../services/analytics.dart';
import '../services/user_kv.dart';
import '../theme/app_tokens.dart';
import '../widgets/app_text_style.dart';
import '../widgets/content_width.dart';
import '../widgets/yak_says.dart';
import '../widgets/yak_mascot.dart';
import 'lesson_intro_screen.dart';
import 'quiz_screen.dart';

/// Named routes that learning-path nodes open (`route` in GET /learn/path).
///
/// `/script` and `/script/gate` belong to the script course
/// (`lib/screens/script/`: `ScriptCourseScreen`, `ScriptGateScreen`). Until
/// those are merged they open [PathPlaceholderScreen]; the merge replaces
/// the two builders below.
class PathRoutes {
  PathRoutes._();

  static const String script = '/script';
  static const String scriptGate = '/script/gate';

  static final Map<String, WidgetBuilder> builders = {
    script:
        (_) => const PathPlaceholderScreen(
          title: 'Reading Tibetan',
          body:
              'The script course is on its way. For now, the Basics lessons '
              'teach the letters.',
        ),
    scriptGate:
        (_) => const PathPlaceholderScreen(
          title: 'Reading check',
          body:
              'A short check that you can read Tibetan letters is coming soon. '
              'You can skip it for now if you already read Tibetan.',
          offersGateSkip: true,
        ),
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

/// Stand-in for a path screen another part of the app will provide.
class PathPlaceholderScreen extends StatelessWidget {
  const PathPlaceholderScreen({
    super.key,
    required this.title,
    required this.body,
    this.offersGateSkip = false,
  });

  final String title;
  final String body;

  /// The reading-check stand-in lets a reader skip the gate.
  final bool offersGateSkip;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background(context),
      appBar: AppBar(
        title: Text(title, style: AppTextStyles.title(context)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppTokens.ink(context),
        systemOverlayStyle: AppTokens.statusBar(context),
      ),
      body: ContentWidth(
        maxWidth: ContentWidth.reading,
        child: YakNotice(
          title: title,
          body: body,
          mood: YakMood.happy,
          actionLabel:
              offersGateSkip ? 'I already read Tibetan' : 'Back to the path',
          onAction: () async {
            if (offersGateSkip) {
              await skipReadingGate();
            }
            if (context.mounted) Navigator.of(context).pop();
          },
        ),
      ),
    );
  }
}

/// Skips the reading check (user_kv `script/gate_skipped` = true), the
/// key GET /learn/path reads.
Future<bool> skipReadingGate({String source = 'placeholder'}) async {
  Analytics.track('path_gate_skipped', {'source': source});
  try {
    return await UserKv.instance.update(
          'script',
          'gate_skipped',
          (_) => true,
        ) !=
        null;
  } catch (_) {
    return false;
  }
}
