import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:on_time_front/core/backup/backup_password.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/local_data_reset_service.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';
import 'package:on_time_front/presentation/shared/constants/app_colors.dart';
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
                  const SizedBox(height: 8),
                  Text(
                    '30일 이상 백업되지 않은 변경 사항이 있습니다.',
                    style: TextStyle(color: AppColors.red.shade800),
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
          const Divider(height: 1),
          const SizedBox(height: 17),
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
              padding: EdgeInsets.only(top: 24),
              child: Center(child: CircularProgressIndicator()),
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('암호화 백업을 저장했습니다.')));
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
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('복원 내용 확인'),
          content: Text(
            '백업 시점: ${preview.cutoff.toLocal()}\n'
            '앱 버전: ${preview.sourceAppVersion}\n'
            '원본 플랫폼: ${preview.sourcePlatform}\n'
            '일정 ${preview.scheduleCount}개\n'
            '준비 템플릿 ${preview.templateCount}개\n'
            '기본 준비 단계 ${preview.defaultPreparationStepCount}개\n\n'
            '현재 로컬 데이터는 모두 교체됩니다.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('복원'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      await getIt<BackupService>().applyRestore(candidate);
      await getIt<ReconcileAlarmsUseCase>()();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('백업을 복원했습니다.')));
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
    final first = TextEditingController();
    final second = TextEditingController();
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(confirm ? '백업 비밀번호 만들기' : '백업 비밀번호 입력'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: first,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                autofillHints: null,
                decoration: const InputDecoration(
                  labelText: '백업 비밀번호',
                  helperText: '15~128자, 대소문자와 공백을 그대로 구분합니다.',
                ),
              ),
              if (confirm) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: second,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  autofillHints: null,
                  decoration: const InputDecoration(labelText: '백업 비밀번호 확인'),
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
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () {
                try {
                  final parsed = BackupPassword.parse(first.text);
                  if (confirm &&
                      parsed.normalized !=
                          BackupPassword.parse(second.text).normalized) {
                    throw const FormatException('비밀번호가 서로 다릅니다.');
                  }
                  Navigator.pop(context, parsed.normalized);
                } on FormatException catch (exception) {
                  setDialogState(
                    () => error = exception.message == '비밀번호가 서로 다릅니다.'
                        ? exception.message
                        : '백업 비밀번호는 15~128자로 입력해주세요.',
                  );
                }
              },
              child: const Text('계속'),
            ),
          ],
        ),
      ),
    );
    first.dispose();
    second.dispose();
    return result;
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('작업을 완료하지 못했습니다: $error')));
  }
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
