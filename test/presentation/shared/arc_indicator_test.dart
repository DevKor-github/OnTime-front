import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/presentation/shared/components/arc_indicator.dart';

void main() {
  test('ArcIndicator paints background and progress arcs without throwing', () {
    final recorder = PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = ArcIndicator(progress: 0.5, strokeWidth: 8);

    painter.paint(canvas, const Size(120, 80));
    final picture = recorder.endRecording();
    addTearDown(picture.dispose);

    expect(
      painter.shouldRepaint(ArcIndicator(progress: 0.5, strokeWidth: 8)),
      isTrue,
    );
  });
}
