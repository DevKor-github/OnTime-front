/// Paths and key slots are derived from these allowlisted IDs, never supplied by
/// a backup or copied verbatim out of a recovery record.
final class StorePair {
  const StorePair.legacy() : id = 'legacy';
  StorePair.candidate(this.id) {
    if (!isCandidateId(id)) throw const PairAuthorityUnavailable();
  }
  final String id;
  bool get isLegacy => id == 'legacy';
  static bool isCandidateId(String value) => RegExp(
    r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
  ).hasMatch(value);
  static StorePair decode(Object? value) => value == 'legacy'
      ? const StorePair.legacy()
      : value is String
      ? StorePair.candidate(value)
      : throw const PairAuthorityUnavailable();
  @override
  bool operator ==(Object other) => other is StorePair && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

final class PairAuthorityUnavailable implements Exception {
  const PairAuthorityUnavailable();
  @override
  String toString() => 'Store selection requires recovery';
}

enum PairStage {
  reserved,
  validated,
  confirmed,
  activated,
  verified,
  ready,
  aborting,
  cancelled,
}

final class PairRecord {
  const PairRecord({
    required this.target,
    required this.original,
    required this.originProcess,
    required this.stage,
    this.originalEvidence,
    this.runtimeIdentity,
  });
  final StorePair target;
  final StorePair original;
  final String originProcess;
  final PairStage stage;
  final String? originalEvidence;
  final String? runtimeIdentity;
  bool get confirmed =>
      stage != PairStage.cancelled && stage.index >= PairStage.confirmed.index;
  Map<String, Object?> encode() => {
    'version': 1,
    'target': target.id,
    'original': original.id,
    'originProcess': originProcess,
    'stage': stage.name,
    'originalEvidence': originalEvidence,
    'runtimeIdentity': runtimeIdentity,
  };
  PairRecord at(PairStage next, {String? evidence, String? runtime}) =>
      PairRecord(
        target: target,
        original: original,
        originProcess: originProcess,
        stage: next,
        originalEvidence: evidence ?? originalEvidence,
        runtimeIdentity: runtime ?? runtimeIdentity,
      );
  static PairRecord decode(Object? raw) {
    try {
      if (raw is! Map<String, dynamic> ||
          raw.length != 7 ||
          raw['version'] != 1) {
        throw const PairAuthorityUnavailable();
      }
      final target = StorePair.decode(raw['target']);
      final original = StorePair.decode(raw['original']);
      final process = raw['originProcess'];
      final evidence = raw['originalEvidence'];
      final runtime = raw['runtimeIdentity'];
      final stage = PairStage.values.byName(raw['stage'] as String);
      if (target.isLegacy ||
          target == original ||
          process is! String ||
          !StorePair.isCandidateId(process) ||
          (evidence != null &&
              (evidence is! String ||
                  !RegExp(r'^[a-f0-9]{64}$').hasMatch(evidence))) ||
          (runtime != null &&
              (runtime is! String ||
                  !RegExp(r'^[a-f0-9]{32}$').hasMatch(runtime))) ||
          (stage != PairStage.reserved &&
              stage != PairStage.cancelled &&
              (evidence == null || runtime == null))) {
        throw const PairAuthorityUnavailable();
      }
      return PairRecord(
        target: target,
        original: original,
        originProcess: process,
        stage: stage,
        originalEvidence: evidence as String?,
        runtimeIdentity: runtime as String?,
      );
    } catch (_) {
      throw const PairAuthorityUnavailable();
    }
  }
}
