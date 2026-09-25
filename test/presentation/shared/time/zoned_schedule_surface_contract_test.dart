// Actual home/calendar consumers, not a replacement test-only time widget.
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/calendar/component/schedule_detail.dart';
import 'package:on_time_front/presentation/home/components/todays_schedule_tile.dart';
import 'package:on_time_front/presentation/shared/time/device_time_zone_scope.dart';
import 'package:on_time_front/presentation/shared/time/schedule_zoned_time.dart';

class _SyntheticIcons extends CachingAssetBundle {
  @override
  Future<ByteData> load(String key) async => ByteData.sublistView(
    Uint8List.fromList(
      utf8.encode(
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"></svg>',
      ),
    ),
  );
}

void main() {
  for (final language in ['ko', 'en']) {
    for (final device in ['Asia/Tokyo', 'America/New_York']) {
      for (final home in [true, false]) {
        testWidgets(
          '${home ? 'actual home tile' : 'actual calendar detail'} $language $device exposes both zones at320px text2.5',
          (tester) async {
            tester.view.physicalSize = const Size(320, 568);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.resetPhysicalSize);
            addTearDown(tester.view.resetDevicePixelRatio);
            final semantics = tester.ensureSemantics();
            final controller = DeviceTimeZoneController(
              readZone: () async => device,
            );
            await controller.refresh();
            final schedule = ScheduleEntity(
              id: 'surface-fixture',
              place: const PlaceEntity(
                id: 'fixture-place',
                placeName: 'Synthetic place',
              ),
              scheduleName: 'Synthetic appointment',
              scheduleTime: DateTime.utc(2031, 1, 2, 9, 0, 1, 123, 456),
              timeZoneId: 'Asia/Seoul',
              occurrenceOffsetSeconds: 32400,
              moveTime: const Duration(minutes: 10),
              scheduleSpareTime: null,
              isChanged: false,
              isStarted: false,
              scheduleNote: '',
            );
            try {
              await tester.pumpWidget(
                DefaultAssetBundle(
                  bundle: _SyntheticIcons(),
                  child: DeviceTimeZoneScope(
                    controller: controller,
                    child: MaterialApp(
                      locale: Locale(language),
                      supportedLocales: AppLocalizations.supportedLocales,
                      localizationsDelegates:
                          AppLocalizations.localizationsDelegates,
                      builder: (context, child) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: const TextScaler.linear(2.5),
                          alwaysUse24HourFormat: true,
                        ),
                        child: child!,
                      ),
                      home: Scaffold(
                        body: SingleChildScrollView(
                          child: home
                              ? TodaysScheduleTile(
                                  schedule: schedule,
                                  compact: true,
                                )
                              : ScheduleDetail(schedule: schedule),
                        ),
                      ),
                    ),
                  ),
                ),
              );
              await tester.pump();
              await tester.pump(const Duration(milliseconds: 100));
              expect(tester.takeException(), isNull);
              expect(find.byType(ScheduleZonedTime), findsOneWidget);
              final original = find.textContaining('Asia/Seoul');
              final equivalent = find.textContaining(device);
              expect(original, findsOneWidget);
              expect(equivalent, findsOneWidget);
              for (final finder in [original, equivalent]) {
                final text = tester.widget<Text>(finder);
                expect(
                  text.maxLines,
                  isNull,
                  reason:
                      'Full named zone and date must not be capped/ellipsized.',
                );
                expect(text.overflow, isNot(TextOverflow.ellipsis));
              }
              final label = tester
                  .getSemantics(find.byType(ScheduleZonedTime))
                  .label;
              expect(label, contains('Asia/Seoul'));
              expect(label, contains(device));
              expect(label, contains('123456'));
              if (device == 'America/New_York') {
                expect(
                  label,
                  contains(language == 'en' ? '1/2/2031' : '2031. 1. 2.'),
                );
                expect(
                  label,
                  contains(language == 'en' ? '1/1/2031' : '2031. 1. 1.'),
                );
              }
              expect(schedule.occurrenceOffsetSeconds, 32400);
              expect(schedule.timeZoneId, 'Asia/Seoul');
            } finally {
              // Retire real tile countdown and shared observation before test
              // invariant checks. This is fixture teardown, not product logic.
              await tester.pumpWidget(const SizedBox.shrink());
              await tester.pump();
              controller.dispose();
              semantics.dispose();
            }
          },
        );
      }
    }
  }
}
