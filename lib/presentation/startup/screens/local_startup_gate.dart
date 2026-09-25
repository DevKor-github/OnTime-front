import 'package:on_time_front/core/database/recovery/recovery_restore_service.dart';
import 'package:on_time_front/core/database/recovery/store_pair.dart';
import 'package:on_time_front/domain/ports/recovery_restore_port.dart';
import 'recovery_restore_screen.dart';
import 'dart:async';
import 'package:on_time_front/core/database/bootstrap_privacy_boundary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:on_time_front/core/database/local_data_lifecycle.dart';
import 'package:on_time_front/core/database/local_data_operation_gate.dart';
import 'package:on_time_front/core/database/local_reset_protocol.dart';
import 'package:on_time_front/core/database/restore_runtime_identity.dart';
import 'package:on_time_front/core/startup/startup_failure.dart';
import 'package:on_time_front/core/startup/startup_dependency_scope.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/shared/theme/theme.dart';
import 'local_reset_progress_screen.dart';

/// Visible before DB/DI. A waiting notice never cancels the actual owner.
class LocalStartupGate extends StatefulWidget {
  const LocalStartupGate({
    super.key,
    required this.prepare,
    required this.ready,
    required this.retryReset,
    this.beginReset,
    this.recovery,
    this.stage,
    this.cleanupAttempt,
    this.waitNoticeAfter = const Duration(seconds: 10),
  });
  final Future<void> Function() prepare;
  final Widget Function() ready;
  final Future<LocalResetResult> Function() retryReset;
  final Future<LocalResetResult> Function()? beginReset;
  final Future<void> Function()? cleanupAttempt;
  final Future<RecoveryRestorePort> Function()? recovery;
  final Duration waitNoticeAfter;
  final ValueListenable<StartupStage>? stage;
  @override
  State<LocalStartupGate> createState() => _LocalStartupGateState();
}

class _LocalStartupGateState extends State<LocalStartupGate> {
  Widget? _ready;
  Object? _failure;
  bool _busy = false;
  bool _waiting = false;
  bool _needsCleanup = false;
  bool _canRetry = true;
  bool _confirming = false;
  bool _resetStarted = false;
  bool _restoreRequested = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    widget.stage?.addListener(_stageChanged);
    unawaited(_load());
  }

  void _stageChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant LocalStartupGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stage != widget.stage) {
      oldWidget.stage?.removeListener(_stageChanged);
      widget.stage?.addListener(_stageChanged);
    }
  }

  Future<void> _load() async {
    if (_busy || _resetStarted) return;
    setState(() {
      _busy = true;
      _failure = null;
      _waiting = false;
    });
    _timer = Timer(widget.waitNoticeAfter, () {
      if (mounted && _busy) setState(() => _waiting = true);
    });
    var constructing = false;
    var attemptingCleanup = false;
    try {
      if (_needsCleanup) {
        attemptingCleanup = true;
        await widget.cleanupAttempt?.call();
        attemptingCleanup = false;
        _needsCleanup = false;
      }
      await widget.prepare();
      if (!mounted) {
        await widget.cleanupAttempt?.call();
        return;
      }
      constructing = true;
      final app = widget.ready();
      if (mounted) setState(() => _ready = app);
    } catch (original) {
      Object failure = original;
      _needsCleanup = widget.cleanupAttempt != null;
      if (_needsCleanup && !attemptingCleanup) {
        try {
          await widget.cleanupAttempt!();
          _needsCleanup = false;
        } catch (_) {
          failure = const StartupCleanupIncomplete();
        }
      }
      if (attemptingCleanup) failure = const StartupCleanupIncomplete();
      _canRetry = !constructing || widget.cleanupAttempt != null;
      if (mounted) setState(() => _failure = failure);
    } finally {
      _timer?.cancel();
      if (mounted) setState(() => _busy = false);
    }
  }

  Iterable<Object> get _failureChain sync* {
    Object? current = _failure;
    final seen = Set<Object>.identity();
    while (current != null && seen.add(current)) {
      yield current;
      current = switch (current) {
        StartupFailure failure => failure.cause,
        BootstrapPrivacyCleanupFailure failure => failure.bootstrapError,
        _ => null,
      };
    }
  }

  Object? get _cause => _failureChain.lastOrNull;
  bool get _privacyCleanupPending =>
      _failureChain.any((value) => value is BootstrapPrivacyCleanupFailure);

  Future<void> _confirmReset(BuildContext context, bool ko) async {
    if (_busy || _confirming || _resetStarted) return;
    setState(() => _confirming = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(ko ? '복구하지 않고 삭제할까요?' : 'Delete without recovering?'),
        content: Text(
          ko
              ? '이 설치의 모든 로컬 데이터와 암호화 키가 삭제됩니다. 되돌릴 수 없습니다. 외부 백업 파일은 삭제되지 않습니다.'
              : 'All local data and encryption keys in this installation will be deleted. This cannot be undone. External backup files are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ko ? '취소' : 'Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ko ? '모두 삭제' : 'Delete all'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() {
      _confirming = false;
      _resetStarted = confirmed == true;
    });
  }

  @override
  void dispose() {
    widget.stage?.removeListener(_stageChanged);
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
          final cause = _cause;
          if ((_restoreRequested ||
                  (!_busy && cause is PairRecoveryRequired)) &&
              widget.recovery != null) {
            return RecoveryRestoreScreen(
              port: widget.recovery!,
              initialReceipt: cause is PairRecoveryRequired
                  ? cause.receipt
                  : null,
              onCancelled: () => setState(() {
                _restoreRequested = false;
                if (cause is PairRecoveryRequired) {
                  _failure = const RestoreStoreUnavailable(
                    PairAuthorityUnavailable(),
                  );
                }
              }),
              onCompleted: () {
                setState(() => _restoreRequested = false);
                unawaited(_load());
              },
            );
          }
          if (_resetStarted) {
            return LocalResetProgressScreen(operation: widget.beginReset!);
          }
          if (!_busy && cause is LocalResetRecoveryRequired) {
            return LocalResetProgressScreen(
              initialResult: cause.result,
              operation: widget.retryReset,
            );
          }
          final ko = Localizations.localeOf(context).languageCode == 'ko';
          // No intl/date initialization or stored preference is required for the
          // minimum failure copy. Normal generated localization remains available.
          final store =
              cause is RestoreStoreUnavailable ||
              cause is LocalStorePreservationRequired ||
              cause is PairAuthorityUnavailable ||
              (_failure is StartupFailure &&
                  (_failure as StartupFailure).allowsReset);
          final restoring = cause is RestoreRecoveryRequired;
          final cleanup = cause is StartupCleanupIncomplete;
          final phase = cleanup
              ? StartupStage.cleanup
              : _failure is StartupFailure
              ? (_failure as StartupFailure).stage
              : widget.stage?.value;
          final phaseLabel = switch (phase) {
            StartupStage.locale =>
              ko ? '언어 정보 준비' : 'Preparing language information',
            StartupStage.lifecycle =>
              ko
                  ? '설치 상태 확인 및 기존 정리'
                  : 'Checking installation and prior cleanup',
            StartupStage.temporaryFiles =>
              ko ? '임시 복원 파일 정리' : 'Cleaning temporary restore files',
            StartupStage.store =>
              ko ? '암호화된 로컬 데이터 확인' : 'Checking encrypted local data',
            StartupStage.dependencies =>
              ko ? '앱 구성 요소 준비' : 'Preparing app components',
            StartupStage.cleanup =>
              ko ? '시작 작업 자원 정리' : 'Closing startup resources',
            null => null,
          };
          final title = _busy
              ? (_waiting
                    ? (ko
                          ? '시작 작업이 아직 끝나지 않았습니다.'
                          : 'Startup is still in progress.')
                    : (ko ? 'OnTime을 준비하고 있습니다.' : 'Preparing OnTime.'))
              : restoring
              ? (ko
                    ? '복원한 데이터의 정리가 남아 있습니다.'
                    : 'Restored data has pending cleanup.')
              : cleanup
              ? (ko
                    ? '이전 시작 작업을 정리해야 합니다.'
                    : 'Previous startup resources need cleanup.')
              : store
              ? (ko
                    ? '로컬 데이터를 안전하게 열 수 없습니다.'
                    : 'Local data cannot be opened safely.')
              : (ko ? '앱 시작을 완료하지 못했습니다.' : 'Startup could not finish.');
          final body = restoring
              ? (ko
                    ? '데이터 복원은 적용되었습니다. 남은 정리만 다시 시도합니다.'
                    : 'Data restoration was committed. Retry only the remaining cleanup.')
              : store
              ? (ko
                    ? '기존 데이터와 키를 새로 만들거나 자동 삭제하지 않습니다. 다시 시도하거나, 복구를 포기할 때만 명시적으로 초기화하세요.'
                    : 'Existing data and keys will not be replaced or automatically deleted. Retry, or explicitly reset only if you choose to give up recovery.')
              : cleanup
              ? (ko
                    ? '정리가 확인되기 전에는 새 시작 작업을 실행하지 않습니다.'
                    : 'A new startup cannot begin until cleanup is confirmed.')
              : _canRetry
              ? (ko
                    ? '완료된 단계와 남은 작업을 확인한 뒤 다시 시도합니다.'
                    : 'Retry after checking the completed and remaining startup work.')
              : (ko ? '앱을 다시 열어주세요.' : 'Please reopen the app.');
          return Scaffold(
            body: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 440),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_busy) const CircularProgressIndicator(),
                        const SizedBox(height: 20),
                        Text(title, textAlign: TextAlign.center),
                        if (phaseLabel != null) ...[
                          const SizedBox(height: 12),
                          Text(phaseLabel, textAlign: TextAlign.center),
                        ],
                        if (!_busy) ...[
                          const SizedBox(height: 12),
                          Text(body, textAlign: TextAlign.center),
                          if (_privacyCleanupPending) ...[
                            const SizedBox(height: 12),
                            Text(
                              ko
                                  ? '이전 임시 정보의 개인정보 정리도 완료되지 않았습니다.'
                                  : 'Privacy cleanup of previous temporary information is also incomplete.',
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: 16),
                          if (_canRetry)
                            FilledButton(
                              onPressed: _confirming ? null : _load,
                              child: Text(ko ? '다시 시도' : 'Try again'),
                            ),
                          if (store &&
                              widget.recovery != null &&
                              !_needsCleanup)
                            FilledButton(
                              onPressed: _confirming
                                  ? null
                                  : () => setState(
                                      () => _restoreRequested = true,
                                    ),
                              child: Text(
                                ko
                                    ? 'OnTime 백업으로 복원'
                                    : 'Restore an OnTime Backup',
                              ),
                            ),
                          if (store &&
                              widget.beginReset != null &&
                              !_needsCleanup)
                            TextButton(
                              onPressed: _confirming
                                  ? null
                                  : () => _confirmReset(context, ko),
                              child: Text(
                                ko ? '로컬 데이터 초기화' : 'Reset all local data',
                                textAlign: TextAlign.center,
                              ),
                            ),
                        ],
                      ],
                    ),
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
