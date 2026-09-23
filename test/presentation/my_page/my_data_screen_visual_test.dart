import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/my_page/my_data_screen.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';

import '../../helpers/visual_test_fonts.dart';

class _BackupServiceStub extends Fake implements BackupService {
  @override
  Future<BackupFreshnessStatus> getFreshness() async =>
      const BackupFreshnessStatus(freshness: BackupFreshness.neverExported);
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
      398,
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
}
