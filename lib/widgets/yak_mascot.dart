/// The Bojang yak — the app's mascot, drawn in code so it can blink,
/// breathe and react instead of sitting still like the old logo JPG.
///
/// The head is traced from `logos/Bojang/logo.jpg` (same horns, fringe,
/// muzzle and thick outline) in the logo's own 1024-unit coordinate space;
/// the body, arms and hooves extend that space downward.
///
/// One [YakMascot] is a single character with many moods. Changing [mood]
/// tweens the pose, so the yak visibly *reacts* rather than swapping images.
library;

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// What the yak is feeling. Pick by moment, not by screen.
enum YakMood {
  /// Resting state: gentle smile, idle blink.
  happy,

  /// Greeting — one arm waving.
  waving,

  /// Big win: jumping, both arms up, sparkles.
  cheering,

  /// Quiet satisfaction: closed smiling eyes, blush.
  proud,

  /// After a miss: determined brows, fist up. Never scolding.
  encouraging,

  /// Something was lost (streak, failed lesson): droopy ears, a tear.
  sad,

  /// Loading / waiting on the learner: hoof on chin, looking up.
  thinking,

  /// Nothing happening yet today: eyes shut, Zzz.
  sleeping,

  /// Wide eyes, small "o" mouth.
  surprised,

  /// Thank-you moments: hearts.
  love,
}

enum _EyeStyle { open, smile, closed }

enum _Extra { none, sparkles, tear, zzz, question, hearts }

@immutable
class _Pose {
  const _Pose({
    this.armL = 0.22,
    this.armR = 0.22,
    this.waveL = 0,
    this.waveR = 0,
    this.headTilt = 0,
    this.eyeOpen = 1,
    this.brow = 0,
    this.browTilt = 0,
    this.browLift = 0,
    this.mouthCurve = 0.75,
    this.mouthOpen = 0,
    this.mouthWidth = 1,
    this.earDroop = 0,
    this.lookX = 0,
    this.lookY = 0,
    this.blush = 0,
    this.bounce = 0,
    this.breath = 1,
    this.eyes = _EyeStyle.open,
    this.extra = _Extra.none,
    this.armRInFront = false,
  });

  /// Arm angles in radians. 0 hangs straight down, ~2.6 is raised overhead.
  final double armL;
  final double armR;

  /// How far each arm swings while idling in this pose.
  final double waveL;
  final double waveR;
  final double headTilt;
  final double eyeOpen;

  /// Eyebrow opacity. The logo has none, so they only appear with emotion.
  final double brow;

  /// Positive = worried (inner ends up), negative = determined.
  final double browTilt;
  final double browLift;

  /// -1 frown … 1 smile.
  final double mouthCurve;
  final double mouthOpen;
  final double mouthWidth;
  final double earDroop;
  final double lookX;
  final double lookY;
  final double blush;

  /// Jump height in logo units.
  final double bounce;
  final double breath;
  final _EyeStyle eyes;
  final _Extra extra;
  final bool armRInFront;

  static _Pose lerp(_Pose a, _Pose b, double t) {
    double l(double x, double y) => lerpDouble(x, y, t)!;
    final late = t >= 0.5;
    return _Pose(
      armL: l(a.armL, b.armL),
      armR: l(a.armR, b.armR),
      waveL: l(a.waveL, b.waveL),
      waveR: l(a.waveR, b.waveR),
      headTilt: l(a.headTilt, b.headTilt),
      eyeOpen: l(a.eyeOpen, b.eyeOpen),
      brow: l(a.brow, b.brow),
      browTilt: l(a.browTilt, b.browTilt),
      browLift: l(a.browLift, b.browLift),
      mouthCurve: l(a.mouthCurve, b.mouthCurve),
      mouthOpen: l(a.mouthOpen, b.mouthOpen),
      mouthWidth: l(a.mouthWidth, b.mouthWidth),
      earDroop: l(a.earDroop, b.earDroop),
      lookX: l(a.lookX, b.lookX),
      lookY: l(a.lookY, b.lookY),
      blush: l(a.blush, b.blush),
      bounce: l(a.bounce, b.bounce),
      breath: l(a.breath, b.breath),
      eyes: late ? b.eyes : a.eyes,
      extra: late ? b.extra : a.extra,
      armRInFront: late ? b.armRInFront : a.armRInFront,
    );
  }
}

const Map<YakMood, _Pose> _poses = {
  YakMood.happy: _Pose(),
  YakMood.waving: _Pose(
    armR: 2.5,
    waveR: 0.3,
    headTilt: 0.05,
    mouthCurve: 0.95,
    mouthOpen: 0.7,
  ),
  YakMood.cheering: _Pose(
    armL: 2.55,
    armR: 2.55,
    waveL: 0.2,
    waveR: -0.2,
    mouthCurve: 1,
    mouthOpen: 1,
    blush: 0.7,
    bounce: 46,
    eyes: _EyeStyle.smile,
    extra: _Extra.sparkles,
  ),
  YakMood.proud: _Pose(
    armL: 0.5,
    armR: 0.5,
    headTilt: -0.05,
    mouthCurve: 1,
    blush: 1,
    eyes: _EyeStyle.smile,
  ),
  YakMood.encouraging: _Pose(
    armR: 2.3,
    waveR: 0.08,
    headTilt: 0.04,
    brow: 1,
    browTilt: -0.26,
    mouthCurve: 0.7,
    mouthOpen: 0.35,
  ),
  YakMood.sad: _Pose(
    armL: 0.06,
    armR: 0.06,
    headTilt: -0.07,
    eyeOpen: 0.9,
    brow: 1,
    browTilt: 0.36,
    mouthCurve: -0.7,
    mouthWidth: 0.7,
    earDroop: 1,
    lookY: 0.7,
    breath: 0.6,
    extra: _Extra.tear,
  ),
  YakMood.thinking: _Pose(
    armR: 3.36,
    headTilt: -0.07,
    brow: 1,
    browTilt: -0.08,
    browLift: 10,
    mouthCurve: 0.25,
    mouthWidth: 0.45,
    lookX: 0.8,
    lookY: -0.8,
    extra: _Extra.question,
    armRInFront: true,
  ),
  YakMood.sleeping: _Pose(
    armL: 0.1,
    armR: 0.1,
    headTilt: -0.1,
    mouthCurve: 0.5,
    mouthWidth: 0.5,
    earDroop: 0.6,
    breath: 2.2,
    eyes: _EyeStyle.closed,
    extra: _Extra.zzz,
  ),
  YakMood.surprised: _Pose(
    armL: 0.95,
    armR: 0.95,
    eyeOpen: 1.2,
    brow: 1,
    browLift: 16,
    mouthCurve: 0,
    mouthOpen: 1,
    mouthWidth: 0.32,
  ),
  YakMood.love: _Pose(
    armL: 0.55,
    armR: 0.55,
    waveL: 0.06,
    waveR: 0.06,
    mouthCurve: 1,
    mouthOpen: 0.5,
    blush: 1,
    eyes: _EyeStyle.smile,
    extra: _Extra.hearts,
  ),
};

/// The yak. [size] is its height; a full-body yak is narrower than tall,
/// a head-only yak ([showBody] false) is square.
class YakMascot extends StatefulWidget {
  const YakMascot({
    super.key,
    this.mood = YakMood.happy,
    this.size = 120,
    this.showBody = true,
    this.animate = true,
    this.semanticLabel,
  });

  final YakMood mood;
  final double size;

  /// Head-only reads better below ~56px (avatars, banners, list rows).
  final bool showBody;

  /// Set false for a frozen pose (e.g. inside a list of many yaks).
  final bool animate;

  /// The yak is decorative by default. Give a label when it is the only
  /// thing carrying meaning on screen.
  final String? semanticLabel;

  static const double bodyAspect = 900 / 1140;

  double get width => showBody ? size * bodyAspect : size;

  @override
  State<YakMascot> createState() => _YakMascotState();
}

class _YakMascotState extends State<YakMascot> with TickerProviderStateMixin {
  /// One 6s loop drives every idle motion (blink, breath, wave, jump) at
  /// whole-number multiples, so the cycle is seamless.
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  late final AnimationController _shift = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 340),
    value: 1,
  );

  late _Pose _from = _poses[widget.mood]!;
  late _Pose _to = _poses[widget.mood]!;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _syncLoop();
  }

  @override
  void didUpdateWidget(YakMascot old) {
    super.didUpdateWidget(old);
    if (old.mood != widget.mood) {
      _from = _Pose.lerp(_from, _to, Curves.easeOutCubic.transform(_shift.value));
      _to = _poses[widget.mood]!;
      if (_reduceMotion || !widget.animate) {
        _shift.value = 1;
      } else {
        _shift.forward(from: 0);
      }
    }
    if (old.animate != widget.animate) _syncLoop();
  }

  void _syncLoop() {
    final shouldRun = widget.animate && !_reduceMotion;
    if (shouldRun && !_loop.isAnimating) {
      _loop.repeat();
    } else if (!shouldRun && _loop.isAnimating) {
      _loop.stop();
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    _shift.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = !widget.animate || _reduceMotion;
    Widget child = RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([_loop, _shift]),
        builder: (context, _) {
          final k = Curves.easeOutCubic.transform(_shift.value);
          return CustomPaint(
            size: Size(widget.width, widget.size),
            painter: _YakPainter(
              pose: _Pose.lerp(_from, _to, k),
              // A fixed, flattering frame when motion is off.
              t: still ? 0.1 : _loop.value,
              pop: math.sin(math.pi * _shift.value),
              showBody: widget.showBody,
              still: still,
            ),
          );
        },
      ),
    );
    if (widget.semanticLabel != null) {
      child = Semantics(label: widget.semanticLabel, image: true, child: child);
    } else {
      child = ExcludeSemantics(child: child);
    }
    return child;
  }
}

class _YakColors {
  static const outline = Color(0xFF2B1F1A);
  static const fur = Color(0xFFAB6640);
  static const furDark = Color(0xFF96573A);
  static const cream = Color(0xFFEBBB9C);
  static const horn = Color(0xFFF0C4A8);
  static const hoof = Color(0xFF4A342B);
  static const belly = Color(0xFFC07E55);
  static const eye = Color(0xFF1E1614);
  static const mouth = Color(0xFF4A1F1C);
  static const tongue = Color(0xFFF28B82);
  static const blush = Color(0xFFF2857A);
  static const gold = Color(0xFFFFC800);
  static const tear = Color(0xFF5BC0F8);
  static const zzz = Color(0xFF7F8C9B);
  static const heart = Color(0xFFFF4B6E);
}

class _YakPainter extends CustomPainter {
  _YakPainter({
    required this.pose,
    required this.t,
    required this.pop,
    required this.showBody,
    required this.still,
  });

  final _Pose pose;
  final double t;
  final double pop;
  final bool showBody;
  final bool still;

  static const double _tau = math.pi * 2;
  static const double _stroke = 18;

  static const Rect _bodyBox = Rect.fromLTRB(62, 100, 962, 1240);
  static const Rect _headBox = Rect.fromLTRB(72, 70, 952, 950);

  final Paint _line =
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = _stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = _YakColors.outline
        ..isAntiAlias = true;

  Paint _fill(Color c) =>
      Paint()
        ..style = PaintingStyle.fill
        ..color = c
        ..isAntiAlias = true;

  void _shape(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, _fill(color));
    canvas.drawPath(path, _line);
  }

  /// 0 fully shut … 1 open. Two blinks per loop, the second a double.
  double get _blink {
    if (still) return 1;
    double dip(double start, double len) {
      if (t < start || t > start + len) return 0;
      return math.sin(math.pi * (t - start) / len);
    }

    final d = math.max(
      dip(0.30, 0.03),
      math.max(dip(0.72, 0.028), dip(0.765, 0.028)),
    );
    return 1 - d;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final box = showBody ? _bodyBox : _headBox;
    final s = size.height / box.height;
    canvas.save();
    canvas.translate((size.width - box.width * s) / 2, 0);
    canvas.scale(s);
    canvas.translate(-box.left, -box.top);

    final breath = still ? 0.0 : math.sin(_tau * t * 2) * pose.breath;
    final wave = still ? 0.6 : math.sin(_tau * t * 8);
    final fast = (t * 10) % 1.0;
    final jump = still ? 0.0 : pose.bounce * math.sin(math.pi * fast);
    final sway = still ? 0.0 : math.sin(_tau * t) * 0.012;

    if (showBody) {
      // Ground shadow — shrinks as the yak leaves the ground.
      final lift = pose.bounce == 0 ? 0.0 : jump / pose.bounce;
      canvas.drawOval(
        Rect.fromCenter(
          center: const Offset(512, 1206),
          width: 420 * (1 - 0.25 * lift),
          height: 44 * (1 - 0.25 * lift),
        ),
        _fill(Colors.black.withOpacity(0.10)),
      );
    }

    // Mood-change "pop" and jump act on the whole character.
    final anchor = showBody ? const Offset(512, 1200) : const Offset(512, 510);
    canvas.translate(anchor.dx, anchor.dy - jump);
    canvas.scale(1 + 0.05 * pop, 1 + 0.05 * pop);
    canvas.translate(-anchor.dx, -anchor.dy);

    if (showBody) {
      _paintTail(canvas, wave);
      _paintFeet(canvas);
      _paintBody(canvas, breath);
      _paintArm(canvas, left: true, angle: pose.armL + pose.waveL * wave);
      if (!pose.armRInFront) {
        _paintArm(canvas, left: false, angle: pose.armR + pose.waveR * wave);
      }
    }

    canvas.save();
    canvas.translate(512, 800 - 5 * breath);
    canvas.rotate(pose.headTilt + sway);
    canvas.translate(-512, -800);
    _paintHead(canvas);
    canvas.restore();

    if (showBody && pose.armRInFront) {
      _paintArm(canvas, left: false, angle: pose.armR + pose.waveR * wave);
    }

    _paintExtra(canvas);
    canvas.restore();
  }

  // ── Body ────────────────────────────────────────────────────────────

  void _paintTail(Canvas canvas, double wave) {
    canvas.save();
    canvas.translate(720, 1104);
    canvas.rotate(-0.1 + 0.12 * wave * (pose.bounce > 0 ? 1.6 : 1));
    final stem =
        Path()
          ..moveTo(0, 0)
          ..quadraticBezierTo(64, 6, 96, -44);
    canvas.drawPath(
      stem,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 44
        ..strokeCap = StrokeCap.round
        ..color = _YakColors.outline,
    );
    canvas.drawPath(
      stem,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 16
        ..strokeCap = StrokeCap.round
        ..color = _YakColors.fur,
    );
    final tuft =
        Path()
          ..moveTo(70, -38)
          ..lineTo(84, -98)
          ..lineTo(106, -72)
          ..lineTo(140, -100)
          ..lineTo(134, -52)
          ..lineTo(158, -24)
          ..lineTo(112, -8)
          ..close();
    _shape(canvas, tuft, _YakColors.furDark);
    canvas.restore();
  }

  void _paintFeet(Canvas canvas) {
    for (final cx in const [428.0, 596.0]) {
      final hoof = RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(cx, 1166), width: 124, height: 72),
        const Radius.circular(30),
      );
      canvas.drawRRect(hoof, _fill(_YakColors.hoof));
      canvas.drawRRect(hoof, _line);
    }
  }

  void _paintBody(Canvas canvas, double breath) {
    canvas.save();
    canvas.translate(512, 1140);
    canvas.scale(1 + 0.008 * breath, 1 + 0.014 * breath);
    canvas.translate(-512, -1140);
    const skirt = [
      Offset(326, 1146),
      Offset(360, 1108),
      Offset(398, 1152),
      Offset(438, 1114),
      Offset(476, 1154),
      Offset(512, 1118),
      Offset(548, 1154),
      Offset(586, 1114),
      Offset(626, 1152),
      Offset(664, 1108),
      Offset(698, 1146),
    ];
    final body =
        Path()
          ..moveTo(390, 730)
          ..cubicTo(296, 770, 262, 920, 294, 1090);
    for (final o in skirt) {
      body.lineTo(o.dx, o.dy);
    }
    body
      ..lineTo(730, 1090)
      ..cubicTo(762, 920, 728, 770, 634, 730)
      ..close();
    _shape(canvas, body, _YakColors.fur);
    canvas.drawOval(
      Rect.fromCenter(
        center: const Offset(512, 1010),
        width: 230,
        height: 190,
      ),
      _fill(_YakColors.belly),
    );
    canvas.restore();
  }

  void _paintArm(Canvas canvas, {required bool left, required double angle}) {
    canvas.save();
    canvas.translate(left ? 320 : 704, 858);
    canvas.rotate(left ? angle : -angle);
    final arm = RRect.fromRectAndRadius(
      const Rect.fromLTRB(-40, -30, 40, 158),
      const Radius.circular(40),
    );
    canvas.drawRRect(arm, _fill(_YakColors.fur));
    // Hoof cap on the end of the arm.
    canvas.save();
    canvas.clipRRect(arm);
    canvas.drawRect(
      const Rect.fromLTRB(-40, 104, 40, 158),
      _fill(_YakColors.hoof),
    );
    canvas.drawLine(const Offset(-40, 104), const Offset(40, 104), _line);
    canvas.restore();
    canvas.drawRRect(arm, _line);
    canvas.restore();
  }

  // ── Head ────────────────────────────────────────────────────────────

  static Path _mirrored(Path left) {
    final m = Matrix4.identity()
      ..translate(1024.0, 0.0)
      ..scale(-1.0, 1.0);
    return left.transform(m.storage);
  }

  static final Path _hornL =
      Path()
        ..moveTo(330, 300)
        ..cubicTo(262, 278, 234, 224, 268, 152)
        ..cubicTo(194, 196, 156, 270, 204, 328)
        ..cubicTo(232, 360, 272, 376, 308, 374)
        ..close();

  static final Path _hornR = _mirrored(_hornL);

  static final Path _earOuter =
      Path()
        ..moveTo(6, -40)
        ..cubicTo(-50, -72, -112, -58, -162, -2)
        ..cubicTo(-112, 40, -66, 72, -4, 44)
        ..close();

  static final Path _earInner =
      Path()
        ..moveTo(-26, -10)
        ..cubicTo(-62, -30, -100, -24, -128, -2)
        ..cubicTo(-100, 14, -62, 24, -26, 16)
        ..close();

  static final Path _head = () {
    const jag = [
      Offset(256, 598),
      Offset(300, 612),
      Offset(284, 676),
      Offset(334, 692),
      Offset(342, 748),
      Offset(394, 750),
      Offset(424, 810),
      Offset(464, 802),
      Offset(512, 864),
    ];
    final p =
        Path()
          ..moveTo(512, 196)
          ..cubicTo(430, 190, 352, 226, 326, 300)
          ..cubicTo(300, 370, 284, 440, 290, 520);
    for (final o in jag) {
      p.lineTo(o.dx, o.dy);
    }
    for (final o in jag.reversed.skip(1)) {
      p.lineTo(1024 - o.dx, o.dy);
    }
    p
      ..lineTo(734, 520)
      ..cubicTo(740, 440, 724, 370, 698, 300)
      ..cubicTo(672, 226, 594, 190, 512, 196)
      ..close();
    return p;
  }();

  static final Path _fringe =
      Path()
        ..moveTo(322, 304)
        ..cubicTo(344, 236, 396, 200, 444, 194)
        ..lineTo(452, 158)
        ..lineTo(490, 184)
        ..lineTo(526, 148)
        ..lineTo(552, 186)
        ..lineTo(600, 170)
        ..lineTo(604, 206)
        ..cubicTo(652, 222, 686, 258, 702, 304)
        ..lineTo(672, 346)
        ..lineTo(622, 318)
        ..lineTo(572, 374)
        ..lineTo(536, 328)
        ..lineTo(510, 394)
        ..lineTo(484, 330)
        ..lineTo(446, 370)
        ..lineTo(398, 316)
        ..lineTo(352, 346)
        ..close();

  void _paintHead(Canvas canvas) {
    final twitch =
        still || t < 0.5 || t > 0.56
            ? 0.0
            : math.sin(math.pi * (t - 0.5) / 0.06) * 0.14;

    // Ears sit behind everything; each pivots where it meets the head.
    for (final left in const [true, false]) {
      canvas.save();
      if (!left) {
        canvas.translate(1024, 0);
        canvas.scale(-1, 1);
      }
      canvas.translate(300, 432);
      canvas.rotate(-pose.earDroop * 0.5 - (left ? twitch : 0));
      _shape(canvas, _earOuter, _YakColors.fur);
      canvas.drawPath(_earInner, _fill(_YakColors.furDark));
      canvas.restore();
    }

    _shape(canvas, _hornL, _YakColors.horn);
    _shape(canvas, _hornR, _YakColors.horn);
    _shape(canvas, _head, _YakColors.fur);
    _shape(canvas, _fringe, _YakColors.furDark);

    // Muzzle.
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(510, 628), width: 292, height: 226),
      _fill(_YakColors.cream),
    );
    for (final dx in const [-60.0, 60.0]) {
      canvas.save();
      canvas.translate(510 + dx, 588);
      canvas.rotate(dx < 0 ? 0.25 : -0.25);
      canvas.drawOval(
        Rect.fromCenter(center: Offset.zero, width: 40, height: 46),
        _fill(_YakColors.outline),
      );
      canvas.restore();
    }

    if (pose.blush > 0.01) {
      for (final cx in const [334.0, 690.0]) {
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, 556), width: 64, height: 38),
          _fill(_YakColors.blush.withOpacity(0.6 * pose.blush.clamp(0, 1))),
        );
      }
    }

    _paintEye(canvas, const Offset(392, 464));
    _paintEye(canvas, const Offset(632, 464));
    _paintBrows(canvas);
    _paintMouth(canvas);
  }

  void _paintEye(Canvas canvas, Offset c) {
    canvas.drawCircle(c, 50, _fill(_YakColors.cream));

    if (pose.eyes == _EyeStyle.smile) {
      final arc =
          Path()
            ..moveTo(c.dx - 30, c.dy + 14)
            ..quadraticBezierTo(c.dx, c.dy - 34, c.dx + 30, c.dy + 14);
      canvas.drawPath(arc, _line);
      return;
    }
    if (pose.eyes == _EyeStyle.closed) {
      final arc =
          Path()
            ..moveTo(c.dx - 30, c.dy)
            ..quadraticBezierTo(c.dx, c.dy + 30, c.dx + 30, c.dy);
      canvas.drawPath(arc, _line);
      return;
    }

    final open = pose.eyeOpen * _blink;
    final center = c.translate(2 + pose.lookX * 9, 6 + pose.lookY * 8);
    if (open < 0.14) {
      canvas.drawLine(
        center.translate(-28, 0),
        center.translate(28, 0),
        _line,
      );
      return;
    }
    final scale = pose.eyeOpen.clamp(1.0, 1.3);
    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: 62 * scale,
        height: 78 * open.clamp(0.0, 1.3),
      ),
      _fill(_YakColors.eye),
    );
    if (open > 0.5) {
      canvas.drawCircle(center.translate(3, -13), 9, _fill(Colors.white));
    }
  }

  void _paintBrows(Canvas canvas) {
    if (pose.brow < 0.02) return;
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 16
          ..strokeCap = StrokeCap.round
          ..color = _YakColors.outline.withOpacity(pose.brow.clamp(0, 1));
    for (final left in const [true, false]) {
      canvas.save();
      canvas.translate(left ? 392 : 632, 400 - pose.browLift);
      // Positive tilt lifts the inner end (worried); mirror for the right.
      canvas.rotate(left ? -pose.browTilt : pose.browTilt);
      canvas.drawLine(const Offset(-32, 0), const Offset(32, 0), paint);
      canvas.restore();
    }
  }

  void _paintMouth(Canvas canvas) {
    const cx = 510.0;
    final curve = pose.mouthCurve;
    final open = pose.mouthOpen;
    final halfW = 100 * pose.mouthWidth;
    final endY = 656 - curve * 8;

    // Round "o" for surprise.
    if (curve.abs() < 0.2 && open > 0.5) {
      final o = Rect.fromCenter(
        center: const Offset(cx, 672),
        width: halfW * 2,
        height: 84 * open,
      );
      canvas.drawOval(o, _fill(_YakColors.mouth));
      canvas.drawOval(o, _line);
      return;
    }

    if (open < 0.06) {
      final smile =
          Path()
            ..moveTo(cx - halfW, endY)
            ..quadraticBezierTo(cx, endY + curve * 86, cx + halfW, endY);
      canvas.drawPath(smile, _line);
      return;
    }

    final bottom = endY + curve * 86 + open * 62;
    final mouth =
        Path()
          ..moveTo(cx - halfW, endY)
          ..quadraticBezierTo(cx, endY + curve * 18, cx + halfW, endY)
          ..quadraticBezierTo(cx, bottom, cx - halfW, endY)
          ..close();
    canvas.drawPath(mouth, _fill(_YakColors.mouth));
    canvas.save();
    canvas.clipPath(mouth);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, (endY + bottom) / 2 + 26),
        width: halfW * 1.1,
        height: 56,
      ),
      _fill(_YakColors.tongue),
    );
    canvas.restore();
    canvas.drawPath(mouth, _line);
  }

  // ── Extras ──────────────────────────────────────────────────────────

  void _paintExtra(Canvas canvas) {
    final phase = still ? 0.35 : (t * 3) % 1.0;
    switch (pose.extra) {
      case _Extra.none:
        return;
      case _Extra.sparkles:
        const spots = [
          (Offset(118, 250), 34.0, 0.0),
          (Offset(912, 420), 40.0, 0.33),
          (Offset(126, 690), 26.0, 0.66),
        ];
        for (final (at, r, offset) in spots) {
          final p = (phase + offset) % 1.0;
          final k = math.sin(math.pi * p);
          _star(canvas, at, r * (0.4 + 0.6 * k), _YakColors.gold);
        }
      case _Extra.tear:
        final y = 536 + 96 * phase;
        final fade = (1 - phase).clamp(0.0, 1.0);
        final drop =
            Path()
              ..moveTo(372, y - 30)
              ..quadraticBezierTo(346, y + 6, 372, y + 14)
              ..quadraticBezierTo(398, y + 6, 372, y - 30)
              ..close();
        canvas.drawPath(drop, _fill(_YakColors.tear.withOpacity(fade)));
      case _Extra.zzz:
        const spots = [
          (Offset(822, 322), 28.0, 0.0),
          (Offset(874, 240), 38.0, 0.33),
          (Offset(920, 152), 48.0, 0.66),
        ];
        for (final (at, size, offset) in spots) {
          final p = (phase + offset) % 1.0;
          final alpha = math.sin(math.pi * p);
          _zed(canvas, at.translate(8 * p, -18 * p), size, alpha);
        }
      case _Extra.question:
        final bob = still ? 0.0 : math.sin(_tau * phase) * 8;
        _question(canvas, Offset(900, 236 + bob));
      case _Extra.hearts:
        const spots = [
          (Offset(138, 596), 28.0, 0.0),
          (Offset(892, 604), 34.0, 0.4),
          (Offset(872, 156), 24.0, 0.75),
        ];
        for (final (at, r, offset) in spots) {
          final p = (phase + offset) % 1.0;
          final alpha = math.sin(math.pi * p);
          _heart(canvas, at.translate(0, -30 * p), r, alpha);
        }
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final p = Path();
    for (var i = 0; i < 8; i++) {
      final a = -math.pi / 2 + i * math.pi / 4;
      final rad = i.isEven ? r : r * 0.36;
      final pt = c + Offset(math.cos(a), math.sin(a)) * rad;
      if (i == 0) {
        p.moveTo(pt.dx, pt.dy);
      } else {
        p.lineTo(pt.dx, pt.dy);
      }
    }
    p.close();
    canvas.drawPath(p, _fill(color));
  }

  void _zed(Canvas canvas, Offset c, double size, double alpha) {
    final h = size / 2;
    final z =
        Path()
          ..moveTo(c.dx - h, c.dy - h)
          ..lineTo(c.dx + h, c.dy - h)
          ..lineTo(c.dx - h, c.dy + h)
          ..lineTo(c.dx + h, c.dy + h);
    canvas.drawPath(
      z,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = size * 0.26
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = _YakColors.zzz.withOpacity(alpha.clamp(0.0, 1.0)),
    );
  }

  void _question(Canvas canvas, Offset c) {
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 22
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = _YakColors.gold;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(0.2);
    final hook =
        Path()
          ..moveTo(-30, -44)
          ..cubicTo(-30, -92, 38, -92, 38, -46)
          ..cubicTo(38, -14, 2, -14, 2, 18);
    canvas.drawPath(hook, paint);
    canvas.drawCircle(const Offset(2, 58), 13, _fill(_YakColors.gold));
    canvas.restore();
  }

  void _heart(Canvas canvas, Offset c, double r, double alpha) {
    final p =
        Path()
          ..moveTo(c.dx, c.dy + r)
          ..cubicTo(
            c.dx - r * 1.6,
            c.dy - r * 0.1,
            c.dx - r * 0.8,
            c.dy - r * 1.2,
            c.dx,
            c.dy - r * 0.4,
          )
          ..cubicTo(
            c.dx + r * 0.8,
            c.dy - r * 1.2,
            c.dx + r * 1.6,
            c.dy - r * 0.1,
            c.dx,
            c.dy + r,
          )
          ..close();
    canvas.drawPath(
      p,
      _fill(_YakColors.heart.withOpacity(alpha.clamp(0.0, 1.0))),
    );
  }

  @override
  bool shouldRepaint(_YakPainter old) =>
      old.t != t ||
      old.pop != pop ||
      old.pose != pose ||
      old.showBody != showBody ||
      old.still != still;
}
