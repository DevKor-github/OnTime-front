import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/presentation/backup/backup_processing_panel.dart';

void main() {
  for (final locale in ['ko', 'en']) {
    testWidgets(
      '$locale at 200% exposes cancellation and retry without losing running ownership',
      (tester) async {
        final semantics = tester.ensureSemantics();

        await tester.binding.setSurfaceSize(const Size(360, 800));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final owner = BackupProcessingOwner();
        final lease = owner.acquire()..beginOperation();
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            supportedLocales: const [Locale('ko'), Locale('en')],
            localizationsDelegates: GlobalMaterialLocalizations.delegates,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: SingleChildScrollView(
                child: BackupProcessingPanel(owner: owner),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.text(locale == 'ko' ? '백업 작업 취소' : 'Cancel backup operation'),
        );
        await tester.pump();
        expect(
          find.textContaining(
            locale == 'ko' ? '시스템 파일 창' : 'system file window',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        expect(owner.active, same(lease));
        var cleaned = false;
        lease.retainCleanup(() async {
          cleaned = true;
        });
        await tester.pump();
        await tester.tap(
          find.text(
            locale == 'ko'
                ? '같은 작업 정리 다시 시도'
                : 'Retry this operation’s cleanup',
          ),
        );
        await tester.pump();
        expect(cleaned, false);
        expect(owner.active, same(lease));
        lease.endOperation();
        await tester.pumpAndSettle();
        expect(cleaned, true);
        expect(owner.active, isNull);
        expect(tester.takeException(), isNull);
        semantics.dispose();
      },
    );
  }
}
