/// Building a Tibetan syllable from its parts, for the `build_stack`
/// exercise. Mirrors `compose()` in the backend's `curriculum/script.py`.
///
/// Unicode spelling order: prefix, then the stack (superscript as a full
/// letter with the root in its subjoined form below it, or the root as a
/// full letter), the subscript's subjoined form, the vowel sign, then the
/// suffixes. ཡ ར ལ ཝ have short subjoined forms (ྱ ྲ ླ ྭ).
library;

/// The parts of a syllable a learner picks.
enum StackSlot { prefix, superscript, root, subscript, vowel }

StackSlot? stackSlotFromId(String id) {
  for (final s in StackSlot.values) {
    if (s.name == id) return s;
  }
  return null;
}

class StackBuilder {
  StackBuilder._();

  static const Map<String, String> _subscriptForms = {
    'ཡ': 'ྱ',
    'ར': 'ྲ',
    'ལ': 'ླ',
    'ཝ': 'ྭ',
  };

  /// The stacked-below form of a base consonant (ཀ -> ྐ).
  static String subjoined(String letter) {
    final short = _subscriptForms[letter];
    if (short != null) return short;
    final code = letter.runes.single;
    if (code < 0x0F40 || code > 0x0F68) {
      throw ArgumentError('no subjoined form for $letter');
    }
    return String.fromCharCode(code + 0x50);
  }

  /// The syllable built from [root] and the optional parts. Empty strings
  /// mean "none".
  static String compose({
    required String root,
    String prefix = '',
    String superscript = '',
    String subscript = '',
    String vowel = '',
    String tail = '',
  }) {
    if (root.isEmpty) return '';
    final stack =
        superscript.isEmpty ? root : superscript + subjoined(root);
    return prefix +
        stack +
        (subscript.isEmpty ? '' : subjoined(subscript)) +
        vowel +
        tail;
  }

  /// [compose] from a slot -> letter choice.
  static String fromChoices(Map<StackSlot, String> choices, {String tail = ''}) =>
      compose(
        root: choices[StackSlot.root] ?? '',
        prefix: choices[StackSlot.prefix] ?? '',
        superscript: choices[StackSlot.superscript] ?? '',
        subscript: choices[StackSlot.subscript] ?? '',
        vowel: choices[StackSlot.vowel] ?? '',
        tail: tail,
      );

  /// A Tibetan answer without tsheg, shad or spaces, for comparing.
  static String normalize(String text) =>
      text.replaceAll(RegExp('[་། \\s]'), '');

  /// Whether the built syllable is the target (tsheg and shad ignored).
  static bool matches(String built, String target) {
    final a = normalize(built);
    return a.isNotEmpty && a == normalize(target);
  }
}
