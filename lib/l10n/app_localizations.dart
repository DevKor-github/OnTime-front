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
    Locale('ko'),
  ];

  /// No description provided for @detailedNotificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Show schedule names in notifications'**
  String get detailedNotificationTitle;

  /// No description provided for @detailedNotificationPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Shows the schedule name and a differing time zone on the lock screen. Places, notes and preparation details stay private.'**
  String get detailedNotificationPrivacy;

  /// No description provided for @detailedNotificationLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking setting'**
  String get detailedNotificationLoading;

  /// No description provided for @detailedNotificationReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to read the setting. Check the saved value again.'**
  String get detailedNotificationReadFailed;

  /// No description provided for @detailedNotificationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Check the setting again after the local data operation finishes.'**
  String get detailedNotificationUnavailable;

  /// No description provided for @detailedNotificationRequestOn.
  ///
  /// In en, this message translates to:
  /// **'On requested · not saved yet'**
  String get detailedNotificationRequestOn;

  /// No description provided for @detailedNotificationRequestOff.
  ///
  /// In en, this message translates to:
  /// **'Off requested · not saved yet'**
  String get detailedNotificationRequestOff;

  /// No description provided for @detailedNotificationSavedOn.
  ///
  /// In en, this message translates to:
  /// **'Saved: on'**
  String get detailedNotificationSavedOn;

  /// No description provided for @detailedNotificationSavedOff.
  ///
  /// In en, this message translates to:
  /// **'Saved: off'**
  String get detailedNotificationSavedOff;

  /// No description provided for @detailedNotificationSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'The requested change could not be saved and has not been applied.'**
  String get detailedNotificationSaveFailed;

  /// No description provided for @detailedNotificationApplying.
  ///
  /// In en, this message translates to:
  /// **'Applying the saved setting to notifications'**
  String get detailedNotificationApplying;

  /// No description provided for @detailedNotificationDelayed.
  ///
  /// In en, this message translates to:
  /// **'The device is taking longer to respond. Notification changes are still being checked.'**
  String get detailedNotificationDelayed;

  /// No description provided for @detailedNotificationApplied.
  ///
  /// In en, this message translates to:
  /// **'Applied to current notification registrations'**
  String get detailedNotificationApplied;

  /// No description provided for @detailedNotificationOff.
  ///
  /// In en, this message translates to:
  /// **'Schedule notifications are off.'**
  String get detailedNotificationOff;

  /// No description provided for @detailedNotificationEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no upcoming notifications to update.'**
  String get detailedNotificationEmpty;

  /// No description provided for @detailedNotificationPermission.
  ///
  /// In en, this message translates to:
  /// **'Check notification permission. The saved setting is kept.'**
  String get detailedNotificationPermission;

  /// No description provided for @detailedNotificationCancellation.
  ///
  /// In en, this message translates to:
  /// **'Existing notifications may still show a schedule name. Check notification cleanup again.'**
  String get detailedNotificationCancellation;

  /// No description provided for @detailedNotificationSchedulingFailed.
  ///
  /// In en, this message translates to:
  /// **'Some notifications could not be scheduled. Apply notifications again.'**
  String get detailedNotificationSchedulingFailed;

  /// No description provided for @detailedNotificationNeedsCheck.
  ///
  /// In en, this message translates to:
  /// **'Notification changes could not be confirmed. Check again.'**
  String get detailedNotificationNeedsCheck;

  /// No description provided for @detailedNotificationHeld.
  ///
  /// In en, this message translates to:
  /// **'New detailed notifications are on hold until the off request is resolved. Existing notifications may remain.'**
  String get detailedNotificationHeld;

  /// No description provided for @detailedNotificationRetry.
  ///
  /// In en, this message translates to:
  /// **'Check or apply again'**
  String get detailedNotificationRetry;

  /// No description provided for @startupRecoveryTitle.
  ///
  /// In en, this message translates to:
  /// **'Unable to start OnTime'**
  String get startupRecoveryTitle;

  /// No description provided for @startupRecoveryBody.
  ///
  /// In en, this message translates to:
  /// **'OnTime could not verify local data. Please try again shortly.'**
  String get startupRecoveryBody;

  /// No description provided for @startupRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get startupRetryAction;

  /// No description provided for @restartRequiredBody.
  ///
  /// In en, this message translates to:
  /// **'Close the app completely, then reopen it.'**
  String get restartRequiredBody;

  /// No description provided for @resetInProgressTitle.
  ///
  /// In en, this message translates to:
  /// **'Resetting local data'**
  String get resetInProgressTitle;

  /// No description provided for @resetInProgressBody.
  ///
  /// In en, this message translates to:
  /// **'Checking notification and local data cleanup.'**
  String get resetInProgressBody;

  /// No description provided for @resetWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the device to finish a notification operation. Reset is not complete. Reopening the app will resume cleanup.'**
  String get resetWaitingBody;

  /// No description provided for @resetDeletedPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Local data was deleted, but some notification cleanup is still unconfirmed.'**
  String get resetDeletedPendingBody;

  /// No description provided for @resetIncompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Reset is not complete. Only unconfirmed cleanup steps will be retried.'**
  String get resetIncompleteBody;

  /// No description provided for @resetNoIntentBody.
  ///
  /// In en, this message translates to:
  /// **'The reset record could not be verified. Reset has not been reported as complete. Please try again.'**
  String get resetNoIntentBody;

  /// No description provided for @resetCompleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Local data reset complete'**
  String get resetCompleteTitle;

  /// No description provided for @resetCompleteBody.
  ///
  /// In en, this message translates to:
  /// **'Local data and notification cleanup were verified. Close the app completely and reopen it to start again.'**
  String get resetCompleteBody;

  /// No description provided for @resetRetryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry cleanup'**
  String get resetRetryAction;

  /// No description provided for @notificationCleanupNeededStatus.
  ///
  /// In en, this message translates to:
  /// **'Off · cancellation needs checking'**
  String get notificationCleanupNeededStatus;

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

  /// Action to retry loading failed content
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get retry;

  /// Status label for an active preparation on the home card
  ///
  /// In en, this message translates to:
  /// **'Preparing'**
  String get preparationInProgress;

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

  /// Warning shown when onboarding spare time is at the minimum value
  ///
  /// In en, this message translates to:
  /// **'Minimum spare time is 10 minutes'**
  String get spareTimeMinimumWarning;

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

  /// Button text to allow alarm permission
  ///
  /// In en, this message translates to:
  /// **'Allow alarms'**
  String get allowAlarms;

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
  /// **'OnTime sends schedule preparation reminders so you can get ready on time.'**
  String get notificationPermissionDescription;

  /// Button text to allow precise schedule notification timing
  ///
  /// In en, this message translates to:
  /// **'Allow precise notifications'**
  String get allowPreciseNotifications;

  /// Title asking the user to allow alarm permission
  ///
  /// In en, this message translates to:
  /// **'Please allow alarms'**
  String get pleaseAllowAlarms;

  /// Description explaining why alarm permission is needed
  ///
  /// In en, this message translates to:
  /// **'OnTime uses alarms so preparation starts at the right moment, even when the app is closed.'**
  String get alarmPermissionDescription;

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

  /// Modal title when all preparation steps are completed before being late
  ///
  /// In en, this message translates to:
  /// **'All steps are done!'**
  String get preparationCompletedTitle;

  /// Modal content when all preparation steps are completed before being late
  ///
  /// In en, this message translates to:
  /// **'You finished every step. You can finish now or keep preparing.'**
  String get preparationCompletedDescription;

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

  /// No description provided for @finishPreparationConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Have you finished preparing?'**
  String get finishPreparationConfirmTitle;

  /// No description provided for @finishPreparationConfirmDescription.
  ///
  /// In en, this message translates to:
  /// **'Finish preparation to see your result.'**
  String get finishPreparationConfirmDescription;

  /// Center timer label shown after all preparation steps are complete and there is still time before leaving
  ///
  /// In en, this message translates to:
  /// **'Ready to go'**
  String get preparationReadyToGo;

  /// Slogan on the sign-in screen
  ///
  /// In en, this message translates to:
  /// **'We\'ll find your lost leisure.'**
  String get signInSlogan;

  /// Dialog title shown when social sign-in fails after provider authentication
  ///
  /// In en, this message translates to:
  /// **'Sign-in failed'**
  String get signInFailedTitle;

  /// Dialog description shown when social sign-in fails after provider authentication
  ///
  /// In en, this message translates to:
  /// **'Please try again in a moment.'**
  String get signInFailedDescription;

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

  /// Label for preparation time
  ///
  /// In en, this message translates to:
  /// **'Preparation Time'**
  String get preparationTime;

  /// Error shown when a preparation step name is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter a preparation name.'**
  String get preparationNameRequired;

  /// Error shown when a preparation step time is zero or negative
  ///
  /// In en, this message translates to:
  /// **'Set preparation time to at least 1 minute.'**
  String get preparationTimeMinimumError;

  /// Error shown when a preparation step time exceeds the maximum allowed minutes
  ///
  /// In en, this message translates to:
  /// **'Preparation time can be up to {minutes} minutes.'**
  String preparationTimeMaximumError(int minutes);

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

  /// Primary button text on the early-start screen to start preparing immediately
  ///
  /// In en, this message translates to:
  /// **'Start preparing now'**
  String get startPreparingNow;

  /// Secondary button text on the early-start screen to decline starting preparation now
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get notNow;

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

  /// Title for the my page screen
  ///
  /// In en, this message translates to:
  /// **'My Page'**
  String get myPageTitle;

  /// Title for the my account section
  ///
  /// In en, this message translates to:
  /// **'My Account'**
  String get myAccount;

  /// Title for the app settings section
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// Title for the account settings section
  ///
  /// In en, this message translates to:
  /// **'Account Settings'**
  String get accountSettings;

  /// Setting tile for editing default preparation and spare time
  ///
  /// In en, this message translates to:
  /// **'Edit Default Preparation / Spare Time'**
  String get editDefaultPreparation;

  /// Title of the spare-time and preparation edit screen
  ///
  /// In en, this message translates to:
  /// **'Edit spare time and preparation'**
  String get editPreparationSpareTimeHeader;

  /// Action that saves and closes an edit screen
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// Accessible label for the preparation list add button
  ///
  /// In en, this message translates to:
  /// **'Add preparation step'**
  String get addPreparationStep;

  /// Setting tile for allowing app notifications
  ///
  /// In en, this message translates to:
  /// **'Allow App Notifications'**
  String get allowAppNotifications;

  /// Setting switch label for optional privacy-safe analytics
  ///
  /// In en, this message translates to:
  /// **'Help improve OnTime'**
  String get helpImproveOnTime;

  /// Setting tile for opening the privacy policy
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Dialog message shown when the privacy policy link cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open the privacy policy. Please try again later.'**
  String get privacyPolicyOpenError;

  /// Setting tile for logging out
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get logOut;

  /// Setting tile for deleting the account
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccount;

  /// Section title for editing spare time
  ///
  /// In en, this message translates to:
  /// **'Edit spare time'**
  String get editSpareTime;

  /// Section title for editing preparation time
  ///
  /// In en, this message translates to:
  /// **'Edit preparation steps and times'**
  String get editPreparationTime;

  /// Label for total preparation time
  ///
  /// In en, this message translates to:
  /// **'Total time: '**
  String get totalTime;

  /// Warning message when schedule overlaps with next schedule
  ///
  /// In en, this message translates to:
  /// **'To avoid overlapping with \"{scheduleName}\", you need to prepare within {minutes} minutes'**
  String scheduleOverlapWarning(int minutes, String scheduleName);

  /// Error message when schedule is already overlapping with next schedule
  ///
  /// In en, this message translates to:
  /// **'Overlapped with next schedule {scheduleName}! Next schedule preparation starts at {startTime}'**
  String scheduleOverlapError(String scheduleName, String startTime);

  /// Error message when selected appointment time is in the past
  ///
  /// In en, this message translates to:
  /// **'Choose a future appointment time.'**
  String get scheduleTimePastError;

  /// Error message when schedule is already overlapping with previous schedule
  ///
  /// In en, this message translates to:
  /// **'Overlapped with \"{scheduleName}\"! You need to prepare {minutes} minutes earlier.'**
  String previousScheduleOverlapError(int minutes, String scheduleName);

  /// Confirmation text shown in the logout modal
  ///
  /// In en, this message translates to:
  /// **'Do you want to log out?'**
  String get logOutConfirm;

  /// Title of the delete account confirmation modal
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your account?'**
  String get deleteAccountConfirmTitle;

  /// Description of the delete account confirmation modal
  ///
  /// In en, this message translates to:
  /// **'This will request deletion for the account you are currently signed in with. You will be signed out when deletion succeeds.'**
  String get deleteAccountConfirmDescription;

  /// Button label to keep using the app
  ///
  /// In en, this message translates to:
  /// **'I\'ll keep using it'**
  String get keepUsing;

  /// Button label to proceed with deletion anyway
  ///
  /// In en, this message translates to:
  /// **'Delete anyway'**
  String get deleteAnyway;

  /// Title of schedule delete confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this appointment?'**
  String get scheduleDeleteConfirmTitle;

  /// Description of schedule delete confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Once deleted, this appointment cannot be restored.'**
  String get scheduleDeleteConfirmDescription;

  /// Button text to confirm schedule deletion
  ///
  /// In en, this message translates to:
  /// **'Delete appointment'**
  String get deleteScheduleConfirmAction;

  /// Title shown when schedule deletion is rejected or fails
  ///
  /// In en, this message translates to:
  /// **'Appointment cannot be deleted'**
  String get scheduleDeleteFailedTitle;

  /// Description shown when schedule deletion is rejected or fails
  ///
  /// In en, this message translates to:
  /// **'This appointment can no longer be deleted. Please refresh the calendar and try again if the status changed recently.'**
  String get scheduleDeleteFailedDescription;

  /// Delete feedback modal title
  ///
  /// In en, this message translates to:
  /// **'We hope to meet you again with a better service'**
  String get deleteFeedbackTitle;

  /// Delete feedback modal description
  ///
  /// In en, this message translates to:
  /// **'Feedback is optional. When you continue, OnTime will submit your account deletion request.'**
  String get deleteFeedbackDescription;

  /// Placeholder for delete feedback input
  ///
  /// In en, this message translates to:
  /// **'Please tell us the reason for leaving.'**
  String get deleteFeedbackPlaceholder;

  /// Button to keep using instead of deleting
  ///
  /// In en, this message translates to:
  /// **'Keep using without deleting'**
  String get keepUsingLong;

  /// Button to send feedback and delete
  ///
  /// In en, this message translates to:
  /// **'Send feedback and delete'**
  String get sendFeedbackAndDelete;

  /// Message shown when receiving 5 minutes before notification
  ///
  /// In en, this message translates to:
  /// **'Preparation starts in 5 minutes.\nWould you like to start preparing early?'**
  String get preparationStartsInFiveMinutes;

  /// Message shown when user opens schedule start before preparation start time from home, including the exact lead time
  ///
  /// In en, this message translates to:
  /// **'You\'re starting {duration} early.\nWould you like to start preparing early now?'**
  String preparationStartsEarlyBy(String duration);

  /// Fallback message shown when user opens schedule start before preparation start time from home but exact lead time is unavailable
  ///
  /// In en, this message translates to:
  /// **'You\'re a little early.\nWould you like to start preparing early now?'**
  String get preparationStartsLaterStartEarly;

  /// Notification body text for continuing preparation
  ///
  /// In en, this message translates to:
  /// **'Continue preparing'**
  String get continuePreparingNext;

  /// Dialog title when notification is already enabled
  ///
  /// In en, this message translates to:
  /// **'Notification Already Enabled'**
  String get notificationAlreadyEnabled;

  /// Dialog content when notification is already enabled
  ///
  /// In en, this message translates to:
  /// **'Schedule preparation reminders are currently active.'**
  String get notificationAlreadyEnabledDescription;

  /// Dialog title when requesting notification permission
  ///
  /// In en, this message translates to:
  /// **'Notification Permission Required'**
  String get notificationPermissionRequired;

  /// Dialog content when requesting notification permission
  ///
  /// In en, this message translates to:
  /// **'OnTime uses notifications for schedule preparation reminders and appointment alerts.\nWould you like to allow notifications?'**
  String get notificationPermissionRequiredDescription;

  /// Button text to allow permission
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get allow;

  /// Dialog title when notification permission is granted
  ///
  /// In en, this message translates to:
  /// **'Notification Permission Granted'**
  String get notificationPermissionGranted;

  /// Dialog content when notification permission is granted
  ///
  /// In en, this message translates to:
  /// **'Schedule preparation reminders are now active.'**
  String get notificationPermissionGrantedDescription;

  /// Dialog title to open notification settings
  ///
  /// In en, this message translates to:
  /// **'Allow Notifications in Settings'**
  String get openNotificationSettings;

  /// Dialog content to open notification settings
  ///
  /// In en, this message translates to:
  /// **'Notification permission was denied.\nTo receive schedule preparation reminders, please allow notifications in Settings.'**
  String get openNotificationSettingsDescription;

  /// Title asking the user to allow precise schedule notification timing
  ///
  /// In en, this message translates to:
  /// **'Precise notification permission needed'**
  String get preciseNotificationPermissionRequired;

  /// Description explaining why precise schedule notification timing is needed
  ///
  /// In en, this message translates to:
  /// **'OnTime needs this permission to notify you at the exact time to start preparing.'**
  String get preciseNotificationPermissionDescription;

  /// My Page setting label for schedule preparation notifications
  ///
  /// In en, this message translates to:
  /// **'Schedule notifications'**
  String get scheduleNotificationSetting;

  /// Status label when schedule delivery uses a real alarm experience
  ///
  /// In en, this message translates to:
  /// **'Alarm'**
  String get alarmStatus;

  /// Status label when schedule delivery uses precise notification timing
  ///
  /// In en, this message translates to:
  /// **'Precise notification'**
  String get preciseNotificationStatus;

  /// Status label when schedule delivery uses regular notifications
  ///
  /// In en, this message translates to:
  /// **'Notification'**
  String get notificationStatus;

  /// Status label when no upcoming schedule notification is armed
  ///
  /// In en, this message translates to:
  /// **'No scheduled notifications'**
  String get noScheduledNotificationStatus;

  /// Status label when notifications cannot be shown without permission
  ///
  /// In en, this message translates to:
  /// **'Notification permission needed'**
  String get notificationPermissionNeededStatus;

  /// Dialog title when exact alarm permission is required
  ///
  /// In en, this message translates to:
  /// **'Precise notification permission needed'**
  String get exactAlarmPermissionRequired;

  /// Dialog content explaining why exact alarm permission is needed
  ///
  /// In en, this message translates to:
  /// **'OnTime needs this permission to notify you at the exact time to start preparing.\nAllow alarms and reminders in Android settings.'**
  String get exactAlarmPermissionRequiredDescription;

  /// Button text to open app settings
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @notificationTimingEducationTitle.
  ///
  /// In en, this message translates to:
  /// **'Improve preparation notification timing'**
  String get notificationTimingEducationTitle;

  /// No description provided for @notificationTimingEducationDescription.
  ///
  /// In en, this message translates to:
  /// **'Notifications are on, but may arrive after preparation starts. Allow precise timing to improve scheduling. Delivery may still be delayed by the OS, battery settings, or device conditions.'**
  String get notificationTimingEducationDescription;

  /// No description provided for @notificationTimingAvailable.
  ///
  /// In en, this message translates to:
  /// **'Precise timing available'**
  String get notificationTimingAvailable;

  /// No description provided for @notificationTimingApproximate.
  ///
  /// In en, this message translates to:
  /// **'Approximate timing · precise timing can be enabled'**
  String get notificationTimingApproximate;

  /// No description provided for @notificationApproximateStatus.
  ///
  /// In en, this message translates to:
  /// **'Notification · approximate timing'**
  String get notificationApproximateStatus;

  /// No description provided for @notificationMixedTimingStatus.
  ///
  /// In en, this message translates to:
  /// **'Notification · some approximate timing'**
  String get notificationMixedTimingStatus;

  /// No description provided for @notificationIncompleteStatus.
  ///
  /// In en, this message translates to:
  /// **'Notification scheduling incomplete or needs checking'**
  String get notificationIncompleteStatus;

  /// No description provided for @notificationTimingSettings.
  ///
  /// In en, this message translates to:
  /// **'Timing settings'**
  String get notificationTimingSettings;

  /// No description provided for @startupLoadingBody.
  ///
  /// In en, this message translates to:
  /// **'Checking the data stored on this device.'**
  String get startupLoadingBody;

  /// No description provided for @startupWaitingBody.
  ///
  /// In en, this message translates to:
  /// **'Waiting for the device to respond. Please wait until the check finishes.'**
  String get startupWaitingBody;

  /// No description provided for @preparationStartFailed.
  ///
  /// In en, this message translates to:
  /// **'Preparation could not be started. Try again.'**
  String get preparationStartFailed;

  /// No description provided for @preparationStartPartial.
  ///
  /// In en, this message translates to:
  /// **'Preparation has started. Some progress storage or alarm cleanup is incomplete.'**
  String get preparationStartPartial;

  /// No description provided for @dataTitle.
  ///
  /// In en, this message translates to:
  /// **'My data'**
  String get dataTitle;

  /// No description provided for @dataBackupStatus.
  ///
  /// In en, this message translates to:
  /// **'Backup status'**
  String get dataBackupStatus;

  /// No description provided for @dataReminder.
  ///
  /// In en, this message translates to:
  /// **'Some changes have not been backed up for at least 30 days.'**
  String get dataReminder;

  /// No description provided for @dataExport.
  ///
  /// In en, this message translates to:
  /// **'Export encrypted backup'**
  String get dataExport;

  /// No description provided for @dataExportDescription.
  ///
  /// In en, this message translates to:
  /// **'Save only to the file location you choose.'**
  String get dataExportDescription;

  /// No description provided for @dataRestore.
  ///
  /// In en, this message translates to:
  /// **'Restore from backup'**
  String get dataRestore;

  /// No description provided for @dataRestoreDescription.
  ///
  /// In en, this message translates to:
  /// **'Review the backup before replacing all current data.'**
  String get dataRestoreDescription;

  /// No description provided for @dataReset.
  ///
  /// In en, this message translates to:
  /// **'Reset local data'**
  String get dataReset;

  /// No description provided for @dataResetDescription.
  ///
  /// In en, this message translates to:
  /// **'Delete all OnTime data and alarms on this device.'**
  String get dataResetDescription;

  /// No description provided for @dataChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get dataChecking;

  /// No description provided for @dataNeverExported.
  ///
  /// In en, this message translates to:
  /// **'No backup has been exported yet.'**
  String get dataNeverExported;

  /// No description provided for @dataNoChanges.
  ///
  /// In en, this message translates to:
  /// **'No changes since the last backup.'**
  String get dataNoChanges;

  /// No description provided for @dataUnexportedChanges.
  ///
  /// In en, this message translates to:
  /// **'Some changes have not been backed up.'**
  String get dataUnexportedChanges;

  /// No description provided for @dataFreshnessFailed.
  ///
  /// In en, this message translates to:
  /// **'Backup status could not be checked. Try again.'**
  String get dataFreshnessFailed;

  /// No description provided for @dataRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get dataRetry;

  /// No description provided for @dataRetryDelivery.
  ///
  /// In en, this message translates to:
  /// **'Retry notification processing only'**
  String get dataRetryDelivery;

  /// No description provided for @dataRestoreCleanupPending.
  ///
  /// In en, this message translates to:
  /// **'Data was restored, but remaining cleanup and notification processing are incomplete. Retry the remaining work without restoring data again.'**
  String get dataRestoreCleanupPending;

  /// No description provided for @dataRetryCleanup.
  ///
  /// In en, this message translates to:
  /// **'Retry remaining work'**
  String get dataRetryCleanup;

  /// No description provided for @dataRestorePartial.
  ///
  /// In en, this message translates to:
  /// **'Data was restored, but notification processing is incomplete. You can retry notification processing only.'**
  String get dataRestorePartial;

  /// No description provided for @dataUncommittedCleanup.
  ///
  /// In en, this message translates to:
  /// **'Data was not restored. Notification cleanup already began; retry notification processing for the current data.'**
  String get dataUncommittedCleanup;

  /// No description provided for @dataExportSaved.
  ///
  /// In en, this message translates to:
  /// **'Encrypted backup saved.'**
  String get dataExportSaved;

  /// No description provided for @dataExportMetadataFailed.
  ///
  /// In en, this message translates to:
  /// **'The file was saved, but backup status could not be updated. Retry checking backup status.'**
  String get dataExportMetadataFailed;

  /// No description provided for @dataRestoreComplete.
  ///
  /// In en, this message translates to:
  /// **'Backup restored.'**
  String get dataRestoreComplete;

  /// No description provided for @dataDeliveryUpdated.
  ///
  /// In en, this message translates to:
  /// **'Notification processing completed for the current data.'**
  String get dataDeliveryUpdated;

  /// No description provided for @dataBusy.
  ///
  /// In en, this message translates to:
  /// **'Another data operation is in progress. Try again after it finishes.'**
  String get dataBusy;

  /// No description provided for @dataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Local data is unavailable. Reopen the app.'**
  String get dataUnavailable;

  /// No description provided for @dataStalePreview.
  ///
  /// In en, this message translates to:
  /// **'Data changed after the preview. Select and review the backup again.'**
  String get dataStalePreview;

  /// No description provided for @dataInvalidBackup.
  ///
  /// In en, this message translates to:
  /// **'The operation could not be completed. Check the backup file and password.'**
  String get dataInvalidBackup;

  /// No description provided for @dataStagingCleanupFailed.
  ///
  /// In en, this message translates to:
  /// **'Data was not restored, and temporary file cleanup is incomplete. Reopen the app to retry cleanup.'**
  String get dataStagingCleanupFailed;

  /// No description provided for @dataOperationFailed.
  ///
  /// In en, this message translates to:
  /// **'The operation could not be completed. Try again.'**
  String get dataOperationFailed;

  /// No description provided for @dataRestorePreviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review restore'**
  String get dataRestorePreviewTitle;

  /// No description provided for @dataRestoreAction.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get dataRestoreAction;

  /// No description provided for @dataCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get dataCancel;

  /// No description provided for @dataContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get dataContinue;

  /// No description provided for @dataCreatePassword.
  ///
  /// In en, this message translates to:
  /// **'Create backup password'**
  String get dataCreatePassword;

  /// No description provided for @dataEnterPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter backup password'**
  String get dataEnterPassword;

  /// No description provided for @dataPassword.
  ///
  /// In en, this message translates to:
  /// **'Backup password'**
  String get dataPassword;

  /// No description provided for @dataPasswordHelp.
  ///
  /// In en, this message translates to:
  /// **'15–128 characters. Case and spaces are preserved.'**
  String get dataPasswordHelp;

  /// No description provided for @dataConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm backup password'**
  String get dataConfirmPassword;

  /// No description provided for @dataPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get dataPasswordMismatch;

  /// No description provided for @dataPasswordInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a backup password of 15–128 characters.'**
  String get dataPasswordInvalid;

  /// No description provided for @dataRestorePreview.
  ///
  /// In en, this message translates to:
  /// **'Backup cutoff: {cutoff}\nApp version: {version}\nSource platform: {platform}\nSchedules: {schedules}\nPreparation templates: {templates}\nDefault preparation steps: {steps}\n\nAll current local data will be replaced.'**
  String dataRestorePreview(
    String cutoff,
    String version,
    String platform,
    int schedules,
    int templates,
    int steps,
  );

  /// No description provided for @dataResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Local data could not be reset. Try again.'**
  String get dataResetFailed;

  /// No description provided for @scheduleSavedPending.
  ///
  /// In en, this message translates to:
  /// **'Schedule saved'**
  String get scheduleSavedPending;

  /// No description provided for @scheduleDeliveryPendingBody.
  ///
  /// In en, this message translates to:
  /// **'Notifications could not be updated. Retry updates notifications without saving the schedule again.'**
  String get scheduleDeliveryPendingBody;

  /// No description provided for @scheduleSaveConflict.
  ///
  /// In en, this message translates to:
  /// **'Review changes before saving'**
  String get scheduleSaveConflict;

  /// No description provided for @scheduleSaveConflictBody.
  ///
  /// In en, this message translates to:
  /// **'Local data changed after this form was opened. Your draft is preserved. A new schedule also requires review when other data changes.'**
  String get scheduleSaveConflictBody;

  /// No description provided for @scheduleReviewCurrent.
  ///
  /// In en, this message translates to:
  /// **'Review current data'**
  String get scheduleReviewCurrent;

  /// No description provided for @scheduleCreateReview.
  ///
  /// In en, this message translates to:
  /// **'Prepare a new save using the current local data. Review your draft, then press Save again.'**
  String get scheduleCreateReview;

  /// No description provided for @scheduleDraftPreserved.
  ///
  /// In en, this message translates to:
  /// **'This is the currently saved schedule. Confirm to preserve your draft and prepare a new save. Review the changes, then press Save again.'**
  String get scheduleDraftPreserved;

  /// No description provided for @scheduleSaveProtected.
  ///
  /// In en, this message translates to:
  /// **'Schedules that have started or reached preparation time cannot be edited. Your draft is preserved.'**
  String get scheduleSaveProtected;

  /// No description provided for @scheduleSaveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Unable to save. Your draft is preserved. Check the current state and preparation steps.'**
  String get scheduleSaveUnavailable;

  /// No description provided for @defaultPreferencesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load your settings. Please try again.'**
  String get defaultPreferencesLoadFailed;

  /// No description provided for @defaultPreferencesSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Settings were not saved. Your edits are still here. Please try again.'**
  String get defaultPreferencesSaveFailed;

  /// No description provided for @defaultPreferencesInvalid.
  ///
  /// In en, this message translates to:
  /// **'Check the preparation names, durations and spare time. Settings were not saved.'**
  String get defaultPreferencesInvalid;

  /// No description provided for @defaultPreferencesConflict.
  ///
  /// In en, this message translates to:
  /// **'Schedules or settings changed while you were editing. Your edits are still here and have not been saved. Reload the latest settings to review them.'**
  String get defaultPreferencesConflict;

  /// No description provided for @defaultPreferencesReloadPending.
  ///
  /// In en, this message translates to:
  /// **'Settings are saved, but refreshing the displayed data is incomplete. Retry the refresh without saving again.'**
  String get defaultPreferencesReloadPending;

  /// No description provided for @defaultPreferencesDeliveryPending.
  ///
  /// In en, this message translates to:
  /// **'Settings are saved, but notification setup is incomplete. Retry notification setup without saving again.'**
  String get defaultPreferencesDeliveryPending;

  /// No description provided for @defaultPreferencesBothPending.
  ///
  /// In en, this message translates to:
  /// **'Settings are saved, but refreshing the displayed data and notification setup are incomplete. Retry only the remaining work without saving again.'**
  String get defaultPreferencesBothPending;

  /// No description provided for @defaultPreferencesSavedStoreChanged.
  ///
  /// In en, this message translates to:
  /// **'The local operation state changed after these settings were saved. This screen will not repeat the operation. Close it and review the current settings.'**
  String get defaultPreferencesSavedStoreChanged;

  /// No description provided for @defaultPreferencesRetryFollowUp.
  ///
  /// In en, this message translates to:
  /// **'Retry remaining work'**
  String get defaultPreferencesRetryFollowUp;

  /// No description provided for @defaultPreferencesLoadLatest.
  ///
  /// In en, this message translates to:
  /// **'Reload latest settings'**
  String get defaultPreferencesLoadLatest;

  /// No description provided for @defaultPreferencesDiscardTitle.
  ///
  /// In en, this message translates to:
  /// **'Discard edits and reload?'**
  String get defaultPreferencesDiscardTitle;

  /// No description provided for @defaultPreferencesDiscardDescription.
  ///
  /// In en, this message translates to:
  /// **'Loading the latest settings replaces your unsaved edits on this screen. If loading fails, your edits stay here.'**
  String get defaultPreferencesDiscardDescription;

  /// No description provided for @defaultPreferencesMinutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String defaultPreferencesMinutes(int minutes);

  /// No description provided for @defaultPreferencesAuthorityPending.
  ///
  /// In en, this message translates to:
  /// **'Settings are saved, but the current local data could not be checked. Retry the remaining work without saving again.'**
  String get defaultPreferencesAuthorityPending;

  /// No description provided for @zonedTimeOriginal.
  ///
  /// In en, this message translates to:
  /// **'Commitment time'**
  String get zonedTimeOriginal;

  /// No description provided for @zonedTimeDevice.
  ///
  /// In en, this message translates to:
  /// **'Device time'**
  String get zonedTimeDevice;

  /// No description provided for @zonedTimeDeviceLoading.
  ///
  /// In en, this message translates to:
  /// **'Checking the device time zone.'**
  String get zonedTimeDeviceLoading;

  /// No description provided for @zonedTimeDeviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The device time zone is unavailable, so its equivalent time cannot be shown.'**
  String get zonedTimeDeviceUnavailable;

  /// No description provided for @zonedTimeDeviceOutOfRange.
  ///
  /// In en, this message translates to:
  /// **'The equivalent device date is outside the supported range. The original commitment is preserved.'**
  String get zonedTimeDeviceOutOfRange;

  /// No description provided for @zonedTimeUnknownZone.
  ///
  /// In en, this message translates to:
  /// **'Review the time zone.'**
  String get zonedTimeUnknownZone;

  /// No description provided for @zonedTimeHistoricalUnknownZone.
  ///
  /// In en, this message translates to:
  /// **'The time zone rules for this historical record are unavailable. The stored commitment is preserved.'**
  String get zonedTimeHistoricalUnknownZone;

  /// No description provided for @zonedTimeHistoricalUncertain.
  ///
  /// In en, this message translates to:
  /// **'The occurrence of this historical record is uncertain. The stored time is preserved.'**
  String get zonedTimeHistoricalUncertain;

  /// No description provided for @zonedTimeNonexistent.
  ///
  /// In en, this message translates to:
  /// **'This time does not exist in this time zone. Choose another time.'**
  String get zonedTimeNonexistent;

  /// No description provided for @zonedTimeAmbiguous.
  ///
  /// In en, this message translates to:
  /// **'This time occurs twice. Choose which occurrence to use.'**
  String get zonedTimeAmbiguous;

  /// No description provided for @zonedTimeRulesChanged.
  ///
  /// In en, this message translates to:
  /// **'Time zone rules have changed. Review the new occurrence.'**
  String get zonedTimeRulesChanged;

  /// No description provided for @zonedTimeInvalid.
  ///
  /// In en, this message translates to:
  /// **'Review the commitment time.'**
  String get zonedTimeInvalid;

  /// No description provided for @zonedTimeInstant.
  ///
  /// In en, this message translates to:
  /// **'Instant (UTC)'**
  String get zonedTimeInstant;

  /// No description provided for @zonedTimeChooseZone.
  ///
  /// In en, this message translates to:
  /// **'Choose a time zone'**
  String get zonedTimeChooseZone;

  /// No description provided for @zonedTimeSearch.
  ///
  /// In en, this message translates to:
  /// **'Search city or time zone'**
  String get zonedTimeSearch;

  /// No description provided for @zonedTimeClearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get zonedTimeClearSearch;

  /// No description provided for @zonedTimeCurrentDeviceZone.
  ///
  /// In en, this message translates to:
  /// **'Current device time zone'**
  String get zonedTimeCurrentDeviceZone;

  /// No description provided for @zonedTimeCurrentSelection.
  ///
  /// In en, this message translates to:
  /// **'Current schedule time zone'**
  String get zonedTimeCurrentSelection;

  /// No description provided for @zonedTimeDraftPreview.
  ///
  /// In en, this message translates to:
  /// **'Selection preview'**
  String get zonedTimeDraftPreview;

  /// No description provided for @zonedTimeKeepCivil.
  ///
  /// In en, this message translates to:
  /// **'Keep the wall date and time while changing the time zone. Review the commitment before saving.'**
  String get zonedTimeKeepCivil;

  /// No description provided for @zonedTimeNoMatches.
  ///
  /// In en, this message translates to:
  /// **'No matching time zones. Try a city name or IANA identifier.'**
  String get zonedTimeNoMatches;

  /// No description provided for @zonedTimeApplyDraft.
  ///
  /// In en, this message translates to:
  /// **'Apply selection'**
  String get zonedTimeApplyDraft;

  /// No description provided for @zonedTimeReviewTitle.
  ///
  /// In en, this message translates to:
  /// **'Review commitment time'**
  String get zonedTimeReviewTitle;

  /// No description provided for @zonedTimeReviewDescription.
  ///
  /// In en, this message translates to:
  /// **'Review the commitment and its time on this device before saving.'**
  String get zonedTimeReviewDescription;

  /// No description provided for @zonedTimeBefore.
  ///
  /// In en, this message translates to:
  /// **'Before change'**
  String get zonedTimeBefore;

  /// No description provided for @zonedTimeAfter.
  ///
  /// In en, this message translates to:
  /// **'Commitment to save'**
  String get zonedTimeAfter;

  /// No description provided for @zonedTimeConfirmSave.
  ///
  /// In en, this message translates to:
  /// **'Confirm and save'**
  String get zonedTimeConfirmSave;

  /// No description provided for @zonedTimeFirstOccurrence.
  ///
  /// In en, this message translates to:
  /// **'First occurrence'**
  String get zonedTimeFirstOccurrence;

  /// No description provided for @zonedTimeSecondOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Second occurrence'**
  String get zonedTimeSecondOccurrence;

  /// No description provided for @zonedTimeDetectedZone.
  ///
  /// In en, this message translates to:
  /// **'Detected device time zone'**
  String get zonedTimeDetectedZone;

  /// No description provided for @zonedTimeSelectedZone.
  ///
  /// In en, this message translates to:
  /// **'Selected by you'**
  String get zonedTimeSelectedZone;

  /// No description provided for @zonedTimeSavedZone.
  ///
  /// In en, this message translates to:
  /// **'Saved schedule time zone'**
  String get zonedTimeSavedZone;

  /// No description provided for @zonedTimeSelectUnavailableZone.
  ///
  /// In en, this message translates to:
  /// **'Device time zone unavailable. Select one to continue.'**
  String get zonedTimeSelectUnavailableZone;

  /// No description provided for @zonedTimeNextValid.
  ///
  /// In en, this message translates to:
  /// **'Review next valid time'**
  String get zonedTimeNextValid;

  /// No description provided for @zonedTimePreparationStart.
  ///
  /// In en, this message translates to:
  /// **'Preparation starts'**
  String get zonedTimePreparationStart;

  /// No description provided for @zonedCityAsiaSeoul.
  ///
  /// In en, this message translates to:
  /// **'Seoul'**
  String get zonedCityAsiaSeoul;

  /// No description provided for @zonedCityAsiaTokyo.
  ///
  /// In en, this message translates to:
  /// **'Tokyo'**
  String get zonedCityAsiaTokyo;

  /// No description provided for @zonedCityAsiaShanghai.
  ///
  /// In en, this message translates to:
  /// **'Shanghai'**
  String get zonedCityAsiaShanghai;

  /// No description provided for @zonedCityAsiaHongKong.
  ///
  /// In en, this message translates to:
  /// **'Hong Kong'**
  String get zonedCityAsiaHongKong;

  /// No description provided for @zonedCityAsiaTaipei.
  ///
  /// In en, this message translates to:
  /// **'Taipei'**
  String get zonedCityAsiaTaipei;

  /// No description provided for @zonedCityAsiaSingapore.
  ///
  /// In en, this message translates to:
  /// **'Singapore'**
  String get zonedCityAsiaSingapore;

  /// No description provided for @zonedCityAsiaBangkok.
  ///
  /// In en, this message translates to:
  /// **'Bangkok'**
  String get zonedCityAsiaBangkok;

  /// No description provided for @zonedCityAsiaDubai.
  ///
  /// In en, this message translates to:
  /// **'Dubai'**
  String get zonedCityAsiaDubai;

  /// No description provided for @zonedCityAsiaKolkata.
  ///
  /// In en, this message translates to:
  /// **'Kolkata'**
  String get zonedCityAsiaKolkata;

  /// No description provided for @zonedCityAsiaKathmandu.
  ///
  /// In en, this message translates to:
  /// **'Kathmandu'**
  String get zonedCityAsiaKathmandu;

  /// No description provided for @zonedCityEuropeLondon.
  ///
  /// In en, this message translates to:
  /// **'London'**
  String get zonedCityEuropeLondon;

  /// No description provided for @zonedCityEuropeParis.
  ///
  /// In en, this message translates to:
  /// **'Paris'**
  String get zonedCityEuropeParis;

  /// No description provided for @zonedCityEuropeBerlin.
  ///
  /// In en, this message translates to:
  /// **'Berlin'**
  String get zonedCityEuropeBerlin;

  /// No description provided for @zonedCityEuropeRome.
  ///
  /// In en, this message translates to:
  /// **'Rome'**
  String get zonedCityEuropeRome;

  /// No description provided for @zonedCityEuropeMadrid.
  ///
  /// In en, this message translates to:
  /// **'Madrid'**
  String get zonedCityEuropeMadrid;

  /// No description provided for @zonedCityEuropeMoscow.
  ///
  /// In en, this message translates to:
  /// **'Moscow'**
  String get zonedCityEuropeMoscow;

  /// No description provided for @zonedCityAmericaNewYork.
  ///
  /// In en, this message translates to:
  /// **'New York'**
  String get zonedCityAmericaNewYork;

  /// No description provided for @zonedCityAmericaLosAngeles.
  ///
  /// In en, this message translates to:
  /// **'Los Angeles'**
  String get zonedCityAmericaLosAngeles;

  /// No description provided for @zonedCityAmericaChicago.
  ///
  /// In en, this message translates to:
  /// **'Chicago'**
  String get zonedCityAmericaChicago;

  /// No description provided for @zonedCityAmericaDenver.
  ///
  /// In en, this message translates to:
  /// **'Denver'**
  String get zonedCityAmericaDenver;

  /// No description provided for @zonedCityAmericaToronto.
  ///
  /// In en, this message translates to:
  /// **'Toronto'**
  String get zonedCityAmericaToronto;

  /// No description provided for @zonedCityAmericaVancouver.
  ///
  /// In en, this message translates to:
  /// **'Vancouver'**
  String get zonedCityAmericaVancouver;

  /// No description provided for @zonedCityAmericaSaoPaulo.
  ///
  /// In en, this message translates to:
  /// **'Sao Paulo'**
  String get zonedCityAmericaSaoPaulo;

  /// No description provided for @zonedCityAustraliaSydney.
  ///
  /// In en, this message translates to:
  /// **'Sydney'**
  String get zonedCityAustraliaSydney;

  /// No description provided for @zonedCityAustraliaMelbourne.
  ///
  /// In en, this message translates to:
  /// **'Melbourne'**
  String get zonedCityAustraliaMelbourne;

  /// No description provided for @zonedCityAustraliaPerth.
  ///
  /// In en, this message translates to:
  /// **'Perth'**
  String get zonedCityAustraliaPerth;

  /// No description provided for @zonedCityAustraliaLordHowe.
  ///
  /// In en, this message translates to:
  /// **'Lord Howe'**
  String get zonedCityAustraliaLordHowe;

  /// No description provided for @zonedCityPacificAuckland.
  ///
  /// In en, this message translates to:
  /// **'Auckland'**
  String get zonedCityPacificAuckland;

  /// No description provided for @zonedCityPacificHonolulu.
  ///
  /// In en, this message translates to:
  /// **'Honolulu'**
  String get zonedCityPacificHonolulu;

  /// No description provided for @zonedCityPacificApia.
  ///
  /// In en, this message translates to:
  /// **'Apia'**
  String get zonedCityPacificApia;

  /// No description provided for @zonedCityAfricaCairo.
  ///
  /// In en, this message translates to:
  /// **'Cairo'**
  String get zonedCityAfricaCairo;

  /// No description provided for @zonedCityAfricaJohannesburg.
  ///
  /// In en, this message translates to:
  /// **'Johannesburg'**
  String get zonedCityAfricaJohannesburg;

  /// No description provided for @zonedCityUtc.
  ///
  /// In en, this message translates to:
  /// **'UTC'**
  String get zonedCityUtc;

  /// No description provided for @zonedTimeHomeDateBasis.
  ///
  /// In en, this message translates to:
  /// **'Today · device date'**
  String get zonedTimeHomeDateBasis;

  /// No description provided for @zonedTimeCalendarDateBasis.
  ///
  /// In en, this message translates to:
  /// **'Calendar · commitment date'**
  String get zonedTimeCalendarDateBasis;

  /// No description provided for @zonedTimeDateBasisTitle.
  ///
  /// In en, this message translates to:
  /// **'Why dates can differ'**
  String get zonedTimeDateBasisTitle;

  /// No description provided for @zonedTimeDateBasisDescription.
  ///
  /// In en, this message translates to:
  /// **'Today on Home groups appointments by the current device date. The month calendar places each appointment on its original commitment date and time zone. The same instant can fall on different dates, so both dates and zones are shown when they differ.'**
  String get zonedTimeDateBasisDescription;

  /// No description provided for @zonedTimeAllReviewedOccurrences.
  ///
  /// In en, this message translates to:
  /// **'View all reviewed occurrences'**
  String get zonedTimeAllReviewedOccurrences;

  /// No description provided for @zonedTimeReviewScopeOccurrence.
  ///
  /// In en, this message translates to:
  /// **'Changes: this occurrence'**
  String get zonedTimeReviewScopeOccurrence;

  /// No description provided for @zonedTimeReviewScopeFollowing.
  ///
  /// In en, this message translates to:
  /// **'Changes: this and following occurrences'**
  String get zonedTimeReviewScopeFollowing;

  /// No description provided for @zonedTimeReviewScopeNew.
  ///
  /// In en, this message translates to:
  /// **'New recurring schedule'**
  String get zonedTimeReviewScopeNew;

  /// No description provided for @zonedTimePreparationUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The preparation start cannot be displayed with the available time zone rules. Review it again before saving.'**
  String get zonedTimePreparationUnavailable;

  /// No description provided for @homeNextAppointment.
  ///
  /// In en, this message translates to:
  /// **'Next appointment'**
  String get homeNextAppointment;

  /// No description provided for @homePreparationInProgress.
  ///
  /// In en, this message translates to:
  /// **'Preparation in progress'**
  String get homePreparationInProgress;

  /// No description provided for @homePreparationPrompt.
  ///
  /// In en, this message translates to:
  /// **'Appointment to prepare for'**
  String get homePreparationPrompt;

  /// No description provided for @homePreviouslyCheckedAppointment.
  ///
  /// In en, this message translates to:
  /// **'Previously checked appointment'**
  String get homePreviouslyCheckedAppointment;

  /// No description provided for @homeCheckingAppointments.
  ///
  /// In en, this message translates to:
  /// **'Checking upcoming appointments.'**
  String get homeCheckingAppointments;

  /// No description provided for @homeNoUpcomingAppointments.
  ///
  /// In en, this message translates to:
  /// **'No upcoming appointments.'**
  String get homeNoUpcomingAppointments;

  /// No description provided for @homeQueryFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check appointments. Please try again.'**
  String get homeQueryFailed;

  /// No description provided for @homeQueryCancelled.
  ///
  /// In en, this message translates to:
  /// **'Appointment checking was cancelled. You can review your appointments in the calendar.'**
  String get homeQueryCancelled;

  /// No description provided for @homeQueryInterrupted.
  ///
  /// In en, this message translates to:
  /// **'Appointment checking was interrupted. Continue checking when you are ready.'**
  String get homeQueryInterrupted;

  /// No description provided for @homeQueryLimited.
  ///
  /// In en, this message translates to:
  /// **'Could not check all appointments. Review your appointments or repeat settings in the calendar.'**
  String get homeQueryLimited;

  /// No description provided for @homeQueryStale.
  ///
  /// In en, this message translates to:
  /// **'These are previously checked details. Recheck them before starting preparation from this card.'**
  String get homeQueryStale;

  /// No description provided for @homeRetryQuery.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get homeRetryQuery;

  /// No description provided for @homeContinueQuery.
  ///
  /// In en, this message translates to:
  /// **'Continue checking'**
  String get homeContinueQuery;

  /// No description provided for @homeCancelQuery.
  ///
  /// In en, this message translates to:
  /// **'Cancel checking'**
  String get homeCancelQuery;

  /// No description provided for @homeTimeIssues.
  ///
  /// In en, this message translates to:
  /// **'Some appointment times need review. Check their dates and time zones in the calendar.'**
  String get homeTimeIssues;

  /// No description provided for @homeReviewCalendar.
  ///
  /// In en, this message translates to:
  /// **'Review calendar'**
  String get homeReviewCalendar;

  /// No description provided for @scheduleDeletionRemovedTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule history removed'**
  String get scheduleDeletionRemovedTitle;

  /// No description provided for @scheduleDeletionComplete.
  ///
  /// In en, this message translates to:
  /// **'The schedule history and its delivery registrations have been removed.'**
  String get scheduleDeletionComplete;

  /// No description provided for @scheduleDeletionCleaning.
  ///
  /// In en, this message translates to:
  /// **'History has been removed. Delivery cleanup is in progress.'**
  String get scheduleDeletionCleaning;

  /// No description provided for @scheduleDeletionPending.
  ///
  /// In en, this message translates to:
  /// **'History has been removed, but delivery cleanup is not yet confirmed. You can retry when the current operation finishes.'**
  String get scheduleDeletionPending;

  /// No description provided for @scheduleDeletionPreparationActive.
  ///
  /// In en, this message translates to:
  /// **'Preparation is in progress. Finish it on the preparation screen before deleting this schedule.'**
  String get scheduleDeletionPreparationActive;

  /// No description provided for @scheduleDeletionConsequences.
  ///
  /// In en, this message translates to:
  /// **'The selected schedule’s details, private preparation and outcome will be removed. Other schedules, shared content and existing punctuality totals are preserved. There is no undo in the app. Restoring an older exported backup can bring this history back.'**
  String get scheduleDeletionConsequences;

  /// No description provided for @scheduleDeletionFollowing.
  ///
  /// In en, this message translates to:
  /// **'Delete this and later unstarted occurrences.'**
  String get scheduleDeletionFollowing;

  /// No description provided for @scheduleDeletionOnlySelected.
  ///
  /// In en, this message translates to:
  /// **'Delete only the selected schedule. Other schedules and recurrence rules are preserved.'**
  String get scheduleDeletionOnlySelected;

  /// No description provided for @scheduleDeletionAlreadyAbsent.
  ///
  /// In en, this message translates to:
  /// **'This schedule is already absent from the current data. No additional data was deleted.'**
  String get scheduleDeletionAlreadyAbsent;

  /// No description provided for @scheduleDeletionRetryCleanup.
  ///
  /// In en, this message translates to:
  /// **'Retry delivery cleanup'**
  String get scheduleDeletionRetryCleanup;

  /// No description provided for @scheduleDeletionAbsentTitle.
  ///
  /// In en, this message translates to:
  /// **'Schedule already absent'**
  String get scheduleDeletionAbsentTitle;

  /// No description provided for @scheduleDeletionFollowingConsequences.
  ///
  /// In en, this message translates to:
  /// **'Delete this and following upcoming, unstarted occurrences in this series and stop generating later occurrences. Individually edited following occurrences are also included. Their names, notes and preparation content that no other schedule shares will be removed. Past history, active or preparation-frozen occurrences, other series, shared content and existing punctuality totals are preserved. There is no undo in the app. Existing exported backup files are unchanged; restoring an older backup can bring back deleted occurrences and their recurrence.'**
  String get scheduleDeletionFollowingConsequences;
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
    'that was used.',
  );
}
