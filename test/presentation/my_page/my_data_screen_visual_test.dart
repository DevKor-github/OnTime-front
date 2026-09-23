import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/my_page/my_data_screen.dart';
import 'package:on_time_front/presentation/shared/components/app_spinner.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

import '../../helpers/visual_test_fonts.dart';

class _BackupServiceStub extends Fake implements BackupService {
  String? exportedPassword;
  String? restorePassword;
  BackupFreshnessStatus freshness = const BackupFreshnessStatus(
    freshness: BackupFreshness.neverExported,
  );
  Completer<BackupFreshnessStatus>? pendingFreshness;
  Completer<bool>? pendingExport;
  Object? exportError;

  @override
  Future<BackupFreshnessStatus> getFreshness() async =>
      pendingFreshness?.future ?? freshness;

  @override
  Future<bool> exportToUserSelectedFile(String password) async {
    exportedPassword = password;
    if (exportError case final error?) throw error;
    if (pendingExport case final operation?) return operation.future;
    return true;
  }

  @override
  Future<BackupRestoreCandidate?> selectAndPreviewRestore(
    String password,
  ) async {
    restorePassword = password;
    return null;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadVisualTestFonts);

  late _BackupServiceStub backupService;

  setUp(() async {
    await getIt.reset();
    backupService = _BackupServiceStub();
    getIt.registerSingleton<BackupService>(backupService);
  });

  tearDown(() async => getIt.reset());

  Future<void> pumpScreen(WidgetTester tester, {double textScale = 1}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.padding = FakeViewPadding(top: 44, bottom: 21);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPadding);

    await tester.pumpWidget(
      MaterialApp(
        theme: themeData,
        debugShowCheckedModeBanner: false,
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            padding: const EdgeInsets.only(top: 44, bottom: 21),
            textScaler: TextScaler.linear(textScale),
          ),
          child: const MyDataScreen(),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('my data uses the Figma 358px content grid', (tester) async {
    await pumpScreen(tester);

    for (final key in [
      'backupStatusCard',
      'backupExportRow',
      'backupRestoreRow',
      'localDataResetRow',
    ]) {
      final finder = find.byKey(Key(key));
      expect(finder, findsOneWidget);
      expect(tester.getTopLeft(finder).dx, 16);
      expect(tester.getSize(finder).width, 358);
      expect(tester.getSize(finder).height, 68);
    }
    expect(
      tester.getTopLeft(find.byKey(const Key('backupStatusCard'))).dy,
      122,
    );
    expect(tester.getTopLeft(find.byKey(const Key('backupExportRow'))).dy, 208);
    expect(
      tester.getTopLeft(find.byKey(const Key('backupRestoreRow'))).dy,
      294,
    );
    expect(
      tester.getTopLeft(find.byKey(const Key('localDataResetRow'))).dy,
      380,
    );
    expect(find.text('아직 내보낸 백업이 없습니다.'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('backupExportRow'))).height,
      greaterThanOrEqualTo(68),
    );
  });

  testWidgets('my data default visual remains reviewed', (tester) async {
    await pumpScreen(tester);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('../../goldens/goldens/my_data_default_390x844.png'),
    );
  });

  testWidgets('freshness checking has the reviewed status card', (
    tester,
  ) async {
    backupService.pendingFreshness = Completer<BackupFreshnessStatus>();
    await pumpScreen(tester);
    expect(find.text('확인 중'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        '../../goldens/goldens/my_data_freshness_checking_390x844.png',
      ),
    );
    backupService.pendingFreshness!.complete(backupService.freshness);
    await tester.pump();
  });

  testWidgets('freshness no changes has the reviewed status card', (
    tester,
  ) async {
    backupService.freshness = const BackupFreshnessStatus(
      freshness: BackupFreshness.noChanges,
    );
    await pumpScreen(tester);
    expect(find.text('마지막 백업 이후 변경 사항이 없습니다.'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        '../../goldens/goldens/my_data_freshness_no_changes_390x844.png',
      ),
    );
  });

  testWidgets('freshness unexported changes has the reviewed status card', (
    tester,
  ) async {
    backupService.freshness = const BackupFreshnessStatus(
      freshness: BackupFreshness.unexportedChanges,
    );
    await pumpScreen(tester);
    expect(find.text('백업되지 않은 변경 사항이 있습니다.'), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        '../../goldens/goldens/my_data_freshness_unexported_390x844.png',
      ),
    );
  });

  testWidgets('freshness reminder grows the card without hiding actions', (
    tester,
  ) async {
    backupService.freshness = const BackupFreshnessStatus(
      freshness: BackupFreshness.unexportedChanges,
      reminderDue: true,
    );
    await pumpScreen(tester);
    expect(find.text('30일 이상 백업되지 않은 변경 사항이 있습니다.'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('backupStatusCard'))).height,
      greaterThan(68),
    );
    expect(find.byKey(const Key('localDataResetRow')), findsOneWidget);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile(
        '../../goldens/goldens/my_data_freshness_reminder_390x844.png',
      ),
    );
  });

  testWidgets('large text keeps every data action available', (tester) async {
    await pumpScreen(tester, textScale: 2);

    for (final key in [
      'backupExportRow',
      'backupRestoreRow',
      'localDataResetRow',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('canceling reset leaves data untouched', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byKey(const Key('localDataResetRow')));
    await tester.pumpAndSettle();
    expect(find.text('모든 로컬 데이터를 삭제할까요?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('모든 로컬 데이터를 삭제할까요?'), findsNothing);
  });

  testWidgets('reset confirmation uses the Figma-sized destructive dialog', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('localDataResetRow')));
    await tester.pumpAndSettle();

    expect(
      tester
          .getSize(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Material),
                )
                .first,
          )
          .width,
      277,
    );
    expect(find.text('모두 삭제'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/goldens/my_data_reset_confirmation_390x844.png',
      ),
    );
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('data actions meet iOS tap and label guidelines', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester);

    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();
  });

  testWidgets('backup creation rejects short and mismatched passwords', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('backupExportRow')));
    await tester.pumpAndSettle();

    expect(find.text('백업 비밀번호 만들기'), findsOneWidget);
    expect(
      tester
          .getSize(
            find
                .descendant(
                  of: find.byType(Dialog),
                  matching: find.byType(Material),
                )
                .first,
          )
          .width,
      277,
    );
    await tester.enterText(find.byType(TextField).first, '123456789');
    await tester.enterText(find.byType(TextField).last, '123456789');
    await tester.tap(find.text('계속'));
    await tester.pumpAndSettle();
    expect(find.text('백업 비밀번호는 15~128자로 입력해주세요.'), findsOneWidget);
    expect(backupService.exportedPassword, isNull);
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/goldens/my_data_password_invalid_390x844.png',
      ),
    );

    await tester.enterText(find.byType(TextField).first, '123456789012345');
    await tester.enterText(find.byType(TextField).last, '123456789012346');
    await tester.tap(find.text('계속'));
    await tester.pumpAndSettle();
    expect(find.text('비밀번호가 서로 다릅니다.'), findsOneWidget);
    expect(backupService.exportedPassword, isNull);
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/goldens/my_data_password_mismatch_390x844.png',
      ),
    );

    await tester.enterText(find.byType(TextField).last, '123456789012345');
    await tester.tap(find.text('계속'));
    await tester.pumpAndSettle();
    expect(backupService.exportedPassword, '123456789012345');
    expect(find.text('암호화 백업을 저장했습니다.'), findsOneWidget);
  });

  testWidgets('canceling password dialog never starts backup or restore', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('backupExportRow')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(backupService.exportedPassword, isNull);

    await tester.tap(find.byKey(const Key('backupRestoreRow')));
    await tester.pumpAndSettle();
    expect(find.text('백업 비밀번호 입력'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(backupService.restorePassword, isNull);
  });

  testWidgets('restore uses the validated password and waits for a file', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('backupRestoreRow')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), '123456789012345');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/goldens/my_data_password_input_390x844.png',
      ),
    );
    await tester.tap(find.text('계속'));
    await tester.pumpAndSettle();
    expect(backupService.restorePassword, '123456789012345');
    expect(find.text('복원 내용 확인'), findsNothing);
  });

  testWidgets('backup password creation matches the reviewed dialog', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('backupExportRow')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123456789012345');
    await tester.enterText(find.byType(TextField).last, '123456789012345');
    tester.binding.focusManager.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final card = find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first;
    expect(tester.getTopLeft(card).dy, 352);
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/goldens/my_data_password_create_390x844.png',
      ),
    );
    semantics.dispose();
  });

  testWidgets('busy export disables actions and shows the reviewed spinner', (
    tester,
  ) async {
    backupService.pendingExport = Completer<bool>();
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('backupExportRow')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123456789012345');
    await tester.enterText(find.byType(TextField).last, '123456789012345');
    await tester.tap(find.text('계속'));
    await tester.pump(const Duration(milliseconds: 900));

    expect(find.byType(AppSpinner), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
    expect(tester.getTopLeft(find.byType(AppSpinner)).dy, 466);
    expect(tester.getSize(find.byType(AppSpinner)), const Size(40, 40));
    await tester.tap(find.byKey(const Key('backupRestoreRow')));
    await tester.pump();
    expect(find.text('백업 비밀번호 입력'), findsNothing);
    await expectLater(
      find.byType(Scaffold),
      matchesGoldenFile('../../goldens/goldens/my_data_busy_390x844.png'),
    );

    backupService.pendingExport!.complete(false);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.byType(AppSpinner), findsNothing);
  });

  testWidgets('export success uses the reviewed result snackbar', (
    tester,
  ) async {
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('backupExportRow')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123456789012345');
    await tester.enterText(find.byType(TextField).last, '123456789012345');
    await tester.tap(find.text('계속'));
    await tester.pumpAndSettle();
    expect(find.text('암호화 백업을 저장했습니다.'), findsOneWidget);
    final bar = find
        .descendant(of: find.byType(SnackBar), matching: find.byType(Material))
        .first;
    expect(tester.getTopLeft(bar).dy, closeTo(752, 1));
    expect(tester.getSize(bar), const Size(358, 44));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/goldens/my_data_export_success_390x844.png',
      ),
    );
  });

  testWidgets('failed export clears busy state and presents an error', (
    tester,
  ) async {
    backupService.exportError = StateError('disk full');
    await pumpScreen(tester);
    await tester.tap(find.byKey(const Key('backupExportRow')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '123456789012345');
    await tester.enterText(find.byType(TextField).last, '123456789012345');
    await tester.tap(find.text('계속'));
    await tester.pumpAndSettle();
    expect(find.byType(AppSpinner), findsNothing);
    expect(find.textContaining('disk full'), findsOneWidget);
    expect(find.byKey(const Key('backupExportRow')), findsOneWidget);
  });

  testWidgets('restore success and operation failure share result placement', (
    tester,
  ) async {
    await pumpScreen(tester);
    final context = tester.element(find.byType(MyDataScreen));
    showMyDataResultSnackBar(context, '백업을 복원했습니다.');
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/goldens/my_data_restore_success_390x844.png',
      ),
    );
    ScaffoldMessenger.of(context).removeCurrentSnackBar();
    await tester.pumpAndSettle();

    showMyDataResultSnackBar(context, '작업을 완료하지 못했습니다: {error}');
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/goldens/my_data_operation_failure_390x844.png',
      ),
    );
  });

  testWidgets('password dialog remains usable with keyboard and large text', (
    tester,
  ) async {
    tester.view.viewInsets = FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await pumpScreen(tester, textScale: 2);
    await tester.tap(find.byKey(const Key('backupExportRow')));
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('계속'), findsOneWidget);
    expect(tester.getBottomLeft(find.text('계속')).dy, lessThan(544));
    expect(tester.takeException(), isNull);
  });

  testWidgets('restore preview matches Figma and cancel preserves data', (
    tester,
  ) async {
    await pumpScreen(tester);
    final context = tester.element(find.byType(MyDataScreen));
    final result = showRestorePreviewDialog(
      context,
      BackupRestorePreview(
        cutoff: DateTime(2026, 8, 29, 21, 41),
        sourceAppVersion: '1.0.0+1',
        sourcePlatform: 'iOS',
        scheduleCount: 3,
        templateCount: 1,
        defaultPreparationStepCount: 6,
      ),
    );
    await tester.pumpAndSettle();

    final card = find
        .descendant(of: find.byType(Dialog), matching: find.byType(Material))
        .first;
    expect(tester.getSize(card).width, 277);
    expect(tester.getTopLeft(card).dy, 352);
    expect(find.textContaining('일정 3개'), findsOneWidget);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile(
        '../../goldens/goldens/my_data_restore_preview_390x844.png',
      ),
    );

    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(await result, DialogActionResult.secondary);
  });

  testWidgets('restore preview keeps both actions at large text', (
    tester,
  ) async {
    await pumpScreen(tester, textScale: 2);
    final result = showRestorePreviewDialog(
      tester.element(find.byType(MyDataScreen)),
      BackupRestorePreview(
        cutoff: DateTime(2026, 8, 29, 21, 41),
        sourceAppVersion: '1.0.0+1',
        sourcePlatform: 'iOS',
        scheduleCount: 3,
        templateCount: 1,
        defaultPreparationStepCount: 6,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('취소'), findsOneWidget);
    expect(find.text('복원'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(await result, DialogActionResult.secondary);
  });
}
