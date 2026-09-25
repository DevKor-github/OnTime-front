import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:on_time_front/core/database/local_data_lifecycle.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/local_reset_protocol.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'local_reset_progress_screen.dart';

/// Minimal pre-DI recovery surface. The broader D01 startup transaction remains
/// separate; a failure during DI construction requires a restart, not reuse.
class LocalStartupGate extends StatefulWidget {
  const LocalStartupGate({
    super.key,
    required this.prepare,
    required this.ready,
    required this.retryReset,
  });
  final Future<void> Function() prepare;
  final Widget Function() ready;
  final Future<LocalResetResult> Function() retryReset;
  @override
  State<LocalStartupGate> createState() => _LocalStartupGateState();
}

class _LocalStartupGateState extends State<LocalStartupGate> {
  Widget? _ready;
  Object? _failure;
  bool _busy = true;
  bool _canRetry = true;
  bool _waiting = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    setState(() {
      _busy = true;
      _failure = null;
      _waiting = false;
    });
    _timer = Timer(const Duration(seconds: 10), () {
      if (mounted && _busy) setState(() => _waiting = true);
    });
    try {
      await widget.prepare();
      if (!mounted) return;
      _canRetry = false;
      final app = widget.ready();
      setState(() => _ready = app);
    } catch (error) {
      if (mounted) setState(() => _failure = error);
    } finally {
      _timer?.cancel();
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready != null) return _ready!;
    return MaterialApp(
      theme: themeData,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          final failure = _failure;
          if (failure is LocalResetRecoveryRequired) {
            return LocalResetProgressScreen(
              initialResult: failure.result,
              operation: widget.retryReset,
            );
          }
          final l10n = AppLocalizations.of(context)!;
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_busy) const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text(
                        _busy
                            ? (_waiting
                                  ? l10n.startupWaitingBody
                                  : l10n.startupLoadingBody)
                            : l10n.startupRecoveryTitle,
                        textAlign: TextAlign.center,
                      ),
                      if (!_busy) ...[
                        const SizedBox(height: 12),
                        Text(
                          _canRetry
                              ? l10n.startupRecoveryBody
                              : l10n.restartRequiredBody,
                          textAlign: TextAlign.center,
                        ),
                        if (_canRetry)
                          FilledButton(
                            onPressed: _load,
                            child: Text(l10n.startupRetryAction),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Invalidating the installation disposes the old app's blocs/timers and never
/// rebuilds them against a closed database. Only a new process starts fresh.
class ResetAwareApp extends StatelessWidget {
  const ResetAwareApp({
    super.key,
    required this.gate,
    required this.reset,
    required this.child,
  });
  final LocalDataOperationGate gate;
  final Future<LocalResetResult> Function() reset;
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: gate,
    builder: (context, _) => gate.isInvalidated
        ? MaterialApp(
            theme: themeData,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: LocalResetProgressScreen(operation: reset),
          )
        : child,
  );
}
