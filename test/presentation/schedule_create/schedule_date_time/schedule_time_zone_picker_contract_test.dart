import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/schedule_date_time/screens/schedule_time_zone_picker.dart';
import 'package:on_time_front/presentation/shared/time/device_time_zone_scope.dart';
import 'package:on_time_front/presentation/shared/time/time_zone_catalog.dart';

class _Fixture {
  String device = 'Asia/Tokyo';
  String draftZone = 'Asia/Seoul';
  bool current = true;
  int applied = 0;
  late final controller = DeviceTimeZoneController(
    readZone: () async => device,
  );

  Future<void> mount(
    WidgetTester tester, {
    String language = 'en',
    bool narrow = false,
  }) async {
    await controller.refresh();
    if (narrow) {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }
    await tester.pumpWidget(
      DeviceTimeZoneScope(
        controller: controller,
        child: MaterialApp(
          locale: Locale(language),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(narrow ? 2.5 : 1)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  final selected = await showScheduleTimeZonePicker(
                    context: context,
                    currentZone: draftZone,
                    civil: DateTime.utc(2031, 1, 2, 9, 0, 1, 123, 456),
                    offsetSeconds: 32400,
                    isCurrent: () => current,
                  );
                  if (selected != null) {
                    draftZone = selected;
                    applied++;
                  }
                },
                child: const Text('Open picker'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open picker'));
    await tester.pumpAndSettle();
  }

  Future<void> search(WidgetTester tester, String query) async {
    final finder = find.byKey(const ValueKey('time-zone-search'));
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.enterText(finder, query);
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String label) async {
    final finder = find.text(label);
    await tester.scrollUntilVisible(
      finder,
      100,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await Scrollable.ensureVisible(tester.element(finder), alignment: 0.5);
    await tester.pumpAndSettle();
    expect(finder.hitTestable(), findsOneWidget);
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    controller.dispose();
  }
}

void main() {
  testWidgets(
    'unknown saved zone and unavailable device remain explicit until UTC is chosen',
    (tester) async {
      final f = _Fixture()
        ..device = 'Missing/Device'
        ..draftZone = 'Vendor/Removed';
      try {
        await f.mount(tester);
        expect(
          find.textContaining('device time zone is unavailable'),
          findsOneWidget,
        );
        expect(find.textContaining('Vendor/Removed'), findsOneWidget);
        expect(f.draftZone, 'Vendor/Removed');
        expect(f.applied, 0);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('time-zone-apply')),
              )
              .onPressed,
          isNull,
        );
        await f.search(tester, 'UTC');
        await f.choose(
          tester,
          '${TimeZoneCatalog.cityName('UTC', 'en')} · UTC',
        );
        expect(f.draftZone, 'Vendor/Removed');
        await tester.tap(find.byKey(const ValueKey('time-zone-apply')));
        await tester.pumpAndSettle();
        expect(f.draftZone, 'UTC');
        expect(f.applied, 1);
      } finally {
        await f.dispose(tester);
      }
    },
  );

  testWidgets(
    'empty search explains recovery and clearing search preserves the draft',
    (tester) async {
      final f = _Fixture();
      try {
        await f.mount(tester);
        await f.search(tester, 'fixture impossible zone');
        expect(find.textContaining('No matching time zones'), findsOneWidget);
        await tester.tap(find.byTooltip('Clear search'));
        await tester.pumpAndSettle();
        expect(find.textContaining('No matching time zones'), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byKey(const ValueKey('time-zone-search')))
              .controller!
              .text,
          isEmpty,
        );
        expect(f.draftZone, 'Asia/Seoul');
        expect(f.applied, 0);
      } finally {
        await f.dispose(tester);
      }
    },
  );

  test(
    'offline catalog supports Korean city, normalized English and full IANA names',
    () {
      expect(
        TimeZoneCatalog.search('  new_YORK '),
        contains('America/New_York'),
      );
      expect(TimeZoneCatalog.search('뉴욕'), contains('America/New_York'));
      expect(
        TimeZoneCatalog.search('ASIA/KATHMANDU'),
        contains('Asia/Kathmandu'),
      );
      expect(TimeZoneCatalog.search('서울'), contains('Asia/Seoul'));
      expect(TimeZoneCatalog.search('impossible fixture zone'), isEmpty);
    },
  );

  testWidgets(
    'selection previews civil fields and device equivalent before explicit apply',
    (tester) async {
      final f = _Fixture();
      try {
        await f.mount(tester);
        expect(
          tester
              .widget<FilledButton>(
                find.byKey(const ValueKey('time-zone-apply')),
              )
              .onPressed,
          isNull,
        );
        await f.search(tester, 'new york');
        await f.choose(tester, 'New York · America/New_York');
        expect(f.draftZone, 'Asia/Seoul');
        expect(f.applied, 0);
        expect(find.textContaining('America/New_York'), findsWidgets);
        expect(find.textContaining('123456'), findsWidgets);
        await tester.tap(find.byKey(const ValueKey('time-zone-apply')));
        await tester.pumpAndSettle();
        expect(f.draftZone, 'America/New_York');
        expect(f.applied, 1);
        expect(tester.takeException(), isNull);
      } finally {
        await f.dispose(tester);
      }
    },
  );

  for (final back in [false, true]) {
    testWidgets(
      '${back ? 'system back' : 'cancel'} discards preview without applying to draft',
      (tester) async {
        final f = _Fixture();
        try {
          await f.mount(tester);
          await f.search(tester, 'Kathmandu');
          await f.choose(tester, 'Kathmandu · Asia/Kathmandu');
          if (back) {
            await tester.binding.handlePopRoute();
          } else {
            await tester.tap(find.text('Cancel'));
          }
          await tester.pumpAndSettle();
          expect(f.draftZone, 'Asia/Seoul');
          expect(f.applied, 0);
          expect(find.byKey(const ValueKey('time-zone-apply')), findsNothing);
        } finally {
          await f.dispose(tester);
        }
      },
    );
  }

  testWidgets('retired form owner cannot receive a picker result', (
    tester,
  ) async {
    final f = _Fixture();
    try {
      await f.mount(tester);
      await f.search(tester, 'Kathmandu');
      await f.choose(tester, 'Kathmandu · Asia/Kathmandu');
      f.current = false;
      await tester.tap(find.byKey(const ValueKey('time-zone-apply')));
      await tester.pumpAndSettle();
      expect(f.draftZone, 'Asia/Seoul');
      expect(f.applied, 0);
    } finally {
      await f.dispose(tester);
    }
  });

  testWidgets('device zone observation never replaces chosen draft candidate', (
    tester,
  ) async {
    final f = _Fixture();
    try {
      await f.mount(tester);
      await f.search(tester, 'Kathmandu');
      await f.choose(tester, 'Kathmandu · Asia/Kathmandu');
      f.device = 'America/New_York';
      await f.controller.refresh();
      await tester.pumpAndSettle();
      expect(find.textContaining('America/New_York'), findsWidgets);
      expect(f.draftZone, 'Asia/Seoul');
      await tester.tap(find.byKey(const ValueKey('time-zone-apply')));
      await tester.pumpAndSettle();
      expect(f.draftZone, 'Asia/Kathmandu');
      expect(f.applied, 1);
    } finally {
      await f.dispose(tester);
    }
  });

  for (final language in ['ko', 'en']) {
    testWidgets(
      '$language narrow large-text picker remains usable with keyboard insets',
      (tester) async {
        final f = _Fixture();
        try {
          await f.mount(tester, language: language, narrow: true);
          tester.view.viewInsets = const FakeViewPadding(bottom: 250);
          addTearDown(tester.view.resetViewInsets);
          await f.search(tester, 'Kathmandu');
          await f.choose(
            tester,
            '${language == 'ko' ? '카트만두' : 'Kathmandu'} · Asia/Kathmandu',
          );
          expect(tester.takeException(), isNull);
          final apply = find.byKey(const ValueKey('time-zone-apply'));
          expect(apply.hitTestable(), findsOneWidget);
          await tester.tap(apply);
          await tester.pumpAndSettle();
          expect(f.draftZone, 'Asia/Kathmandu');
          expect(tester.takeException(), isNull);
        } finally {
          await f.dispose(tester);
        }
      },
    );
  }
}
