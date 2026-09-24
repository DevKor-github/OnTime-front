// Widget raster evidence, not a mobile OS screenshot or delivery test.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/database/local_reset_protocol.dart';
import 'package:on_time_front/core/services/alarm_ownership_journal.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:on_time_front/presentation/startup/screens/local_reset_progress_screen.dart';

void main() {
  testWidgets('capture localized reset receipts with bundled fonts', (
    tester,
  ) async {
    final output = Directory(Platform.environment['D03_CAPTURE_DIR']!);
    await tester.runAsync(() => output.create(recursive: true));
    final font = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    await tester.runAsync(font.load);
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await tester.runAsync(icons.load);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final locale in ['ko', 'en']) {
      for (final complete in [false, true]) {
        final result = LocalResetResult(
          intentRecorded: true,
          completed: complete
              ? ResetStep.values.toSet()
              : {
                  ResetStep.database,
                  ResetStep.preferences,
                  ResetStep.key,
                  ResetStep.credentials,
                  ResetStep.launch,
                },
          isComplete: complete,
          recoveryRequired: !complete,
        );
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          MaterialApp(
            key: ValueKey('$locale-$complete'),
            theme: themeData,
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MediaQuery(
              data: const MediaQueryData(
                size: Size(430, 932),
                textScaler: TextScaler.linear(2),
              ),
              child: RepaintBoundary(
                key: boundaryKey,
                child: LocalResetProgressScreen(
                  initialResult: result,
                  operation: () async => result,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            '${output.path}/reset-${complete ? 'complete' : 'pending'}-$locale.png',
          );
          await file.writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
          image.dispose();
        });
      }
    }
  });
}
