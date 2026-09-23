import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/backup/backup_password.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/local_data_reset_service.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
import 'package:on_time_front/presentation/shared/components/app_spinner.dart';
import 'package:on_time_front/presentation/shared/components/modal_wide_button.dart';
import 'package:on_time_front/presentation/shared/components/two_action_dialog.dart';

class MyDataScreen extends StatefulWidget {
  const MyDataScreen({super.key});

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  bool _busy = false;
  BackupFreshnessStatus? _freshness;

  @override
  void initState() {
    super.initState();
    _loadFreshness();
  }

  Future<void> _loadFreshness() async {
    final value = await getIt<BackupService>().getFreshness();
    if (mounted) setState(() => _freshness = value);
  }

  @override
  Widget build(BuildContext context) {
    final freshness = _freshness;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: '뒤로',
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 8),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/myPage');
            }
          },
          icon: SvgPicture.asset(
            'chevron_left.svg',
            package: 'assets',
            width: 8,
            height: 14,
            colorFilter: ColorFilter.mode(
              AppColors.grey.shade500,
              BlendMode.srcIn,
            ),
          ),
        ),
        title: const Text('내 데이터'),
        centerTitle: true,
        toolbarHeight: 60,
        titleTextStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: 19,
          fontWeight: FontWeight.w600,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
        children: [
          Padding(
            key: const Key('backupStatusCard'),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '백업 상태',
                  style: TextStyle(
                    fontSize: 16,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _freshnessLabel(freshness),
                  style: const TextStyle(fontSize: 14, height: 1.2),
                ),
                if (freshness?.reminderDue == true) ...[
                  const Text(
                    '30일 이상 백업되지 않은 변경 사항이 있습니다.',
                    style: TextStyle(fontSize: 14, height: 1.2),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 18),
          _DataActionRow(
            rowKey: const Key('backupExportRow'),
            enabled: !_busy,
            icon: Icons.lock_outline,
            title: '암호화 백업 내보내기',
            subtitle: '선택한 파일 위치에만 저장합니다.',
            onTap: _export,
          ),
          const SizedBox(height: 18),
          _DataActionRow(
            rowKey: const Key('backupRestoreRow'),
            enabled: !_busy,
            icon: Icons.restore,
            title: '백업에서 복원',
            subtitle: '미리 확인한 뒤 현재 데이터를 완전히 교체합니다.',
            onTap: _restore,
          ),
          const SizedBox(height: 18),
          _DataActionRow(
            rowKey: const Key('localDataResetRow'),
            enabled: !_busy,
            icon: Icons.delete_forever,
            title: '로컬 데이터 초기화',
            subtitle: '이 기기의 OnTime 데이터와 알람을 모두 삭제합니다.',
            destructive: true,
            onTap: _reset,
          ),
          if (_busy)
            const Padding(
              padding: EdgeInsets.only(top: 18),
              child: Center(child: AppSpinner()),
            ),
        ],
      ),
    );
  }

  String _freshnessLabel(BackupFreshnessStatus? status) {
    if (status == null) return '확인 중';
    return switch (status.freshness) {
      BackupFreshness.neverExported => '아직 내보낸 백업이 없습니다.',
      BackupFreshness.noChanges => '마지막 백업 이후 변경 사항이 없습니다.',
      BackupFreshness.unexportedChanges => '백업되지 않은 변경 사항이 있습니다.',
    };
  }

  Future<void> _export() async {
    final password = await _askPassword(confirm: true);
    if (password == null) return;
    await _run(() async {
      final saved = await getIt<BackupService>().exportToUserSelectedFile(
        password,
      );
      if (!mounted || !saved) return;
      showMyDataResultSnackBar(context, '암호화 백업을 저장했습니다.');
      await _loadFreshness();
    });
  }

  Future<void> _restore() async {
    final password = await _askPassword(confirm: false);
    if (password == null) return;
    await _run(() async {
      final candidate = await getIt<BackupService>().selectAndPreviewRestore(
        password,
      );
      if (!mounted || candidate == null) return;
      final preview = candidate.preview;
      final confirmed = await showRestorePreviewDialog(context, preview);
      if (confirmed != DialogActionResult.primary) return;
      await getIt<BackupService>().applyRestore(candidate);
      await getIt<ReconcileAlarmsUseCase>()();
      if (!mounted) return;
      showMyDataResultSnackBar(context, '백업을 복원했습니다.');
      await _loadFreshness();
    });
  }

  Future<void> _reset() async {
    final result = await showTwoActionDialog(
      context,
      config: const TwoActionDialogConfig(
        title: '모든 로컬 데이터를 삭제할까요?',
        description:
            '일정, 준비 단계, 기록, 설정, 알람과 기기 암호화 키가 삭제됩니다. '
            '이미 내보낸 백업 파일은 삭제되지 않습니다. 이 작업은 되돌릴 수 없습니다.',
        secondaryAction: DialogActionConfig(label: '취소'),
        primaryAction: DialogActionConfig(
          label: '모두 삭제',
          variant: ModalWideButtonVariant.destructive,
        ),
        barrierColor: Color(0x6B000000),
        alignment: Alignment(0, 0.04),
      ),
    );
    if (result != DialogActionResult.primary) return;
    setState(() => _busy = true);
    try {
      await getIt<LocalDataResetService>().reset();
      if (mounted) context.go('/resetComplete');
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(error);
    }
  }

  Future<String?> _askPassword({required bool confirm}) async {
    return showDialog<String>(
      context: context,
      barrierColor: const Color(0x6B000000),
      builder: (context) => _BackupPasswordDialog(confirm: confirm),
    );
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showError(Object error) {
    showMyDataResultSnackBar(context, '작업을 완료하지 못했습니다: $error');
  }
}

void showMyDataResultSnackBar(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        message,
        style: const TextStyle(
          fontFamily: 'Pretendard',
          fontSize: 14,
          height: 16 / 14,
          color: Colors.white,
        ),
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFF323232),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 48),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _continue() {
    try {
      final parsed = BackupPassword.parse(_first.text);
      if (widget.confirm &&
          parsed.normalized != BackupPassword.parse(_second.text).normalized) {
        throw const FormatException('비밀번호가 서로 다릅니다.');
      }
      Navigator.of(context).pop(parsed.normalized);
    } on FormatException catch (exception) {
      setState(
        () => _error = exception.message == '비밀번호가 서로 다릅니다.'
            ? exception.message
            : '백업 비밀번호는 15~128자로 입력해주세요.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final topInset = _figmaDialogTopInset(context);
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom;
    const bodyStyle = TextStyle(
      fontFamily: 'Pretendard',
      fontSize: 13,
      height: 1.4,
      color: Color(0xFF545454),
    );
    return TwoActionDialog(
      config: TwoActionDialogConfig(
        title: widget.confirm ? '백업 비밀번호 만들기' : '백업 비밀번호 입력',
        secondaryAction: const DialogActionConfig(label: '취소'),
        primaryAction: const DialogActionConfig(
          label: '계속',
          variant: ModalWideButtonVariant.primary,
        ),
        alignment: Alignment.topCenter,
        insetPadding: EdgeInsets.only(top: topInset),
        innerPadding: const EdgeInsets.all(16),
        titleContentSpacing: 12,
        contentActionsSpacing: 11,
      ),
      onSecondaryPressed: () => Navigator.of(context).pop(),
      onPrimaryPressed: _continue,
      customContent: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: (availableHeight - topInset - 124).clamp(
            80.0,
            double.infinity,
          ),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('백업 비밀번호', style: bodyStyle),
              const SizedBox(height: 12),
              _passwordField(_first, '백업 비밀번호', bodyStyle),
              const Text(
                '15~128자, 대소문자와 공백을 그대로 구분합니다.',
                style: bodyStyle,
                textAlign: TextAlign.center,
              ),
              if (widget.confirm) ...[
                const SizedBox(height: 16),
                const Text('백업 비밀번호 확인', style: bodyStyle),
                const SizedBox(height: 12),
                _passwordField(_second, '백업 비밀번호 확인', bodyStyle),
              ],
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  style: bodyStyle.copyWith(color: const Color(0xFFBF2E22)),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _passwordField(
    TextEditingController controller,
    String label,
    TextStyle style,
  ) {
    return SizedBox(
      height: 44,
      child: Center(
        child: Semantics(
          label: label,
          child: TextField(
            controller: controller,
            obscureText: true,
            enableSuggestions: false,
            autocorrect: false,
            autofillHints: null,
            textAlign: TextAlign.center,
            style: style,
            decoration: const InputDecoration(
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              disabledBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
        ),
      ),
    );
  }
}

double _figmaDialogTopInset(BuildContext context) {
  final availableHeight =
      MediaQuery.sizeOf(context).height -
      MediaQuery.viewInsetsOf(context).bottom;
  final targetTop = (availableHeight - 400).clamp(16.0, 352.0);
  final systemTopInset =
      View.of(context).padding.top / View.of(context).devicePixelRatio;
  return (targetTop - systemTopInset).clamp(0.0, double.infinity);
}

Future<DialogActionResult> showRestorePreviewDialog(
  BuildContext context,
  BackupRestorePreview preview,
) {
  final description =
      '백업 시점: ${_formatBackupCutoff(preview.cutoff)}\n'
      '앱 버전: ${preview.sourceAppVersion}\n'
      '원본 플랫폼: ${preview.sourcePlatform}\n'
      '일정 ${preview.scheduleCount}개\n'
      '준비 템플릿 ${preview.templateCount}개\n'
      '기본 준비 단계 ${preview.defaultPreparationStepCount}개\n\n'
      '현재 로컬 데이터는 모두 교체됩니다.';
  return showTwoActionDialog(
    context,
    config: TwoActionDialogConfig(
      title: '복원 내용 확인',
      secondaryAction: const DialogActionConfig(label: '취소'),
      primaryAction: const DialogActionConfig(
        label: '복원',
        variant: ModalWideButtonVariant.primary,
      ),
      barrierColor: const Color(0x6B000000),
      alignment: Alignment.topCenter,
      insetPadding: EdgeInsets.only(top: _figmaDialogTopInset(context)),
    ),
    customContent: Text(
      description,
      style: const TextStyle(
        fontFamily: 'Pretendard',
        fontSize: 13,
        height: 1.55,
        letterSpacing: -0.4,
        color: Color(0xFF545454),
      ),
      textAlign: TextAlign.center,
    ),
  );
}

String _formatBackupCutoff(DateTime cutoff) {
  final local = cutoff.toLocal();
  final period = local.hour < 12 ? '오전' : '오후';
  final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final minute = local.minute.toString().padLeft(2, '0');
  return '${local.year}. ${local.month}. ${local.day}. $period $hour:$minute';
}

class _DataActionRow extends StatelessWidget {
  const _DataActionRow({
    required this.rowKey,
    required this.enabled,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.destructive = false,
  });

  final Key rowKey;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final titleColor = destructive
        ? AppColors.red.shade800
        : AppColors.grey[950]!;
    return Semantics(
      button: true,
      enabled: enabled,
      label: '$title. $subtitle',
      child: Opacity(
        opacity: enabled ? 1 : 0.38,
        child: InkWell(
          key: rowKey,
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 68),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Icon(
                    icon,
                    size: 24,
                    color: destructive ? titleColor : AppColors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            color: titleColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            height: 1.2,
                            color: AppColors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class LocalDataResetCompleteScreen extends StatelessWidget {
  const LocalDataResetCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 27),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      height: 77,
                      child: Icon(
                        Icons.check_circle_outline,
                        size: 68,
                        color: Color(0xFF111111),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const Text(
                      '로컬 데이터를 삭제했습니다.',
                      style: TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 20,
                        height: 1.5,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 18),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 336),
                      child: const Text(
                        'OnTime을 완전히 종료한 뒤 다시 열면 새 로컬 프로필로\n시작합니다.',
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 14,
                          height: 1.2,
                          letterSpacing: -0.15,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
