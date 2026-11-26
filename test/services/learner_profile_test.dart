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

  group('profile photo', () {
    test('upload shows the photo; server errors map to reasons', () async {
      final p = LearnerProfile.instance;
      p.fetch = () async => null;
      var status = 200;
      p.uploader =
          (bytes, name) async => (
            status,
            status == 200
                ? {'photo_url': 'https://s.example/profile-photos/a.jpg'}
                : null,
          );
      expect(await p.uploadPhoto([1, 2, 3], 'a.jpg'), PhotoUploadResult.ok);
      expect(p.photoUrl, 'https://s.example/profile-photos/a.jpg');
      for (final (code, want) in [
        (413, PhotoUploadResult.tooLarge),
        (415, PhotoUploadResult.notAPhoto),
        (429, PhotoUploadResult.tooMany),
        (500, PhotoUploadResult.failed),
      ]) {
        status = code;
        expect(await p.uploadPhoto([1], 'a.jpg'), want);
      }
      p.uploader = (bytes, name) async => (null, null);
      expect(await p.uploadPhoto([1], 'a.jpg'), PhotoUploadResult.offline);
      // A failed upload keeps the photo that was there.
      expect(p.photoUrl, 'https://s.example/profile-photos/a.jpg');
    });

    test('over 5 MB is refused before uploading', () async {
      final p = LearnerProfile.instance;
      var called = false;
      p.uploader = (bytes, name) async {
        called = true;
        return (200, null);
      };
      final big = List<int>.filled(5 * 1024 * 1024 + 1, 0);
      expect(await p.uploadPhoto(big, 'big.jpg'), PhotoUploadResult.tooLarge);
      expect(called, isFalse);
    });

    test('remove clears it only when the server took it', () async {
      final p = LearnerProfile.instance;
      p.uploader =
          (bytes, name) async => (
            200,
            {'photo_url': 'https://s.example/profile-photos/a.jpg'},
          );
      await p.uploadPhoto([1], 'a.jpg');
      p.remover = () async => false;
      expect(await p.removePhoto(), isFalse);
      expect(p.photoUrl, isNotNull);
      p.remover = () async => true;
      expect(await p.removePhoto(), isTrue);
      expect(p.photoUrl, isNull);
    });

    test('refresh takes the photo, review state and default avatar', () async {
      final p = LearnerProfile.instance;
      p.fetch =
          () async => {
            'display_name': 'Pema',
            'avatar': null,
            'default_avatar': 'conch:green',
            'photo_url': 'https://s.example/profile-photos/b.jpg',
            'photo_hidden': true,
          };
      await p.refresh();
      expect(p.photoUrl, 'https://s.example/profile-photos/b.jpg');
      expect(p.photoHidden, isTrue);
      expect(p.avatar, isNull);
      expect(p.shownAvatar, 'conch:green');
      // An admin removed it: the server's answer wins.
      p.fetch = () async => {'display_name': 'Pema', 'photo_url': null};
      await p.refresh();
      expect(p.photoUrl, isNull);
    });
  });

  group('show my city', () {
    test('off by default; on sends only city and country', () async {
      final p = LearnerProfile.instance;
      p.fetch = () async => null;
      expect(p.showPlace, isFalse);
      Map<String, String?>? sent;
      bool? sentShow;
      p.locate = ({bool ask = true}) async =>
          {'city': 'Dharamsala', 'country_code': 'IN', 'country': 'India'};
      p.pushPlace = (show, place) async {
        sentShow = show;
        sent = place;
        return {'show_place': show, 'place': place};
      };
      expect(await p.setShowPlace(true), PlaceResult.ok);
      expect(sentShow, isTrue);
      expect(sent!.keys.toSet(), {'city', 'country_code', 'country'});
      expect(p.place, 'Dharamsala, India');
      expect(await p.setShowPlace(false), PlaceResult.ok);
      expect(sentShow, isFalse);
      expect(sent, isNull);
      expect(p.place, isNull);
    });

    test('no location: stays off and sends nothing', () async {
      final p = LearnerProfile.instance;
      var pushed = false;
      p.locate = ({bool ask = true}) async => null;
      p.pushPlace = (show, place) async {
        pushed = true;
        return {};
      };
      expect(await p.setShowPlace(true), PlaceResult.noLocation);
      expect(p.showPlace, isFalse);
      expect(pushed, isFalse);
    });

    test('refresh follows the server opt-in', () async {
      final p = LearnerProfile.instance;
      p.fetch = () async => {
        'show_place': true,
        'place': {'city': 'Delhi', 'country_code': 'IN', 'country': 'India'},
        'place_hidden': false,
      };
      await p.refresh();
      expect(p.showPlace, isTrue);
      expect(p.place, 'Delhi, India');
    });
  });
}
