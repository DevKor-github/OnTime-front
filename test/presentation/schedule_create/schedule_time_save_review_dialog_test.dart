import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/schedule_create/bloc/schedule_time_save_review.dart';
import 'package:on_time_front/presentation/schedule_create/screens/schedule_time_save_review_dialog.dart';
import 'package:on_time_front/presentation/shared/time/device_time_zone_scope.dart';
import 'package:on_time_front/presentation/shared/time/schedule_zoned_time.dart';

void main() {
  for (final language in ['ko', 'en']) {
    for (final confirm in [false, true]) {
      testWidgets(
        '$language actual final dialog exposes before/after at320px text2.5 and returns $confirm',
        (tester) async {
          tester.view.physicalSize = const Size(320, 568);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final controller = DeviceTimeZoneController(
            readZone: () async => 'Asia/Tokyo',
          );
          await controller.refresh();
          final original = ScheduleEntity(
            id: 'dialog-fixture',
            place: const PlaceEntity(
              id: 'fixture-place',
              placeName: 'Synthetic',
            ),
            scheduleName: 'Synthetic appointment',
            scheduleTime: DateTime.utc(2031, 1, 2, 23, 0, 1, 123, 456),
            timeZoneId: 'Asia/Seoul',
            occurrenceOffsetSeconds: 32400,
            moveTime: Duration.zero,
            isChanged: false,
            isStarted: false,
            scheduleSpareTime: Duration.zero,
            scheduleNote: '',
          );
          final proposed = original.copyWith(
            timeZoneId: 'America/New_York',
            occurrenceOffsetSeconds: -18000,
          );
          final now = DateTime.utc(2030);
          final resolution = ScheduleTimeResolver.resolve(
            proposed,
            nowUtc: now,
          );
          final review = ScheduleTimeSaveReview(
            original: original,
            proposed: proposed,
            resolution: resolution,
            baseline: null,
            reviewedAtUtc: now,
            preparationStartUtc: resolution.instantUtc!,
            rulesIdentity: TimeZoneRules.loadedIdentity,
            formOwner: Object(),
            draftRevision: 1,
            editing: true,
          );
          bool? result;
          var replies = 0;
          final semantics = tester.ensureSemantics();
          try {
            await tester.pumpWidget(
              DeviceTimeZoneScope(
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
                    body: Builder(
                      builder: (context) => TextButton(
                        onPressed: () async {
                          result = await showScheduleTimeSaveReview(
                            context: context,
                            review: review,
                          );
                          replies++;
                        },
                        child: const Text('Review'),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Review'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byType(ScheduleZonedTime), findsNWidgets(2));
            expect(find.textContaining('Asia/Seoul'), findsOneWidget);
            expect(find.textContaining('America/New_York'), findsOneWidget);
            expect(find.textContaining('Asia/Tokyo'), findsNWidgets(2));
            expect(
              find.textContaining('2031-01-03T04:00:01.123456Z'),
              findsOneWidget,
            );
            final after = find.byType(ScheduleZonedTime).last;
            await tester.ensureVisible(after);
            await tester.pumpAndSettle();
            final label = tester.getSemantics(after).label;
            expect(label, contains('America/New_York'));
            expect(label, contains('Asia/Tokyo'));
            expect(label, contains('123456'));
            expect(replies, 0);
            final action = confirm
                ? find.byKey(const ValueKey('schedule-time-review-confirm'))
                : find.text(language == 'ko' ? '취소' : 'Cancel');
            expect(action.hitTestable(), findsOneWidget);
            await tester.tap(action);
            await tester.pumpAndSettle();
            expect(result, confirm);
            expect(replies, 1);
            expect(tester.takeException(), isNull);
            expect(original.timeZoneId, 'Asia/Seoul');
            expect(proposed.timeZoneId, 'America/New_York');
          } finally {
            await tester.pumpWidget(const SizedBox());
            await tester.pump();
            controller.dispose();
            semantics.dispose();
          }
        },
      );
    }
  }
}
