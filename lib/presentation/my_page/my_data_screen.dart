import 'package:on_time_front/presentation/backup/backup_recurring_time_review_screen.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/entities/backup_time_review.dart';
import 'package:on_time_front/presentation/backup/backup_time_review_screen.dart';
import 'package:on_time_front/presentation/backup/backup_processing_panel.dart';
import 'package:on_time_front/domain/entities/local_reset_result.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/use-cases/local_data_workflows.dart';
import 'package:on_time_front/l10n/app_localizations.dart';
import 'package:on_time_front/presentation/startup/screens/local_reset_progress_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:on_time_front/presentation/recurring/recurrence_components.dart';
import 'package:on_time_front/presentation/startup/screens/local_data_recovery_screen.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/core/backup/backup_password.dart';
import 'package:on_time_front/core/di/di_setup.dart';

class MyDataScreen extends StatefulWidget {
  const MyDataScreen({
    super.key,
    this.initialAction,
    this.workflow,
    this.resetWorkflow,
  });

  final String? initialAction;
  final BackupWorkflow? workflow;
  final LocalResetWorkflow? resetWorkflow;

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  bool _busy = false;
  bool _working = false;
  bool _freshnessFailed = false;
  int _freshnessRequest = 0;
  BackupRestoreReceipt? _restoreReceipt;
  BackupWorkflow get _workflow => widget.workflow ?? getIt<BackupWorkflow>();
  LocalResetWorkflow get _reset =>
      widget.resetWorkflow ?? getIt<LocalResetWorkflow>();
  AppLocalizations get l10n =>
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('ko'));
  bool get _routeCurrent =>
      mounted && (ModalRoute.of(context)?.isCurrent ?? true);

  LocalResetResult? _resetResult;
  BackupFreshnessStatus? _freshness;

  @override
  void initState() {
    super.initState();
    _loadFreshness();
    if (widget.initialAction != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        switch (widget.initialAction) {
          case 'backup':
            _export();
          case 'restore':
            _restore();
          case 'reset':
            _resetData();
        }
      });
    }
  }

  Future<void> _loadFreshness() async {
    final request = ++_freshnessRequest;
    final generation = _workflow.generation;
    try {
      final value = await _workflow.freshness();
      if (mounted &&
          request == _freshnessRequest &&
          generation == _workflow.generation) {
        setState(() {
          _freshness = value;
          _freshnessFailed = false;
        });
      }
    } catch (_) {
      if (mounted &&
          request == _freshnessRequest &&
          generation == _workflow.generation) {
        setState(() => _freshnessFailed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final resetResult = _resetResult;
    if (resetResult != null) {
      return LocalResetProgressScreen(
        initialResult: resetResult,
        operation: _reset.call,
      );
    }
    final freshness = _freshness;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.dataTitle)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.dataBackupStatus,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _freshnessFailed
                        ? l10n.dataFreshnessFailed
                        : _freshnessLabel(freshness),
                  ),
                  if (_freshnessFailed)
                    TextButton(
                      onPressed: _busy ? null : _loadFreshness,
                      child: Text(l10n.dataRetry),
                    ),
                  if (freshness?.reminderDue == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.dataReminder,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (_restoreReceipt?.followUpPending == true)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(switch (_restoreReceipt!.disposition) {
                      BackupCommitDisposition.committed =>
                        l10n.dataRestoreCleanupPending,
                      BackupCommitDisposition.notCommitted =>
                        l10n.dataUncommittedCleanup,
                      BackupCommitDisposition.undetermined =>
                        _unknownRestoreMessage,
                    }),
                    TextButton(
                      onPressed: _busy || _unknownCommit
                          ? null
                          : _retryRestoreDelivery,
                      child: Text(switch (_restoreReceipt!.disposition) {
                        BackupCommitDisposition.committed =>
                          l10n.dataRetryCleanup,
                        BackupCommitDisposition.notCommitted =>
                          l10n.dataRetryDelivery,
                        BackupCommitDisposition.undetermined =>
                          l10n.dataChecking,
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ListTile(
            enabled: !_busy && !_unknownCommit,
            leading: const Icon(Icons.lock_outline),
            title: Text(l10n.dataExport),
            subtitle: Text(l10n.dataExportDescription),
            onTap: _export,
          ),
          ListTile(
            enabled: !_busy && !_unknownCommit,
            leading: const Icon(Icons.restore),
            title: Text(l10n.dataRestore),
            subtitle: Text(l10n.dataRestoreDescription),
            onTap: _restore,
          ),
          const Divider(height: 32),
          ListTile(
            enabled: !_busy && !_unknownCommit,
            leading: Icon(
              Icons.delete_forever,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              l10n.dataReset,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: Text(l10n.dataResetDescription),
            onTap: _resetData,
          ),
          const BackupProcessingPanel(),
          if (_working)
            const Padding(
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  bool get _unknownCommit =>
      _restoreReceipt?.disposition == BackupCommitDisposition.undetermined;
  String get _unknownRestoreMessage =>
      Localizations.localeOf(context).languageCode == 'ko'
      ? '복원 적용 여부를 아직 확인할 수 없습니다. 앱을 다시 열어 같은 작업을 확인하세요.'
      : 'The restore outcome is not yet confirmed. Reopen the app to check the same operation.';

  String _freshnessLabel(BackupFreshnessStatus? status) {
    if (status == null) return l10n.dataChecking;
    return switch (status.freshness) {
      BackupFreshness.neverExported => l10n.dataNeverExported,
      BackupFreshness.noChanges => l10n.dataNoChanges,
      BackupFreshness.unexportedChanges => l10n.dataUnexportedChanges,
    };
  }

  Future<void> _export() async {
    if (_busy || _unknownCommit) return;
    setState(() => _busy = true);
    final operationGeneration = _workflow.generation;
    try {
      final password = await _askPassword(confirm: true);
      if (password == null ||
          !_routeCurrent ||
          operationGeneration != _workflow.generation) {
        return;
      }
      final generation = _workflow.generation;
      setState(() => _working = true);
      final saved = await _workflow.export(password);
      if (!_routeCurrent ||
          generation != _workflow.generation ||
          saved == BackupExportResult.cancelled) {
        return;
      }
      _message(
        saved == BackupExportResult.saved
            ? l10n.dataExportSaved
            : l10n.dataExportMetadataFailed,
      );
      await _loadFreshness();
    } catch (error) {
      if (_routeCurrent && operationGeneration == _workflow.generation) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _working = false;
        });
      }
    }
  }

  Future<void> _restore() async {
    if (_busy || _unknownCommit) return;
    setState(() => _busy = true);
    final operationGeneration = _workflow.generation;
    BackupRestoreInput? candidate;
    BackupRestoreSelection? selected;
    final workflow = _workflow;
    BackupRestoreReceipt? ownedReceipt;
    try {
      final password = await _askPassword(confirm: false);
      if (password == null ||
          !_routeCurrent ||
          operationGeneration != _workflow.generation) {
        return;
      }
      final generation = _workflow.generation;
      setState(() => _working = true);
      selected = await workflow.selectForRestore(password);
      if (!_routeCurrent ||
          !identical(workflow, _workflow) ||
          generation != workflow.generation ||
          selected == null) {
        return;
      }
      setState(() => _working = false);
      if (!mounted) return;
      if (selected is BackupTimeReviewInput) {
        final review = selected;
        candidate = await Navigator.of(context).push<BackupRestoreInput>(
          MaterialPageRoute(
            builder: (reviewContext) => BackupTimeReviewScreen(
              input: review,
              onReviewRecurrence: (currentInput, issue) async {
                if (!mounted ||
                    !reviewContext.mounted ||
                    ModalRoute.of(reviewContext)?.isCurrent == false ||
                    !identical(workflow, _workflow) ||
                    generation != workflow.generation) {
                  return;
                }
                await Navigator.of(reviewContext).push<void>(
                  MaterialPageRoute(
                    builder: (_) => BackupRecurringTimeReviewScreen(
                      input: currentInput,
                      issue: issue,
                    ),
                  ),
                );
              },
            ),
          ),
        );
      } else if (selected is BackupRestoreInput) {
        candidate = selected;
      } else {
        throw const DataOperationException(DataOperationFailure.invalidBackup);
      }
      if (candidate == null ||
          !_routeCurrent ||
          !identical(workflow, _workflow) ||
          generation != workflow.generation) {
        return;
      }
      final preview = candidate.preview;
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l10n.dataRestorePreviewTitle),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.dataRestorePreview(
                    preview.cutoffLiteral ?? '${preview.cutoff.toLocal()}',
                    preview.sourceAppVersion,
                    preview.sourcePlatform,
                    preview.scheduleCount,
                    preview.templateCount,
                    preview.defaultPreparationStepCount,
                  ),
                ),
                BackupPreviewNotices(input: candidate!),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l10n.dataCancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l10n.dataRestoreAction),
            ),
          ],
        ),
      );
      if (confirmed != true ||
          !_routeCurrent ||
          !identical(workflow, _workflow) ||
          generation != workflow.generation) {
        return;
      }
      setState(() => _working = true);
      final receipt = await workflow.restore(candidate);
      ownedReceipt = receipt;
      if (!_routeCurrent || receipt.generation != _workflow.generation) return;
      setState(() => _restoreReceipt = receipt);
      switch (receipt.disposition) {
        case BackupCommitDisposition.committed:
          _message(
            receipt.followUpPending
                ? l10n.dataRestoreCleanupPending
                : l10n.dataRestoreComplete,
          );
          await _loadFreshness();
        case BackupCommitDisposition.undetermined:
          _message(_unknownRestoreMessage);
        case BackupCommitDisposition.notCommitted:
          _showError(
            DataOperationException(
              receipt.failure ?? DataOperationFailure.failed,
            ),
          );
      }
    } catch (error) {
      if (_routeCurrent && identical(workflow, _workflow)) {
        if (error is DataOperationException &&
            error.followUpPending &&
            error.generation == workflow.generation) {
          setState(
            () => _restoreReceipt = BackupRestoreReceipt(
              disposition: BackupCommitDisposition.notCommitted,
              generation: error.generation!,
              followUpPending: true,
              failure: error.failure,
            ),
          );
          _showError(error);
        } else if (operationGeneration == workflow.generation) {
          _showError(error);
        }
      }
    } finally {
      try {
        if (ownedReceipt?.disposition != BackupCommitDisposition.undetermined) {
          try {
            await candidate?.dispose();
          } finally {
            if (!identical(candidate, selected)) await selected?.dispose();
          }
        }
      } catch (error) {
        final ownerGeneration = ownedReceipt?.generation ?? operationGeneration;
        if (_routeCurrent &&
            ownerGeneration == _workflow.generation &&
            (ownedReceipt == null ||
                ownedReceipt.disposition ==
                    BackupCommitDisposition.notCommitted)) {
          _showError(error);
        }
      }
      if (mounted) {
        setState(() {
          _busy = false;
          _working = false;
        });
      }
    }
  }

  Future<void> _retryRestoreDelivery() async {
    final receipt = _restoreReceipt;
    if (_busy || receipt == null) return;
    setState(() => _busy = true);
    try {
      final result = await _workflow.retryFollowUp(receipt);
      if (!_routeCurrent || result.generation != _workflow.generation) return;
      setState(() => _restoreReceipt = result);
      if (!result.followUpPending) _message(l10n.dataDeliveryUpdated);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _working = false;
        });
      }
    }
  }

  Future<void> _resetData() async {
    if (_busy || _unknownCommit) return;
    setState(() => _busy = true);
    final generation = _workflow.generation;
    try {
      final confirmed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => const LocalDataResetConfirmationScreen(),
        ),
      );
      if (confirmed != true ||
          !_routeCurrent ||
          generation != _workflow.generation) {
        return;
      }
      setState(() => _working = true);
      final result = await _reset();
      if (_routeCurrent) setState(() => _resetResult = result);
    } catch (error) {
      if (_routeCurrent && generation == _workflow.generation) {
        _showError(error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _working = false;
        });
      }
    }
  }

  Future<String?> _askPassword({required bool confirm}) => showDialog<String>(
    context: context,
    builder: (context) => _BackupPasswordDialog(confirm: confirm),
  );

  void _message(String message) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) {
    final processing = backupProcessingError(
      error,
      Localizations.localeOf(context).languageCode == 'ko',
    );
    if (processing != null) {
      _message(processing);
      return;
    }
    if (error is RestoreStagingCleanupFailure) {
      _message(l10n.dataStagingCleanupFailed);
      return;
    }
    final code = error is DataOperationException
        ? error.failure
        : DataOperationFailure.failed;
    _message(switch (code) {
      DataOperationFailure.busy => l10n.dataBusy,
      DataOperationFailure.unavailable => l10n.dataUnavailable,
      DataOperationFailure.stalePreview => l10n.dataStalePreview,
      DataOperationFailure.invalidBackup => l10n.dataInvalidBackup,
      DataOperationFailure.failed => l10n.dataOperationFailed,
    });
  }
}

class LocalDataResetCompleteScreen extends StatelessWidget {
  const LocalDataResetCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: RecurrenceSheet(
      title: '초기화 완료',
      showBack: false,
      footer: ScreenActions(
        action: '다시 시작 안내',
        onAction: () => showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('OnTime을 다시 열어 주세요'),
            content: const Text('앱을 완전히 종료한 뒤 다시 열면 새 로컬 프로필로 시작합니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('확인'),
              ),
            ],
          ),
        ),
      ),
      children: [
        const SizedBox(height: 40),
        Center(
          child: SvgPicture.asset(
            'assets/design/reset_success.svg',
            width: 69,
            height: 69,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '로컬 데이터 초기화가\n완료되었습니다',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            height: 1.3,
            fontWeight: FontWeight.w700,
          ),
        ),
        const Text(
          '이 기기에 저장된 모든 로컬 데이터가 삭제되었습니다.\nOnTime을 완전히 종료한 뒤 다시 열면 새 로컬 프로필로 시작합니다.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 8),
        const RecurrencePanel(
          child: Text(
            '외부에 저장된 백업 파일은 삭제되지 않았습니다.\n필요한 경우 직접 삭제해 주세요.',
            style: TextStyle(fontSize: 13, height: 1.6),
          ),
        ),
      ],
    ),
  );
}

class _BackupPasswordDialog extends StatefulWidget {
  const _BackupPasswordDialog({required this.confirm});
  final bool confirm;

  @override
  State<_BackupPasswordDialog> createState() => _BackupPasswordDialogState();
}

class _BackupPasswordDialogState extends State<_BackupPasswordDialog> {
  final first = TextEditingController();
  final second = TextEditingController();
  String? error;

  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  AppLocalizations get l10n =>
      AppLocalizations.of(context) ??
      lookupAppLocalizations(const Locale('ko'));

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(
      widget.confirm ? l10n.dataCreatePassword : l10n.dataEnterPassword,
    ),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: first,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: null,
            decoration: InputDecoration(
              labelText: l10n.dataPassword,
              helperText: l10n.dataPasswordHelp,
              helperMaxLines: 4,
            ),
          ),
          if (widget.confirm) ...[
            const SizedBox(height: 12),
            TextField(
              controller: second,
              obscureText: true,
              enableSuggestions: false,
              autocorrect: false,
              autofillHints: null,
              decoration: InputDecoration(labelText: l10n.dataConfirmPassword),
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(l10n.dataCancel),
      ),
      FilledButton(
        onPressed: () {
          try {
            final parsed = BackupPassword.parse(first.text);
            if (widget.confirm &&
                parsed.normalized !=
                    BackupPassword.parse(second.text).normalized) {
              setState(() => error = l10n.dataPasswordMismatch);
              return;
            }
            Navigator.pop(context, parsed.normalized);
          } on FormatException {
            setState(() => error = l10n.dataPasswordInvalid);
          }
        },
        child: Text(l10n.dataContinue),
      ),
    ],
  );
}
