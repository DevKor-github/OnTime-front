import 'package:on_time_front/core/database/local_reset_protocol.dart';
import 'package:on_time_front/presentation/startup/screens/local_reset_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:on_time_front/core/backup/backup_password.dart';
import 'package:on_time_front/core/backup/backup_service.dart';
import 'package:on_time_front/core/database/local_data_reset_service.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/domain/use-cases/reconcile_alarms_use_case.dart';

class MyDataScreen extends StatefulWidget {
  const MyDataScreen({super.key});

  @override
  State<MyDataScreen> createState() => _MyDataScreenState();
}

class _MyDataScreenState extends State<MyDataScreen> {
  bool _busy = false;
  LocalResetResult? _resetResult;
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
    final resetResult = _resetResult;
    if (resetResult != null) {
      return LocalResetProgressScreen(
        initialResult: resetResult,
        operation: getIt<LocalDataResetService>().reset,
      );
    }
    final freshness = _freshness;
    return Scaffold(
      appBar: AppBar(title: const Text('내 데이터')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('백업 상태', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text(_freshnessLabel(freshness)),
                  if (freshness?.reminderDue == true) ...[
                    const SizedBox(height: 8),
                    Text(
                      '30일 이상 백업되지 않은 변경 사항이 있습니다.',
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
          ListTile(
            enabled: !_busy,
            leading: const Icon(Icons.lock_outline),
            title: const Text('암호화 백업 내보내기'),
            subtitle: const Text('선택한 파일 위치에만 저장합니다.'),
            onTap: _export,
          ),
          ListTile(
            enabled: !_busy,
            leading: const Icon(Icons.restore),
            title: const Text('백업에서 복원'),
            subtitle: const Text('미리 확인한 뒤 현재 데이터를 완전히 교체합니다.'),
            onTap: _restore,
          ),
          const Divider(height: 32),
          ListTile(
            enabled: !_busy,
            leading: Icon(
              Icons.delete_forever,
              color: Theme.of(context).colorScheme.error,
            ),
            title: Text(
              '로컬 데이터 초기화',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: const Text('이 기기의 OnTime 데이터와 알람을 모두 삭제합니다.'),
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
      if (!mounted || saved == BackupExportResult.cancelled) return;
      final message = saved == BackupExportResult.saved
          ? '암호화 백업을 저장했습니다.'
          : '파일은 저장됐지만 백업 상태를 갱신하지 못했습니다. 앱을 다시 열어 백업 상태를 확인하고 필요하면 다시 내보내주세요.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      if (saved == BackupExportResult.saved) await _loadFreshness();
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
      if (confirmed != true || !mounted) return;
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('모든 로컬 데이터를 삭제할까요?'),
        content: const Text(
          '일정, 준비 단계, 기록, 설정, 알람과 기기 암호화 키가 삭제됩니다. '
          '이미 내보낸 백업 파일은 삭제되지 않습니다. 이 작업은 되돌릴 수 없습니다.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('모두 삭제'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final result = await getIt<LocalDataResetService>().reset();
      if (mounted) setState(() => _resetResult = result);
    } catch (error) {
      if (!mounted) return;
      setState(() => _busy = false);
      _showError(error);
    }
  }

  Future<String?> _askPassword({required bool confirm}) => showDialog<String>(
    context: context,
    builder: (context) => _BackupPasswordDialog(confirm: confirm),
  );

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

class LocalDataResetCompleteScreen extends StatelessWidget {
  const LocalDataResetCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle_outline, size: 64),
              SizedBox(height: 20),
              Text(
                '로컬 데이터를 삭제했습니다.',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 12),
              Text(
                'OnTime을 완전히 종료한 뒤 다시 열면 새 로컬 프로필로 시작합니다.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
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

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.confirm ? '백업 비밀번호 만들기' : '백업 비밀번호 입력'),
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
        if (widget.confirm) ...[
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
            if (widget.confirm &&
                parsed.normalized !=
                    BackupPassword.parse(second.text).normalized) {
              throw const FormatException('비밀번호가 서로 다릅니다.');
            }
            Navigator.pop(context, parsed.normalized);
          } on FormatException catch (exception) {
            setState(
              () => error = exception.message == '비밀번호가 서로 다릅니다.'
                  ? exception.message
                  : '백업 비밀번호는 15~128자로 입력해주세요.',
            );
          }
        },
        child: const Text('계속'),
      ),
    ],
  );
}
