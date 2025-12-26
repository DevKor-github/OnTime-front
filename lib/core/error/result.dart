/// A small Result type for explicit error handling.
///
/// - Prefer returning `Result<T, Failure>` from repositories/use-cases instead of throwing.
/// - Keeps error propagation explicit and testable.
sealed class Result<S, F> {
  const Result();

  bool get isSuccess => this is Success<S, F>;
  bool get isFailure => this is Err<S, F>;

  S? get successOrNull => switch (this) {
    Success(value: final v) => v,
    _ => null,
  };

  F? get failureOrNull => switch (this) {
    Err(failure: final f) => f,
    _ => null,
  };

  T fold<T>({
    required T Function(S value) onSuccess,
    required T Function(F failure) onFailure,
  }) {
    return switch (this) {
      Success(value: final v) => onSuccess(v),
      Err(failure: final f) => onFailure(f),
    };
  }

  Result<S2, F> map<S2>(S2 Function(S value) transform) {
    return fold(
      onSuccess: (v) => Success<S2, F>(transform(v)),
      onFailure: (f) => Err<S2, F>(f),
    );
  }

  Result<S2, F> flatMap<S2>(Result<S2, F> Function(S value) transform) {
    return fold(onSuccess: transform, onFailure: (f) => Err<S2, F>(f));
  }

  S getOrElse(S Function(F failure) fallback) {
    return fold(onSuccess: (v) => v, onFailure: fallback);
  }
}

final class Success<S, F> extends Result<S, F> {
  const Success(this.value);
  final S value;
}

final class Err<S, F> extends Result<S, F> {
  const Err(this.failure);
  final F failure;
}
