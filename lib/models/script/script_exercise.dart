/// The type-specific part of the script course exercises (`near_sound`,
/// `build_stack`, `find_root`, `read_syllable`, `trace`), carried on a
/// [QuizQuestion] as [QuizQuestion.script]. Contracts: the backend's
/// `models/script_exercise.py`.
library;

import '../../services/pronunciation_voices.dart';
import 'script_chart.dart' show voiceUrls;
import 'stack_builder.dart';

class ScriptClip {
  const ScriptClip({required this.char, this.audioUrl, this.audioUrls = const {}});

  final String char;
  final String? audioUrl;
  final Map<String, String> audioUrls;

  String? audioFor(String voice) =>
      PronunciationVoices.pick(audioUrls, voice, fallbackUrl: audioUrl);

  factory ScriptClip.fromJson(Map<String, dynamic> json) => ScriptClip(
    char: json['char']?.toString() ?? '',
    audioUrl: _s(json['audio_url']),
    audioUrls: voiceUrls(json['audio_urls']),
  );
}

/// A consonant of a syllable in `find_root`, with its spelling position.
class RootTile {
  const RootTile({required this.id, required this.char, required this.role});

  final String id;
  final String char;

  /// prefix, superscript, root, subscript, suffix or post_suffix.
  final String role;

  String get roleLabel => switch (role) {
    'prefix' => 'prefix',
    'superscript' => 'on top',
    'root' => 'root',
    'subscript' => 'underneath',
    'suffix' => 'suffix',
    'post_suffix' => '2nd suffix',
    _ => role,
  };

  factory RootTile.fromJson(Map<String, dynamic> json) => RootTile(
    id: json['id']?.toString() ?? '',
    char: json['char']?.toString() ?? '',
    role: json['role']?.toString() ?? '',
  );
}

class StackTile {
  const StackTile({required this.id, required this.char, required this.label});

  final String id;

  /// "" for "none".
  final String char;
  final String label;

  factory StackTile.fromJson(Map<String, dynamic> json) => StackTile(
    id: json['id']?.toString() ?? '',
    char: json['char']?.toString() ?? '',
    label: json['label']?.toString() ?? '',
  );
}

class StackSlotChoices {
  const StackSlotChoices({required this.slot, required this.label, required this.tiles});

  final StackSlot slot;
  final String label;
  final List<StackTile> tiles;

  static StackSlotChoices? fromJson(Map<String, dynamic> json) {
    final slot = stackSlotFromId(json['slot']?.toString() ?? '');
    if (slot == null) return null;
    return StackSlotChoices(
      slot: slot,
      label: json['label']?.toString() ?? slot.name,
      tiles: [
        for (final t in json['tiles'] as List? ?? const [])
          if (t is Map<String, dynamic>) StackTile.fromJson(t),
      ],
    );
  }
}

class ScriptPayload {
  const ScriptPayload({
    required this.char,
    this.mode = '',
    this.clips = const [],
    this.group = const [],
    this.syllable = '',
    this.reading = '',
    this.english = '',
    this.rootTiles = const [],
    this.slots = const [],
    this.tail = '',
    this.target = '',
    this.correctTileIds = const [],
  });

  /// The chart item practised.
  final String char;

  /// near_sound: same_different | pick_heard; build_stack: shown | heard;
  /// trace: guided | freehand.
  final String mode;
  final List<ScriptClip> clips;
  final List<String> group;
  final String syllable;
  final String reading;
  final String english;
  final List<RootTile> rootTiles;
  final List<StackSlotChoices> slots;
  final String tail;
  final String target;
  final List<String> correctTileIds;

  bool get freehand => mode == 'freehand';
  bool get heard => mode == 'heard';

  /// What the exercise is about, for "fix it again" and the feedback line.
  String get focusText =>
      target.isNotEmpty ? target : (syllable.isNotEmpty ? syllable : char);

  /// The tile the learner should pick per slot, from [correctTileIds].
  Map<StackSlot, String> get correctChoices {
    final out = <StackSlot, String>{};
    for (final id in correctTileIds) {
      final i = id.indexOf(':');
      if (i < 0) continue;
      final slot = stackSlotFromId(id.substring(0, i));
      if (slot != null) out[slot] = id.substring(i + 1);
    }
    return out;
  }

  factory ScriptPayload.fromJson(Map<String, dynamic> json) => ScriptPayload(
    char: json['char']?.toString() ?? '',
    mode: json['mode']?.toString() ?? '',
    clips: [
      for (final c in json['clips'] as List? ?? const [])
        if (c is Map<String, dynamic>) ScriptClip.fromJson(c),
    ],
    group: [for (final g in json['group'] as List? ?? const []) g.toString()],
    syllable: json['syllable']?.toString() ?? json['target']?.toString() ?? '',
    reading: json['reading']?.toString() ?? '',
    english: json['english']?.toString() ?? '',
    rootTiles: [
      for (final t in json['tiles'] as List? ?? const [])
        if (t is Map<String, dynamic> && t.containsKey('role')) RootTile.fromJson(t),
    ],
    slots: [
      for (final s in json['slots'] as List? ?? const [])
        if (s is Map<String, dynamic>)
          if (StackSlotChoices.fromJson(s) case final slot?) slot,
    ],
    tail: json['tail']?.toString() ?? '',
    target: json['target']?.toString() ?? '',
    correctTileIds: [
      for (final id in json['correct_tile_ids'] as List? ?? const []) id.toString(),
    ],
  );
}

String? _s(Object? value) {
  final text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}
