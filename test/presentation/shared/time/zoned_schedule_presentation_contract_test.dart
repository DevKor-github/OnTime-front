// Independent U02 display contracts. These use supplied commitment facts and
// actual bundled device-zone conversion, never the host's current offset.
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:on_time_front/core/time/schedule_time_resolution.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:on_time_front/domain/entities/place_entity.dart';
import 'package:on_time_front/domain/entities/schedule_entity.dart';
import 'package:on_time_front/l10n/app_localizations_en.dart';
import 'package:on_time_front/l10n/app_localizations_ko.dart';
import 'package:on_time_front/presentation/shared/time/device_time_zone_state.dart';
import 'package:on_time_front/presentation/shared/time/schedule_zoned_time_text.dart';
import 'package:on_time_front/presentation/shared/time/zoned_schedule_presentation.dart';

ZonedSchedulePresentation project({
  required String civil,
  required String zone,
  DateTime? instant,
  String device = 'UTC',
  ScheduleTimeResolution? resolution,
  DeviceTimeZoneState? deviceState,
}) => ZonedSchedulePresentation.from(
  civil: CivilDateTime.parse(civil),
  scheduleTimeZoneId: zone,
  resolution:
      resolution ??
      ScheduleTimeResolution(
        status: ScheduleTimeResolutionStatus.resolved,
        instantUtc: instant,
      ),
  deviceTimeZone: deviceState ?? DeviceTimeZoneState.known(device),
);

void main() {
  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ko');
  });

  test('Seoul commitment still names Tokyo when both offsets are +09:00', () {
    final value = project(
      civil: '2031-01-02T09:00:00',
      zone: 'Asia/Seoul',
      instant: DateTime.utc(2031, 1, 2),
      device: 'Asia/Tokyo',
    );
    expect(value.showDeviceEquivalent, isTrue);
    expect(value.hasDifferentDeviceDate, isFalse);
    expect(value.original.timeZoneId, 'Asia/Seoul');
    expect(value.device!.timeZoneId, 'Asia/Tokyo');
    expect(value.original.civil, value.device!.civil);
    expect(value.original.offsetSeconds, 32400);
    expect(value.device!.offsetSeconds, 32400);
    final words = ScheduleZonedTimeText.format(
      presentation: value,
      l10n: AppLocalizationsEn(),
      use24HourFormat: true,
    );
    expect(words.original, contains('Asia/Seoul'));
    expect(words.device, contains('Asia/Tokyo'));
    expect(words.semanticsLabel, contains('Asia/Tokyo'));
  });

  test('same named device zone has no redundant secondary line', () {
    final value = project(
      civil: '2031-01-02T09:00:00',
      zone: 'Asia/Seoul',
      instant: DateTime.utc(2031, 1, 2),
      device: 'Asia/Seoul',
    );
    expect(value.showDeviceEquivalent, isFalse);
    expect(
      ScheduleZonedTimeText.format(
        presentation: value,
        l10n: AppLocalizationsKo(),
        use24HourFormat: true,
      ).device,
      isNull,
    );
  });

  test('date-line display keeps both dates and commitment microseconds', () {
    final value = project(
      civil: '2031-01-02T09:00:01.123456',
      zone: 'Asia/Seoul',
      instant: DateTime.utc(2031, 1, 2, 0, 0, 1, 123, 456),
      device: 'America/New_York',
    );
    expect(
      value.original.civil.toCivilIso8601String(),
      '2031-01-02T09:00:01.123456',
    );
    expect(
      value.device!.civil.toCivilIso8601String(),
      '2031-01-01T19:00:01.123456',
    );
    expect(value.hasDifferentDeviceDate, isTrue);
    final words = ScheduleZonedTimeText.format(
      presentation: value,
      l10n: AppLocalizationsEn(),
      use24HourFormat: true,
    );
    expect(words.original, contains('1/2/2031'));
    expect(words.device, contains('1/1/2031'));
    expect(words.original, contains('09:00:01.123456'));
    expect(words.device, contains('19:00:01.123456'));
  });

  test('device offset is for the occurrence, including each New York fold', () {
    final first = project(
      civil: '2026-11-01T05:30:00',
      zone: 'UTC',
      instant: DateTime.utc(2026, 11, 1, 5, 30),
      device: 'America/New_York',
    );
    final second = project(
      civil: '2026-11-01T06:30:00',
      zone: 'UTC',
      instant: DateTime.utc(2026, 11, 1, 6, 30),
      device: 'America/New_York',
    );
    expect(first.device!.civil, second.device!.civil);
    expect(
      first.device!.civil.toCivilIso8601String(),
      '2026-11-01T01:30:00.000',
    );
    expect(first.device!.offsetSeconds, -14400);
    expect(second.device!.offsetSeconds, -18000);
    expect(first.instantUtc, isNot(second.instantUtc));
    expect(
      ScheduleZonedTimeText.format(
        presentation: first,
        l10n: AppLocalizationsEn(),
        use24HourFormat: true,
      ).device,
      contains('UTC-04:00'),
    );
    expect(
      ScheduleZonedTimeText.format(
        presentation: second,
        l10n: AppLocalizationsEn(),
        use24HourFormat: true,
      ).device,
      contains('UTC-05:00'),
    );
  });

  for (final sample in [
    (
      zone: 'Asia/Kathmandu',
      month: 1,
      offset: 20700,
      civil: '2031-01-02T05:45:00.000',
    ),
    (
      zone: 'Australia/Lord_Howe',
      month: 1,
      offset: 39600,
      civil: '2031-01-02T11:00:00.000',
    ),
    (
      zone: 'Australia/Lord_Howe',
      month: 7,
      offset: 37800,
      civil: '2031-07-02T10:30:00.000',
    ),
  ]) {
    test(
      'device conversion retains fractional-hour rules for ${sample.zone} month ${sample.month}',
      () {
        final value = project(
          civil: CivilDateTime.fromFields(
            DateTime.utc(2031, sample.month, 2),
          ).toCivilIso8601String(),
          zone: 'UTC',
          instant: DateTime.utc(2031, sample.month, 2),
          device: sample.zone,
        );
        expect(value.device!.offsetSeconds, sample.offset);
        expect(value.device!.civil.toCivilIso8601String(), sample.civil);
      },
    );
  }

  test(
    'historical explicit second offset is not reinterpreted by modern rules',
    () {
      final civil = CivilDateTime.parse('1900-01-02T12:00:03.000007');
      final instant = civil.atOffset(561);
      final value = project(
        civil: civil.toCivilIso8601String(),
        zone: 'Europe/Paris',
        resolution: ScheduleTimeResolution(
          status: ScheduleTimeResolutionStatus.resolved,
          instantUtc: instant,
          isHistorical: true,
        ),
      );
      expect(value.original.offsetSeconds, 561);
      expect(value.instantUtc, instant);
      final words = ScheduleZonedTimeText.format(
        presentation: value,
        l10n: AppLocalizationsEn(),
        use24HourFormat: true,
      );
      expect(words.original, contains('UTC+00:09:21'));
      expect(words.original, contains('12:00:03.000007'));
      expect(words.device, contains('11:50:42.000007'));
    },
  );

  for (final status in [
    ScheduleTimeResolutionStatus.historicalUncertain,
    ScheduleTimeResolutionStatus.unknownZone,
    ScheduleTimeResolutionStatus.nonexistent,
    ScheduleTimeResolutionStatus.ambiguous,
    ScheduleTimeResolutionStatus.changed,
    ScheduleTimeResolutionStatus.invalid,
  ]) {
    test(
      '$status does not display a proposed instant as an accepted commitment',
      () {
        final resolution = ScheduleTimeResolution(
          status: status,
          proposedInstantUtc: DateTime.utc(2031, 1, 2),
          isHistorical:
              status == ScheduleTimeResolutionStatus.historicalUncertain,
        );
        final value = project(
          civil: '2031-01-02T09:00:00',
          zone: 'Asia/Seoul',
          resolution: resolution,
        );
        expect(value.instantUtc, isNull);
        expect(value.device, isNull);
        expect(value.original.offsetSeconds, isNull);
        expect(
          value.original.civil.toCivilIso8601String(),
          '2031-01-02T09:00:00.000',
        );
        final words = ScheduleZonedTimeText.format(
          presentation: value,
          l10n: AppLocalizationsEn(),
          use24HourFormat: true,
        );
        expect(words.statusMessage, isNotEmpty);
        expect(words.instant, isNull);
        expect(words.device, isNull);
      },
    );
  }

  test(
    'unique future null offset uses real resolver without persisting a guess',
    () {
      final row = ScheduleEntity(
        id: 'original',
        scheduleName: 'Synthetic appointment',
        place: const PlaceEntity(id: 'place', placeName: 'Synthetic'),
        scheduleTime: DateTime.utc(2031, 1, 2, 9),
        timeZoneId: 'Asia/Seoul',
        occurrenceOffsetSeconds: null,
        moveTime: Duration.zero,
        isChanged: false,
        isStarted: false,
        scheduleSpareTime: null,
        scheduleNote: '',
      );
      final value = project(
        civil: '2031-01-02T09:00:00',
        zone: row.timeZoneId,
        resolution: ScheduleTimeResolver.resolve(
          row,
          nowUtc: DateTime.utc(2030),
        ),
      );
      expect(value.instantUtc, DateTime.utc(2031, 1, 2));
      expect(value.original.offsetSeconds, 32400);
      expect(row.occurrenceOffsetSeconds, isNull);
    },
  );

  for (final state in [
    const DeviceTimeZoneState.loading(),
    const DeviceTimeZoneState.unavailable(),
    const DeviceTimeZoneState.known('Removed/Zone'),
  ]) {
    test(
      'device ${state.status}/${state.identifier} never invents UTC equivalent',
      () {
        final value = project(
          civil: '2031-01-02T09:00:00',
          zone: 'Asia/Seoul',
          instant: DateTime.utc(2031, 1, 2),
          deviceState: state,
        );
        expect(value.instantUtc, DateTime.utc(2031, 1, 2));
        expect(value.device, isNull);
        expect(value.original.timeZoneId, 'Asia/Seoul');
        expect(
          ScheduleZonedTimeText.format(
            presentation: value,
            l10n: AppLocalizationsKo(),
            use24HourFormat: true,
          ).statusMessage,
          isNotEmpty,
        );
      },
    );
  }

  for (final sample in [
    (
      civil: '0001-01-01T00:00:00',
      instant: DateTime.utc(1),
      device: 'America/New_York',
    ),
    (
      civil: '9999-12-31T23:59:59',
      instant: DateTime.utc(9999, 12, 31, 23, 59, 59),
      device: 'Asia/Seoul',
    ),
  ]) {
    test('device year overflow preserves valid original ${sample.civil}', () {
      final value = project(
        civil: sample.civil,
        zone: 'UTC',
        instant: sample.instant,
        device: sample.device,
      );
      expect(value.original.civil, CivilDateTime.parse(sample.civil));
      expect(value.instantUtc, sample.instant);
      expect(value.device, isNull);
      expect(value.deviceTimeZone.identifier, sample.device);
      expect(
        value.deviceConversionStatus,
        DeviceTimeConversionStatus.outOfRange,
      );
      expect(
        ScheduleZonedTimeText.format(
          presentation: value,
          l10n: AppLocalizationsEn(),
          use24HourFormat: true,
        ).statusMessage,
        isNotEmpty,
      );
    });
  }

  for (final locale in ['en', 'ko']) {
    test(
      '$locale follows explicit 12/24-hour preference without losing precision',
      () {
        final civil = CivilDateTime.parse('2031-01-02T13:04:05.000007');
        final twelve = ScheduleZonedTimeText.formatCivil(
          civil,
          locale: locale,
          use24HourFormat: false,
        );
        final twentyFour = ScheduleZonedTimeText.formatCivil(
          civil,
          locale: locale,
          use24HourFormat: true,
        );
        expect(
          twentyFour,
          contains(locale == 'ko' ? '13시 4분 5.000007초' : '13:04:05.000007'),
        );
        expect(twelve, contains('1:04:05.000007'));
        expect(twelve, contains(locale == 'en' ? 'PM' : '오후'));
        expect(twentyFour, isNot(contains(locale == 'en' ? 'PM' : '오후')));
      },
    );
  }
}
