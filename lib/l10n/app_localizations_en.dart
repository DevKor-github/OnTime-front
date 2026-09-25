// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get detailedNotificationTitle =>
      'Show schedule names in notifications';

  @override
  String get detailedNotificationPrivacy =>
      'Shows the schedule name and a differing time zone on the lock screen. Places, notes and preparation details stay private.';

  @override
  String get detailedNotificationLoading => 'Checking setting';

  @override
  String get detailedNotificationReadFailed =>
      'Unable to read the setting. Check the saved value again.';

  @override
  String get detailedNotificationUnavailable =>
      'Check the setting again after the local data operation finishes.';

  @override
  String get detailedNotificationRequestOn => 'On requested · not saved yet';

  @override
  String get detailedNotificationRequestOff => 'Off requested · not saved yet';

  @override
  String get detailedNotificationSavedOn => 'Saved: on';

  @override
  String get detailedNotificationSavedOff => 'Saved: off';

  @override
  String get detailedNotificationSaveFailed =>
      'The requested change could not be saved and has not been applied.';

  @override
  String get detailedNotificationApplying =>
      'Applying the saved setting to notifications';

  @override
  String get detailedNotificationDelayed =>
      'The device is taking longer to respond. Notification changes are still being checked.';

  @override
  String get detailedNotificationApplied =>
      'Applied to current notification registrations';

  @override
  String get detailedNotificationOff => 'Schedule notifications are off.';

  @override
  String get detailedNotificationEmpty =>
      'There are no upcoming notifications to update.';

  @override
  String get detailedNotificationPermission =>
      'Check notification permission. The saved setting is kept.';

  @override
  String get detailedNotificationCancellation =>
      'Existing notifications may still show a schedule name. Check notification cleanup again.';

  @override
  String get detailedNotificationSchedulingFailed =>
      'Some notifications could not be scheduled. Apply notifications again.';

  @override
  String get detailedNotificationNeedsCheck =>
      'Notification changes could not be confirmed. Check again.';

  @override
  String get detailedNotificationHeld =>
      'New detailed notifications are on hold until the off request is resolved. Existing notifications may remain.';

  @override
  String get detailedNotificationRetry => 'Check or apply again';

  @override
  String get startupRecoveryTitle => 'Unable to start OnTime';

  @override
  String get startupRecoveryBody =>
      'OnTime could not verify local data. Please try again shortly.';

  @override
  String get startupRetryAction => 'Try again';

  @override
  String get restartRequiredBody => 'Close the app completely, then reopen it.';

  @override
  String get resetInProgressTitle => 'Resetting local data';

  @override
  String get resetInProgressBody =>
      'Checking notification and local data cleanup.';

  @override
  String get resetWaitingBody =>
      'Waiting for the device to finish a notification operation. Reset is not complete. Reopening the app will resume cleanup.';

  @override
  String get resetDeletedPendingBody =>
      'Local data was deleted, but some notification cleanup is still unconfirmed.';

  @override
  String get resetIncompleteBody =>
      'Reset is not complete. Only unconfirmed cleanup steps will be retried.';

  @override
  String get resetNoIntentBody =>
      'The reset record could not be verified. Reset has not been reported as complete. Please try again.';

  @override
  String get resetCompleteTitle => 'Local data reset complete';

  @override
  String get resetCompleteBody =>
      'Local data and notification cleanup were verified. Close the app completely and reopen it to start again.';

  @override
  String get resetRetryAction => 'Retry cleanup';

  @override
  String get notificationCleanupNeededStatus =>
      'Off · cancellation needs checking';

  @override
  String get calendarTitle => 'Calendar';

  @override
  String get error => 'Error';

  @override
  String get retry => 'Try again';

  @override
  String get preparationInProgress => 'Preparing';

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
  String get spareTimeMinimumWarning => 'Minimum spare time is 10 minutes';

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
  String get allowAlarms => 'Allow alarms';

  @override
  String get doItLater => 'I\'ll do it later.';

  @override
  String get pleaseAllowNotifications => 'Please allow notifications';

  @override
  String get notificationPermissionDescription =>
      'OnTime sends schedule preparation reminders so you can get ready on time.';

  @override
  String get allowPreciseNotifications => 'Allow precise notifications';

  @override
  String get pleaseAllowAlarms => 'Please allow alarms';

  @override
  String get alarmPermissionDescription =>
      'OnTime uses alarms so preparation starts at the right moment, even when the app is closed.';

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
  String get preparationCompletedTitle => 'All steps are done!';

  @override
  String get preparationCompletedDescription =>
      'You finished every step. You can finish now or keep preparing.';

  @override
  String get continuePreparing => 'Continue Preparing';

  @override
  String get finishPreparation => 'Finish Preparation';

  @override
  String get finishPreparationConfirmTitle => 'Have you finished preparing?';

  @override
  String get finishPreparationConfirmDescription =>
      'Finish preparation to see your result.';

  @override
  String get preparationReadyToGo => 'Ready to go';

  @override
  String get signInSlogan => 'We\'ll find your lost leisure.';

  @override
  String get signInFailedTitle => 'Sign-in failed';

  @override
  String get signInFailedDescription => 'Please try again in a moment.';

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
  String get preparationTime => 'Preparation Time';

  @override
  String get preparationNameRequired => 'Please enter a preparation name.';

  @override
  String get preparationTimeMinimumError =>
      'Set preparation time to at least 1 minute.';

  @override
  String preparationTimeMaximumError(int minutes) {
    return 'Preparation time can be up to $minutes minutes.';
  }

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
  String get startPreparingNow => 'Start preparing now';

  @override
  String get notNow => 'Not now';

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
  String get editPreparationSpareTimeHeader =>
      'Edit spare time and preparation';

  @override
  String get done => 'Done';

  @override
  String get addPreparationStep => 'Add preparation step';

  @override
  String get allowAppNotifications => 'Allow App Notifications';

  @override
  String get helpImproveOnTime => 'Help improve OnTime';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicyOpenError =>
      'Could not open the privacy policy. Please try again later.';

  @override
  String get logOut => 'Log out';

  @override
  String get deleteAccount => 'Delete account';

  @override
  String get editSpareTime => 'Edit spare time';

  @override
  String get editPreparationTime => 'Edit preparation steps and times';

  @override
  String get totalTime => 'Total time: ';

  @override
  String scheduleOverlapWarning(int minutes, String scheduleName) {
    return 'To avoid overlapping with \"$scheduleName\", you need to prepare within $minutes minutes';
  }

  @override
  String scheduleOverlapError(String scheduleName, String startTime) {
    return 'Overlapped with next schedule $scheduleName! Next schedule preparation starts at $startTime';
  }

  @override
  String get scheduleTimePastError => 'Choose a future appointment time.';

  @override
  String previousScheduleOverlapError(int minutes, String scheduleName) {
    return 'Overlapped with \"$scheduleName\"! You need to prepare $minutes minutes earlier.';
  }

  @override
  String get logOutConfirm => 'Do you want to log out?';

  @override
  String get deleteAccountConfirmTitle =>
      'Are you sure you want to delete your account?';

  @override
  String get deleteAccountConfirmDescription =>
      'This will request deletion for the account you are currently signed in with. You will be signed out when deletion succeeds.';

  @override
  String get keepUsing => 'I\'ll keep using it';

  @override
  String get deleteAnyway => 'Delete anyway';

  @override
  String get scheduleDeleteConfirmTitle =>
      'Are you sure you want to delete this appointment?';

  @override
  String get scheduleDeleteConfirmDescription =>
      'Once deleted, this appointment cannot be restored.';

  @override
  String get deleteScheduleConfirmAction => 'Delete appointment';

  @override
  String get scheduleDeleteFailedTitle => 'Appointment cannot be deleted';

  @override
  String get scheduleDeleteFailedDescription =>
      'This appointment can no longer be deleted. Please refresh the calendar and try again if the status changed recently.';

  @override
  String get deleteFeedbackTitle =>
      'We hope to meet you again with a better service';

  @override
  String get deleteFeedbackDescription =>
      'Feedback is optional. When you continue, OnTime will submit your account deletion request.';

  @override
  String get deleteFeedbackPlaceholder =>
      'Please tell us the reason for leaving.';

  @override
  String get keepUsingLong => 'Keep using without deleting';

  @override
  String get sendFeedbackAndDelete => 'Send feedback and delete';

  @override
  String get preparationStartsInFiveMinutes =>
      'Preparation starts in 5 minutes.\nWould you like to start preparing early?';

  @override
  String preparationStartsEarlyBy(String duration) {
    return 'You\'re starting $duration early.\nWould you like to start preparing early now?';
  }

  @override
  String get preparationStartsLaterStartEarly =>
      'You\'re a little early.\nWould you like to start preparing early now?';

  @override
  String get continuePreparingNext => 'Continue preparing';

  @override
  String get notificationAlreadyEnabled => 'Notification Already Enabled';

  @override
  String get notificationAlreadyEnabledDescription =>
      'Schedule preparation reminders are currently active.';

  @override
  String get notificationPermissionRequired =>
      'Notification Permission Required';

  @override
  String get notificationPermissionRequiredDescription =>
      'OnTime uses notifications for schedule preparation reminders and appointment alerts.\nWould you like to allow notifications?';

  @override
  String get allow => 'Allow';

  @override
  String get notificationPermissionGranted => 'Notification Permission Granted';

  @override
  String get notificationPermissionGrantedDescription =>
      'Schedule preparation reminders are now active.';

  @override
  String get openNotificationSettings => 'Allow Notifications in Settings';

  @override
  String get openNotificationSettingsDescription =>
      'Notification permission was denied.\nTo receive schedule preparation reminders, please allow notifications in Settings.';

  @override
  String get preciseNotificationPermissionRequired =>
      'Precise notification permission needed';

  @override
  String get preciseNotificationPermissionDescription =>
      'OnTime needs this permission to notify you at the exact time to start preparing.';

  @override
  String get scheduleNotificationSetting => 'Schedule notifications';

  @override
  String get alarmStatus => 'Alarm';

  @override
  String get preciseNotificationStatus => 'Precise notification';

  @override
  String get notificationStatus => 'Notification';

  @override
  String get noScheduledNotificationStatus => 'No scheduled notifications';

  @override
  String get notificationPermissionNeededStatus =>
      'Notification permission needed';

  @override
  String get exactAlarmPermissionRequired =>
      'Precise notification permission needed';

  @override
  String get exactAlarmPermissionRequiredDescription =>
      'OnTime needs this permission to notify you at the exact time to start preparing.\nAllow alarms and reminders in Android settings.';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get notificationTimingEducationTitle =>
      'Improve preparation notification timing';

  @override
  String get notificationTimingEducationDescription =>
      'Notifications are on, but may arrive after preparation starts. Allow precise timing to improve scheduling. Delivery may still be delayed by the OS, battery settings, or device conditions.';

  @override
  String get notificationTimingAvailable => 'Precise timing available';

  @override
  String get notificationTimingApproximate =>
      'Approximate timing · precise timing can be enabled';

  @override
  String get notificationApproximateStatus =>
      'Notification · approximate timing';

  @override
  String get notificationMixedTimingStatus =>
      'Notification · some approximate timing';

  @override
  String get notificationIncompleteStatus =>
      'Notification scheduling incomplete or needs checking';

  @override
  String get notificationTimingSettings => 'Timing settings';

  @override
  String get startupLoadingBody => 'Checking the data stored on this device.';

  @override
  String get startupWaitingBody =>
      'Waiting for the device to respond. Please wait until the check finishes.';

  @override
  String get preparationStartFailed =>
      'Preparation could not be started. Try again.';

  @override
  String get preparationStartPartial =>
      'Preparation has started. Some progress storage or alarm cleanup is incomplete.';

  @override
  String get dataTitle => 'My data';

  @override
  String get dataBackupStatus => 'Backup status';

  @override
  String get dataReminder =>
      'Some changes have not been backed up for at least 30 days.';

  @override
  String get dataExport => 'Export encrypted backup';

  @override
  String get dataExportDescription =>
      'Save only to the file location you choose.';

  @override
  String get dataRestore => 'Restore from backup';

  @override
  String get dataRestoreDescription =>
      'Review the backup before replacing all current data.';

  @override
  String get dataReset => 'Reset local data';

  @override
  String get dataResetDescription =>
      'Delete all OnTime data and alarms on this device.';

  @override
  String get dataChecking => 'Checking';

  @override
  String get dataNeverExported => 'No backup has been exported yet.';

  @override
  String get dataNoChanges => 'No changes since the last backup.';

  @override
  String get dataUnexportedChanges => 'Some changes have not been backed up.';

  @override
  String get dataFreshnessFailed =>
      'Backup status could not be checked. Try again.';

  @override
  String get dataRetry => 'Try again';

  @override
  String get dataRetryDelivery => 'Retry notification processing only';

  @override
  String get dataRestoreCleanupPending =>
      'Data was restored, but remaining cleanup and notification processing are incomplete. Retry the remaining work without restoring data again.';

  @override
  String get dataRetryCleanup => 'Retry remaining work';

  @override
  String get dataRestorePartial =>
      'Data was restored, but notification processing is incomplete. You can retry notification processing only.';

  @override
  String get dataUncommittedCleanup =>
      'Data was not restored. Notification cleanup already began; retry notification processing for the current data.';

  @override
  String get dataExportSaved => 'Encrypted backup saved.';

  @override
  String get dataExportMetadataFailed =>
      'The file was saved, but backup status could not be updated. Retry checking backup status.';

  @override
  String get dataRestoreComplete => 'Backup restored.';

  @override
  String get dataDeliveryUpdated =>
      'Notification processing completed for the current data.';

  @override
  String get dataBusy =>
      'Another data operation is in progress. Try again after it finishes.';

  @override
  String get dataUnavailable => 'Local data is unavailable. Reopen the app.';

  @override
  String get dataStalePreview =>
      'Data changed after the preview. Select and review the backup again.';

  @override
  String get dataInvalidBackup =>
      'The operation could not be completed. Check the backup file and password.';

  @override
  String get dataStagingCleanupFailed =>
      'Data was not restored, and temporary file cleanup is incomplete. Reopen the app to retry cleanup.';

  @override
  String get dataOperationFailed =>
      'The operation could not be completed. Try again.';

  @override
  String get dataRestorePreviewTitle => 'Review restore';

  @override
  String get dataRestoreAction => 'Restore';

  @override
  String get dataCancel => 'Cancel';

  @override
  String get dataContinue => 'Continue';

  @override
  String get dataCreatePassword => 'Create backup password';

  @override
  String get dataEnterPassword => 'Enter backup password';

  @override
  String get dataPassword => 'Backup password';

  @override
  String get dataPasswordHelp =>
      '15–128 characters. Case and spaces are preserved.';

  @override
  String get dataConfirmPassword => 'Confirm backup password';

  @override
  String get dataPasswordMismatch => 'Passwords do not match.';

  @override
  String get dataPasswordInvalid =>
      'Enter a backup password of 15–128 characters.';

  @override
  String dataRestorePreview(
    String cutoff,
    String version,
    String platform,
    int schedules,
    int templates,
    int steps,
  ) {
    return 'Backup cutoff: $cutoff\nApp version: $version\nSource platform: $platform\nSchedules: $schedules\nPreparation templates: $templates\nDefault preparation steps: $steps\n\nAll current local data will be replaced.';
  }

  @override
  String get dataResetFailed => 'Local data could not be reset. Try again.';

  @override
  String get scheduleSavedPending => 'Schedule saved';

  @override
  String get scheduleDeliveryPendingBody =>
      'Notifications could not be updated. Retry updates notifications without saving the schedule again.';

  @override
  String get scheduleSaveConflict => 'Review changes before saving';

  @override
  String get scheduleSaveConflictBody =>
      'Local data changed after this form was opened. Your draft is preserved. A new schedule also requires review when other data changes.';

  @override
  String get scheduleReviewCurrent => 'Review current data';

  @override
  String get scheduleCreateReview =>
      'Prepare a new save using the current local data. Review your draft, then press Save again.';

  @override
  String get scheduleDraftPreserved =>
      'This is the currently saved schedule. Confirm to preserve your draft and prepare a new save. Review the changes, then press Save again.';

  @override
  String get scheduleSaveProtected =>
      'Schedules that have started or reached preparation time cannot be edited. Your draft is preserved.';

  @override
  String get scheduleSaveUnavailable =>
      'Unable to save. Your draft is preserved. Check the current state and preparation steps.';

  @override
  String get defaultPreferencesLoadFailed =>
      'Could not load your settings. Please try again.';

  @override
  String get defaultPreferencesSaveFailed =>
      'Settings were not saved. Your edits are still here. Please try again.';

  @override
  String get defaultPreferencesInvalid =>
      'Check the preparation names, durations and spare time. Settings were not saved.';

  @override
  String get defaultPreferencesConflict =>
      'Schedules or settings changed while you were editing. Your edits are still here and have not been saved. Reload the latest settings to review them.';

  @override
  String get defaultPreferencesReloadPending =>
      'Settings are saved, but refreshing the displayed data is incomplete. Retry the refresh without saving again.';

  @override
  String get defaultPreferencesDeliveryPending =>
      'Settings are saved, but notification setup is incomplete. Retry notification setup without saving again.';

  @override
  String get defaultPreferencesBothPending =>
      'Settings are saved, but refreshing the displayed data and notification setup are incomplete. Retry only the remaining work without saving again.';

  @override
  String get defaultPreferencesSavedStoreChanged =>
      'The local operation state changed after these settings were saved. This screen will not repeat the operation. Close it and review the current settings.';

  @override
  String get defaultPreferencesRetryFollowUp => 'Retry remaining work';

  @override
  String get defaultPreferencesLoadLatest => 'Reload latest settings';

  @override
  String get defaultPreferencesDiscardTitle => 'Discard edits and reload?';

  @override
  String get defaultPreferencesDiscardDescription =>
      'Loading the latest settings replaces your unsaved edits on this screen. If loading fails, your edits stay here.';

  @override
  String defaultPreferencesMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get defaultPreferencesAuthorityPending =>
      'Settings are saved, but the current local data could not be checked. Retry the remaining work without saving again.';

  @override
  String get zonedTimeOriginal => 'Commitment time';

  @override
  String get zonedTimeDevice => 'Device time';

  @override
  String get zonedTimeDeviceLoading => 'Checking the device time zone.';

  @override
  String get zonedTimeDeviceUnavailable =>
      'The device time zone is unavailable, so its equivalent time cannot be shown.';

  @override
  String get zonedTimeDeviceOutOfRange =>
      'The equivalent device date is outside the supported range. The original commitment is preserved.';

  @override
  String get zonedTimeUnknownZone => 'Review the time zone.';

  @override
  String get zonedTimeHistoricalUnknownZone =>
      'The time zone rules for this historical record are unavailable. The stored commitment is preserved.';

  @override
  String get zonedTimeHistoricalUncertain =>
      'The occurrence of this historical record is uncertain. The stored time is preserved.';

  @override
  String get zonedTimeNonexistent =>
      'This time does not exist in this time zone. Choose another time.';

  @override
  String get zonedTimeAmbiguous =>
      'This time occurs twice. Choose which occurrence to use.';

  @override
  String get zonedTimeRulesChanged =>
      'Time zone rules have changed. Review the new occurrence.';

  @override
  String get zonedTimeInvalid => 'Review the commitment time.';

  @override
  String get zonedTimeInstant => 'Instant (UTC)';

  @override
  String get zonedTimeChooseZone => 'Choose a time zone';

  @override
  String get zonedTimeSearch => 'Search city or time zone';

  @override
  String get zonedTimeClearSearch => 'Clear search';

  @override
  String get zonedTimeCurrentDeviceZone => 'Current device time zone';

  @override
  String get zonedTimeCurrentSelection => 'Current schedule time zone';

  @override
  String get zonedTimeDraftPreview => 'Selection preview';

  @override
  String get zonedTimeKeepCivil =>
      'Keep the wall date and time while changing the time zone. Review the commitment before saving.';

  @override
  String get zonedTimeNoMatches =>
      'No matching time zones. Try a city name or IANA identifier.';

  @override
  String get zonedTimeApplyDraft => 'Apply selection';

  @override
  String get zonedTimeReviewTitle => 'Review commitment time';

  @override
  String get zonedTimeReviewDescription =>
      'Review the commitment and its time on this device before saving.';

  @override
  String get zonedTimeBefore => 'Before change';

  @override
  String get zonedTimeAfter => 'Commitment to save';

  @override
  String get zonedTimeConfirmSave => 'Confirm and save';

  @override
  String get zonedTimeFirstOccurrence => 'First occurrence';

  @override
  String get zonedTimeSecondOccurrence => 'Second occurrence';

  @override
  String get zonedTimeDetectedZone => 'Detected device time zone';

  @override
  String get zonedTimeSelectedZone => 'Selected by you';

  @override
  String get zonedTimeSavedZone => 'Saved schedule time zone';

  @override
  String get zonedTimeSelectUnavailableZone =>
      'Device time zone unavailable. Select one to continue.';

  @override
  String get zonedTimeNextValid => 'Review next valid time';

  @override
  String get zonedTimePreparationStart => 'Preparation starts';

  @override
  String get zonedCityAsiaSeoul => 'Seoul';

  @override
  String get zonedCityAsiaTokyo => 'Tokyo';

  @override
  String get zonedCityAsiaShanghai => 'Shanghai';

  @override
  String get zonedCityAsiaHongKong => 'Hong Kong';

  @override
  String get zonedCityAsiaTaipei => 'Taipei';

  @override
  String get zonedCityAsiaSingapore => 'Singapore';

  @override
  String get zonedCityAsiaBangkok => 'Bangkok';

  @override
  String get zonedCityAsiaDubai => 'Dubai';

  @override
  String get zonedCityAsiaKolkata => 'Kolkata';

  @override
  String get zonedCityAsiaKathmandu => 'Kathmandu';

  @override
  String get zonedCityEuropeLondon => 'London';

  @override
  String get zonedCityEuropeParis => 'Paris';

  @override
  String get zonedCityEuropeBerlin => 'Berlin';

  @override
  String get zonedCityEuropeRome => 'Rome';

  @override
  String get zonedCityEuropeMadrid => 'Madrid';

  @override
  String get zonedCityEuropeMoscow => 'Moscow';

  @override
  String get zonedCityAmericaNewYork => 'New York';

  @override
  String get zonedCityAmericaLosAngeles => 'Los Angeles';

  @override
  String get zonedCityAmericaChicago => 'Chicago';

  @override
  String get zonedCityAmericaDenver => 'Denver';

  @override
  String get zonedCityAmericaToronto => 'Toronto';

  @override
  String get zonedCityAmericaVancouver => 'Vancouver';

  @override
  String get zonedCityAmericaSaoPaulo => 'Sao Paulo';

  @override
  String get zonedCityAustraliaSydney => 'Sydney';

  @override
  String get zonedCityAustraliaMelbourne => 'Melbourne';

  @override
  String get zonedCityAustraliaPerth => 'Perth';

  @override
  String get zonedCityAustraliaLordHowe => 'Lord Howe';

  @override
  String get zonedCityPacificAuckland => 'Auckland';

  @override
  String get zonedCityPacificHonolulu => 'Honolulu';

  @override
  String get zonedCityPacificApia => 'Apia';

  @override
  String get zonedCityAfricaCairo => 'Cairo';

  @override
  String get zonedCityAfricaJohannesburg => 'Johannesburg';

  @override
  String get zonedCityUtc => 'UTC';

  @override
  String get zonedTimeHomeDateBasis => 'Today · device date';

  @override
  String get zonedTimeCalendarDateBasis => 'Calendar · commitment date';

  @override
  String get zonedTimeDateBasisTitle => 'Why dates can differ';

  @override
  String get zonedTimeDateBasisDescription =>
      'Today on Home groups appointments by the current device date. The month calendar places each appointment on its original commitment date and time zone. The same instant can fall on different dates, so both dates and zones are shown when they differ.';

  @override
  String get zonedTimeAllReviewedOccurrences => 'View all reviewed occurrences';

  @override
  String get zonedTimeReviewScopeOccurrence => 'Changes: this occurrence';

  @override
  String get zonedTimeReviewScopeFollowing =>
      'Changes: this and following occurrences';

  @override
  String get zonedTimeReviewScopeNew => 'New recurring schedule';

  @override
  String get zonedTimePreparationUnavailable =>
      'The preparation start cannot be displayed with the available time zone rules. Review it again before saving.';

  @override
  String get homeNextAppointment => 'Next appointment';

  @override
  String get homePreparationInProgress => 'Preparation in progress';

  @override
  String get homePreparationPrompt => 'Appointment to prepare for';

  @override
  String get homePreviouslyCheckedAppointment =>
      'Previously checked appointment';

  @override
  String get homeCheckingAppointments => 'Checking upcoming appointments.';

  @override
  String get homeNoUpcomingAppointments => 'No upcoming appointments.';

  @override
  String get homeQueryFailed =>
      'Could not check appointments. Please try again.';

  @override
  String get homeQueryCancelled =>
      'Appointment checking was cancelled. You can review your appointments in the calendar.';

  @override
  String get homeQueryInterrupted =>
      'Appointment checking was interrupted. Continue checking when you are ready.';

  @override
  String get homeQueryLimited =>
      'Could not check all appointments. Review your appointments or repeat settings in the calendar.';

  @override
  String get homeQueryStale =>
      'These are previously checked details. Recheck them before starting preparation from this card.';

  @override
  String get homeRetryQuery => 'Retry';

  @override
  String get homeContinueQuery => 'Continue checking';

  @override
  String get homeCancelQuery => 'Cancel checking';

  @override
  String get homeTimeIssues =>
      'Some appointment times need review. Check their dates and time zones in the calendar.';

  @override
  String get homeReviewCalendar => 'Review calendar';

  @override
  String get scheduleDeletionRemovedTitle => 'Schedule history removed';

  @override
  String get scheduleDeletionComplete =>
      'The schedule history and its delivery registrations have been removed.';

  @override
  String get scheduleDeletionCleaning =>
      'History has been removed. Delivery cleanup is in progress.';

  @override
  String get scheduleDeletionPending =>
      'History has been removed, but delivery cleanup is not yet confirmed. You can retry when the current operation finishes.';

  @override
  String get scheduleDeletionPreparationActive =>
      'Preparation is in progress. Finish it on the preparation screen before deleting this schedule.';

  @override
  String get scheduleDeletionConsequences =>
      'The selected schedule’s details, private preparation and outcome will be removed. Other schedules, shared content and existing punctuality totals are preserved. There is no undo in the app. Restoring an older exported backup can bring this history back.';

  @override
  String get scheduleDeletionFollowing =>
      'Delete this and later unstarted occurrences.';

  @override
  String get scheduleDeletionOnlySelected =>
      'Delete only the selected schedule. Other schedules and recurrence rules are preserved.';

  @override
  String get scheduleDeletionAlreadyAbsent =>
      'This schedule is already absent from the current data. No additional data was deleted.';

  @override
  String get scheduleDeletionRetryCleanup => 'Retry delivery cleanup';

  @override
  String get scheduleDeletionAbsentTitle => 'Schedule already absent';

  @override
  String get scheduleDeletionFollowingConsequences =>
      'Delete this and following upcoming, unstarted occurrences in this series and stop generating later occurrences. Individually edited following occurrences are also included. Their names, notes and preparation content that no other schedule shares will be removed. Past history, active or preparation-frozen occurrences, other series, shared content and existing punctuality totals are preserved. There is no undo in the app. Existing exported backup files are unchanged; restoring an older backup can bring back deleted occurrences and their recurrence.';
}
