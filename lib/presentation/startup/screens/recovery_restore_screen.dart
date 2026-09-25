import 'package:on_time_front/presentation/backup/backup_recurring_time_review_screen.dart';
import 'package:on_time_front/domain/entities/backup_restore_selection.dart';
import 'package:on_time_front/domain/entities/backup_time_review.dart';
import 'package:on_time_front/domain/ports/backup_time_review_port.dart';
import 'package:on_time_front/domain/ports/recovery_preclaim_cleanup_port.dart';
import 'package:on_time_front/presentation/backup/backup_time_review_screen.dart';
import 'package:on_time_front/presentation/backup/backup_processing_panel.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/core/backup/backup_password.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';
import 'package:on_time_front/domain/ports/recovery_restore_port.dart';

/// Pre-DI restore UI. The operation owner, not this State, owns native work.
class RecoveryRestoreScreen extends StatefulWidget {
  const RecoveryRestoreScreen({
    super.key,
    required this.port,
    required this.onCancelled,
    required this.onCompleted,
    this.initialReceipt,
  });
  final Future<RecoveryRestorePort> Function() port;
  final VoidCallback onCancelled;
  final VoidCallback onCompleted;
  final BackupRestoreReceipt? initialReceipt;
  @override
  State<RecoveryRestoreScreen> createState() => _RecoveryRestoreScreenState();
}

class _RecoveryRestoreScreenState extends State<RecoveryRestoreScreen> {
  bool _busy = false;
  String? _error;
  BackupRestoreReceipt? _receipt;
  final _selections = <BackupRestoreSelection>{};
  RecoveryPreclaimCleanupPort? _preclaimPort;
  int? _preclaimGeneration;
  bool get _preclaimPending => _preclaimGeneration != null;
  bool get ko => Localizations.localeOf(context).languageCode == 'ko';
  bool get _ownsIntent => _receipt?.followUpPending == true;
  bool get _cleanupPending => _selections.isNotEmpty;
  @override
  void initState() {
    super.initState();
    _receipt = widget.initialReceipt;
  }

  Future<bool> _releaseSelections() async {
    var complete = true;
    for (final selected in List<BackupRestoreSelection>.of(_selections)) {
      try {
        await selected.dispose();
        _selections.remove(selected);
      } catch (_) {
        complete = false;
      }
    }
    return complete;
  }

  Future<void> _retryCandidateCleanup() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final complete = await _releaseSelections();
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (!complete) {
        _error = ko
            ? '후보 파일 정리를 완료하지 못했어요. 다시 시도해주세요.'
            : 'Candidate cleanup did not finish. Retry cleanup.';
      }
    });
  }

  Future<void> _retryPreclaimCleanup() async {
    final port = _preclaimPort, generation = _preclaimGeneration;
    if (_busy || port == null || generation == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await port.retryPreclaimCleanup(generation);
      if (!mounted) return;
      setState(() {
        _preclaimPort = null;
        _preclaimGeneration = null;
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = ko
              ? '알림 정리를 완료하지 못했어요. 같은 정리 작업을 다시 시도해주세요.'
              : 'Alarm cleanup did not finish. Retry the same cleanup operation.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _select() async {
    if (_busy || _ownsIntent || _cleanupPending || _preclaimPending) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    RecoveryRestorePort? selectedPort;
    try {
      final password = await showDialog<String>(
        context: context,
        builder: (_) => const RecoveryPasswordDialog(),
      );
      if (!mounted || password == null) return;
      final port = await widget.port();
      selectedPort = port;
      if (!mounted) return;
      final selected = port is BackupTimeReviewPort
          ? await (port as BackupTimeReviewPort).selectForRestore(password)
          : await port.preview(password);
      if (selected != null) _selections.add(selected);
      if (!mounted || selected == null) return;
      BackupRestoreInput? candidate;
      if (selected is BackupTimeReviewInput) {
        candidate = await Navigator.of(context).push<BackupRestoreInput?>(
          MaterialPageRoute(
            builder: (_) => BackupTimeReviewScreen(
              input: selected,
              onReviewRecurrence: (current, issue) async {
                if (!mounted) return;
                await Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => BackupRecurringTimeReviewScreen(
                      input: current,
                      issue: issue,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        if (candidate != null) _selections.add(candidate);
      } else if (selected is BackupRestoreInput) {
        candidate = selected;
      } else {
        throw const DataOperationException(DataOperationFailure.invalidBackup);
      }
      if (!mounted || candidate == null) return;
      final ready = candidate;
      final preview = ready.preview;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(ko ? '백업으로 교체할까요?' : 'Replace data with this backup?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                ko
                    ? '백업 시점: ${preview.cutoffLiteral ?? preview.cutoff}\n앱: ${preview.sourceAppVersion}\n일정 ${preview.scheduleCount}개 · 템플릿 ${preview.templateCount}개 · 기본 준비 단계 ${preview.defaultPreparationStepCount}개\n\n현재 손상 데이터의 개수는 알 수 없습니다. 현재 데이터가 백업 내용으로 교체됩니다.'
                    : 'Backup cutoff: ${preview.cutoffLiteral ?? preview.cutoff}\nApp: ${preview.sourceAppVersion}\n${preview.scheduleCount} schedules · ${preview.templateCount} templates · ${preview.defaultPreparationStepCount} default preparation steps\n\nThe damaged original count is unknown. This backup will replace the current data.',
              ),
              BackupPreviewNotices(input: ready),
            ],
          ),
          actions: [
            TextButton(
              key: const Key('cancel-recovery-replacement'),
              onPressed: () => Navigator.pop(context, false),
              child: Text(ko ? '취소' : 'Cancel'),
            ),
            FilledButton(
              key: const Key('confirm-recovery-replacement'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(ko ? '교체' : 'Replace'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      final result = await port.activate(ready);
      if (mounted) setState(() => _receipt = result);
    } on RecoveryOriginalAvailable {
      if (mounted) {
        setState(
          () => _error = ko
              ? '원본 데이터를 다시 열 수 있습니다. 돌아가서 정상 앱의 내 데이터에서 새 복원 확인을 진행하세요.'
              : 'The original data can be opened again. Return to My Data and confirm a new restore there.',
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          if (error is DataOperationException &&
              error.followUpPending &&
              error.generation != null) {
            _preclaimGeneration = error.generation;
            _preclaimPort = selectedPort is RecoveryPreclaimCleanupPort
                ? selectedPort as RecoveryPreclaimCleanupPort
                : null;
            _receipt = null;
          }
          _error =
              backupProcessingError(error, ko) ??
              (ko
                  ? '복구를 완료하지 못했습니다. 현재 단계에서 다시 시도하세요.'
                  : 'Recovery did not finish. Retry the current step.');
        });
      }
    } finally {
      final complete = await _releaseSelections();
      if (mounted) {
        setState(() {
          if (!complete) {
            _error = ko
                ? '후보 파일 정리가 남아 있습니다. 후보 정리를 다시 시도해주세요.'
                : 'Candidate cleanup remains. Retry candidate cleanup.';
          }
          _busy = false;
        });
      }
    }
  }

  Future<void> _resume() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await (await widget.port()).resume();
      if (!mounted) return;
      setState(() => _receipt = result);
      if (result.disposition == BackupCommitDisposition.committed &&
          !result.followUpPending) {
        widget.onCompleted();
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = ko
              ? '같은 복구 작업의 상태를 확인할 수 없습니다. 잠시 후 다시 시도하세요.'
              : 'The same recovery operation could not be checked. Try again later.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _abort() async {
    if (_busy ||
        _receipt?.disposition != BackupCommitDisposition.notCommitted) {
      return;
    }
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(ko ? '이 복구를 중단할까요?' : 'Stop this recovery?'),
        content: Text(
          ko
              ? '백업은 적용되지 않았습니다. 원본 데이터와 키를 유지하고 이 복구의 후보 파일과 키만 제거합니다.'
              : 'The backup was not applied. Keep the original data and key and remove only this recovery candidate and its key.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(ko ? '돌아가기' : 'Back'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(ko ? '복구 중단' : 'Stop recovery'),
          ),
        ],
      ),
    );
    if (!mounted || yes != true) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final receipt = await (await widget.port()).abort();
      if (mounted) setState(() => _receipt = receipt);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = ko
              ? '중단 정리가 끝나지 않았습니다. 같은 작업을 계속하세요.'
              : 'Abort cleanup is incomplete. Continue the same operation.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get status {
    if (_preclaimPending) {
      return ko
          ? '백업은 적용되지 않았습니다. 검토가 만료됐거나 복원 전 정리가 끝나지 않았습니다. 이미 시작한 알림 정리만 완료한 뒤 백업을 다시 선택해주세요.'
          : 'The backup was not applied. Review expired or preparation for restoration did not finish. Complete the alarm cleanup already started, then select the backup again.';
    }
    final receipt = _receipt;
    if (receipt == null) {
      return ko
          ? '원본 데이터와 키를 보존한 채 백업을 검증합니다.'
          : 'The backup is validated while preserving the original data and key.';
    }
    return switch (receipt.disposition) {
      BackupCommitDisposition.undetermined =>
        ko
            ? '복원 적용 여부를 아직 확인할 수 없습니다. 새 복원이나 초기화를 시작하지 말고 같은 복구를 계속하세요.'
            : 'The restore outcome is not confirmed. Continue this recovery without starting another restore or reset.',
      BackupCommitDisposition.notCommitted =>
        ko
            ? '교체가 적용되지 않았습니다. 원본을 유지하며 이 복구를 중단할 수 있습니다.'
            : 'Replacement was not committed. You can stop this recovery while keeping the original.',
      BackupCommitDisposition.committed => switch (receipt.recoveryFollowUp) {
        RecoveryFollowUp.awaitingNewProcess =>
          ko
              ? '백업이 적용되었습니다. 앱을 완전히 닫고 다시 열어 검증과 정리를 완료하세요. 기존 데이터와 키는 그때까지 보존됩니다.'
              : 'The backup was applied. Fully close and reopen the app to verify and finish cleanup. The old data and key remain preserved until then.',
        RecoveryFollowUp.verifyingPair =>
          ko
              ? '복원된 데이터를 다시 검증해야 합니다.'
              : 'The restored data requires verification.',
        RecoveryFollowUp.cleanupPending =>
          ko
              ? '복원은 적용되었으며 후속 정리가 남아 있습니다.'
              : 'Restoration was applied and cleanup remains.',
        null => ko ? '복원이 완료되었습니다.' : 'Restoration is complete.',
      },
    };
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy && !_ownsIntent && !_cleanupPending && !_preclaimPending,
    child: Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    ko ? '백업으로 복구' : 'Recover from backup',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),
                  Text(status, textAlign: TextAlign.center),
                  const BackupProcessingPanel(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, textAlign: TextAlign.center),
                  ],
                  const SizedBox(height: 20),
                  if (_busy) ...[
                    const CircularProgressIndicator(),
                    const SizedBox(height: 12),
                    Text(
                      ko
                          ? '현재 작업이 끝날 때까지 기다려 주세요.'
                          : 'Please wait for the current operation to finish.',
                    ),
                  ],
                  if (_cleanupPending && !_busy)
                    OutlinedButton(
                      key: const Key('retry-recovery-candidate-cleanup'),
                      onPressed: _retryCandidateCleanup,
                      child: Text(
                        ko ? '후보 정리 다시 시도' : 'Retry candidate cleanup',
                      ),
                    ),
                  if (_preclaimPending) ...[
                    FilledButton(
                      key: const Key('retry-recovery-preclaim-cleanup'),
                      onPressed: _busy || _preclaimPort == null
                          ? null
                          : _retryPreclaimCleanup,
                      child: Text(ko ? '알림 정리 다시 시도' : 'Retry alarm cleanup'),
                    ),
                    if (_preclaimPort == null)
                      Text(
                        ko
                            ? '같은 정리 작업을 열 수 없습니다. 앱을 완전히 닫고 다시 열어 상태를 확인해주세요.'
                            : 'The same cleanup operation is unavailable. Fully close and reopen the app to check its state.',
                      ),
                  ] else if (!_ownsIntent) ...[
                    FilledButton(
                      key: const Key('select-recovery-backup'),
                      onPressed: _busy || _cleanupPending ? null : _select,
                      child: Text(ko ? '백업 파일 선택' : 'Choose backup file'),
                    ),
                    TextButton(
                      onPressed: _busy || _cleanupPending
                          ? null
                          : widget.onCancelled,
                      child: Text(ko ? '돌아가기' : 'Back'),
                    ),
                  ] else ...[
                    FilledButton(
                      onPressed: _busy ? null : _resume,
                      child: Text(ko ? '복구 계속' : 'Continue recovery'),
                    ),
                    if (_receipt?.disposition ==
                        BackupCommitDisposition.notCommitted)
                      TextButton(
                        onPressed: _busy ? null : _abort,
                        child: Text(ko ? '이 복구 중단' : 'Stop this recovery'),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class RecoveryPasswordDialog extends StatefulWidget {
  const RecoveryPasswordDialog({super.key});
  @override
  State<RecoveryPasswordDialog> createState() => _RecoveryPasswordDialogState();
}

class _RecoveryPasswordDialogState extends State<RecoveryPasswordDialog> {
  final text = TextEditingController();
  bool invalid = false;
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ko = Localizations.localeOf(context).languageCode == 'ko';
    return AlertDialog(
      scrollable: true,
      title: Text(ko ? '백업 비밀번호' : 'Backup password'),
      content: TextField(
        controller: text,
        obscureText: true,
        enableSuggestions: false,
        autocorrect: false,
        autofillHints: null,
        decoration: InputDecoration(
          errorText: invalid
              ? (ko
                    ? '백업에 사용한 비밀번호 전체를 입력하세요.'
                    : 'Enter the full backup password.')
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ko ? '취소' : 'Cancel'),
        ),
        FilledButton(
          onPressed: () {
            try {
              Navigator.pop(
                context,
                BackupPassword.parse(text.text).normalized,
              );
            } on FormatException {
              setState(() => invalid = true);
            }
          },
          child: Text(ko ? '계속' : 'Continue'),
        ),
      ],
    );
  }
}
