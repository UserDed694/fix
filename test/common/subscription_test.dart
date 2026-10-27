import 'package:fl_clash/common/common.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('subscriptionUrlFor', () {
    test('turns a bare key into a link on the panel host', () {
      expect(
        subscriptionUrlFor(' aB3-x_9 '),
        'https://subrw.victorycloud.ru/aB3-x_9',
      );
    });

    test('keeps a full link, a share link and an empty value as they are', () {
      const link = 'https://subrw.victorycloud.ru/token?x=1';
      expect(subscriptionUrlFor(link), link);
      expect(
        subscriptionUrlFor('vless://id@host:443#HK'),
        'vless://id@host:443#HK',
      );
      expect(subscriptionUrlFor('  '), '');
      expect(subscriptionUrlFor('a b'), 'a b');
    });
  });

  group('isAllowedSubscriptionUrl', () {
    test('accepts the panel host in either case and over http', () {
      expect(
        isAllowedSubscriptionUrl('https://subrw.victorycloud.ru/t'),
        isTrue,
      );
      expect(
        isAllowedSubscriptionUrl('http://SUBRW.victorycloud.ru/t'),
        isTrue,
      );
    });

    test('rejects other hosts, lookalikes, share links and plain keys', () {
      expect(isAllowedSubscriptionUrl('https://example.com/t'), isFalse);
      expect(
        isAllowedSubscriptionUrl('https://subrw.victorycloud.ru.evil.com/t'),
        isFalse,
      );
      expect(
        isAllowedSubscriptionUrl('https://evil.com/subrw.victorycloud.ru'),
        isFalse,
      );
      expect(
        isAllowedSubscriptionUrl('vless://id@subrw.victorycloud.ru:443'),
        isFalse,
      );
      expect(isAllowedSubscriptionUrl('token'), isFalse);
    });
  });

  group('subscriptionHeaders', () {
    test('sends the device id to the panel only', () {
      expect(
        subscriptionHeaders(Uri.parse('https://subrw.victorycloud.ru/t'), 'id'),
        {'x-hwid': 'id'},
      );
      expect(
        subscriptionHeaders(Uri.parse('https://github.com/geo.dat'), 'id'),
        isEmpty,
      );
    });
  });

  group('preferences.getDeviceId', () {
    setUp(() => mockPreferences());

    test('is a v4 UUID that stays the same across reads and rebinds', () async {
      final id = await preferences.getDeviceId();
      expect(
        id,
        matches(
          RegExp(
            r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
          ),
        ),
      );
      expect(await preferences.getDeviceId(), id);
      await preferences.rebind();
      expect(await preferences.getDeviceId(), id);
    });

    test('is read back from the stored value', () async {
      await mockPreferences({deviceIdKey: 'stored-id'});
      expect(await preferences.getDeviceId(), 'stored-id');
    });
  });
}
