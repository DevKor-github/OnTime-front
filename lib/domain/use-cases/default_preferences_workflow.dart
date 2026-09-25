import 'package:injectable/injectable.dart';
import 'package:on_time_front/domain/entities/default_preferences.dart';
import 'package:on_time_front/domain/repositories/default_preferences_repository.dart';
import 'package:on_time_front/domain/use-cases/load_user_use_case.dart';
import 'package:on_time_front/domain/use-cases/schedule_mutation_alarm_effects_coordinator.dart';

@Injectable()
class DefaultPreferencesWorkflow {
  DefaultPreferencesWorkflow(this.repository, this.loadUser, this.effects);
  final DefaultPreferencesRepository repository;
  final LoadUserUseCase loadUser;
  final ScheduleMutationAlarmEffectsCoordinator effects;
  final _saves = Expando<Future<DefaultPreferencesSaveReceipt>>();
  final _saved = Expando<DefaultPreferencesSaveReceipt>();
  final _followUps = Expando<Future<DefaultPreferencesSaveReceipt>>();
  final _latest = Expando<DefaultPreferencesSaveReceipt>();

  int get generation => repository.generation;
  Future<DefaultPreferencesSnapshot> read() => repository.read();
  bool isGenerationCurrent(int generation) =>
      repository.isGenerationCurrent(generation);

  Future<DefaultPreferencesSaveReceipt> save(
    DefaultPreferencesSubmission input,
  ) {
    final pending = _saves[input];
    if (pending != null) return pending;
    final completed = _saved[input];
    if (completed != null) return retry(completed);
    final future = _save(input);
    _saves[input] = future;
    future.then(
      (_) {
        _saves[input] = null;
      },
      onError: (Object _, StackTrace __) {
        _saves[input] = null;
      },
    );
    return future;
  }

  Future<DefaultPreferencesSaveReceipt> _save(
    DefaultPreferencesSubmission input,
  ) async {
    final receipt = await repository.save(input);
    // Record commit before any follow-up: reusing this command cannot write twice.
    _saved[input] = receipt;
    return retry(receipt);
  }

  Future<DefaultPreferencesSaveReceipt> retry(
    DefaultPreferencesSaveReceipt receipt,
  ) {
    final pending = _followUps[receipt.operation];
    if (pending != null) return pending;
    final latest = _latest[receipt.operation] ?? receipt;
    final future = _retry(latest);
    _followUps[receipt.operation] = future;
    future.then(
      (value) {
        _latest[receipt.operation] = value;
        _followUps[receipt.operation] = null;
      },
      onError: (Object _, StackTrace __) {
        _followUps[receipt.operation] = null;
      },
    );
    return future;
  }

  Future<DefaultPreferencesSaveReceipt> _retry(
    DefaultPreferencesSaveReceipt receipt,
  ) async {
    var reload = receipt.reloadPending;
    var delivery = receipt.deliveryPending;
    DefaultPreferencesSaveReceipt result(
      DefaultPreferencesAuthority authority,
    ) => receipt.withFollowUp(
      reloadPending: reload,
      deliveryPending: delivery,
      superseded: authority == DefaultPreferencesAuthority.superseded,
      authorityPending: authority == DefaultPreferencesAuthority.unavailable,
    );
    var authority = await repository.authority(receipt);
    if (authority != DefaultPreferencesAuthority.current) {
      return result(authority);
    }
    if (reload) {
      try {
        await loadUser();
        reload = false;
      } catch (_) {
        /* Commit remains durable. */
      }
    }
    authority = await repository.authority(receipt);
    if (authority != DefaultPreferencesAuthority.current) {
      return result(authority);
    }
    if (delivery) {
      try {
        delivery = !await effects.afterCommit();
      } catch (_) {
        /* Retry only the current-data projection. */
      }
    }
    return result(await repository.authority(receipt));
  }
}
