import 'dart:async';
import 'package:get_it/get_it.dart';

/// One attempted product graph, including resources whose constructor fails
/// before GetIt can register them. Not an owner of shared native operations.
/// Product constructors use the single GetIt.I container. The Zone also supports
/// explicit registration/creation within this attempt; arbitrary other containers
/// must use track instead of relying on the product's late-resolution fallback.
final class StartupDependencyScope {
  StartupDependencyScope(this.container);
  final GetIt container;
  static final _zoneKey = Object();
  static final _owners = Expando<StartupDependencyScope>();
  static int _next = 0;
  final String name = 'startup-${_next++}';
  final List<_Cleanup> _resources = [];
  bool _opened = false;
  bool _popped = false;
  Future<void>? _cleanupFlight;

  static void own(Object resource, FutureOr<void> Function() dispose) {
    final scoped = GetIt.I.isRegistered<StartupDependencyScope>()
        ? GetIt.I<StartupDependencyScope>()
        : null;
    final owner =
        Zone.current[_zoneKey] as StartupDependencyScope? ??
        (scoped != null && scoped.container.currentScopeName == scoped.name
            ? scoped
            : null);
    if (owner == null) return;
    _owners[resource] = owner;
    owner._resources.add(_Cleanup(resource, dispose));
  }

  /// GetIt must continue LIFO cleanup even when one resource fails. The owner
  /// retains that resource and its real Future, independently of registration.
  static Future<void> release(
    Object resource,
    FutureOr<void> Function() dispose,
  ) async {
    final owner = _owners[resource];
    if (owner == null) {
      await dispose();
      return;
    }
    await owner._resources
        .firstWhere((entry) => identical(entry.resource, resource))
        .run();
  }

  T track<T>(T Function() action) =>
      runZoned(action, zoneValues: {_zoneKey: this});

  static Future<void> releaseChecked(
    Object resource,
    FutureOr<void> Function() dispose,
  ) async {
    await release(resource, dispose);
    final owner = _owners[resource];
    if (owner != null &&
        !owner._resources
            .firstWhere((entry) => identical(entry.resource, resource))
            .done) {
      throw const StartupCleanupIncomplete();
    }
  }

  T configure<T>(T Function() register) {
    if (_opened) throw StateError('Startup scope already opened');
    // No init callback: GetIt 9.2.1's synchronous init failure cannot await
    // disposer Futures. Registration and owned rollback are separate phases.
    container.pushNewScope(scopeName: name);
    _opened = true;
    container.registerSingleton<StartupDependencyScope>(this);
    return track(register);
  }

  bool get cleanupComplete =>
      (!_opened || _popped) && _resources.every((entry) => entry.done);

  Future<void> cleanup() =>
      _cleanupFlight ??= _cleanup().whenComplete(() => _cleanupFlight = null);

  Future<void> _cleanup() async {
    final attemptedBefore = _resources
        .where((entry) => entry.attempted)
        .toSet();
    if (_opened && !_popped) {
      if (container.currentScopeName != name) {
        throw const StartupCleanupIncomplete();
      }
      try {
        await container.popScope();
      } catch (_) {
        // Scope absence and resource termination remain different facts.
        _popped = !container.hasScope(name);
        throw const StartupCleanupIncomplete();
      }
      _popped = !container.hasScope(name);
    }
    for (final entry in _resources.reversed) {
      // First pass handles unregistered constructor resources, but never
      // immediately repeats a failed disposer already called by popScope.
      if (!entry.attempted || attemptedBefore.contains(entry)) {
        await entry.run();
      }
    }
    if (!cleanupComplete) throw const StartupCleanupIncomplete();
    for (final entry in _resources) {
      _owners[entry.resource] = null;
    }
    _resources.clear();
  }
}

final class StartupCleanupIncomplete implements Exception {
  const StartupCleanupIncomplete();
  @override
  String toString() => 'Startup resource cleanup remains incomplete';
}

final class _Cleanup {
  _Cleanup(this.resource, this.dispose);
  final Object resource;
  final FutureOr<void> Function() dispose;
  bool done = false;
  bool attempted = false;
  Future<void>? _flight;
  Future<void> run() {
    if (done) return Future.value();
    return _flight ??= _run().whenComplete(() => _flight = null);
  }

  Future<void> _run() async {
    attempted = true;
    try {
      await dispose();
      done = true;
    } catch (_) {
      // Keep the bounded owner reference. A later explicit cleanup retry may
      // retry this terminal failure; an unreturned Future is never duplicated.
    }
  }
}
