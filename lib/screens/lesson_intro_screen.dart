import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/lesson_content.dart';
import '../models/level_models.dart';
import '../services/analytics.dart';
import '../services/api_service.dart';
import '../services/pronunciation_player.dart';
import '../services/theme_service.dart';
import '../theme/app_tokens.dart';
import '../utils/yak_lines.dart';
import '../widgets/app_text_style.dart';
import '../widgets/content_width.dart';
import '../widgets/reading_voice_pickers.dart';
import '../widgets/romanisation_text.dart';
import '../widgets/yak_says.dart';
import 'quiz_screen.dart';

/// Opens a topic: Basics lessons show their teaching cards first, every
/// other topic goes straight into the quiz.
void openTopic(BuildContext context, Sublevel sublevel, {String source = 'topic'}) {
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

/// Teach before testing: a Basics lesson's notes and its letters or phrases
/// as cards (tap to hear), then a button into practice.
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

  void _startPractice(LessonContent? lesson) {
    Analytics.track('lesson_intro_practice', {
      'level': widget.levelId,
      'items': lesson?.items.length ?? 0,
      'heard': _heard.length,
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
    return ContentWidth(
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Letters are small square cards; phrases need a full row.
          final minWidth = lesson.isScript ? 150.0 : 300.0;
          final columns = (constraints.maxWidth / minWidth).floor().clamp(1, 5);
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                sliver: SliverToBoxAdapter(child: _NotesCard(lesson: lesson)),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    'Tap a card to hear it',
                    style: AppTextStyles.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppTokens.ink(context),
                    ),
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
                    mainAxisExtent: lesson.isScript ? 200 : 168,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => _ItemCard(
                      item: lesson.items[index],
                      isScript: lesson.isScript,
                      onTap: () => _play(lesson.items[index]),
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
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDeep,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => _startPractice(lesson),
                child: Text(
                  'Start practice',
                  style: AppTextStyles.poppins(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesCard extends StatelessWidget {
  final LessonContent lesson;

  const _NotesCard({required this.lesson});

  @override
  Widget build(BuildContext context) {
    if (lesson.notes.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTokens.surface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTokens.cardBorder(context)),
        boxShadow: AppTokens.shadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in lesson.notes)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 7, right: 10),
                    child: Icon(Icons.circle, size: 7, color: AppColors.primary),
                  ),
                  Expanded(
                    child: Text(
                      note,
                      style: AppTextStyles.poppins(
                        fontSize: 15,
                        height: 1.5,
                        color: AppTokens.ink(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

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
    final isPlayingUrl = PronunciationPlayer.instance.playingUrl;
    final voice = context.watch<ThemeService>().pronunciationVoice;
    final url = item.audioFor(voice);
    return ValueListenableBuilder<String?>(
      valueListenable: isPlayingUrl,
      builder: (context, playing, _) {
        final active = url != null && playing == url;
        return Semantics(
          button: true,
          label:
              isScript
                  ? '${item.tibetan}, read ${item.english}. ${item.note}'
                  : '${item.tibetan}, ${item.english}',
          excludeSemantics: true,
          child: Material(
            color: AppTokens.surface(context),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color:
                        active ? AppColors.primary : AppTokens.cardBorder(context),
                    width: active ? 2 : 1,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          item.tibetan,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.poppins(
                            fontSize: isScript ? 52 : 30,
                            fontWeight: FontWeight.w600,
                            color: ink,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (isScript)
                      Text(
                        item.english,
                        style: AppTextStyles.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDeep,
                        ),
                      )
                    else ...[
                      RomanisationText(item.romanisation, fontSize: 15),
                      Text(
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
                    ],
                    if (item.note.isNotEmpty && item.note != item.english) ...[
                      const SizedBox(height: 4),
                      Text(
                        item.note,
                        textAlign: TextAlign.center,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.poppins(
                          fontSize: 12,
                          color: RomanisationText.colorOf(context),
                          height: 1.35,
                        ),
                      ),
                    ],
                    if (!item.hasAudio)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Icon(
                          Icons.volume_off,
                          size: 14,
                          color: RomanisationText.colorOf(context),
                          semanticLabel: 'No recording yet',
                        ),
                      ),
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
