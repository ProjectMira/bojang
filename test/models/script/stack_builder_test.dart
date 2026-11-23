import 'package:bojang/models/script/stack_builder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('subjoined forms', () {
    expect(StackBuilder.subjoined('ཀ'), 'ྐ');
    expect(StackBuilder.subjoined('ག'), 'ྒ');
    expect(StackBuilder.subjoined('ཡ'), 'ྱ');
    expect(StackBuilder.subjoined('ར'), 'ྲ');
    expect(StackBuilder.subjoined('ལ'), 'ླ');
    expect(StackBuilder.subjoined('ཝ'), 'ྭ');
    expect(() => StackBuilder.subjoined('a'), throwsArgumentError);
  });

  test('compose every part', () {
    expect(
      StackBuilder.compose(prefix: 'བ', superscript: 'ས', root: 'ག', subscript: 'ར', vowel: 'ུ', tail: 'བས'),
      'བསྒྲུབས',
    );
    expect(StackBuilder.compose(root: 'ཁ', subscript: 'ཡ', vowel: 'ི'), 'ཁྱི');
    expect(StackBuilder.compose(superscript: 'ར', root: 'ཏ'), 'རྟ');
    expect(StackBuilder.compose(superscript: 'ལ', root: 'ཧ'), 'ལྷ');
    expect(StackBuilder.compose(prefix: 'ག', root: 'ཡ', tail: 'ག'), 'གཡག');
    expect(StackBuilder.compose(root: ''), '');
  });

  test('from slot choices', () {
    final built = StackBuilder.fromChoices({
      StackSlot.prefix: 'བ',
      StackSlot.superscript: 'ར',
      StackSlot.root: 'ག',
      StackSlot.subscript: 'ཡ',
      StackSlot.vowel: '',
    }, tail: 'ད');
    expect(built, 'བརྒྱད');
  });

  test('matching ignores tsheg and shad, not letters', () {
    expect(StackBuilder.matches('སྟག', 'སྟག་'), isTrue);
    expect(StackBuilder.matches('སྟག།', 'སྟག'), isTrue);
    expect(StackBuilder.matches('སྡག', 'སྟག'), isFalse);
    expect(StackBuilder.matches('', ''), isFalse);
  });

  test('slot ids', () {
    expect(stackSlotFromId('superscript'), StackSlot.superscript);
    expect(stackSlotFromId('nope'), isNull);
  });
}
