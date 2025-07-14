import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ko.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ko')
  ];

  /// The title of the calendar screen
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarTitle;

  /// Generic error message
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Text shown when there are no schedules on a selected date
  ///
  /// In en, this message translates to:
  /// **'No schedules'**
  String get noSchedules;

  /// Title for setting spare time during onboarding
  ///
  /// In en, this message translates to:
  /// **'Set your spare time'**
  String get setSpareTimeTitle;

  /// Description for setting spare time during onboarding
  ///
  /// In en, this message translates to:
  /// **'You can arrive early by the spare time you set.'**
  String get setSpareTimeDescription;

  /// Warning for setting spare time during onboarding
  ///
  /// In en, this message translates to:
  /// **'You must set a spare time in case of unexpected situations.'**
  String get setSpareTimeWarning;

  /// Title for today's appointments section on the home screen
  ///
  /// In en, this message translates to:
  /// **'Today\'s Appointments'**
  String get todaysAppointments;

  /// Slogan displayed on the home screen
  ///
  /// In en, this message translates to:
  /// **'A little preparation\nmakes a lot of leeway!'**
  String get slogan;

  /// Text displayed when there are no appointments for the day
  ///
  /// In en, this message translates to:
  /// **'No appointments today'**
  String get noAppointments;

  /// AM part of a time
  ///
  /// In en, this message translates to:
  /// **'AM'**
  String get am;

  /// PM part of a time
  ///
  /// In en, this message translates to:
  /// **'PM'**
  String get pm;

  /// Button text to allow notifications
  ///
  /// In en, this message translates to:
  /// **'Allow notifications'**
  String get allowNotifications;

  /// Button text to skip a step and do it later
  ///
  /// In en, this message translates to:
  /// **'I\'ll do it later.'**
  String get doItLater;

  /// Title asking the user to allow notifications
  ///
  /// In en, this message translates to:
  /// **'Please allow notifications'**
  String get pleaseAllowNotifications;

  /// Description explaining why notification permission is needed
  ///
  /// In en, this message translates to:
  /// **'OnTime needs notifications to help you get ready'**
  String get notificationPermissionDescription;

  /// Appended to the time when the user is late
  ///
  /// In en, this message translates to:
  /// **' late'**
  String get late;

  /// Appended to the time when the user is early
  ///
  /// In en, this message translates to:
  /// **' early'**
  String get early;

  /// Button text on the early/late screen
  ///
  /// In en, this message translates to:
  /// **'Let\'s go without forgetting'**
  String get letsGo;

  /// Modal title when the preparation time is over
  ///
  /// In en, this message translates to:
  /// **'Are you running late?'**
  String get areYouRunningLate;

  /// Modal content when the preparation time is over
  ///
  /// In en, this message translates to:
  /// **'If you\'re not ready yet, you can stay and continue preparing.\nBut you might be late!'**
  String get runningLateDescription;

  /// Button text to continue preparing
  ///
  /// In en, this message translates to:
  /// **'Continue Preparing'**
  String get continuePreparing;

  /// Button text to finish preparing
  ///
  /// In en, this message translates to:
  /// **'Finish Preparation'**
  String get finishPreparation;

  /// Slogan on the sign-in screen
  ///
  /// In en, this message translates to:
  /// **'We\'ll find your lost leisure.'**
  String get signInSlogan;

  /// Title on the onboarding start screen
  ///
  /// In en, this message translates to:
  /// **'Welcome!'**
  String get welcome;

  /// Subtitle on the onboarding start screen
  ///
  /// In en, this message translates to:
  /// **'To get ready with OnTime,\nplease tell us about your usual preparation process.'**
  String get onboardingStartSubtitle;

  /// Button text to start onboarding
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get start;

  /// Title on the preparation order screen
  ///
  /// In en, this message translates to:
  /// **'Please tell us the order of the preparation process you selected.'**
  String get preparationOrderTitle;

  /// Title on the preparation name selection screen
  ///
  /// In en, this message translates to:
  /// **'Please select your usual preparation process.'**
  String get preparationNameTitle;

  /// Hint for multiple selection
  ///
  /// In en, this message translates to:
  /// **'(Multiple selection)'**
  String get multipleSelection;

  /// Title on the preparation time screen
  ///
  /// In en, this message translates to:
  /// **'Please tell us the time required for each step.'**
  String get preparationTimeTitle;

  /// Title for adding an appointment
  ///
  /// In en, this message translates to:
  /// **'Add appointment'**
  String get addAppointment;

  /// Button text to go to the next page
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Label for the appointment name text field
  ///
  /// In en, this message translates to:
  /// **'Appointment Name'**
  String get appointmentName;

  /// Hint for the appointment name text field
  ///
  /// In en, this message translates to:
  /// **'e.g. Watch a movie'**
  String get appointmentNameHint;

  /// Label for the appointment place text field
  ///
  /// In en, this message translates to:
  /// **'Appointment Place'**
  String get appointmentPlace;

  /// Label for the travel time text field
  ///
  /// In en, this message translates to:
  /// **'Travel Time'**
  String get travelTime;

  /// Unit of time
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get hours;

  /// Unit of time
  ///
  /// In en, this message translates to:
  /// **'minutes'**
  String get minutes;

  /// Title for the time picker modal
  ///
  /// In en, this message translates to:
  /// **'Please select a time'**
  String get selectTime;

  /// Label for the appointment time text field
  ///
  /// In en, this message translates to:
  /// **'Appointment Time'**
  String get appointmentTime;

  /// Title for the date picker modal
  ///
  /// In en, this message translates to:
  /// **'Please enter a date.'**
  String get enterDate;

  /// Title for the time picker modal
  ///
  /// In en, this message translates to:
  /// **'Please enter a time.'**
  String get enterTime;

  /// Title for this week's appointments section on the home screen
  ///
  /// In en, this message translates to:
  /// **'This week\'s appointments'**
  String get thisWeeksAppointments;

  /// Button text to view the calendar
  ///
  /// In en, this message translates to:
  /// **'View calendar'**
  String get viewCalendar;

  /// Punctuality score
  ///
  /// In en, this message translates to:
  /// **'{score} points'**
  String points(int score);

  /// Comment on the user's punctuality score
  ///
  /// In en, this message translates to:
  /// **'Your punctuality score has increased by {score} points!\nYou\'re doing a great job keeping your appointments.'**
  String punctualityComment(int score);

  /// Title for the moving screen
  ///
  /// In en, this message translates to:
  /// **'this is moving screen'**
  String get movingScreenTitle;

  /// Button text to cancel an action
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Button text to confirm an action
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Warning on the schedule start screen
  ///
  /// In en, this message translates to:
  /// **'If you don\'t start preparing now, you\'ll be late!'**
  String get youWillBeLate;

  /// Button text to start preparing
  ///
  /// In en, this message translates to:
  /// **'Start Preparing'**
  String get startPreparing;

  /// Modal title to confirm leaving the screen
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave?'**
  String get confirmLeave;

  /// Modal content to confirm leaving the screen
  ///
  /// In en, this message translates to:
  /// **'If you leave this screen,\nwe won\'t be able to prepare for the appointment together.'**
  String get confirmLeaveDescription;

  /// Button text to leave the screen
  ///
  /// In en, this message translates to:
  /// **'I\'m leaving'**
  String get leave;

  /// Button text to stay on the screen
  ///
  /// In en, this message translates to:
  /// **'I\'ll stay'**
  String get stay;

  /// Label for the time remaining until an appointment
  ///
  /// In en, this message translates to:
  /// **'Until\nAppointment'**
  String get untilAppointment;

  /// The name of the application
  ///
  /// In en, this message translates to:
  /// **'OnTime'**
  String get appName;

  /// Label for spare time
  ///
  /// In en, this message translates to:
  /// **'Spare Time'**
  String get spareTime;

  /// Label for the home button in the bottom navigation bar
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Label for the my page button in the bottom navigation bar
  ///
  /// In en, this message translates to:
  /// **'My'**
  String get myPage;

  /// Semantics label for the plus icon
  ///
  /// In en, this message translates to:
  /// **'plus'**
  String get plus;

  /// Label for the schedule button in the bottom navigation bar
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// A formatted string for hours, handling pluralization.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{{count} hour} other{{count} hours}}'**
  String hourFormatted(int count);

  /// A formatted string for minutes, handling pluralization.
  ///
  /// In en, this message translates to:
  /// **'{count,plural, =1{{count} minute} other{{count} minutes}}'**
  String minuteFormatted(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ko'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ko':
      return AppLocalizationsKo();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
