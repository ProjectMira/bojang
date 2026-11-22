import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lesson_content.dart';
import '../models/lesson_note.dart';
import '../models/level_models.dart';
import '../services/analytics.dart';
import '../services/api_service.dart';
import '../services/pronunciation_player.dart';
import '../services/theme_service.dart';
import '../theme/app_tokens.dart';
import '../theme/motion.dart';
import '../theme/tibetan_type.dart';
import '../utils/yak_lines.dart';
import '../widgets/app_text_style.dart';
import '../widgets/content_width.dart';
import '../widgets/reading_voice_pickers.dart';
import '../widgets/romanisation_text.dart';
import '../widgets/speaker_button.dart';
import '../widgets/yak_says.dart';
import 'quiz_screen.dart';

/// Opens a topic: Basics lessons show their teaching cards first, every
/// other topic goes straight into the quiz.
void openTopic(
  BuildContext context,
  Sublevel sublevel, {
  String source = 'topic',
}) {
  final levelId = sublevel.levelId;
  if (sublevel.hasLesson && levelId != null) {
    Navigator.push(
      context,
      screenRoute(
        'lesson_intro',
        (context) => LessonIntroScreen(
          levelId: levelId,
          title: sublevel.name,
          topicPath: sublevel.path,
          source: source,
        ),
      ),
    );
    return;
  }
  Navigator.push(
    context,
    screenRoute(
      'quiz',
      (context) => QuizScreen(
        topicFilePath: sublevel.path,
        title: sublevel.name,
        source: source,
      ),
    ),
  );
}

/// Teach before testing, briefly: a Basics lesson's letters or phrases as
/// cards (tap to hear one and see how it sounds), the lesson's notes behind
/// a small Tips button, and a pinned button straight into practice.
class LessonIntroScreen extends StatefulWidget {
  final String levelId;
  final String title;
  final String topicPath;
  final String source;

  const LessonIntroScreen({
    super.key,
    required this.levelId,
    required this.title,
    required this.topicPath,
    this.source = 'topic',
  });

  @override
  State<LessonIntroScreen> createState() => _LessonIntroScreenState();
}

class _LessonIntroScreenState extends State<LessonIntroScreen> {
  late Future<LessonContent?> _lesson;
  final DateTime _openedAt = DateTime.now();
  final Set<String> _heard = {};
  bool _tipsOpened = false;

  @override
  void initState() {
    super.initState();
    _lesson = _load();
    Analytics.track('lesson_intro_opened', {
      'level': widget.levelId,
      'source': widget.source,
    });
  }

  Future<LessonContent?> _load() async {
    final json = await ApiService().getLevelLesson(widget.levelId);
    if (json == null) return null;
    final lesson = LessonContent.fromJson(json);
    if (mounted) {
      final voice = context.read<ThemeService>().pronunciationVoice;
      PronunciationPlayer.instance.prefetch(
        lesson.items.map((i) => i.audioFor(voice)),
      );
    }
    return lesson;
  }

  @override
  void dispose() {
    PronunciationPlayer.instance.stop();
    super.dispose();
  }

  void _play(LessonItem item) {
    final theme = context.read<ThemeService>();
    _heard.add(item.id);
    PronunciationPlayer.instance.play(
      item.audioFor(theme.pronunciationVoice),
      volume: theme.pronunciationVolume,
      source: 'lesson_card',
    );
  }

  void _showTips(LessonContent lesson) {
    _tipsOpened = true;
    Analytics.track('lesson_tips_opened', {'level': widget.levelId});
    _showLessonSheet<void>(
      context,
      (sheetContext) => _TipsSheet(notes: lesson.notes),
    );
  }

  /// Plays [index] and, when there is more to say about it than the card
  /// shows, opens its sheet. The sheet steps through the rest of the lesson
  /// and ends at practice.
  void _openItem(LessonContent lesson, int index) {
    final item = lesson.items[index];
    _play(item);
    final note = LessonNote.parse(item.note);
    final hasMore =
        lesson.isScript ||
        (item.note.isNotEmpty && item.note != item.english && !note.isEmpty);
    if (!hasMore) return;
    Analytics.track('lesson_item_opened', {
      'level': widget.levelId,
      'item': item.id,
    });
    _showLessonSheet<void>(
      context,
      (sheetContext) => _ItemSheet(
        lesson: lesson,
        initialIndex: index,
        onPlay: _play,
        onPractice: () {
          Navigator.of(sheetContext).pop();
          _startPractice(lesson);
        },
      ),
    );
  }

  void _startPractice(LessonContent? lesson) {
    Analytics.track('lesson_intro_practice', {
      'level': widget.levelId,
      'items': lesson?.items.length ?? 0,
      'heard': _heard.length,
      'tips_opened': _tipsOpened,
      'duration_s': DateTime.now().difference(_openedAt).inSeconds,
    });
    Navigator.pushReplacement(
      context,
      screenRoute(
        'quiz',
        (context) => QuizScreen(
          topicFilePath: widget.topicPath,
          title: widget.title,
          source: 'lesson_intro',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTokens.background(context),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: AppTextStyles.title(context),
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        systemOverlayStyle: AppTokens.statusBar(context),
        foregroundColor: AppTokens.ink(context),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 12),
            child: Center(child: VoiceChip(source: 'lesson_intro')),
          ),
        ],
      ),
      body: FutureBuilder<LessonContent?>(
        future: _lesson,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const YakLoader(message: 'Getting your lesson ready…');
          }
          final lesson = snapshot.data;
          if (lesson == null || lesson.items.isEmpty) {
            return YakNotice.line(
              YakLines.offline,
              actionLabel: 'Practise anyway',
              onAction: () => _startPractice(null),
            );
          }
          return Column(
            children: [
              Expanded(child: _buildCards(context, lesson)),
              _buildPracticeBar(context, lesson),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCards(BuildContext context, LessonContent lesson) {
    final tablet = Breakpoints.isTablet(context);
    // Script lessons whose items are words carry a short meaning per card.
    final hasGlosses = lesson.isScript && !_isLetterLesson(lesson);
    return ContentWidth(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Letters are small square cards; phrases need a full row.
          final minWidth = lesson.isScript ? (tablet ? 160.0 : 140.0) : 300.0;
          final columns = (constraints.maxWidth / minWidth).floor().clamp(1, 6);
          final extent =
              lesson.isScript
                  ? (hasGlosses ? 184.0 : 160.0) + (tablet ? 16 : 0)
                  : 156.0;
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isLetterLesson(lesson)
                              ? 'Tap a letter to hear it'
                              : 'Tap a card to hear it',
                          style: AppTextStyles.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppTokens.ink(context),
                          ),
                        ),
                      ),
                      if (lesson.notes.isNotEmpty)
                        _TipsButton(onTap: () => _showTips(lesson)),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    mainAxisExtent: extent,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ItemCard(
                      item: lesson.items[index],
                      isScript: lesson.isScript,
                      onTap: () => _openItem(lesson, index),
                    ),
                    childCount: lesson.items.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPracticeBar(BuildContext context, LessonContent lesson) {
    return Container(
      decoration: BoxDecoration(
        color: AppTokens.surface(context),
        border: Border(top: BorderSide(color: AppTokens.cardBorder(context))),
      ),
      child: SafeArea(
        top: false,
        child: ContentWidth(
          maxWidth: ContentWidth.reading,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: _PracticeButton(onPressed: () => _startPractice(lesson)),
          ),
        ),
      ),
    );
  }
}

/// A script lesson of single letters and vowel signs, as opposed to one of
/// whole words with a meaning each.
bool _isLetterLesson(LessonContent lesson) =>
    lesson.isScript &&
    !lesson.items.any((i) => LessonNote.parse(i.note).isShortMeaning);

/// The one primary action on the screen and in the item sheet.
class _PracticeButton extends StatelessWidget {
  final VoidCallback onPressed;
  final String label;

  const _PracticeButton({
    required this.onPressed,
    this.label = 'Start practice',
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          label,
          style: AppTextStyles.poppins(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet sized to its content and no wider than a reading column on
/// iPad.
Future<T?> _showLessonSheet<T>(BuildContext context, WidgetBuilder builder) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: AppTokens.background(context),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder:
        (sheetContext) => SafeArea(
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: ContentWidth.reading),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: builder(sheetContext),
              ),
            ),
          ),
        ),
  );
}

class _TipsButton extends StatelessWidget {
  final VoidCallback onTap;

  const _TipsButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = AppTokens.accent(AppPalette.blue, context);
    return Semantics(
      button: true,
      label: 'Tips for this lesson',
      excludeSemantics: true,
      child: Material(
        color: AppTokens.hueTint(AppPalette.blue, context),
        shape: const StadiumBorder(),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 40, minWidth: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 18,
                    color: accent,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Tips',
                    style: AppTextStyles.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: accent,
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

class _TipsSheet extends StatelessWidget {
  final List<String> notes;

  const _TipsSheet({required this.notes});

  @override
  Widget build(BuildContext context) {
    final ink = AppTokens.ink(context);
    final accent = AppTokens.accent(AppPalette.blue, context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, color: accent),
            const SizedBox(width: 8),
            Text('Tips', style: AppTextStyles.title(context)),
          ],
        ),
        const SizedBox(height: 12),
        for (final note in notes)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 9, right: 10),
                  child: Icon(Icons.circle, size: 7, color: accent),
                ),
                Expanded(
                  child: Text(note, style: AppTextStyles.mixed(context)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 16),
        SizedBox(
          height: 48,
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: ink,
              side: BorderSide(
                color: AppTokens.cardBorder(context),
                width: 1.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Got it',
              style: AppTextStyles.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: ink,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// One letter (or word) up close: the sound hint and the example word that
/// used to crowd the card, plus Next so the learner can walk the lesson and
/// land on practice.
class _ItemSheet extends StatefulWidget {
  final LessonContent lesson;
  final int initialIndex;
  final ValueChanged<LessonItem> onPlay;
  final VoidCallback onPractice;

  const _ItemSheet({
    required this.lesson,
    required this.initialIndex,
    required this.onPlay,
    required this.onPractice,
  });

  @override
  State<_ItemSheet> createState() => _ItemSheetState();
}

class _ItemSheetState extends State<_ItemSheet> {
  late int _index = widget.initialIndex;

  bool get _isLast => _index >= widget.lesson.items.length - 1;

  void _next() {
    setState(() => _index++);
    widget.onPlay(widget.lesson.items[_index]);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.lesson.items[_index];
    final isScript = widget.lesson.isScript;
    final note = LessonNote.parse(item.note);
    final ink = AppTokens.ink(context);
    final accent = AppTokens.accent(AppPalette.blue, context);
    final soft = RomanisationText.colorOf(context);
    final tablet = Breakpoints.isTablet(context);
    final voice = context.watch<ThemeService>().pronunciationVoice;
    final url = item.audioFor(voice);
    final hint =
        note.hint.isNotEmpty && note.hint != item.english ? note.hint : '';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TibetanText(
                    item.tibetan,
                    size: isScript ? (tablet ? 112 : 96) : (tablet ? 64 : 48),
                    color: ink,
                    maxLines: 2,
                  ),
                  if (isScript)
                    Text(
                      item.english,
                      style: AppTextStyles.poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    )
                  else ...[
                    RomanisationText(
                      item.romanisation,
                      fontSize: 16,
                      textAlign: TextAlign.start,
                      alignment: CrossAxisAlignment.start,
                    ),
                    Text(
                      item.english,
                      style: AppTextStyles.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: ink,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (url != null)
              SpeakerButton(url: url, size: 32)
            else
              Icon(
                Icons.volume_off,
                color: soft,
                semanticLabel: 'No recording yet',
              ),
          ],
        ),
        if (hint.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            hint,
            style: AppTextStyles.mixed(context, fontSize: 16, color: ink),
          ),
        ],
        if (note.hasExample) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            decoration: BoxDecoration(
              color: AppTokens.surface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTokens.cardBorder(context)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Example word',
                  style: AppTextStyles.caption(context, color: soft),
                ),
                const SizedBox(height: 2),
                TibetanText(
                  note.exampleTibetan!,
                  size: 34,
                  color: ink,
                  maxLines: 2,
                ),
                if (note.exampleMeaning != null)
                  Text(
                    note.exampleMeaning!,
                    style: AppTextStyles.poppins(fontSize: 15, color: ink),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        if (_isLast)
          _PracticeButton(onPressed: widget.onPractice)
        else ...[
          _PracticeButton(
            onPressed: _next,
            label: _isLetterLesson(widget.lesson) ? 'Next letter' : 'Next',
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: widget.onPractice,
            style: TextButton.styleFrom(
              foregroundColor: accent,
              minimumSize: const Size.fromHeight(44),
            ),
            child: Text(
              'Start practice',
              style: AppTextStyles.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: accent,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A card is the letter, its reading and a speaker: nothing to read before
/// tapping it.
class _ItemCard extends StatelessWidget {
  final LessonItem item;
  final bool isScript;
  final VoidCallback onTap;

  const _ItemCard({
    required this.item,
    required this.isScript,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ink = AppTokens.ink(context);
    final accent = AppTokens.accent(AppPalette.blue, context);
    final soft = RomanisationText.colorOf(context);
    final isPlayingUrl = PronunciationPlayer.instance.playingUrl;
    final voice = context.watch<ThemeService>().pronunciationVoice;
    final url = item.audioFor(voice);
    final note = LessonNote.parse(item.note);
    final gloss = isScript && note.isShortMeaning ? note.hint : null;
    final tablet = Breakpoints.isTablet(context);
    final duration = Motion.of(
      context,
    ).scale(const Duration(milliseconds: 150));
    return ValueListenableBuilder<String?>(
      valueListenable: isPlayingUrl,
      builder: (context, playing, _) {
        final active = url != null && playing == url;
        final speaker = Icon(
          !item.hasAudio
              ? Icons.volume_off
              : (active ? Icons.volume_up_rounded : Icons.volume_up_outlined),
          size: 20,
          color: item.hasAudio ? accent : soft,
        );
        return Semantics(
          button: true,
          label:
              isScript
                  ? '${item.tibetan}, read ${item.english}${gloss == null ? '' : ', $gloss'}'
                  : '${item.tibetan}, ${item.english}',
          hint: item.hasAudio ? 'Plays it and shows how it sounds' : null,
          excludeSemantics: true,
          child: Material(
            color: AppTokens.surface(context),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: AnimatedContainer(
                duration: duration,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: active ? accent : AppTokens.cardBorder(context),
                    width: active ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Center(
                        child: TibetanText(
                          item.tibetan,
                          size:
                              isScript
                                  ? (tablet ? 60 : TibetanType.letterSize)
                                  : TibetanType.titleSize,
                          color: ink,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    if (isScript) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              item.english,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          speaker,
                        ],
                      ),
                      if (gloss != null)
                        Text(
                          gloss,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.poppins(
                            fontSize: 13,
                            color: soft,
                          ),
                        ),
                    ] else ...[
                      RomanisationText(item.romanisation, fontSize: 15),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              item.english,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTextStyles.poppins(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          speaker,
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
