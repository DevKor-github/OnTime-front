/// A value representing "no meaningful value".
///
/// Use this instead of `void` in generics (Dart disallows `void` as a field type).
class Unit {
  const Unit();
}

const unit = Unit();
