import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/shared/constants/early_late_text_images.dart';

void main() {
  group('early_late_text_images data', () {
    test('every early message entry includes message and image', () {
      for (final entries in earlyMessagesWithImages.values) {
        for (final entry in entries) {
          expect(entry['message'], isNotNull);
          expect(entry['message']!, isNotEmpty);
          expect(entry['image'], isNotNull);
          expect(entry['image']!, isNotEmpty);
        }
      }
    });

    test('getEarlyMessage always returns both message and image', () {
      const sampleMinutes = <int>[
        0,
        5,
        6,
        10,
        11,
        15,
        16,
        20,
        21,
        30,
        31,
        40,
        41,
        59,
        60,
        120,
      ];

      for (final minutes in sampleMinutes) {
        final result = getEarlyMessage(minutes);
        expect(result['message'], isNotNull);
        expect(result['message']!, isNotEmpty);
        expect(result['image'], isNotNull);
        expect(result['image']!, isNotEmpty);
      }
    });
  });
}
