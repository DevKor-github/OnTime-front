part of 'auth_bloc.dart';

abstract class AuthEvent {
  const AuthEvent();
}

final class AuthUserSubscriptionRequested extends AuthEvent {
  const AuthUserSubscriptionRequested();
}

final class AuthSignOutPressed extends AuthEvent {
  const AuthSignOutPressed();
}
