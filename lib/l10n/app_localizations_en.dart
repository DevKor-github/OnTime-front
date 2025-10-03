// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get error => 'Error';

  @override
  String get noSchedules => 'No schedules';

  @override
  String get setSpareTimeTitle => 'Set your spare time';

  @override
  String get setSpareTimeDescription =>
      'You can arrive early by the spare time you set.';

  @override
  String get setSpareTimeWarning =>
      'You must set a spare time in case of unexpected situations.';

  @override
  String get todaysAppointments => 'Today\'s Appointments';

  @override
  String get slogan => 'A little preparation\nmakes a lot of leeway!';

  @override
  String get noAppointments => 'No appointments today';

  @override
  String get am => 'AM';

  @override
  String get pm => 'PM';

  @override
  String get allowNotifications => 'Allow notifications';

  @override
  String get doItLater => 'I\'ll do it later.';

  @override
  String get pleaseAllowNotifications => 'Please allow notifications';

  @override
  String get notificationPermissionDescription =>
      'OnTime needs notifications to help you get ready';

  @override
  String get late => ' late';

  @override
  String get early => ' early';

  @override
  String get letsGo => 'Let\'s go without forgetting';

  @override
  String get areYouRunningLate => 'Are you running late?';

  @override
  String get runningLateDescription =>
      'If you\'re not ready yet, you can stay and continue preparing.\nBut you might be late!';

  @override
  String get continuePreparing => 'Continue Preparing';

  @override
  String get finishPreparation => 'Finish Preparation';

  @override
  String get signInSlogan => 'We\'ll find your lost leisure.';

  @override
  String get welcome => 'Welcome!';

  @override
  String get onboardingStartSubtitle =>
      'To get ready with OnTime,\nplease tell us about your usual preparation process.';

  @override
  String get start => 'Start';

  @override
  String get preparationOrderTitle =>
      'Please tell us the order of the preparation process you selected.';

  @override
  String get preparationNameTitle =>
      'Please select your usual preparation process.';

  @override
  String get multipleSelection => '(Multiple selection)';

  @override
  String get preparationTimeTitle =>
      'Please tell us the time required for each step.';

  @override
  String get addAppointment => 'Add appointment';

  @override
  String get next => 'Next';

  @override
  String get appointmentName => 'Appointment Name';

  @override
  String get appointmentNameHint => 'e.g. Watch a movie';

  @override
  String get appointmentPlace => 'Appointment Place';

  @override
  String get travelTime => 'Travel Time';

  @override
  String get hours => 'hours';

  @override
  String get minutes => 'minutes';

  @override
  String get selectTime => 'Please select a time';

  @override
  String get appointmentTime => 'Appointment Time';

  @override
  String get enterDate => 'Please enter a date.';

  @override
  String get enterTime => 'Please enter a time.';

  @override
  String get thisWeeksAppointments => 'This week\'s appointments';

  @override
  String get viewCalendar => 'View calendar';

  @override
  String points(int score) {
    return '$score points';
  }

  @override
  String punctualityComment(int score) {
    return 'Your punctuality score has increased by $score points!\nYou\'re doing a great job keeping your appointments.';
  }

  @override
  String get movingScreenTitle => 'this is moving screen';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get youWillBeLate =>
      'If you don\'t start preparing now, you\'ll be late!';

  @override
  String get startPreparing => 'Start Preparing';

  @override
  String get confirmLeave => 'Are you sure you want to leave?';

  @override
  String get confirmLeaveDescription =>
      'If you leave this screen,\nwe won\'t be able to prepare for the appointment together.';

  @override
  String get leave => 'I\'m leaving';

  @override
  String get stay => 'I\'ll stay';

  @override
  String get untilAppointment => 'Until\nAppointment';

  @override
  String get appName => 'OnTime';

  @override
  String get spareTime => 'Spare Time';

  @override
  String get home => 'Home';

  @override
  String get myPage => 'My';

  @override
  String get plus => 'plus';

  @override
  String get schedule => 'Schedule';

  @override
  String hourFormatted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '$count hour',
    );
    return '$_temp0';
  }

  @override
  String minuteFormatted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '$count minute',
    );
    return '$_temp0';
  }

  @override
  String get myPageTitle => 'My Page';

  @override
  String get myAccount => 'My Account';

  @override
  String get appSettings => 'App Settings';

  @override
  String get accountSettings => 'Account Settings';

  @override
  String get editDefaultPreparation => 'Edit Default Preparation / Spare Time';

  @override
  String get allowAppNotifications => 'Allow App Notifications';

  @override
  String get logOut => 'Log out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get editSpareTime => 'Edit spare time';

  @override
  String get editPreparationTime => 'Edit preparation time';

  @override
  String get totalTime => 'Total time: ';

  @override
  String get logOutConfirm => 'Do you want to log out?';

  @override
  String get deleteAccountConfirmTitle =>
      'Are you sure you want to delete your account?';

  @override
  String get deleteAccountConfirmDescription =>
      'If you keep preparing with OnTime, you can reduce lateness by 60%.';

  @override
  String get keepUsing => 'I\'ll keep using it';

  @override
  String get deleteAnyway => 'Delete anyway';

  @override
  String get deleteFeedbackTitle =>
      'We hope to meet you again with a better service';

  @override
  String get deleteFeedbackDescription =>
      'Please let us know what was inconvenient so OnTime can improve.';

  @override
  String get deleteFeedbackPlaceholder =>
      'Please tell us the reason for leaving.';

  @override
  String get keepUsingLong => 'Keep using without deleting';

  @override
  String get sendFeedbackAndDelete => 'Send feedback and delete';
}
