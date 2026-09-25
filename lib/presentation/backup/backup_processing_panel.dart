import 'package:flutter/material.dart';
import 'package:on_time_front/domain/entities/backup_processing.dart';
import 'package:on_time_front/domain/entities/backup_operation.dart';

String? backupProcessingError(Object error, bool ko) {
  if (error is BackupProcessingCleanupFailure) {
    final original = error.originalError;
    final reason = original == null
        ? ''
        : '${backupProcessingError(original, ko) ?? ''}\n';
    return '$reason${ko ? '임시 자료 정리가 아직 확인되지 않았어요. 같은 작업의 정리를 다시 시도하세요.' : 'Temporary cleanup is not confirmed. Retry cleanup for this operation.'}';
  }
  if (error is! BackupProcessingFailure) return null;
  return switch (error.kind) {
    BackupFailureKind.userCancelled =>
      ko ? '백업 작업을 취소했어요.' : 'The backup operation was cancelled.',
    BackupFailureKind.resourceLimit =>
      ko
          ? '이 백업은 지원하는 크기 또는 처리 한도를 넘었어요. 원본 파일과 현재 데이터는 유지됩니다.'
          : 'This backup exceeds a supported size or processing limit. The source file and current data are preserved.',
    BackupFailureKind.unsupportedRepresentation =>
      ko
          ? '이 백업 버전 또는 값의 표현은 지원하지 않아요. 호환되는 앱에서 백업을 확인해 주세요.'
          : 'This backup version or value representation is not supported. Check it with a compatible app.',
    BackupFailureKind.authentication =>
      ko
          ? '비밀번호가 맞지 않거나 파일의 무결성을 확인할 수 없어요. 비밀번호와 원본 파일을 확인해 주세요.'
          : 'The password or file integrity could not be verified. Check the password and original file.',
    BackupFailureKind.dataInvariant =>
      ko
          ? '백업 내용의 값이나 연결 관계를 확인할 수 없어요. 원본 파일을 다시 확인해 주세요.'
          : 'The backup contains invalid values or relationships. Check the original file.',
    BackupFailureKind.timeZoneChoiceRequired =>
      ko
          ? '일정의 시간대 또는 반복 순서를 명시적으로 검토해야 해요. 현재 데이터는 변경되지 않았으며 이 화면에서는 해당 내용을 수정할 수 없어요.'
          : 'The time-zone choice or recurrence order needs explicit review. Current data is unchanged. This screen cannot edit those choices yet.',
    BackupFailureKind.inputOutput =>
      ko
          ? '파일을 끝까지 읽거나 저장하지 못했어요. 파일 접근 권한과 저장 공간을 확인한 뒤 다시 시도하세요.'
          : 'The file could not be fully read or saved. Check file access and available storage, then retry.',
  };
}

/// A process owner survives this widget; disposing the screen neither releases
/// a lease nor treats an outstanding provider/crypto/database call as complete.
class BackupProcessingPanel extends StatefulWidget {
  const BackupProcessingPanel({super.key, this.owner});
  final BackupProcessingOwner? owner;
  @override
  State<BackupProcessingPanel> createState() => _BackupProcessingPanelState();
}

class _BackupProcessingPanelState extends State<BackupProcessingPanel> {
  bool retrying = false;
  String? failure;
  BackupProcessingOwner get owner =>
      widget.owner ?? BackupProcessingOwner.shared;
  @override
  Widget build(BuildContext context) {
    final ko = Localizations.localeOf(context).languageCode == 'ko';
    return StreamBuilder<BackupProcessingPhase?>(
      stream: owner.changes,
      builder: (context, snapshot) {
        final lease = owner.active;
        if (lease == null || lease.phase == BackupProcessingPhase.preview) {
          return const SizedBox.shrink();
        }
        final phase = lease.phase;
        final text = switch (phase) {
          BackupProcessingPhase.reading =>
            ko ? '백업 파일을 읽고 있어요.' : 'Reading the backup file.',
          BackupProcessingPhase.validating =>
            ko ? '백업 내용을 검증하고 있어요.' : 'Validating the backup.',
          BackupProcessingPhase.encrypting =>
            ko ? '백업을 암호화하고 있어요.' : 'Encrypting the backup.',
          BackupProcessingPhase.choosingDestination =>
            ko
                ? '파일 저장이 끝날 때까지 기다려 주세요.'
                : 'Waiting for the file save to finish.',
          BackupProcessingPhase.applying =>
            ko ? '확인한 백업을 적용하고 있어요.' : 'Applying the confirmed backup.',
          BackupProcessingPhase.cancelling =>
            ko
                ? '취소 중이에요. 파일 읽기·저장과 임시 자료 정리가 끝날 때까지 기다려 주세요. 시스템 파일 창이 열려 있다면 그 창에서 저장 또는 취소를 마쳐 주세요.'
                : 'Cancelling. Waiting for file reading, saving and temporary cleanup to finish. If a system file window is open, finish saving or cancel in that window.',
          BackupProcessingPhase.cleanupPending =>
            ko ? '임시 자료 정리가 남아 있어요.' : 'Temporary cleanup remains.',
          BackupProcessingPhase.preview => '',
        };
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(liveRegion: true, child: Text(text)),
                if (failure != null) Text(failure!),
                if (phase == BackupProcessingPhase.cleanupPending)
                  TextButton(
                    onPressed: retrying
                        ? null
                        : () async {
                            setState(() {
                              retrying = true;
                              failure = null;
                            });
                            try {
                              await owner.retryCleanup();
                            } catch (e) {
                              if (mounted) {
                                setState(
                                  () => failure =
                                      backupProcessingError(e, ko) ??
                                      (ko
                                          ? '정리를 다시 시도해 주세요.'
                                          : 'Please retry cleanup.'),
                                );
                              }
                            } finally {
                              if (mounted) setState(() => retrying = false);
                            }
                          },
                    child: Text(
                      ko ? '같은 작업 정리 다시 시도' : 'Retry this operation’s cleanup',
                    ),
                  )
                else if (lease.cancellationAllowed &&
                    phase != BackupProcessingPhase.cancelling)
                  TextButton(
                    onPressed: owner.requestCancellation,
                    child: Text(ko ? '백업 작업 취소' : 'Cancel backup operation'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class BackupPreviewNotices extends StatelessWidget {
  const BackupPreviewNotices({super.key, required this.input});
  final BackupRestoreInput input;
  @override
  Widget build(BuildContext context) {
    final ko = Localizations.localeOf(context).languageCode == 'ko';
    final preview = input.preview;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (preview.cutoffLiteral != null)
          Text(
            ko
                ? '백업 시점의 시간대가 기록되지 않았어요. 표시한 원래 날짜와 시각은 절대시각이 아니며 기기 시간대로 변환하지 않습니다.'
                : 'The backup cutoff has no recorded time zone. Its original date and time are shown without converting them into an instant or this device’s zone.',
          ),
        if (preview.uncertainHistoryCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              ko
                  ? '시간대 규칙의 근거를 확정할 수 없는 기록 ${preview.uncertainHistoryCount}개를 원래 값 그대로 보존합니다. 보존만으로 새 준비 시작이나 알림이 허용되지는 않습니다.'
                  : '${preview.uncertainHistoryCount} records retain their original values with uncertain time-zone provenance. Preservation does not authorize a new preparation start or alarm.',
            ),
          ),
        for (final example in preview.uncertainHistoryExamples)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${example.name ?? (ko ? '반복 제외 기록' : 'Excluded recurrence')} · ${example.civil.toIso8601String().replaceAll('Z', '')} · ${example.zone}\n${_uncertaintyReason(example.reason, ko)}',
            ),
          ),
        if (preview.timezoneChangeCount > 0) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              ko
                  ? '현재 시간대 규칙에 따라 미래 일정 ${preview.timezoneChangeCount}개의 절대시각이 다시 계산됩니다. 교체를 누르면 이 변경도 적용됩니다.'
                  : '${preview.timezoneChangeCount} future schedule instants will be recalculated with current time-zone rules. Confirming replacement also applies these changes.',
            ),
          ),
          TextButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => _ImpactDialog(input: input),
            ),
            child: Text(ko ? '변경되는 일정 모두 확인' : 'Review all changed schedules'),
          ),
        ],
      ],
    );
  }

  String _uncertaintyReason(
    BackupHistoryUncertaintyReason reason,
    bool ko,
  ) => switch (reason) {
    BackupHistoryUncertaintyReason.historicalProvenance =>
      ko
          ? '당시 절대시각과 반복 순서의 근거가 불확실합니다.'
          : 'The original instant and recurrence order are uncertain.',
    BackupHistoryUncertaintyReason.unavailableHistoricalZone =>
      ko
          ? '역사 시간대를 확인할 수 없습니다. 원래 값을 보존합니다.'
          : 'The historical time zone is unavailable. Original values are preserved.',
    BackupHistoryUncertaintyReason.protectedStartZone =>
      ko
          ? '보호된 준비 시작 사실입니다. 실행 재개는 별도 확인이 필요합니다.'
          : 'Protected preparation start facts are preserved. Resuming requires a separate check.',
    BackupHistoryUncertaintyReason.historicalOrdinal =>
      ko
          ? '역사 반복 순서의 시간대 규칙 근거가 불확실합니다.'
          : 'The time-zone rules behind the historical recurrence order are uncertain.',
  };
}

class _ImpactDialog extends StatefulWidget {
  const _ImpactDialog({required this.input});
  final BackupRestoreInput input;
  @override
  State<_ImpactDialog> createState() => _ImpactDialogState();
}

class _ImpactDialogState extends State<_ImpactDialog> {
  late Future<BackupTimeZoneImpactPage> page;
  int start = 1;
  @override
  void initState() {
    super.initState();
    page = widget.input.timeZoneImpacts();
  }

  @override
  Widget build(BuildContext context) {
    final ko = Localizations.localeOf(context).languageCode == 'ko';
    return AlertDialog(
      scrollable: true,
      title: Text(ko ? '시간대 변경 영향' : 'Time-zone changes'),
      content: FutureBuilder<BackupTimeZoneImpactPage>(
        future: page,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Text(
              ko
                  ? '목록을 읽지 못했어요. 닫고 다시 시도하세요.'
                  : 'The list could not be read. Close and retry.',
            );
          }
          if (!snapshot.hasData) return const CircularProgressIndicator();
          final data = snapshot.data!;
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$start–${start + data.items.length - 1} / ${widget.input.preview.timezoneChangeCount}',
              ),
              for (final item in data.items)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '${item.name}\n${item.civil.toIso8601String().replaceAll('Z', '')} · ${item.zone}\n${item.previousOffset == null ? (ko ? '미선택' : 'Unspecified') : _offset(item.previousOffset!)} → ${_offset(item.newOffset)}',
                  ),
                ),
              if (data.nextCursor != null)
                TextButton(
                  onPressed: () => setState(() {
                    start += data.items.length;
                    page = widget.input.timeZoneImpacts(
                      cursor: data.nextCursor,
                    );
                  }),
                  child: Text(ko ? '다음 일정' : 'Next schedules'),
                ),
            ],
          );
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(ko ? '닫기' : 'Close'),
        ),
      ],
    );
  }
}

String _offset(int seconds) {
  final value = seconds.abs();
  final hours = (value ~/ 3600).toString().padLeft(2, '0');
  final minutes = ((value % 3600) ~/ 60).toString().padLeft(2, '0');
  final remainder = value % 60;
  return 'UTC${seconds < 0 ? '-' : '+'}$hours:$minutes${remainder == 0 ? '' : ':${remainder.toString().padLeft(2, '0')}'}';
}
