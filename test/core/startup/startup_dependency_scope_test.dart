import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:on_time_front/core/startup/startup_dependency_scope.dart';

class _Resource {
  _Resource(this.label, this.log, {this.failure = false, this.pending}) {
    StartupDependencyScope.own(this, close);
  }
  final String label;
  final List<String> log;
  bool failure;
  Completer<void>? pending;
  bool closed = false;
  Future<void> close() async {
    log.add(label);
    await pending?.future;
    if (failure) throw StateError('private injected cleanup failure');
    closed = true;
  }

  Future<void> dispose() => StartupDependencyScope.release(this, close);
}

void main() {
  test(
    'middle disposal fails but every LIFO owner runs; only failed owner retries',
    () async {
      final getIt = GetIt.asNewInstance();
      final owner = StartupDependencyScope(getIt);
      final log = <String>[];
      late _Resource middle;
      owner.configure(() {
        for (final label in ['first', 'middle', 'last']) {
          final r = _Resource(label, log, failure: label == 'middle');
          if (label == 'middle') middle = r;
          getIt.registerSingleton<_Resource>(
            r,
            instanceName: label,
            dispose: (r) => r.dispose(),
          );
        }
      });
      await expectLater(
        owner.cleanup(),
        throwsA(isA<StartupCleanupIncomplete>()),
      );
      expect(log, ['last', 'middle', 'first']);
      expect(getIt.hasScope(owner.name), false);
      expect(owner.cleanupComplete, false);
      middle.failure = false;
      await owner.cleanup();
      expect(log, ['last', 'middle', 'first', 'middle']);
      expect(owner.cleanupComplete, true);
    },
  );

  test(
    'lazy resolution outside registration Zone still belongs to live GetIt scope',
    () async {
      final owner = StartupDependencyScope(GetIt.I);
      final log = <String>[];
      owner.configure(() {
        GetIt.I.registerLazySingleton<_Resource>(
          () => _Resource('lazy', log),
          dispose: (r) => r.dispose(),
        );
      });
      final resource = GetIt.I<_Resource>();
      resource.failure = true;
      await expectLater(
        owner.cleanup(),
        throwsA(isA<StartupCleanupIncomplete>()),
      );
      expect(log, ['lazy']);
      resource.failure = false;
      await owner.cleanup();
      expect(log, ['lazy', 'lazy']);
    },
  );

  test('constructor resource is cleaned even when never registered', () async {
    final getIt = GetIt.asNewInstance();
    final owner = StartupDependencyScope(getIt);
    final log = <String>[];
    expect(
      () => owner.configure<void>(() {
        _Resource('unregistered', log);
        throw StateError('registration failed');
      }),
      throwsStateError,
    );
    await owner.cleanup();
    expect(log, ['unregistered']);
    expect(owner.cleanupComplete, true);
  });

  test('in-flight disposal is observed once across repeated cleanup', () async {
    final owner = StartupDependencyScope(GetIt.asNewInstance());
    final log = <String>[];
    final pending = Completer<void>();
    owner.track(() => _Resource('pending', log, pending: pending));
    final a = owner.cleanup();
    final b = owner.cleanup();
    expect(identical(a, b), true);
    await Future<void>.delayed(Duration.zero);
    expect(log, ['pending']);
    expect(owner.cleanupComplete, false);
    pending.complete();
    await a;
    expect(owner.cleanupComplete, true);
  });
}
