import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../services/event_tracker.dart';

/// Records every tap, long press, swipe and scroll in the app for
/// [EventTracker]. Sits in `MaterialApp.builder`, above the Navigator, so it
/// sees all routes, dialogs and sheets. It only listens: gestures still reach
/// the widgets underneath.
///
/// A tap reports what was tapped: the button, tile or control's type, its
/// visible label (text, tooltip or semantics label), a key, and toggle state.
/// Taps on nothing interactive are marked `dead`, and three quick taps in one
/// spot add a `rage_tap`. Typed text is never read; labels inside a
/// [PostHogMaskWidget] (the sign-in form) are left out.
class InteractionCapture extends StatefulWidget {
  const InteractionCapture({super.key, required this.child, this.tracker});

  final Widget child;

  /// Defaults to [EventTracker.instance]; tests pass their own.
  final EventTracker? tracker;

  @override
  State<InteractionCapture> createState() => _InteractionCaptureState();
}

class _Down {
  _Down(this.position, this.time, this.hits);
  final Offset position;
  final Duration time;
  final List<RenderObject> hits;
  bool multiTouch = false;
}

/// Keeps the render objects of the most recent hit test under it.
///
/// The framework hit-tests a pointer before delivering its down event, and a
/// scrollable that receives the event first can start ignoring pointers, so
/// a later hit test would miss the row that was touched. Recording the
/// framework's own result keeps what was really under the finger.
class _HitSnapshot extends SingleChildRenderObjectWidget {
  const _HitSnapshot({required this.store, super.child});

  final _HitStore store;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHitSnapshot(store);

  @override
  void updateRenderObject(BuildContext context, _RenderHitSnapshot renderObject) {
    renderObject.store = store;
  }
}

class _HitStore {
  List<RenderObject> last = const [];
}

class _RenderHitSnapshot extends RenderProxyBox {
  _RenderHitSnapshot(this.store);

  _HitStore store;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final before = result.path.length;
    final hit = super.hitTest(result, position: position);
    store.last = [
      for (final entry in result.path.skip(before))
        if (entry.target is RenderObject) entry.target as RenderObject,
    ];
    return hit;
  }
}

class _InteractionCaptureState extends State<InteractionCapture> {
  static const _tapSlop = 18.0;
  static const _longPress = Duration(milliseconds: 500);
  static const _rageWindow = Duration(milliseconds: 1000);
  static const _rageRadius = 40.0;
  static const _rageCount = 3;

  final Map<int, _Down> _downs = {};
  final _HitStore _hitStore = _HitStore();
  final List<(Offset, Duration)> _recentTaps = [];
  bool _rageReported = false;

  EventTracker get _tracker => widget.tracker ?? EventTracker.instance;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollEndNotification>(
      onNotification: _onScrollEnd,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDown,
        onPointerUp: _onUp,
        onPointerCancel: (e) => _downs.remove(e.pointer),
        child: _HitSnapshot(store: _hitStore, child: widget.child),
      ),
    );
  }

  Size get _screenSize {
    final view = View.of(context);
    return view.physicalSize / view.devicePixelRatio;
  }

  void _onDown(PointerDownEvent e) {
    if (!_tracker.enabled || !_tracker.captureTaps) return;
    final down = _Down(e.position, e.timeStamp, _hitStore.last);
    if (_downs.isNotEmpty) {
      down.multiTouch = true;
      for (final d in _downs.values) {
        d.multiTouch = true;
      }
    }
    _downs[e.pointer] = down;
  }

  void _onUp(PointerUpEvent e) {
    final down = _downs.remove(e.pointer);
    if (down == null || !_tracker.enabled) return;
    if (down.multiTouch) {
      if (_downs.isEmpty) _tracker.record('multi_touch');
      return;
    }
    try {
      final size = _screenSize;
      final delta = e.position - down.position;
      final ms = (e.timeStamp - down.time).inMilliseconds;
      final x = _ratio(down.position.dx, size.width);
      final y = _ratio(down.position.dy, size.height);

      if (delta.distance < _tapSlop) {
        final target = describeTarget(context, down.position, hits: down.hits);
        _tracker.record(
          ms >= _longPress.inMilliseconds ? 'long_press' : 'tap',
          properties: {...target, 'x': x, 'y': y, 'duration_ms': ms},
        );
        _checkRage(down.position, e.timeStamp, target['target']);
      } else {
        final horizontal = delta.dx.abs() > delta.dy.abs();
        _tracker.record('swipe', properties: {
          'direction': horizontal
              ? (delta.dx > 0 ? 'right' : 'left')
              : (delta.dy > 0 ? 'down' : 'up'),
          'distance': delta.distance.round(),
          'duration_ms': ms,
          'x': x,
          'y': y,
          'end_x': _ratio(e.position.dx, size.width),
          'end_y': _ratio(e.position.dy, size.height),
        });
      }
    } catch (err) {
      debugPrint('InteractionCapture failed: $err');
    }
  }

  void _checkRage(Offset at, Duration time, Object? target) {
    _recentTaps.removeWhere((t) => time - t.$2 > _rageWindow);
    final near = _recentTaps.where((t) => (t.$1 - at).distance <= _rageRadius);
    if (near.isEmpty) _rageReported = false;
    _recentTaps.add((at, time));
    if (!_rageReported && near.length + 1 >= _rageCount) {
      _rageReported = true;
      _tracker.record('rage_tap', properties: {
        'taps': near.length + 1,
        'target': target,
      });
    }
  }

  bool _onScrollEnd(ScrollEndNotification n) {
    if (!_tracker.enabled || !_tracker.captureTaps) return false;
    final m = n.metrics;
    if (!m.hasContentDimensions || m.maxScrollExtent <= m.minScrollExtent) {
      return false;
    }
    final range = m.maxScrollExtent - m.minScrollExtent;
    _tracker.record('scroll', properties: {
      'axis': m.axis.name,
      'offset': m.pixels.round(),
      'max_offset': m.maxScrollExtent.round(),
      'depth': _ratio(m.pixels - m.minScrollExtent, range),
      'viewport': m.viewportDimension.round(),
      'nested': n.depth > 0,
      if (m is PageMetrics && m.page != null) 'page': m.page!.round(),
    });
    return false;
  }

  static double _ratio(double value, double total) =>
      total <= 0 ? 0 : ((value / total).clamp(0.0, 1.0) * 1000).round() / 1000;
}

// -----------------------------------------------------------------------------
// What was tapped
// -----------------------------------------------------------------------------

/// Describes the widget under [globalPosition]: `widget` (type of the
/// tapped control), `target` (its label), and when present `kind`, `key`,
/// `value`, `dead` and `masked`. [hits] is the hit path recorded when the
/// pointer went down, deepest first; without it a fresh hit test is run.
Map<String, Object?> describeTarget(
  BuildContext root,
  Offset globalPosition, {
  List<RenderObject>? hits,
}) {
  var path = hits;
  if (path == null || path.isEmpty) {
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(
      result,
      globalPosition,
      View.of(root).viewId,
    );
    path = [
      for (final entry in result.path)
        if (entry.target is RenderObject) entry.target as RenderObject,
    ];
  }
  if (path.isEmpty) return const {'dead': true};
  final deepest = path.first;
  final hitSet = HashSet<RenderObject>.identity()..addAll(path);

  // Fast walk first; some boxes (overscroll glow, custom paint) are not on
  // the hit path although their children are, so check the walk reached the
  // tapped leaf and walk the whole tree when it did not.
  var chain = _hitChain(root, hitSet, prune: true);
  if (chain.isEmpty ||
      !identical((chain.last as RenderObjectElement).renderObject, deepest)) {
    chain = _hitChain(root, hitSet, prune: false);
  }
  if (chain.isEmpty) return const {'dead': true};

  final masked = chain.any((e) => e.widget is PostHogMaskWidget);

  // The nearest control under the finger, reported as the richest widget
  // around it: an InkWell inside an ElevatedButton reports the button, a
  // GestureDetector reports itself rather than its RawGestureDetector.
  var index = -1;
  for (var i = chain.length - 1; i >= 0; i--) {
    if (_isControl(chain[i].widget)) {
      index = i;
      break;
    }
  }
  if (index >= 0) {
    int nearest(bool Function(Widget) test, int window) {
      for (var j = index; j >= math.max(0, index - window); j--) {
        if (test(chain[j].widget)) return j;
      }
      return -1;
    }

    var wrapper = nearest(_isWrapper, 40);
    // Private implementation classes (IconButton builds _IconButtonM3)
    // report as the public widget just above them.
    if (wrapper > 0 && chain[wrapper].widget.runtimeType.toString().startsWith('_')) {
      for (var j = wrapper - 1; j >= math.max(0, wrapper - 8); j--) {
        if (_isWrapper(chain[j].widget)) {
          wrapper = j;
          break;
        }
      }
    }
    final ink = nearest((w) => w is InkResponse, 15);
    final detector = nearest((w) => w is GestureDetector, 5);
    index = wrapper >= 0
        ? wrapper
        : ink >= 0
            ? ink
            : detector >= 0
                ? detector
                : index;
  }

  final dead = index < 0;
  final element = dead ? chain.last : chain[index];
  final widget = element.widget;
  final out = <String, Object?>{
    'widget': widget.runtimeType.toString(),
    if (dead) 'dead': true,
    if (masked) 'masked': true,
  };

  final kind = _kind(widget);
  if (kind != null) out['kind'] = kind;

  final value = _toggleValue(widget);
  if (value != null) out['value'] = value;

  final key = _keyNear(chain, dead ? chain.length - 1 : index);
  if (key != null) out['key'] = key;

  if (!masked) {
    var label = widget is TextField
        ? (widget.decoration?.labelText ?? widget.decoration?.hintText)
        : _label(element, dead: dead);
    // A bare switch or checkbox takes the title of the row it sits in.
    if (label == null && !dead) {
      final at = index;
      for (var j = at - 1; j >= math.max(0, at - 80); j--) {
        if (chain[j].widget is ListTile) {
          label = _label(chain[j], dead: false);
          break;
        }
      }
    }
    if (label != null && label.isNotEmpty) {
      out['target'] = label.length > 80 ? label.substring(0, 80) : label;
    }
  }
  return out;
}

/// Root-to-leaf elements whose render objects took the hit.
List<Element> _hitChain(
  BuildContext root,
  Set<RenderObject> hits, {
  required bool prune,
}) {
  var best = <Element>[];
  final chain = <Element>[];
  void visit(Element element) {
    if (element is RenderObjectElement) {
      final render = element.renderObject;
      final hit = hits.contains(render);
      // A box that was not hit has no hit descendants (almost always).
      if (prune && !hit && render is RenderBox) return;
      chain.add(element);
      if (hit && chain.length > best.length) best = List.of(chain);
    } else {
      chain.add(element);
    }
    element.visitChildElements(visit);
    chain.removeLast();
  }

  root.visitChildElements(visit);
  return best;
}

bool _isWrapper(Widget w) =>
    w is ButtonStyleButton ||
    w is IconButton ||
    w is FloatingActionButton ||
    w is ListTile ||
    w is SwitchListTile ||
    w is CheckboxListTile ||
    w is RadioListTile ||
    w is Checkbox ||
    w is Switch ||
    w is Radio ||
    w is Slider ||
    w is RawChip ||
    w is ChoiceChip ||
    w is FilterChip ||
    w is ActionChip ||
    w is InputChip ||
    w is PopupMenuButton ||
    w is PopupMenuItem ||
    w is DropdownButton ||
    w is DropdownMenuItem ||
    w is TextField ||
    w is NavigationDestination ||
    w is Tab ||
    w is CupertinoButton ||
    w is CupertinoSwitch ||
    w is BackButton ||
    w is CloseButton;

bool _isControl(Widget w) =>
    _isWrapper(w) ||
    w is InkResponse ||
    w is GestureDetector ||
    w is RawGestureDetector ||
    w is EditableText;

String? _kind(Widget w) {
  if (w is TextField || w is EditableText) return 'text_field';
  if (w is Switch || w is SwitchListTile || w is CupertinoSwitch) return 'switch';
  if (w is Checkbox || w is CheckboxListTile) return 'checkbox';
  if (w is Radio || w is RadioListTile) return 'radio';
  if (w is Slider) return 'slider';
  if (w is NavigationDestination || w is Tab) return 'navigation';
  if (w is ListTile) return 'list_item';
  if (w is BackButton || w is CloseButton) return 'back';
  if (w is ButtonStyleButton ||
      w is IconButton ||
      w is FloatingActionButton ||
      w is CupertinoButton) {
    return 'button';
  }
  return null;
}

Object? _toggleValue(Widget w) {
  if (w is Switch) return w.value;
  if (w is SwitchListTile) return w.value;
  if (w is CupertinoSwitch) return w.value;
  if (w is Checkbox) return w.value;
  if (w is CheckboxListTile) return w.value;
  if (w is Slider) return w.value;
  return null;
}

String? _keyNear(List<Element> chain, int index) {
  for (var i = index; i >= 0 && i >= index - 3; i--) {
    final key = chain[i].widget.key;
    if (key is ValueKey) return key.value.toString();
  }
  return null;
}

/// Visible label of a control: tooltip, semantics label or its texts.
/// A dead tap gets the text right under the finger only.
String? _label(Element element, {required bool dead}) {
  final w = element.widget;
  if (w is IconButton && w.tooltip != null) return w.tooltip;
  if (w is FloatingActionButton && w.tooltip != null) return w.tooltip;
  if (w is Tooltip && w.message != null) return w.message;

  final texts = <String>[];
  String? icon;
  void collect(Element e) {
    if (texts.length >= 3) return;
    final widget = e.widget;
    if (widget is EditableText) return; // never read what the user typed
    if (widget is Text) {
      final s = _readable(widget.data ?? widget.textSpan?.toPlainText());
      if (s.isNotEmpty) texts.add(s);
      return;
    }
    if (widget is RichText) {
      final s = _readable(widget.text.toPlainText());
      if (s.isNotEmpty) texts.add(s);
      return;
    }
    if (widget is Tooltip && widget.message != null) {
      texts.add(widget.message!);
      return;
    }
    if (widget is Semantics && widget.properties.label != null) {
      final s = widget.properties.label!.trim();
      if (s.isNotEmpty) {
        texts.add(s);
        return;
      }
    }
    if (widget is Icon) {
      // An icon draws its glyph as text; report its name, not the glyph.
      final data = widget.icon;
      if (icon == null && data != null) {
        final name = data.fontFamily == 'MaterialIcons' ? _iconNames[data.codePoint] : null;
        icon = 'icon:${name ?? data.codePoint.toRadixString(16)}';
      }
      return;
    }
    e.visitChildElements(collect);
  }

  if (dead) {
    // Only what is drawn at the tapped spot, not the whole page.
    if (w is Text || w is RichText) collect(element);
  } else {
    collect(element);
  }
  if (texts.isNotEmpty) return texts.join(' · ');
  return icon;
}

/// Readable names for icons that carry a control on their own.
final Map<int, String> _iconNames = {
  Icons.arrow_back.codePoint: 'back',
  Icons.arrow_back_ios.codePoint: 'back',
  Icons.arrow_back_ios_new.codePoint: 'back',
  Icons.arrow_forward.codePoint: 'forward',
  Icons.arrow_forward_ios.codePoint: 'forward',
  Icons.close.codePoint: 'close',
  Icons.settings.codePoint: 'settings',
  Icons.share.codePoint: 'share',
  Icons.ios_share.codePoint: 'share',
  Icons.play_arrow.codePoint: 'play',
  Icons.play_arrow_rounded.codePoint: 'play',
  Icons.volume_up.codePoint: 'speaker',
  Icons.volume_up_rounded.codePoint: 'speaker',
  Icons.auto_awesome.codePoint: 'lesson_style',
  Icons.refresh.codePoint: 'refresh',
  Icons.more_vert.codePoint: 'more',
  Icons.more_horiz.codePoint: 'more',
  Icons.info.codePoint: 'info',
  Icons.info_outline.codePoint: 'info',
  Icons.help_outline.codePoint: 'help',
  Icons.edit.codePoint: 'edit',
  Icons.delete.codePoint: 'delete',
  Icons.check.codePoint: 'check',
  Icons.add.codePoint: 'add',
  Icons.search.codePoint: 'search',
  Icons.home.codePoint: 'home',
  Icons.person.codePoint: 'profile',
  Icons.local_fire_department.codePoint: 'streak',
  Icons.sports_esports.codePoint: 'games',
  Icons.star.codePoint: 'star',
  Icons.lightbulb.codePoint: 'hint',
  Icons.lightbulb_outline.codePoint: 'hint',
};

/// Text without icon-font glyphs (Unicode private use area), trimmed.
String _readable(String? text) {
  if (text == null) return '';
  return String.fromCharCodes(
    text.runes.where((r) => r < 0xE000 || (r > 0xF8FF && r < 0xF0000)),
  ).trim();
}
