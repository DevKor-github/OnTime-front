// Authenticated low-level owner and shared-budget contracts. The ready adapter
// here owns the ingestion only; service/SQLCipher/native proof is separate.
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_time_front/core/backup/backup_crypto.dart';
import 'package:on_time_front/core/backup/backup_ingestion_store.dart';
import 'package:on_time_front/core/backup/backup_limits.dart';
import 'package:on_time_front/core/backup/backup_validated_ingestion.dart';
import 'package:on_time_front/core/time/time_zone_rules.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/entities/backup_time_review.dart';
import 'package:on_time_front/domain/entities/civil_date_time.dart';
import 'package:timezone/timezone.dart' as tz;
import '../../helpers/sodium_test_loader.dart';
import 'backup_validation_contract_test.dart' show validBackup;
import 'backup_validated_ingestion_test.dart' show recurringBackup;

class _Ready extends BackupRestoreInput {
  _Ready(this.data, this.lease);
  final BackupValidatedIngestion data;
  final BackupProcessingLease lease;
  @override
  BackupRestorePreview get preview => data.preview;
  @override
  Future<void> dispose() async {
    await data.release();
    lease.release();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const zone = 'Test/A10_Review_Owned';
  late BackupCrypto crypto;
  late BackupProcessingOwner owner;
  late DateTime now;
  late Map<String, tz.Location> locations;
  final selections = <BackupRestoreSelection>[];
  late BackupIngestionStore store;
  var readyCalls = 0;
  void Function()? duringReady;
  Future<void> Function()? cleanup;
  Map<String, dynamic> input() {
    final value = jsonDecode(jsonEncode(validBackup())) as Map<String, dynamic>;
    value['schedules'][0].addAll({
      'civilTime': '2031-01-02T09:00:00.123456',
      'timeZoneId': 'Removed/Zone',
      'occurrenceOffsetSeconds': 0,
    });
    return value;
  }

  setUp(() {
    TimeZoneRules.ensureInitialized();
    locations = Map.of(tz.timeZoneDatabase.locations);
    tz.timeZoneDatabase.locations[zone] = tz.Location(zone, [], [], [
      const tz.TimeZone(0, isDst: false, abbreviation: 'A'),
    ]);
    now = DateTime.utc(2030);
    crypto = BackupCrypto(sodiumLoader: loadSodiumForTest);
    owner = BackupProcessingOwner();
    readyCalls = 0;
    duringReady = null;
    cleanup = null;
    selections.clear();
  });
  tearDown(() async {
    for (final selected in selections.reversed) {
      await selected.dispose();
    }
    tz.timeZoneDatabase.locations
      ..clear()
      ..addAll(locations);
  });
  Future<BackupTimeReviewInput> open(Map<String, dynamic> value) async {
    final encrypted = await crypto.encrypt(
      plaintext: Uint8List.fromList(utf8.encode(jsonEncode(value))),
      password: 'review boundary password',
    );
    final lease = owner.acquire();
    final selected = await BackupAuthenticatedTimeReview.decrypt(
      ciphertext: Stream.value(encrypted),
      password: 'review boundary password',
      crypto: crypto,
      budget: BackupBudget(lease: lease),
      createStore: (budget) async =>
          store = BackupIngestionStore.memoryForTesting(
            budget,
            onRelease: () async {
              await cleanup?.call();
            },
          ),
      now: () => now,
      ready: (data) async {
        readyCalls++;
        duringReady?.call();
        return _Ready(data, lease);
      },
    );
    selections.add(selected);
    expect(selected, isA<BackupTimeReviewInput>());
    return selected as BackupTimeReviewInput;
  }

  Future<BackupTimeFieldReview> field(
    BackupTimeReviewInput review, {
    String selectedZone = 'UTC',
    String? civil,
  }) async {
    final issue = (await review.issues()).items.first;
    final summary = review.summary;
    return review.review(
      BackupTimeDraft(
        identity: summary.identity,
        revision: summary.revision,
        rulesIdentity: summary.rulesIdentity,
        issueId: issue.id,
        civil: civil == null ? issue.civil : CivilDateTime.parse(civil),
        zone: selectedZone,
      ),
    );
  }

  test(
    'loaded rule mutation retires a choice without editing candidate',
    () async {
      final review = await open(input());
      final selected = await field(review, selectedZone: zone);
      final revision = review.summary.revision;
      tz.timeZoneDatabase.locations[zone]!.zones[0] = const tz.TimeZone(
        3600000,
        isDst: false,
        abbreviation: 'B',
      );
      await expectLater(
        review.choose(BackupTimeChoice(review: selected, offsetSeconds: 0)),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      expect(review.summary.revision, revision);
      expect(readyCalls, 0);
      final refreshed = await review.revalidate();
      expect(refreshed, same(review));
      expect(
        (await field(review, selectedZone: zone)).choices.single.offsetSeconds,
        3600,
      );
    },
  );
  test(
    'rule change during ready construction cannot escape as verified',
    () async {
      final review = await open(input());
      await review.choose(
        BackupTimeChoice(
          review: await field(review, selectedZone: zone),
          offsetSeconds: 0,
        ),
      );
      duringReady = () => tz.timeZoneDatabase.locations[zone]!.zones[0] =
          const tz.TimeZone(3600000, isDst: false, abbreviation: 'B');
      final result = await review.revalidate().then<Object>((v) {
        selections.add(v);
        return v;
      }, onError: (Object e) => e);
      expect(result, isA<BackupTimeReviewStale>());
      expect(owner.active, isNull);
    },
  );
  test('gap remains a proposal until explicit valid civil selection', () async {
    final review = await open(input());
    final gap = await field(
      review,
      selectedZone: 'America/New_York',
      civil: '2031-03-09T02:30:00.123456',
    );
    expect(gap.choices, isEmpty);
    expect(gap.nextValidCivil, CivilDateTime.parse('2031-03-09T03:00:00'));
    await expectLater(
      review.choose(BackupTimeChoice(review: gap, offsetSeconds: -14400)),
      throwsA(isA<BackupTimeReviewStale>()),
    );
    expect(readyCalls, 0);
    final next = await field(
      review,
      selectedZone: 'America/New_York',
      civil: gap.nextValidCivil!.toCivilIso8601String(),
    );
    await review.choose(BackupTimeChoice(review: next, offsetSeconds: -14400));
    final ready = await review.revalidate();
    selections.add(ready);
    expect(ready, isA<BackupRestoreInput>());
  });
  test(
    'overlap requires one actual candidate and preserves microseconds',
    () async {
      final review = await open(input());
      final overlap = await field(
        review,
        selectedZone: 'America/New_York',
        civil: '2031-11-02T01:30:00.123456',
      );
      expect(overlap.choices.map((c) => c.offsetSeconds), [-14400, -18000]);
      await expectLater(
        review.choose(BackupTimeChoice(review: overlap, offsetSeconds: 0)),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      await review.choose(
        BackupTimeChoice(review: overlap, offsetSeconds: -18000),
      );
      final issue = (await review.issues()).items.single;
      expect(issue.currentLiteral, '2031-11-02T01:30:00.123456');
      expect(issue.originalLiteral, '2031-01-02T09:00:00.123456');
      expect(issue.selectedOffsetSeconds, -18000);
    },
  );
  test(
    'recurring scalar zone choice preserves association and records the time override',
    () async {
      final value = recurringBackup(year: 2031);
      value['schedules'][0]['occurrenceOffsetSeconds'] = 3600;
      final review = await open(value);
      final choice = await field(review, selectedZone: 'Asia/Seoul');
      expect(choice.conflictsByOffset[32400]!.conflicts, isEmpty);
      await review.choose(
        BackupTimeChoice(review: choice, offsetSeconds: 32400),
      );
      final result = await review.revalidate();
      selections.add(result);
      expect(result, isA<BackupRestoreInput>());
      final row = store.record('schedule', 's1')!;
      final fields = store.fields(row['node'] as int, {
        'id',
        'recurringSegmentId',
        'recurringSlotKey',
        'recurringOrdinal',
        'recurringOverrides',
        'timeZoneId',
        'occurrenceOffsetSeconds',
      });
      expect(fields['recurringSegmentId'], 'seg');
      expect(fields['recurringOrdinal'], 3);
      expect(fields['recurringOverrides'], 'time');
      expect(fields['timeZoneId'], 'Asia/Seoul');
      expect(fields['occurrenceOffsetSeconds'], 32400);
    },
  );
  test(
    'unmaterialized recurrence includes its explicit spare in its busy interval',
    () async {
      final value = recurringBackup(year: 2031);
      value['schedules'] = input()['schedules'];
      value['schedules'][0]['civilTime'] = '2031-01-01T08:30:00';
      value['profile']['spareTimeMinutes'] = 60;
      final segment = value['recurring']['segments'][0];
      final prototype =
          jsonDecode(segment['scheduleJson'] as String) as Map<String, dynamic>;
      prototype['spare'] = 60;
      segment['scheduleJson'] = jsonEncode(prototype);
      final rule =
          jsonDecode(segment['ruleJson'] as String) as Map<String, dynamic>;
      rule['count'] = 1;
      segment['ruleJson'] = jsonEncode(rule);
      final review = await open(value);
      final choice = await field(review);
      expect(choice.conflictsByOffset[0]!.conflicts, hasLength(1));
      await expectLater(
        review.choose(BackupTimeChoice(review: choice, offsetSeconds: 0)),
        throwsA(isA<BackupTimeChoiceConflict>()),
      );
      expect(readyCalls, 0);
    },
  );
  test(
    'unresolved materialized override occupies its base slot without phantom conflict',
    () async {
      final value = recurringBackup(year: 2031);
      final override = value['schedules'][0];
      override.addAll({
        'civilTime': '2031-01-03T13:00:00',
        'timeZoneId': 'Removed/Zone',
        'recurringOverrides': 'time',
      });
      final target = input()['schedules'][0];
      target.addAll({'id': 'target', 'civilTime': '2031-01-03T09:00:00'});
      value['schedules'] = [target, override];
      final review = await open(value);
      final choice = await field(review);
      final proof = choice.conflictsByOffset[0]!;
      expect(proof.conflicts, isEmpty);
      expect(proof.possibleOverlaps.map((item) => item.id), ['s1']);
      await review.choose(
        BackupTimeChoice(
          review: choice,
          offsetSeconds: 0,
          acknowledgedPossibleIds: {'s1'},
        ),
      );
      expect(await review.revalidate(), same(review));
      expect(review.summary.issueCount, 1);
      expect(readyCalls, 0);
    },
  );
  test(
    'past first overlap candidate does not suppress future second choice',
    () async {
      now = DateTime.utc(2030, 11, 3, 5, 35);
      final review = await open(input());
      final overlap = await field(
        review,
        selectedZone: 'America/New_York',
        civil: '2030-11-03T01:30:00',
      );
      expect(overlap.choices.map((c) => c.offsetSeconds), [-18000]);
      expect(overlap.conflictsByOffset.keys, [-18000]);
      await expectLater(
        review.choose(BackupTimeChoice(review: overlap, offsetSeconds: -14400)),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      await review.choose(
        BackupTimeChoice(review: overlap, offsetSeconds: -18000),
      );
      final ready = await review.revalidate();
      selections.add(ready);
      expect(ready, isA<BackupRestoreInput>());
    },
  );
  test(
    'two instant fields per parent cross a page without duplicate or omitted issue',
    () async {
      final value = input();
      value['schedules'] = [];
      value['templates'] = [
        for (var i = 0; i < 12; i++)
          {
            'id': 'template$i',
            'name': 'Template$i',
            'createdAt': '2020-01-01T10:00:00',
            'updatedAt': '2020-01-02T10:00:00',
            'preparation': [
              {'id': 'step$i', 'name': 'Step', 'minutes': 1, 'nextId': null},
            ],
          },
      ];
      final review = await open(value);
      expect(review.summary.issueCount, 24);
      final first = await review.issues();
      final second = await review.issues(cursor: first.nextCursor);
      expect(first.items, hasLength(20));
      expect(second.items, hasLength(4));
      expect(second.nextCursor, isNull);
      final all = [...first.items, ...second.items];
      expect(all.map((i) => i.id).toSet(), hasLength(24));
      expect(all.map((i) => i.fieldPath).toSet(), hasLength(24));
      expect(
        all.every(
          (i) => i.reason == BackupTimeIssueReason.missingInstantOffset,
        ),
        isTrue,
      );
      await review.choose(
        BackupTimeChoice(
          review: await field(review, selectedZone: 'Asia/Seoul'),
          offsetSeconds: 32400,
        ),
      );
      expect((await review.revalidate()), same(review));
      expect(review.summary.issueCount, 23);
      expect(readyCalls, 0);
    },
  );
  test(
    'invented field review cannot authorize arbitrary JSON changes',
    () async {
      final review = await open(input());
      final actual = await field(review);
      final forged = BackupTimeFieldReview(
        draft: actual.draft,
        issue: actual.issue,
        choices: actual.choices,
      );
      await expectLater(
        review.choose(BackupTimeChoice(review: forged, offsetSeconds: 0)),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      expect(readyCalls, 0);
      expect(
        (await review.issues()).items.single.currentLiteral,
        actual.issue.currentLiteral,
      );
    },
  );
  for (final phase in ['before choose', 'before revalidation']) {
    test('preparation boundary $phase retires old confirmation', () async {
      final value = input();
      value['schedules'][0].addAll({
        'civilTime': '2030-01-01T01:00:00',
        'moveTimeMinutes': 30,
      });
      final review = await open(value);
      final selected = await field(review);
      if (phase == 'before revalidation') {
        await review.choose(
          BackupTimeChoice(review: selected, offsetSeconds: 0),
        );
      }
      now = DateTime.utc(2030, 1, 1, 0, 30);
      await expectLater(
        phase == 'before choose'
            ? review.choose(
                BackupTimeChoice(review: selected, offsetSeconds: 0),
              )
            : review.revalidate(),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      expect(readyCalls, 0);
    });
  }
  test('target passing after review cannot become a historical edit', () async {
    final review = await open(input());
    final selected = await field(review);
    now = DateTime.utc(2032);
    await expectLater(
      review.choose(BackupTimeChoice(review: selected, offsetSeconds: 0)),
      throwsA(isA<BackupTimeReviewStale>()),
    );
    expect(readyCalls, 0);
  });
  test('failed terminal cleanup retries under the same lease', () async {
    var attempts = 0;
    cleanup = () async {
      if (++attempts == 1) throw StateError('owned cleanup failure');
    };
    final review = await open(input());
    final lease = owner.active;
    await expectLater(review.dispose(), throwsStateError);
    expect(owner.active, same(lease));
    expect(lease!.phase, BackupProcessingPhase.cleanupPending);
    await review.dispose();
    expect(attempts, 2);
    expect(owner.active, isNull);
  });
  test(
    'external cancellation after ready allocation retires the late owner',
    () async {
      var released = 0;
      cleanup = () async {
        released++;
      };
      final review = await open(input());
      await review.choose(
        BackupTimeChoice(review: await field(review), offsetSeconds: 0),
      );
      duringReady = owner.requestCancellation;
      await expectLater(
        review.revalidate(),
        throwsA(
          isA<BackupProcessingFailure>().having(
            (e) => e.kind,
            'cancelled',
            BackupFailureKind.userCancelled,
          ),
        ),
      );
      expect(released, 1);
      expect(owner.active, isNull);
    },
  );
  test(
    'same instant known conflict blocks scalar edit without changing original',
    () async {
      final value = input();
      final other =
          jsonDecode(jsonEncode(value['schedules'][0])) as Map<String, dynamic>;
      other.addAll({
        'id': 's2',
        'name': 'Other',
        'timeZoneId': 'UTC',
        'occurrenceOffsetSeconds': 0,
      });
      value['schedules'].add(other);
      final review = await open(value);
      final selected = await field(review);
      expect(
        selected.conflictsByOffset[0]!.conflicts.single.other.schedule.id,
        's2',
      );
      await expectLater(
        review.choose(BackupTimeChoice(review: selected, offsetSeconds: 0)),
        throwsA(isA<BackupTimeChoiceConflict>()),
      );
      expect((await review.issues()).items.single.zone, 'Removed/Zone');
      expect(readyCalls, 0);
    },
  );
  test(
    'possible overlap requires exact acknowledgement and cannot grant final ready',
    () async {
      final value = input();
      final other =
          jsonDecode(jsonEncode(value['schedules'][0])) as Map<String, dynamic>;
      other.addAll({'id': 's2', 'name': 'Other unknown'});
      value['schedules'].add(other);
      final review = await open(value);
      final selected = await field(review);
      expect(selected.conflictsByOffset[0]!.conflicts, isEmpty);
      expect(selected.conflictsByOffset[0]!.possibleOverlaps.single.id, 's2');
      await expectLater(
        review.choose(BackupTimeChoice(review: selected, offsetSeconds: 0)),
        throwsA(isA<BackupTimeChoiceConflict>()),
      );
      await expectLater(
        review.choose(
          BackupTimeChoice(
            review: selected,
            offsetSeconds: 0,
            acknowledgedPossibleIds: {'s2', 'invented'},
          ),
        ),
        throwsA(isA<BackupTimeChoiceConflict>()),
      );
      await review.choose(
        BackupTimeChoice(
          review: selected,
          offsetSeconds: 0,
          acknowledgedPossibleIds: {'s2'},
        ),
      );
      expect(await review.revalidate(), same(review));
      expect(review.summary.issueCount, 1);
      expect(readyCalls, 0);
    },
  );
  test(
    'uncertain historical record does not block an independent future correction',
    () async {
      final value = input();
      final other =
          jsonDecode(jsonEncode(value['schedules'][0])) as Map<String, dynamic>;
      other.addAll({
        'id': 's2',
        'name': 'History',
        'civilTime': '2020-01-01T09:00:00',
        'occurrenceOffsetSeconds': null,
      });
      value['schedules'].add(other);
      final review = await open(value);
      final selected = await field(review);
      expect(selected.conflictsByOffset[0]!.possibleOverlaps, isEmpty);
      await review.choose(BackupTimeChoice(review: selected, offsetSeconds: 0));
      final ready = await review.revalidate();
      selections.add(ready);
      expect(ready, isA<BackupRestoreInput>());
    },
  );
  test(
    'effective default preparation bounds final selection instead of treating missing own steps as zero',
    () async {
      final value = input();
      value['schedules'][0]['civilTime'] = '2030-01-01T01:00:00';
      value['defaultPreparation'][0]['minutes'] = 30;
      final review = await open(value);
      final selected = await field(review);
      now = DateTime.utc(2030, 1, 1, 0, 30);
      await expectLater(
        review.choose(BackupTimeChoice(review: selected, offsetSeconds: 0)),
        throwsA(isA<BackupTimeReviewStale>()),
      );
      expect(readyCalls, 0);
    },
  );
  test('all review passes share the original finite work budget', () async {
    final review = await open(input());
    final before = store.budget.work;
    await review.revalidate();
    expect(store.budget.work, greaterThan(before));
    store.budget.visit(BackupLimits.work - store.budget.work);
    await expectLater(
      review.revalidate(),
      throwsA(
        isA<BackupProcessingFailure>().having(
          (e) => e.kind,
          'work limit',
          BackupFailureKind.resourceLimit,
        ),
      ),
    );
    expect(readyCalls, 0);
    expect(review.summary.independentStructureChecked, isFalse);
    await expectLater(review.issues(), throwsA(isA<BackupTimeReviewStale>()));
  });
}
