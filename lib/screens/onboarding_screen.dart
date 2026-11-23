import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/level_models.dart';
import '../models/onboarding.dart';
import '../services/analytics.dart';
import '../services/levels_repository.dart';
import '../services/notification_primer.dart';
import '../services/onboarding_service.dart';
import '../services/pronunciation_voices.dart';
import '../services/theme_service.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../theme/tibetan_type.dart';
import '../utils/yak_lines.dart';
import '../widgets/app_text_style.dart';
import '../widgets/content_width.dart';
import '../widgets/yak_mascot.dart';
import 'lesson_intro_screen.dart';
import 'main_navigation_screen.dart';

/// How onboarding ended, for [OnboardingScreen.onFinished].
class OnboardingResult {
  const OnboardingResult({
    required this.skipped,
    required this.startLevelId,
    this.startLevel,
  });

  final bool skipped;
  final String startLevelId;

  /// The start level from the live list, or null when it was not found
  /// (offline): the learner then lands on Home.
  final Sublevel? startLevel;
}

/// Onboarding for new installs (plan items #8 and #9): Norbu says hello,
/// then one-tap questions (why, how much Tibetan, which voice, daily goal),
/// a soft notification primer, and straight into the first lesson at the
/// level the knowledge answer placed the learner at.
///
/// Back and Skip always work: Back returns one step with the answer kept,
/// Skip leaves for Home with the answers given so far. No paywall, no
/// "how did you hear about us".
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    this.service,
    this.primer,
    this.loadLevels,
    this.onFinished,
  });

  final OnboardingService? service;
  final NotificationPrimer? primer;

  /// Loads the level tree (tests pass a stub).
  final Future<List<Level>> Function()? loadLevels;

  /// Replaces opening Home and the first lesson (tests).
  final void Function(OnboardingResult result)? onFinished;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with WidgetsBindingObserver {
  late final OnboardingService _service =
      widget.service ?? OnboardingService.instance;
  late final NotificationPrimer _primer =
      widget.primer ?? NotificationPrimer.instance;
  late final Future<List<Level>> _levels;
  final Stopwatch _elapsed = Stopwatch()..start();

  /// Until the OS check answers, the primer step is assumed present, so the
  /// progress bar does not jump back.
  List<OnboardingStep> _steps = OnboardingStep.values;
  int _index = 0;
  bool _forward = true;
  bool _finishing = false;

  Motivation? _motivation;
  PriorKnowledge? _knowledge;
  String? _voice;
  DailyGoal? _goal;

  OnboardingStep get _step => _steps[_index];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _levels = (widget.loadLevels ?? LevelsRepository.loadLevels)().catchError(
      (Object _) => <Level>[],
    );
    unawaited(_service.setStatus(OnboardingStatus.inProgress));
    Analytics.track('onboarding_started', {});
    _trackView();
    _primer.canAskDuringOnboarding().then((canAsk) {
      if (!mounted || canAsk) return;
      setState(() {
        _steps = [
          for (final s in OnboardingStep.values)
            if (s != OnboardingStep.notifications) s,
        ];
        if (_index >= _steps.length) _index = _steps.length - 1;
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Drop-off: the app left the foreground with onboarding unfinished.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused && !_finishing) {
      Analytics.track('onboarding_backgrounded', _stepProps());
    }
  }

  Map<String, Object?> _stepProps() => {
    'step': _step.name,
    'index': _index,
    'count': _steps.length,
    'ms': _elapsed.elapsedMilliseconds,
  };

  void _trackView() {
    Analytics.track('onboarding_step_viewed', _stepProps());
    unawaited(_service.setLastStep(_step.name));
  }

  void _goTo(int index) {
    if (index < 0 || index >= _steps.length) return;
    setState(() {
      _forward = index > _index;
      _index = index;
    });
    _trackView();
  }

  void _next() {
    if (_index + 1 >= _steps.length) {
      _finish(skipped: false);
    } else {
      _goTo(_index + 1);
    }
  }

  void _back() {
    if (_index == 0 || _finishing) return;
    Analytics.track('onboarding_back', _stepProps());
    _goTo(_index - 1);
  }

  void _skip() {
    if (_finishing) return;
    Analytics.track('onboarding_skipped', _stepProps());
    _finish(skipped: true);
  }

  /// Records [answer] for the current step and moves on after a moment, so
  /// the selection is seen.
  Future<void> _answer(String key, Object answer, VoidCallback select) async {
    if (_finishing) return;
    setState(select);
    final step = _step;
    Analytics.track('onboarding_answered', {
      'step': step.name,
      'answer': answer,
    });
    unawaited(_service.remember(key, answer));
    final pause = Motion.read(context).scale(const Duration(milliseconds: 220));
    if (pause > Duration.zero) await Future<void>.delayed(pause);
    if (!mounted || _step != step) return;
    _next();
  }

  void _pickVoice(PronunciationVoice voice) {
    try {
      Provider.of<ThemeService>(
        context,
        listen: false,
      ).setPronunciationVoice(voice.id);
    } on ProviderNotFoundException {
      // Built on its own (tests).
    }
    _answer(OnboardingKeys.voice, voice.id, () => _voice = voice.id);
  }

  Future<void> _answerNotifications(bool turnOn) async {
    if (_finishing) return;
    Analytics.track('onboarding_answered', {
      'step': OnboardingStep.notifications.name,
      'answer': turnOn ? 'turn_on' : 'maybe_later',
    });
    var allowed = false;
    if (turnOn) allowed = await _primer.requestDuringOnboarding();
    unawaited(
      _service.remember(
        OnboardingKeys.notifications,
        turnOn ? (allowed ? 'allowed' : 'refused') : 'maybe_later',
      ),
    );
    if (mounted) _next();
  }

  Future<void> _finish({required bool skipped}) async {
    if (_finishing) return;
    setState(() => _finishing = true);
    List<Level> levels;
    try {
      levels = await _levels.timeout(const Duration(seconds: 3));
    } catch (_) {
      levels = const [];
    }
    final sublevels = [
      for (final level in levels)
        for (final sub in level.sublevels)
          if (sub.levelId != null) sub,
    ];
    final startId = Placement.resolve(_knowledge, [
      for (final sub in sublevels) sub.levelId!,
    ]);
    Sublevel? start;
    for (final sub in sublevels) {
      if (sub.levelId == startId) start = sub;
    }
    await _service.remember(OnboardingKeys.startLevel, startId);
    await _service.remember(
      OnboardingKeys.outcome,
      skipped ? 'skipped' : 'completed',
    );
    await _service.remember(
      OnboardingKeys.completedAt,
      DateTime.now().toUtc().toIso8601String(),
    );
    await _service.setStatus(
      skipped ? OnboardingStatus.skipped : OnboardingStatus.done,
    );
    Analytics.track(skipped ? 'onboarding_exited' : 'onboarding_completed', {
      'motivation': _motivation?.name,
      'prior_knowledge': _knowledge?.id,
      'voice': _voice,
      'daily_goal': _goal?.lessons,
      'start_level': startId,
      'start_level_found': start != null,
      'last_step': _step.name,
      'ms': _elapsed.elapsedMilliseconds,
    });
    // GET /learn/path reads onboarding/start_level, so give the write a
    // moment to land before Home loads. Offline, it is sent next launch.
    try {
      await _service.syncPending().timeout(const Duration(milliseconds: 1500));
    } catch (_) {}
    if (!mounted) return;
    final result = OnboardingResult(
      skipped: skipped,
      startLevelId: startId,
      startLevel: start,
    );
    final onFinished = widget.onFinished;
    if (onFinished != null) {
      onFinished(result);
      return;
    }
    _leave(result);
  }

  void _leave(OnboardingResult result) {
    final navigator = Navigator.of(context);
    navigator.pushReplacement(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'main'),
        pageBuilder: (_, __, ___) => const MainNavigationScreen(),
        transitionsBuilder:
            (_, animation, __, child) =>
                FadeTransition(opacity: animation, child: child),
        transitionDuration: Motion.read(
          context,
        ).scale(const Duration(milliseconds: 300)),
      ),
    );
    final start = result.startLevel;
    if (!result.skipped && start != null) {
      Analytics.track('onboarding_first_lesson_opened', {
        'start_level': result.startLevelId,
      });
      openTopic(navigator.context, start, source: 'onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    return PopScope(
      canPop: _index == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: AppTokens.background(context),
        body: SafeArea(
          child: Column(
            children: [
              ContentWidth(
                maxWidth: ContentWidth.reading,
                child: _TopBar(
                  index: _index,
                  count: _steps.length,
                  onBack: _index == 0 ? null : _back,
                  onSkip: _finishing ? null : _skip,
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: motion.scale(const Duration(milliseconds: 280)),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final dx = _forward ? 0.08 : -0.08;
                    final slide = Tween<Offset>(
                      begin: Offset(child.key == ValueKey(_step) ? dx : -dx, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child:
                          motion.animates
                              ? SlideTransition(position: slide, child: child)
                              : child,
                    );
                  },
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _body(_step),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(OnboardingStep step) => switch (step) {
    OnboardingStep.hello => _HelloStep(
      busy: _finishing,
      onStart: () {
        Analytics.track('onboarding_answered', {
          'step': OnboardingStep.hello.name,
          'answer': 'start',
        });
        _next();
      },
    ),
    OnboardingStep.motivation => _QuestionStep(
      question: 'Why are you learning Tibetan?',
      children: [
        for (final m in Motivation.values)
          _ChoiceCard(
            key: ValueKey('motivation_${m.name}'),
            title: m.title,
            subtitle: m.subtitle,
            icon: _motivationIcon(m),
            hue: _motivationHue(m),
            selected: _motivation == m,
            onTap:
                () => _answer(
                  OnboardingKeys.motivation,
                  m.name,
                  () => _motivation = m,
                ),
          ),
      ],
    ),
    OnboardingStep.knowledge => _QuestionStep(
      question: 'How much Tibetan do you know?',
      hint: 'This picks where you start. Earlier lessons stay open.',
      children: [
        for (final k in PriorKnowledge.values)
          _ChoiceCard(
            key: ValueKey('knowledge_${k.id}'),
            title: k.title,
            subtitle: k.subtitle,
            icon: _knowledgeIcon(k),
            hue: _knowledgeHue(k),
            selected: _knowledge == k,
            onTap:
                () => _answer(
                  OnboardingKeys.priorKnowledge,
                  k.id,
                  () => _knowledge = k,
                ),
          ),
      ],
    ),
    OnboardingStep.voice => _QuestionStep(
      question: 'Which Tibetan do you want to hear?',
      hint: 'You can change the voice any time in Settings.',
      children: [
        for (final dialect in TibetanDialect.values) ..._voiceCards(dialect),
      ],
    ),
    OnboardingStep.goal => _QuestionStep(
      question: 'How much a day?',
      hint: 'A little every day beats a lot once a week.',
      children: [
        for (final g in DailyGoal.values)
          _ChoiceCard(
            key: ValueKey('goal_${g.lessons}'),
            title: g.title,
            subtitle: g.subtitle,
            icon: _goalIcon(g),
            hue: AppPalette.yellow,
            selected: _goal == g,
            onTap:
                () => _answer(
                  OnboardingKeys.dailyGoal,
                  g.lessons,
                  () => _goal = g,
                ),
          ),
      ],
    ),
    OnboardingStep.notifications => _PrimerStep(
      busy: _finishing,
      onTurnOn: () => _answerNotifications(true),
      onLater: () => _answerNotifications(false),
    ),
  };

  List<Widget> _voiceCards(TibetanDialect dialect) {
    final voices = [
      for (final v in PronunciationVoices.all)
        if (v.dialect == dialect) v,
    ];
    final tibetan = _dialectTibetan(dialect);
    if (voices.isEmpty) {
      return [
        _ChoiceCard(
          key: ValueKey('voice_${dialect.name}'),
          title: dialect.label,
          tibetan: tibetan,
          subtitle: '${dialect.region} · coming soon',
          icon: Icons.schedule,
          hue: AppPalette.lapis,
          selected: false,
          onTap: null,
        ),
      ];
    }
    return [
      for (final voice in voices)
        _ChoiceCard(
          key: ValueKey('voice_${voice.id}'),
          title: dialect.label,
          tibetan: tibetan,
          subtitle: '${dialect.region} · ${voice.speaker} voice',
          icon: Icons.record_voice_over,
          hue:
              dialect == TibetanDialect.lhasa
                  ? AppPalette.blue
                  : AppPalette.red,
          selected: _voice == voice.id,
          onTap: () => _pickVoice(voice),
        ),
    ];
  }

  static String _dialectTibetan(TibetanDialect dialect) => switch (dialect) {
    TibetanDialect.lhasa => 'ལྷ་ས།',
    TibetanDialect.kham => 'ཁམས།',
    TibetanDialect.amdo => 'ཨ་མདོ།',
  };

  static IconData _motivationIcon(Motivation m) => switch (m) {
    Motivation.heritage => Icons.family_restroom,
    Motivation.buddhist => Icons.menu_book,
    Motivation.travel => Icons.terrain,
    Motivation.curious => Icons.lightbulb_outline,
  };

  static AppHue _motivationHue(Motivation m) => switch (m) {
    Motivation.heritage => AppPalette.red,
    Motivation.buddhist => AppPalette.saffron,
    Motivation.travel => AppPalette.blue,
    Motivation.curious => AppPalette.green,
  };

  static IconData _knowledgeIcon(PriorKnowledge k) => switch (k) {
    PriorKnowledge.none => Icons.spa_outlined,
    PriorKnowledge.speakSome => Icons.chat_bubble_outline,
    PriorKnowledge.canRead => Icons.auto_stories,
    PriorKnowledge.conversational => Icons.forum_outlined,
  };

  static AppHue _knowledgeHue(PriorKnowledge k) => switch (k) {
    PriorKnowledge.none => AppPalette.green,
    PriorKnowledge.speakSome => AppPalette.blue,
    PriorKnowledge.canRead => AppPalette.saffron,
    PriorKnowledge.conversational => AppPalette.lapis,
  };

  static IconData _goalIcon(DailyGoal g) => switch (g) {
    DailyGoal.easy => Icons.wb_twilight,
    DailyGoal.steady => Icons.directions_walk,
    DailyGoal.keen => Icons.hiking,
    DailyGoal.serious => Icons.landscape,
  };
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.index,
    required this.count,
    required this.onBack,
    required this.onSkip,
  });

  final int index;
  final int count;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final ink = AppTokens.ink(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 0),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child:
                onBack == null
                    ? null
                    : IconButton(
                      key: const ValueKey('onboarding_back'),
                      tooltip: 'Back',
                      icon: Icon(Icons.arrow_back, color: ink),
                      onPressed: onBack,
                    ),
          ),
          Expanded(
            child: Semantics(
              label: 'Step ${index + 1} of $count',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: TweenAnimationBuilder<double>(
                  tween: Tween(end: (index + 1) / count),
                  duration: Motion.of(
                    context,
                  ).scale(const Duration(milliseconds: 300)),
                  builder:
                      (context, value, _) => LinearProgressIndicator(
                        value: value,
                        minHeight: 8,
                        backgroundColor: AppTokens.divider(context),
                        color: AppTokens.accent(AppPalette.blue, context),
                      ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const ValueKey('onboarding_skip'),
            onPressed: onSkip,
            style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
            child: Text(
              'Skip',
              style: AppTextStyles.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTokens.inkSoft(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A step with Norbu, a message and one or two pinned buttons.
class _PinnedStep extends StatelessWidget {
  const _PinnedStep({
    required this.children,
    required this.primaryLabel,
    required this.onPrimary,
    this.primaryKey,
    this.secondaryLabel,
    this.onSecondary,
    this.secondaryKey,
  });

  final List<Widget> children;
  final String primaryLabel;
  final VoidCallback? onPrimary;
  final Key? primaryKey;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Key? secondaryKey;

  @override
  Widget build(BuildContext context) {
    final tablet = Breakpoints.isTablet(context);
    return Column(
      children: [
        Expanded(
          child: ContentWidth(
            maxWidth: ContentWidth.reading,
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: tablet ? 48 : 16,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: children,
                ),
              ),
            ),
          ),
        ),
        ContentWidth(
          maxWidth: ContentWidth.reading,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: FilledButton(
                    key: primaryKey,
                    onPressed: onPrimary,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.button),
                      ),
                    ),
                    child: Text(
                      primaryLabel,
                      style: AppTextStyles.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: 48,
                  child:
                      secondaryLabel == null
                          ? null
                          : Center(
                            child: TextButton(
                              key: secondaryKey,
                              onPressed: onSecondary,
                              child: Text(
                                secondaryLabel!,
                                style: AppTextStyles.poppins(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: AppTokens.inkSoft(context),
                                ),
                              ),
                            ),
                          ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HelloStep extends StatelessWidget {
  const _HelloStep({required this.onStart, required this.busy});

  final VoidCallback onStart;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tablet = Breakpoints.isTablet(context);
    return _PinnedStep(
      primaryKey: const ValueKey('onboarding_start'),
      primaryLabel: 'Let\'s begin',
      onPrimary: busy ? null : onStart,
      children: [
        YakMascot(
          mood: YakMood.waving,
          size: tablet ? 260 : 190,
          semanticLabel: '${YakLines.name} the yak waving hello',
        ),
        const SizedBox(height: 20),
        TibetanText(
          'བཀྲ་ཤིས་བདེ་ལེགས།',
          size: TibetanType.titleSize,
          color: AppTokens.accent(AppPalette.blue, context),
          textAlign: TextAlign.center,
          semanticsLabel: 'Tashi delek',
        ),
        const SizedBox(height: 4),
        Semantics(
          header: true,
          child: Text(
            'Tashi delek! I\'m ${YakLines.name}.',
            textAlign: TextAlign.center,
            style: AppTextStyles.display(context),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'I\'ll help you read, hear and speak Tibetan. A few quick taps to '
          'set things up, then your first lesson.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            context,
            color: AppTokens.inkSoft(context),
          ).copyWith(fontSize: 16, height: 1.45),
        ),
      ],
    );
  }
}

class _PrimerStep extends StatelessWidget {
  const _PrimerStep({
    required this.onTurnOn,
    required this.onLater,
    required this.busy,
  });

  final VoidCallback onTurnOn;
  final VoidCallback onLater;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final tablet = Breakpoints.isTablet(context);
    return _PinnedStep(
      primaryKey: const ValueKey('onboarding_notify_on'),
      primaryLabel: 'Turn on reminders',
      onPrimary: busy ? null : onTurnOn,
      secondaryKey: const ValueKey('onboarding_notify_later'),
      secondaryLabel: 'Maybe later',
      onSecondary: busy ? null : onLater,
      children: [
        YakMascot(
          mood: YakMood.happy,
          size: tablet ? 220 : 160,
          semanticLabel: '${YakLines.name} the yak',
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(
            'Want a nudge from ${YakLines.name}?',
            textAlign: TextAlign.center,
            style: AppTextStyles.display(context),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'One friendly reminder on evenings you haven\'t practised yet. '
          'Never after midnight, and you can turn it off in Settings.',
          textAlign: TextAlign.center,
          style: AppTextStyles.body(
            context,
            color: AppTokens.inkSoft(context),
          ).copyWith(fontSize: 16, height: 1.45),
        ),
      ],
    );
  }
}

/// Norbu asks [question]; one tap on a choice answers and moves on.
class _QuestionStep extends StatelessWidget {
  const _QuestionStep({
    required this.question,
    required this.children,
    this.hint,
  });

  final String question;
  final String? hint;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final tablet = Breakpoints.isTablet(context);
    return ContentWidth(
      maxWidth: ContentWidth.reading,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, tablet ? 32 : 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                YakMascot(
                  mood: YakMood.thinking,
                  size: tablet ? 112 : 84,
                  animate: false,
                  semanticLabel: '${YakLines.name} the yak',
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTokens.surface(context),
                      border: Border.all(color: AppTokens.cardBorder(context)),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(AppRadius.card),
                        topRight: Radius.circular(AppRadius.card),
                        bottomRight: Radius.circular(AppRadius.card),
                        bottomLeft: Radius.circular(4),
                      ),
                      boxShadow: AppTokens.shadow(context),
                    ),
                    child: Semantics(
                      header: true,
                      child: Text(
                        question,
                        style: AppTextStyles.poppins(
                          fontSize: tablet ? 22 : 19,
                          fontWeight: FontWeight.w700,
                          color: AppTokens.ink(context),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (hint != null) ...[
              const SizedBox(height: 12),
              Text(
                hint!,
                style: AppTextStyles.caption(context).copyWith(fontSize: 13),
              ),
            ],
            const SizedBox(height: 20),
            for (final child in children) ...[
              child,
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.hue,
    required this.selected,
    required this.onTap,
    this.tibetan,
  });

  final String title;
  final String subtitle;
  final String? tibetan;
  final IconData icon;
  final AppHue hue;
  final bool selected;

  /// Null = not available yet (shown dimmed).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final accent = AppTokens.accent(hue, context);
    final blue = AppTokens.accent(AppPalette.blue, context);
    return Semantics(
      button: true,
      enabled: enabled,
      selected: selected,
      label: '$title. $subtitle',
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Material(
          color:
              selected
                  ? AppTokens.hueTint(AppPalette.blue, context)
                  : AppTokens.surface(context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: BorderSide(
              color: selected ? blue : AppTokens.cardBorder(context),
              width: selected ? 2 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 72),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppTokens.hueTint(hue, context),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: accent, size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  title,
                                  style: AppTextStyles.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: AppTokens.ink(context),
                                  ),
                                ),
                              ),
                              if (tibetan != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  tibetan!,
                                  style: TibetanType.style(
                                    size: TibetanType.smallSize,
                                    color: AppTokens.inkSoft(context),
                                    height: TibetanType.minLineHeight,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: AppTextStyles.caption(
                              context,
                            ).copyWith(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    if (selected)
                      Icon(Icons.check_circle, color: blue, size: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
