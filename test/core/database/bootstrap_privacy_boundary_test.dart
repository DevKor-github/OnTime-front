import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/bootstrap_privacy_boundary.dart';

void main() {
  test('successful bootstrap does not remove runtime', () async {
    var cleaned = false;
    await bootstrapWithPrivacyCleanup(
      bootstrap: () async {},
      cleanup: () async {
        cleaned = true;
      },
    );
    expect(cleaned, isFalse);
  });
  test(
    'failure before Auth attempts cleanup and preserves original failure',
    () async {
      final failure = StateError('bootstrap unavailable');
      var cleaned = false;
      await expectLater(
        bootstrapWithPrivacyCleanup(
          bootstrap: () async {
            throw failure;
          },
          cleanup: () async {
            cleaned = true;
          },
        ),
        throwsA(same(failure)),
      );
      expect(cleaned, isTrue);
    },
  );
  test(
    'cleanup failure preserves both failures without private message text',
    () async {
      final bootstrapError = StateError('private bootstrap value');
      final cleanupError = StateError('private cleanup value');
      await expectLater(
        bootstrapWithPrivacyCleanup(
          bootstrap: () async {
            throw bootstrapError;
          },
          cleanup: () async {
            throw cleanupError;
          },
        ),
        throwsA(
          isA<BootstrapPrivacyCleanupFailure>()
              .having(
                (e) => e.bootstrapError,
                'bootstrap',
                same(bootstrapError),
              )
              .having((e) => e.cleanupError, 'cleanup', same(cleanupError))
              .having(
                (e) => e.toString(),
                'safe text',
                isNot(contains('private')),
              ),
        ),
      );
    },
  );
}
