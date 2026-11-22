import 'package:bojang/theme/tibetan_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TibetanType.style', () {
    test('uses the bundled face and a tall line', () {
      final s = TibetanType.style();
      expect(s.fontFamily, 'Jomolhari');
      expect(s.height, inInclusiveRange(1.6, 1.8));
    });

    test('never smaller than the floor, line height kept in range', () {
      expect(TibetanType.style(size: 10).fontSize, TibetanType.minSize);
      expect(TibetanType.style(height: 1.2).height, 1.6);
      expect(TibetanType.style(height: 2.4).height, 1.8);
    });
  });

  group('TibetanType.fittedSize', () {
    const phrase = 'བཀྲ་ཤིས་བདེ་ལེགས། ཁྱེད་རང་སྐུ་གཟུགས་བདེ་པོ་ཡིན་པས།';

    test('keeps the requested size when the text fits', () {
      expect(TibetanType.fittedSize(text: 'ཀ', size: 52, maxWidth: 1000), 52);
      expect(
        TibetanType.fittedSize(text: 'ཀ', size: 52, maxWidth: double.infinity),
        52,
      );
    });

    test('shrinks to fit but stops at the floor', () {
      final fitted = TibetanType.fittedSize(
        text: phrase,
        size: 52,
        maxWidth: 400,
      );
      expect(fitted, lessThan(52));
      expect(fitted, greaterThanOrEqualTo(TibetanType.minSize));

      expect(
        TibetanType.fittedSize(text: phrase, size: 52, maxWidth: 40),
        TibetanType.minSize,
      );
    });
  });

  testWidgets('TibetanText wraps at the floor instead of shrinking further', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 60,
            child: TibetanText(
              'བཀྲ་ཤིས་བདེ་ལེགས། ཁྱེད་རང་སྐུ་གཟུགས་བདེ་པོ་ཡིན་པས།',
              size: 40,
            ),
          ),
        ),
      ),
    );
    final text = tester.widget<Text>(find.byType(Text));
    expect(text.style!.fontSize, TibetanType.minSize);
    expect(text.softWrap, isTrue);
  });
}
