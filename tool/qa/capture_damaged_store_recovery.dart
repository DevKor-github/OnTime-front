// Synthetic real-widget raster evidence; no provider/plugin/mobile runtime proof.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/ports/recovery_restore_port.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'package:on_time_front/presentation/startup/screens/recovery_restore_screen.dart';

class _Input extends BackupRestoreInput {
  @override
  BackupRestorePreview get preview => BackupRestorePreview(
    cutoff: DateTime.utc(2026, 9, 24),
    sourceAppVersion: '1.0.0',
    sourcePlatform: 'android',
    scheduleCount: 12,
    templateCount: 3,
    defaultPreparationStepCount: 4,
  );
}

class _Port extends Fake implements RecoveryRestorePort {
  @override
  Future<BackupRestoreInput?> preview(String password) async => _Input();
}

void main() {
  testWidgets('KO EN 200 percent damaged recovery states', (tester) async {
    final output = Directory(Platform.environment['D02_CAPTURE_DIR']!);
    await tester.runAsync(() => output.create(recursive: true));
    final font = FontLoader('Pretendard')
      ..addFont(rootBundle.load('assets/fonts/Pretendard-Regular.ttf'));
    await tester.runAsync(font.load);
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final language in ['ko', 'en']) {
      final receipts = <String, BackupRestoreReceipt?>{
        'select': null,
        'unknown': const BackupRestoreReceipt.uncertain(generation: 1),
        'unapplied': BackupRestoreReceipt(
          disposition: BackupCommitDisposition.notCommitted,
          generation: 1,
          followUpPending: true,
        ),
        'restart': const BackupRestoreReceipt.recovery(
          generation: 1,
          phase: RecoveryFollowUp.awaitingNewProcess,
        ),
        'cleanup': const BackupRestoreReceipt.recovery(
          generation: 1,
          phase: RecoveryFollowUp.cleanupPending,
        ),
      };
      for (final entry in receipts.entries) {
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              key: ValueKey('$language-${entry.key}'),
              debugShowCheckedModeBanner: false,
              theme: themeData,
              locale: Locale(language),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: RecoveryRestoreScreen(
                port: () async => _Port(),
                initialReceipt: entry.value,
                onCancelled: () {},
                onCompleted: () {},
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        Future<void> capture(String name) async {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await tester.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '${output.path}/$name-$language.png',
            ).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
            image.dispose();
          });
        }

        await capture(entry.key);
        if (entry.key == 'select') {
          await tester.tap(
            find.text(language == 'ko' ? '백업 파일 선택' : 'Choose backup file'),
          );
          await capture('password');
          await tester.enterText(
            find.byType(TextField),
            'synthetic backup password',
          );
          await tester.tap(find.text(language == 'ko' ? '계속' : 'Continue'));
          await capture('preview');
          expect(
            find.textContaining(
              language == 'ko' ? '알 수 없습니다' : 'count is unknown',
            ),
            findsOneWidget,
          );
          await tester.tap(find.text(language == 'ko' ? '취소' : 'Cancel'));
          await tester.pumpAndSettle();
        }
      }
    }
  });
}
