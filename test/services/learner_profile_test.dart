import 'package:bojang/services/learner_profile.dart';
import 'package:bojang/widgets/learner_avatar.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LearnerProfile.instance.debugReset();
  });

  test('avatar keys round-trip and reject unknown values', () {
    const choice = AvatarChoice(AvatarFigure.conch, AvatarColour.gold);
    expect(AvatarChoice.parse(choice.key), choice);
    expect(AvatarChoice.parse('yak_love')!.colour, AvatarColour.blue);
    expect(AvatarChoice.parse('https://x/p.png'), isNull);
    expect(AvatarChoice.parse(null), isNull);
  });

  test('a guest with nothing set is asked, then not again for two days', () async {
    final p = LearnerProfile.instance;
    p.fetch = () async => {'display_name': null};
    final now = DateTime(2026, 11, 27, 10);
    expect(await p.shouldAsk(now: now), isTrue);
    await p.markAsked(now: now);
    expect(await p.shouldAsk(now: now.add(const Duration(hours: 5))), isFalse);
    expect(await p.shouldAsk(now: now.add(const Duration(days: 2))), isTrue);
  });

  test('save trims the name, uploads, and stops the asking', () async {
    final p = LearnerProfile.instance;
    p.fetch = () async => null;
    String? sentName;
    String? sentAvatar;
    p.push = (n, a) async {
      sentName = n;
      sentAvatar = a;
      return {'uid': 'x'};
    };
    await p.save(name: '  Pema   Lhamo ', avatar: 'yak_proud:green');
    expect(p.name, 'Pema Lhamo');
    expect(sentName, 'Pema Lhamo');
    expect(sentAvatar, 'yak_proud:green');
    expect(await p.shouldAsk(), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(LearnerProfile.pendingKey), isFalse);
  });

  test('takes the server name when the device has none', () async {
    final p = LearnerProfile.instance;
    p.fetch = () async => {'display_name': 'Tenzin', 'avatar': 'conch:red'};
    await p.load();
    await Future<void>.delayed(Duration.zero);
    await p.refresh();
    expect(p.name, 'Tenzin');
    expect(p.avatar, 'conch:red');
  });
}
