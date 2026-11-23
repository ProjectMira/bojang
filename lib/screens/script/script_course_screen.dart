import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/script/script_chart.dart';
import '../../services/analytics.dart';
import '../../services/api_service.dart';
import '../../services/pronunciation_player.dart';
import '../../services/theme_service.dart';
import '../../theme/app_tokens.dart';
import '../../theme/motion.dart';
import '../../theme/tibetan_type.dart';
import '../../widgets/app_text_style.dart';
import '../../widgets/content_width.dart';
import '../../widgets/yak_says.dart';
import '../quiz_screen.dart';
import 'character_sheet.dart';

/// "Reading Tibetan": the letter chart coloured by strength, with Learn
/// (the next weak letters) and Practice (a strength-weighted session).
/// Route `/script`.
class ScriptCourseScreen extends StatefulWidget {
  const ScriptCourseScreen({super.key, this.source});

  /// Where it was opened from, for analytics.
  final String? source;

  @override
  State<ScriptCourseScreen> createState() => _ScriptCourseScreenState();
}

class _ScriptCourseScreenState extends State<ScriptCourseScreen> {
  ScriptChart? _chart;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load(first: true);
  }

  Future<void> _load({bool first = false}) async {
    setState(() => _loading = _chart == null);
    final json = await ApiService().getScriptCourse();
    if (!mounted) return;
    final chart = json == null ? ScriptChart.fallback() : ScriptChart.fromJson(json);
    setState(() {
      _chart = chart;
      _loading = false;
    });
    final voice = context.read<ThemeService>().pronunciationVoice;
    PronunciationPlayer.instance.prefetch(chart.chars.map((c) => c.audioFor(voice)));
    if (first) {
      Analytics.track('script_course_opened', {
        'source': widget.source ?? 'unknown',
        'offline': chart.offline,
        'seen': chart.seenCount,
        'strong': chart.strongCount,
        'total': chart.total,
        'gate_passed': chart.gatePassed,
      });
    }
  }

  void _open(ScriptChar item) {
    final theme = context.read<ThemeService>();
    final url = item.audioFor(theme.pronunciationVoice);
    if (url != null) {
      PronunciationPlayer.instance.play(url, volume: theme.pronunciationVolume, source: 'script_chart');
    }
    Analytics.track('script_char_opened', {
      'char': item.char,
      'kind': item.kind,
      'strength': (item.strength * 100).round(),
      'seen': item.seen,
      'has_audio': url != null,
      'voice': theme.pronunciationVoice,
    });
    showCharacterSheet(context, item);
  }

  Future<void> _startSession(String mode) async {
    final chart = _chart;
    Analytics.track(mode == 'learn' ? 'script_learn_started' : 'script_practice_started', {
      'next': chart?.nextToLearn().map((c) => c.char).join(),
      'seen': chart?.seenCount,
      'strong': chart?.strongCount,
    });
    await Navigator.of(context).push(
      MaterialPageRoute(
        settings: RouteSettings(name: 'script_$mode'),
        builder: (_) => QuizScreen(
          topicFilePath: 'api://script/$mode',
          title: mode == 'learn' ? 'Learn letters' : 'Practise letters',
          source: 'script_course',
        ),
      ),
    );
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background(context),
      appBar: AppBar(
        title: Text(
          'Reading Tibetan',
          style: AppTextStyles.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: AppTokens.ink(context)),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: AppTokens.ink(context),
        systemOverlayStyle: AppTokens.statusBar(context),
      ),
      body: SafeArea(
        top: false,
        child: ContentWidth(
          child: _loading
              ? const YakLoader()
              : RefreshIndicator(onRefresh: _load, child: _body(_chart!)),
        ),
      ),
    );
  }

  Widget _body(ScriptChart chart) {
    final next = chart.nextToLearn();
    final canPractise = chart.seenCount > 0;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        _Summary(chart: chart),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: chart.offline ? null : () => _startSession('learn'),
                icon: const Icon(Icons.school_rounded),
                label: Text(
                  next.isEmpty ? 'Learn' : 'Learn ${next.map((c) => c.shown).join(' ')}',
                  style: AppTextStyles.poppins(fontSize: 16, fontWeight: FontWeight.w600, height: 1.7)
                      .copyWith(fontFamilyFallback: const [TibetanType.family]),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: chart.offline || !canPractise ? null : () => _startSession('practice'),
                icon: const Icon(Icons.fitness_center_rounded),
                label: const Text('Practice'),
              ),
            ),
          ],
        ),
        if (chart.offline)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Offline: the chart is here, lessons and sounds need a connection.',
              style: AppTextStyles.poppins(fontSize: 13, color: AppTokens.inkSoft(context)),
            ),
          ),
        if (!chart.gatePassed && !chart.offline) ...[
          const SizedBox(height: 12),
          _GateCard(onTap: () => Navigator.of(context).pushNamed('/script/gate').then((_) => _load())),
        ],
        const SizedBox(height: 8),
        for (final group in chart.groups) _GroupView(group: group, onTap: _open),
        const SizedBox(height: 8),
        const _Legend(),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.chart});

  final ScriptChart chart;

  @override
  Widget build(BuildContext context) {
    final share = chart.total == 0 ? 0.0 : chart.strongCount / chart.total;
    return Semantics(
      label: '${chart.strongCount} of ${chart.total} characters strong',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            chart.seenCount == 0
                ? 'Start with the first row: ཀ ཁ ག ང'
                : '${chart.strongCount} of ${chart.total} strong · ${chart.seenCount} started',
            style: AppTextStyles.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: AppTokens.ink(context))
                .copyWith(fontFamilyFallback: const [TibetanType.family]),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: share,
              minHeight: 8,
              backgroundColor: AppTokens.divider(context),
              valueColor: AlwaysStoppedAnimation(AppTokens.accent(AppPalette.green, context)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GateCard extends StatelessWidget {
  const _GateCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTokens.hueTint(AppPalette.yellow, context),
      borderRadius: BorderRadius.circular(AppRadius.card),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.verified_rounded, color: AppTokens.textOnTint(AppColors.gold, context)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Already read Tibetan? Take the reading check to open Unit 2.',
                  style: AppTextStyles.poppins(fontSize: 14, color: AppTokens.ink(context)),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppTokens.inkSoft(context)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupView extends StatelessWidget {
  const _GroupView({required this.group, required this.onTap});

  final ScriptGroup group;
  final ValueChanged<ScriptChar> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            group.title,
            style: AppTextStyles.poppins(fontSize: 18, fontWeight: FontWeight.w700, color: AppTokens.ink(context))
                .copyWith(fontFamilyFallback: const [TibetanType.family]),
          ),
          if (group.subtitle.isNotEmpty)
            Text(group.subtitle, style: AppTextStyles.poppins(fontSize: 13, color: AppTokens.inkSoft(context))),
          const SizedBox(height: 8),
          for (final row in group.rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  for (var i = 0; i < group.columns; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: i < row.length
                          ? StrengthCell(item: row[i], onTap: () => onTap(row[i]))
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Fill and accent for a strength band, from the palette.
(Color fill, Color accent) bandColors(StrengthBand band, BuildContext context) {
  AppHue? hue = switch (band) {
    StrengthBand.unseen => null,
    StrengthBand.weak => AppPalette.saffron,
    StrengthBand.learning => AppPalette.blue,
    StrengthBand.strong => AppPalette.green,
    StrengthBand.mastered => AppPalette.yellow,
  };
  if (hue == null) return (AppTokens.surface(context), AppTokens.inkSoft(context));
  return (AppTokens.hueTint(hue, context), AppTokens.accent(hue, context));
}

/// One chart cell: the character, its reading and a strength bar.
class StrengthCell extends StatelessWidget {
  const StrengthCell({super.key, required this.item, required this.onTap});

  final ScriptChar item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final band = item.band;
    final (fill, accent) = bandColors(band, context);
    final tablet = Breakpoints.isTablet(context);
    final duration = Motion.of(context).scale(const Duration(milliseconds: 250));
    return Semantics(
      button: true,
      label: '${item.shown}, ${item.reading}, ${band.label}',
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: duration,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(AppRadius.chip),
          border: Border.all(
            color: band == StrengthBand.mastered ? accent : AppTokens.cardBorder(context),
            width: band == StrengthBand.mastered ? 2 : 1,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.chip),
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: tablet ? 10 : 6, horizontal: 4),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.shown,
                      style: TibetanType.style(size: tablet ? 48 : 40, color: AppTokens.ink(context)),
                    ),
                  ),
                  Text(
                    item.reading,
                    style: AppTextStyles.poppins(fontSize: tablet ? 14 : 12, color: AppTokens.inkSoft(context)),
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: item.seen ? item.strength.clamp(0.05, 1.0) : 0,
                      minHeight: 4,
                      backgroundColor: AppTokens.divider(context),
                      valueColor: AlwaysStoppedAnimation(accent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final band in StrengthBand.values)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: bandColors(band, context).$1,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: bandColors(band, context).$2),
                ),
              ),
              const SizedBox(width: 4),
              Text(band.label, style: AppTextStyles.poppins(fontSize: 12, color: AppTokens.inkSoft(context))),
            ],
          ),
      ],
    );
  }
}
