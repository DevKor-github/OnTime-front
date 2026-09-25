import 'package:on_time_front/domain/entities/preparation_entity.dart';

/// A coherent edit starting point, scoped to one installation data generation.
class DefaultPreferencesSnapshot {
  const DefaultPreferencesSnapshot({
    required this.preparation,
    required this.spareTime,
    required this.store,
    required this.generation,
    required this.revision,
  });
  final PreparationEntity preparation;
  final Duration spareTime;
  final String store;
  final int generation;
  final int revision;
}

class DefaultPreferencesSubmission {
  DefaultPreferencesSubmission({
    required this.baseline,
    required PreparationEntity preparation,
    required this.spareTime,
  }) : preparation = PreparationEntity(
         preparationStepList: List.unmodifiable(
           preparation.preparationStepList,
         ),
       );
  final DefaultPreferencesSnapshot baseline;
  final PreparationEntity preparation;
  final Duration spareTime;
}

enum DefaultPreferencesAuthority { current, superseded, unavailable }

enum DefaultPreferencesFailure { conflict, invalid, unavailable, failed }

class DefaultPreferencesRejected implements Exception {
  const DefaultPreferencesRejected(this.failure);
  final DefaultPreferencesFailure failure;
}

/// Commit remains true when a cache refresh or delivery projection is pending.
class DefaultPreferencesSaveReceipt {
  const DefaultPreferencesSaveReceipt({
    required this.operation,
    required this.store,
    required this.generation,
    required this.changed,
    required this.revision,
    this.reloadPending = false,
    this.deliveryPending = false,
    this.superseded = false,
    this.authorityPending = false,
  });
  final Object operation;
  final String store;
  final int generation;
  final int revision;
  final bool changed;
  final bool reloadPending;
  final bool deliveryPending;
  final bool superseded;
  final bool authorityPending;
  bool get complete =>
      !reloadPending && !deliveryPending && !superseded && !authorityPending;

  DefaultPreferencesSaveReceipt withFollowUp({
    required bool reloadPending,
    required bool deliveryPending,
    bool superseded = false,
    bool authorityPending = false,
  }) => DefaultPreferencesSaveReceipt(
    operation: operation,
    store: store,
    generation: generation,
    changed: changed,
    revision: revision,
    reloadPending: reloadPending,
    deliveryPending: deliveryPending,
    superseded: superseded,
    authorityPending: authorityPending,
  );
}
