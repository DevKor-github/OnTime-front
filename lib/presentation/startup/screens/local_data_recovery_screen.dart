import 'package:on_time_front/core/database/local_reset_protocol.dart';
import 'package:on_time_front/presentation/startup/screens/local_reset_progress_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:on_time_front/core/database/local_data_reset_service.dart';
import 'package:on_time_front/core/di/di_setup.dart';
import 'package:on_time_front/presentation/app/bloc/auth/auth_bloc.dart';

class LocalDataRecoveryScreen extends StatefulWidget {
  const LocalDataRecoveryScreen({super.key});

  @override
  State<LocalDataRecoveryScreen> createState() =>
      _LocalDataRecoveryScreenState();
}

class _LocalDataRecoveryScreenState extends State<LocalDataRecoveryScreen> {
  bool _busy = false;
  LocalResetResult? _resetResult;

  @override
  Widget build(BuildContext context) {
    final resetResult = _resetResult;
    if (resetResult != null) {
      return LocalResetProgressScreen(
        initialResult: resetResult,
        operation: getIt<LocalDataResetService>().reset,
      );
    }
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storage_rounded, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    '로컬 데이터를 열 수 없습니다.',
                    style: Theme.of(context).textTheme.titleLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'OnTime은 데이터를 자동으로 삭제하지 않았습니다. 잠시 후 다시 시도하거나, '
                    '복구할 수 없는 경우에만 모든 로컬 데이터를 초기화하세요.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () {
                            context.read<AuthBloc>().add(
                              const AuthUserSubscriptionRequested(),
                            );
                          },
                    child: const Text('다시 시도'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _confirmReset,
                    child: Text(
                      '모든 로컬 데이터 초기화',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                  if (_busy)
                    const Padding(
                      padding: EdgeInsets.only(top: 12),
                      child: CircularProgressIndicator(),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmReset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('복구하지 않고 삭제할까요?'),
        content: const Text('현재 설치의 모든 데이터와 암호화 키가 삭제되며 되돌릴 수 없습니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
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
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _resetResult = const LocalResetResult(
          intentRecorded: false,
          completed: {},
        );
      });
    }
  }
}
