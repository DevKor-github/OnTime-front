part of 'app_bloc.dart';

abstract class AppEvent {
  const AppEvent();
}

final class AppUserSubscriptionRequested extends AppEvent {
  const AppUserSubscriptionRequested();
}

final class AppSignOutPressed extends AppEvent {
  const AppSignOutPressed();
}
