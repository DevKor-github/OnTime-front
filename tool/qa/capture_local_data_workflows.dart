// Synthetic widget raster evidence. No mobile picker, OS delivery, or real data.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/ports/local_data_ports.dart';
import 'package:on_time_front/domain/use-cases/local_data_workflows.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/my_page/my_data_screen.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

class _Input extends BackupRestoreInput {
  @override
  BackupRestorePreview get preview => BackupRestorePreview(
    cutoff: DateTime.utc(2026, 9, 24),
    sourceAppVersion: '1.0',
    sourcePlatform: 'android',
    scheduleCount: 2,
    templateCount: 1,
    defaultPreparationStepCount: 3,
  );
}

class _Backup implements BackupOperationsPort {
  @override
  int generation = 0;
  bool freshnessFails = true;
  @override
  Future<BackupFreshnessStatus> freshness() async {
    if (freshnessFails) throw StateError('synthetic');
    return const BackupFreshnessStatus(
      freshness: BackupFreshness.neverExported,
    );
  }

  @override
  Future<BackupExportResult> export(String password) async =>
      BackupExportResult.saved;
  @override
  Future<BackupRestoreInput?> preview(String password) async => _Input();
  @override
  Future<int> apply(BackupRestoreInput input) async => ++generation;
}

class _Delivery implements RestoreDeliveryPort {
  @override
  Future<bool> reconcile() async => false;
}

void main() {
  testWidgets('KO EN 200 percent data workflow states', (tester) async {
    final output = Directory(Platform.environment['C01_CAPTURE_DIR']!);
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
    for (final language in ['ko', 'en']) {
      final port = _Backup();
      final workflow = BackupWorkflow(port, _Delivery());
      final key = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: key,
          child: MaterialApp(
            key: ValueKey(language),
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
            home: MyDataScreen(workflow: workflow),
          ),
        ),
      );
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '${output.path}/$name-$language.png',
          ).writeAsBytes(bytes!.buffer.asUint8List(), flush: true);
          image.dispose();
        });
      }

      await capture('freshness-failed');
      port.freshnessFails = false;
      await tester.tap(find.text(language == 'ko' ? '다시 시도' : 'Try again'));
      await tester.pumpAndSettle();
      final restore = find.text(
        language == 'ko' ? '백업에서 복원' : 'Restore from backup',
      );
      await tester.ensureVisible(restore);
      await tester.tap(restore);
      await tester.pumpAndSettle();
      await capture('password');
      await tester.enterText(
        find.byType(TextField),
        'synthetic backup password',
      );
      await tester.tap(find.text(language == 'ko' ? '계속' : 'Continue'));
      await tester.pumpAndSettle();
      await capture('preview');
      await tester.tap(find.text(language == 'ko' ? '복원' : 'Restore'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(ListView), const Offset(0, 800));
      await capture('restore-pending');
    }
  });
}
