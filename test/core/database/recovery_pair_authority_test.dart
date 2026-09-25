import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:on_time_front/core/database/recovery/pair_files.dart';
import 'package:on_time_front/core/database/recovery/pair_key_store.dart';
import 'package:on_time_front/core/database/recovery/store_pair.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late PairFiles files;
  final target = StorePair.candidate('00000000-0000-4000-8000-000000000001');
  final second = StorePair.candidate('00000000-0000-4000-8000-000000000002');
  const legacy = StorePair.legacy();
  const process = '10000000-0000-4000-8000-000000000001';
  PairRecord record(PairStage stage) => PairRecord(
    target: target,
    original: legacy,
    originProcess: process,
    stage: stage,
    originalEvidence: '0' * 64,
    runtimeIdentity: '1' * 32,
  );
  setUp(() async {
    FlutterSecureStorage.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('d02-authority-');
    files = PairFiles(root, PairKeyStore(), protect: (_) async {});
  });
  tearDown(() => root.delete(recursive: true));
  test('no pair evidence delegates to existing D01 classification', () async {
    expect(await files.selected(), legacy);
  });
  for (final bad in [
    '../../victim',
    '/tmp/victim',
    'legacy.sqlite',
    '123',
    '00000000-0000-0000-0000-000000000001',
  ]) {
    test(
      'rejects non-owned descriptor $bad',
      () => expect(
        () => StorePair.candidate(bad),
        throwsA(isA<PairAuthorityUnavailable>()),
      ),
    );
  }
  for (final name in ['ontime_recovery_pairs', 'ontime_pair_state']) {
    test('parent symlink $name cannot read or delete external bytes', () async {
      final outside = await Directory.systemTemp.createTemp('d02-outside-');
      addTearDown(() => outside.delete(recursive: true));
      final sentinel = File('${outside.path}/${target.id}.sqlite');
      await sentinel.writeAsString('external-original');
      await File(
        '${outside.path}/active-v1.json',
      ).writeAsString(files.manifestBytes(target));
      await Link('${root.path}/$name').create(outside.path);
      await expectLater(
        files.removeFamily(target),
        throwsA(isA<PairAuthorityUnavailable>()),
      );
      await expectLater(
        files.readManifest(),
        throwsA(isA<PairAuthorityUnavailable>()),
      );
      await expectLater(
        files.selected(),
        throwsA(isA<PairAuthorityUnavailable>()),
      );
      expect(await sentinel.readAsString(), 'external-original');
      expect(await File('${outside.path}/active-v1.json').exists(), true);
    });
  }
  test(
    'reservation ownership precedes keys and never selects candidate',
    () async {
      await files.writeRecord(record(PairStage.reserved));
      expect(await files.keys.read(target), null);
      expect(await files.selected(), legacy);
      final key = await files.keys.create(target);
      expect(key.length, 32);
      await expectLater(
        files.keys.create(target),
        throwsA(isA<PairAuthorityUnavailable>()),
      );
      expect(await files.selected(), legacy);
    },
  );
  test('history without manifest is not a fresh or legacy fallback', () async {
    await files.keys.markHistory();
    await expectLater(
      files.selected(),
      throwsA(isA<PairAuthorityUnavailable>()),
    );
  });
  test('target manifest requires confirmed lineage', () async {
    await files.writeRecord(record(PairStage.validated));
    await files.publish(target);
    await expectLater(
      files.selected(),
      throwsA(isA<PairAuthorityUnavailable>()),
    );
    await files.writeRecord(record(PairStage.confirmed));
    expect(await files.selected(), target);
  });
  test('journal cannot silently select a different active pair', () async {
    await files.writeRecord(record(PairStage.activated));
    await files.publish(second);
    await expectLater(
      files.selected(),
      throwsA(isA<PairAuthorityUnavailable>()),
    );
  });
  for (final raw in [
    '{',
    '{"version":2,"pair":"${target.id}"}',
    '{"version":1,"pair":"../../victim"}',
  ]) {
    test('invalid manifest remains untouched: $raw', () async {
      await files.prepareDirectories();
      await files.manifest.writeAsString(raw);
      await expectLater(
        files.publish(target),
        throwsA(isA<PairAuthorityUnavailable>()),
      );
      expect(await files.manifest.readAsString(), raw);
    });
  }
  test('ambiguous pending manifest cannot open the old selection', () async {
    await files.writeRecord(record(PairStage.activated));
    await files.publish(target);
    await File(
      '${files.manifest.path}.pending',
    ).writeAsString(files.manifestBytes(second));
    await expectLater(
      files.selected(),
      throwsA(isA<PairAuthorityUnavailable>()),
    );
    await expectLater(
      files.publish(target),
      throwsA(isA<PairAuthorityUnavailable>()),
    );
    expect(await files.readManifest(), target);
  });
  test('same-size encrypted bytes change invalidates currentness', () async {
    final main = files.database(legacy);
    await main.writeAsString('original');
    final priorTime = await main.lastModified();
    final before = await files.evidence(legacy);
    await main.writeAsString('replaced');
    await main.setLastModified(priorTime);
    expect(await files.evidence(legacy), isNot(before));
  });
  test('record interrupted after rename remains authoritative', () async {
    var once = true;
    final fault = PairFiles(
      root,
      files.keys,
      protect: (_) async {},
      checkpoint: (phase) async {
        if (phase == 'record.reserved.renamed' && once) {
          once = false;
          throw StateError('lost response');
        }
      },
    );
    await expectLater(
      fault.writeRecord(record(PairStage.reserved)),
      throwsStateError,
    );
    expect((await files.readRecord())!.stage, PairStage.reserved);
    expect(await files.keys.read(target), null);
  });
  for (final afterDelete in [false, true]) {
    test(
      'reset retains slot receipt across history delete failure afterDelete=$afterDelete',
      () async {
        final storage = _HistoryDeleteFault()..afterDelete = afterDelete;
        final reset = PairFiles(
          root,
          PairKeyStore(storage: storage),
          protect: (_) async {},
        );
        await reset.writeRecord(record(PairStage.activated));
        await reset.keys.create(target);
        await reset.keys.markHistory();
        await reset.publish(target);
        await reset.database(target).writeAsString('owned');
        await reset.resetFiles();
        storage.armed = true;
        await expectLater(reset.resetKeysAndMetadata(), throwsStateError);
        expect(await reset.keys.raw(target), null);
        expect(await reset.resetCompletion.exists(), true);
        await expectLater(
          reset.selected(),
          throwsA(isA<PairAuthorityUnavailable>()),
        );
        storage.armed = false;
        await reset.resetKeysAndMetadata();
        expect(await reset.keys.hasHistory(), false);
        expect(await reset.resetCompletion.exists(), false);
        expect(await reset.database(target).exists(), false);
        expect(await reset.selected(), legacy);
      },
    );
  }
  for (final step in [
    'active-v1.json.pending',
    'active-v1.json',
    'activation-v1.json.pending',
    'activation-v1.json',
  ]) {
    test(
      'reset resumes after metadata removal $step without losing slot ownership',
      () async {
        var armed = true;
        final reset = PairFiles(
          root,
          files.keys,
          protect: (_) async {},
          checkpoint: (phase) async {
            if (armed && phase == 'resetMetadata.$step.removed') {
              throw StateError('interrupted');
            }
          },
        );
        await reset.writeRecord(record(PairStage.activated));
        await reset.keys.create(target);
        await reset.keys.markHistory();
        await reset.publish(target);
        await reset.database(target).writeAsString('owned');
        await reset.resetFiles();
        await expectLater(reset.resetKeysAndMetadata(), throwsStateError);
        await expectLater(
          reset.selected(),
          throwsA(isA<PairAuthorityUnavailable>()),
        );
        armed = false;
        await reset.resetKeysAndMetadata();
        expect(await reset.keys.hasHistory(), false);
        expect(await reset.keys.raw(target), null);
        expect(await reset.selected(), legacy);
      },
    );
  }
  for (final slots in [
    [],
    [target.id],
    ['legacy', 'legacy'],
    ['legacy', target.id, second.id, '00000000-0000-4000-8000-000000000003'],
  ]) {
    test('malformed reset inventory $slots cannot erase ownership', () async {
      await files.writeRecord(record(PairStage.activated));
      await files.publish(target);
      await files.keys.create(target);
      await files.keys.markHistory();
      final raw = jsonEncode({'version': 1, 'slots': slots});
      await files.resetCompletion.writeAsString(raw);
      await expectLater(
        files.resetKeysAndMetadata(),
        throwsA(isA<PairAuthorityUnavailable>()),
      );
      expect(await files.keys.raw(target), isNotNull);
      expect(await files.keys.hasHistory(), true);
      expect(await files.resetCompletion.readAsString(), raw);
    });
  }
  test('future pending record is not overwritten by an older writer', () async {
    await files.writeRecord(record(PairStage.reserved));
    final raw = record(PairStage.confirmed).encode()..['version'] = 2;
    await File('${files.record.path}.pending').writeAsString(jsonEncode(raw));
    await expectLater(
      files.writeRecord(record(PairStage.validated)),
      throwsA(isA<PairAuthorityUnavailable>()),
    );
    expect(
      jsonDecode(
        await File('${files.record.path}.pending').readAsString(),
      )['version'],
      2,
    );
  });
}

class _HistoryDeleteFault extends FlutterSecureStorage {
  bool armed = false;
  bool afterDelete = false;
  @override
  Future<void> delete({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (armed && key == PairKeyStore.historyKey && !afterDelete) {
      throw StateError('delete unavailable');
    }
    await super.delete(
      key: key,
      iOptions: iOptions,
      aOptions: aOptions,
      lOptions: lOptions,
      webOptions: webOptions,
      mOptions: mOptions,
      wOptions: wOptions,
    );
    if (armed && key == PairKeyStore.historyKey && afterDelete) {
      throw StateError('response lost');
    }
  }
}
