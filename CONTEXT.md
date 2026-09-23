# OnTime Front

This context defines product language for the local-only OnTime app so release
and feature discussions use the same terms.

## Language

**Local-only OnTime**:
The OnTime product whose active user data exists only in the current app installation and whose normal behavior never depends on a remote service.
_Avoid_: Offline-first, local cache mode, standalone mode

**Local Profile**:
The single installation-bound, non-identifying profile that owns Schedules, Places, Preparations, outcomes, and preferences.
_Avoid_: Account, login, member, OnTime User

**Schedule Outcome**:
The final local result of completing one Schedule as On Time, Late, or Abnormal.
_Avoid_: Server result, analytics event, transient completion screen

**Schedule History**:
Past and completed Schedule details retained locally until the user explicitly deletes the Schedule.
_Avoid_: Server archive, analytics history, automatic retention window, score aggregate

**Local Punctuality Score**:
The percentage of eligible Schedule Outcomes completed On Time since the latest Punctuality Score Reset.
_Avoid_: Server score, lifetime score, reward points, zero before first result

**Punctuality Score Reset**:
A user action that starts a new Local Punctuality Score aggregation period without deleting Schedules or their outcomes.
_Avoid_: Local Data Reset, schedule deletion, account reset

**OnTime Backup**:
A platform-neutral encrypted copy of local OnTime data that can move between Android and iOS and is created or restored only by an explicit user action.
_Avoid_: Sync, cloud backup, server backup, replication

**Backup Password**:
A secret chosen during export and required to unlock that specific OnTime Backup.
_Avoid_: Account password, login password, device passcode, recovery code

**Backup Cryptographic Suite**:
The versioned password-key-derivation and authenticated-encryption rules used by one OnTime Backup.
_Avoid_: Installation Data Key, database cipher, custom encryption, unspecified password protection

**Backup Restore**:
An explicit user action that atomically replaces active local data with the contents of a validated OnTime Backup.
_Avoid_: Import, merge, synchronization, partial restore

**Restore Preview**:
The post-validation summary and final confirmation shown before Backup Restore may replace active data.
_Avoid_: File picker, unverified metadata, automatic restore, progress screen

**Durable OnTime Data**:
User content, outcomes, and app preferences expected to survive app restarts and Backup Restore.
_Avoid_: Cache, active timer, device permission, alarm registration

**Local Data Store**:
The authoritative encrypted installation database that contains every item of Durable OnTime Data.
_Avoid_: Local cache, remote replica, preferences file, synchronization store

**Reconstructible App State**:
Temporary, derived, or device-specific state that OnTime can rebuild without losing Durable OnTime Data.
_Avoid_: User content, durable preference, backup source, second source of truth

**Recovery Mode**:
A restricted startup state used when OnTime cannot safely open or migrate the Local Data Store without risking data loss.
_Avoid_: Automatic reset, empty profile, guest mode, migration fallback

**Backup Format Version**:
The declared version that identifies how an OnTime Backup must be decoded, validated, and migrated.
_Avoid_: App version, database version, release number

**Backup Cutoff**:
The single committed Local Data Store point in time represented by one OnTime Backup.
_Avoid_: Export completion time, moving synchronization window, mixed read times

**Backup Freshness**:
The local status comparing current Durable OnTime Data with the Backup Cutoff of the most recent successful export on this installation.
_Avoid_: File-existence guarantee, automatic backup status, restore status, cloud sync state

**Local-only Transition**:
The release boundary where OnTime stops using remote identity and data and begins with installation-owned Local Profiles.
_Avoid_: Server migration, account migration, synchronization rollout

**Legacy Installation State**:
The incomplete caches, credentials, delivery records, and runtime state left by a server-backed OnTime installation before the Local-only Transition.
_Avoid_: Durable OnTime Data, migration source, OnTime Backup, recoverable account data

**Local-only Cutover Marker**:
The installation-local record that the one-way cleanup from server-backed OnTime has completed.
_Avoid_: Feature flag, server migration token, account state, Backup Format Version

**Supported Product Platform**:
A mobile platform on which Local-only OnTime promises its complete data, notification, alarm, backup, and restore behavior.
_Avoid_: Build target, development preview, Widgetbook host

**User-Initiated External Navigation**:
An explicit user choice to leave OnTime and open a public legal, support, email, or store destination in an operating-system app.
_Avoid_: API request, embedded WebView, automatic redirect, background fetch

**Product Network Boundary**:
The release guarantee that Local-only OnTime cannot initiate a network request from its product runtime.
_Avoid_: Offline mode, unused server client, best-effort network avoidance, debug transport

**Offline Cold Start**:
The release scenario where a clean Android or iOS installation completes first launch and all core product flows in airplane mode.
_Avoid_: Warm cache test, reconnect fallback, preloaded account, partial offline mode

**Platform-Managed Data Transfer**:
An operating-system backup, restore, or device-transfer path initiated outside OnTime's explicit backup flow.
_Avoid_: OnTime Backup, Backup Restore, supported recovery

**Installation Data Key**:
A randomly generated device-bound secret that unlocks Durable OnTime Data within one app installation.
_Avoid_: Backup Password, account secret, device passcode, recovery key

**Schedule Notification Coverage**:
The nearest future Schedules currently armed for delivery within a Supported Product Platform's capacity.
_Avoid_: Seven-day window, server alarm window, synchronized delivery queue

**Private Notification Content**:
The default lock-screen delivery text that identifies OnTime and the preparation prompt without revealing Schedule details.
_Avoid_: Empty notification, disabled delivery, encrypted notification

**Detailed Notification Content**:
User-enabled lock-screen delivery text that may reveal a Schedule name and its differing Schedule Time Zone, but never its Place, note, or Preparation details.
_Avoid_: Default notification, full Schedule detail, unrestricted preview

**Local Data Reset**:
A destructive user action that removes every OnTime-owned datum and delivery registration from the current installation.
_Avoid_: Account deletion, logout, cache clear, server deletion

**Schedule Time Zone**:
The named time zone that fixes the intended civil date and time of one Schedule.
_Avoid_: Current device time zone, UTC offset, display locale

**Nonexistent Schedule Time**:
A civil time that does not occur in the selected Schedule Time Zone because its clock moves forward.
_Avoid_: Invalid date, past time, automatically adjusted time

**Ambiguous Schedule Time**:
A civil time that occurs twice in the selected Schedule Time Zone because its clock moves backward.
_Avoid_: Duplicate Schedule, repeated notification, unspecified offset

**Schedule**:
A planned commitment with an intended time, destination place, travel time, and optional preparation plan.
_Avoid_: Alarm, notification, calendar row

**Place**:
The destination or location label attached to a Schedule.
_Avoid_: Route, address record, notification location

**Preparation**:
An ordered plan of steps the user intends to complete before leaving for a Schedule.
_Avoid_: Reminder, notification, alarm

**Preparation Step**:
One named action in a Preparation with an expected duration.
_Avoid_: UI row, checklist widget, notification step

**Schedule**:
A planned commitment with a target time that OnTime helps the user prepare for.
_Avoid_: Event, appointment, alarm

**Preparation**:
The ordered set of steps a user completes before a Schedule.
_Avoid_: Preparation chain, task list

**Preparation Step**:
One named action with an expected duration inside a Preparation.
_Avoid_: Task, checklist item, alarm step

**Schedule**:
A planned commitment with a place, appointment time, travel time, optional buffer time, and preparation.
_Avoid_: Event, appointment record

**Preparation**:
An ordered set of steps and durations used to get ready for a Schedule.
_Avoid_: Routine, prep checklist

**Preparation Step**:
One named action in a Preparation with its own expected duration.
_Avoid_: Task, todo, subroutine

**Preparation Start Moment**:
The intended time for the user to begin Preparation so the Schedule can still be met on time.
_Avoid_: Alarm time, notification time, wake-up time

**Schedule Preparation Session**:
The active period when a user is working through Preparation for one Schedule.
_Avoid_: Schedule run, preparation runtime, alarm session

**Early Start Session**:
A Schedule Preparation Session that the user starts before the Preparation Start Moment.
_Avoid_: Manual start, premature alarm, early alarm

**Preparation Duration**:
The sum of a Schedule's Preparation step durations, excluding move time and Schedule Spare Time.
_Avoid_: Total duration, travel time, buffer time

**Schedule Spare Time**:
A user buffer before a Schedule's appointment time, separate from travel time and Preparation Duration.
_Avoid_: Preparation time, move time

**Default Preparation**:
The user's fallback Preparation for new Schedules.
_Avoid_: Base preparation, global preparation

**Recurring Schedule (반복 일정)**:
A series of scheduled commitments governed by a shared repetition rule.
_Avoid_: Repeating alarm, duplicated notification

**Recurring Schedule Preparation (반복 일정 전용 준비과정)**:
A Preparation independently owned by one Recurring Schedule and reused for its scheduled commitments, separate from the default or template it was copied from.
_Avoid_: Default Preparation, one-off Custom Preparation

**Schedule Occurrence (일정 회차)**:
One individual Schedule belonging to a Recurring Schedule.
_Avoid_: Recurring Schedule, repeated notification

**Unrecorded Schedule Occurrence (진행 기록 없는 회차)**:
A past Schedule Occurrence with no recorded preparation activity or Schedule Outcome.
_Avoid_: Late Schedule, completed Schedule, deleted occurrence

**Custom Preparation**:
A Schedule-specific Preparation that differs from the user's fallback or selected template.
_Avoid_: Changed preparation, edited default

**Preparation Mode**:
The category describing whether a Schedule uses Default Preparation, a preparation template, or Custom Preparation.
_Avoid_: Preparation type, preparation source

**Schedule Notification**:
A user-facing notification that starts preparation for a scheduled commitment at the intended moment.
_Avoid_: Schedule alarm, alarm, push

**Schedule Notification Setting**:
The user-facing setting that controls whether OnTime sends notifications for upcoming schedule preparation.
_Avoid_: Schedule alarm setting, alarm switch

**Alarm**:
An alarm experience that opens an OnTime screen over the lock screen or current app without the user first tapping a notification.
_Avoid_: Notification, alert, push

**iOS AlarmKit Alarm**:
The iOS alarm experience OnTime may use when the device and build support AlarmKit.
_Avoid_: iOS notification, fallback notification

**Android Schedule Notification**:
The Android presentation that alerts the user through a notification instead of an Alarm.
_Avoid_: Android alarm, native alarm UI

**Precise Notification Timing**:
The expectation that a Schedule Notification is delivered at the intended preparation start moment.
_Avoid_: Best-effort reminder, approximate notification

**Fallback Notification**:
A secondary delivery path used only when Precise Notification Timing is unavailable.
_Avoid_: Alarm, alarm permission

**Exact Timing Permission**:
The user's permission for OnTime to schedule notifications at precise times on devices that require it.
_Avoid_: Alarm permission, notification permission

**No Scheduled Notification**:
The state where notifications are enabled but no Schedule Notification is currently armed for an upcoming schedule.
_Avoid_: Pending, waiting, permission pending

**Approximate Notification Timing**:
The state where OnTime may notify the user for a schedule but cannot guarantee delivery at the exact preparation time.
_Avoid_: Disabled notifications, alarm denied

**Precise Notification Status**:
The user-facing status for a Schedule Notification that can be delivered with Precise Notification Timing.
_Avoid_: Native alarm, exact alarm

**Notification Status**:
The user-facing status for schedule delivery through notifications when Alarm delivery or Precise Notification Timing is unavailable.
_Avoid_: Fallback, degraded, time sensitive

**Alarm Status**:
The user-facing status for schedule delivery through an Alarm.
_Avoid_: Notification, native alarm

**Preparation Run**:
One user attempt to prepare for a scheduled commitment.
_Avoid_: Timer session, countdown session

**Preparation Action Event**:
A user-performed action that changes a Preparation Run.
_Avoid_: Timer tick, automatic step transition, elapsed-time snapshot

**Schedule**:
A user commitment with a planned time and preparation context in OnTime.
_Avoid_: Appointment, event, task

**Monthly Calendar**:
The calendar surface that shows Schedules grouped by day across a calendar month.
_Avoid_: Month view, calendar grid

**Calendar Month Range**:
A contiguous span of calendar months whose Schedules are in scope for a Monthly Calendar.
_Avoid_: Loaded range, stream range, cached range

## Relationships

- **Local-only OnTime** keeps Schedules, Places, Preparations, and preferences within one app installation.
- **Local-only OnTime** may use device-provided notification and alarm capabilities without involving a remote service.
- **Local-only OnTime** has exactly one **Local Profile** per app installation.
- A **Local Profile** has no name, email address, social identity, credential, authentication token, or logout state.
- An **OnTime Backup** may exist outside the app installation in a location chosen and controlled by the user.
- **Local-only OnTime** does not automatically create, upload, download, or synchronize an **OnTime Backup**.
- An **OnTime Backup** must be unlocked before its contents can be restored or inspected.
- Every **OnTime Backup** is protected by the **Backup Password** chosen for that export.
- OnTime cannot retrieve, reset, or recover a forgotten **Backup Password**.
- OnTime does not remember a **Backup Password** after an export or restore attempt ends.
- Losing a **Backup Password** makes only that OnTime Backup unusable and does not alter active local data.
- A Backup Password contains 15 through 128 Unicode characters and remains within the backup format's bounded encoded size.
- A Backup Password accepts Unicode, spaces, and symbols without requiring mixtures of character classes; it remains case-sensitive and preserves leading and trailing spaces.
- Export requires the same Backup Password to be entered twice, while restore requires the complete password once.
- OnTime permits pasting a Backup Password but does not save it, autofill it, create a hint, or provide recovery.
- Every OnTime Backup declares one supported **Backup Cryptographic Suite** and fresh per-backup cryptographic material.
- A Backup Cryptographic Suite authenticates encrypted content, required plaintext header fields, chunk order, and stream completion; any tampering, reordering, or truncation invalidates the backup.
- OnTime rejects unsupported or unsafe cryptographic parameters before allocating attacker-controlled resources or changing active data.
- Backup cryptography uses a reviewed library implementation and never a custom cipher or password-key-derivation construction.
- A **Backup Restore** validates the complete OnTime Backup before changing active local data.
- A successful **Backup Restore** replaces rather than merges the current Local Profile data.
- A failed **Backup Restore** leaves the current Local Profile data unchanged.
- An **OnTime Backup** contains all **Durable OnTime Data**, including the Local Profile, onboarding state, Schedules, Places, Preparations, retained outcomes, and app preferences.
- An **OnTime Backup** excludes an active Preparation Run, Early Start Session, device identifier, scheduled-notification registry, operating-system permission, cache, and log.
- A successful **Backup Restore** recalculates Schedule Notifications from restored future Schedules instead of restoring device-specific registrations.
- **Durable OnTime Data** is encrypted while stored in the current app installation as well as when exported in an OnTime Backup.
- Every **OnTime Backup** declares exactly one **Backup Format Version** independently of the app and local database versions.
- An OnTime Backup exported on Android can be restored on iOS, and one exported on iOS can be restored on Android.
- An OnTime Backup represents Durable OnTime Data in a platform-neutral form rather than copying the encrypted Local Data Store file.
- An OnTime Backup declares its creation time, contained data categories and counts, encryption parameters, and integrity metadata.
- Backup Restore validates and migrates the complete backup in a staging Local Data Store before atomically replacing active data.
- Backup Restore rejects content that the destination platform or supported format cannot represent before changing active data.
- Backup Restore never carries over the source Installation Data Key, permissions, notification identifiers, or operating-system delivery registrations.
- Every OnTime Backup represents exactly one **Backup Cutoff** established from a consistent Local Data Store snapshot.
- Durable OnTime Data committed after the Backup Cutoff remains active but is excluded from that OnTime Backup.
- After OnTime captures the Backup Cutoff snapshot, the user may continue using the app while encryption and file writing finish.
- OnTime exposes a completed backup file only after encryption, integrity verification, and file writing all succeed; cancellation or failure does not leave a file presented as a valid OnTime Backup.
- The backup creation time shown to the user is the Backup Cutoff, not the later file-writing completion time.
- **Backup Freshness** is Never Exported, No Changes Since Export, or Unexported Changes based only on the latest successful export and later Durable OnTime Data revisions.
- OnTime records the latest successful export's Backup Cutoff but does not retain its destination, file permission, or Backup Password.
- Backup Restore does not change Backup Freshness to No Changes Since Export; only a successful export on the current installation does.
- When Durable OnTime Data remains unexported for 30 days, OnTime shows a non-blocking in-app backup reminder without scheduling a system notification or disabling another feature.
- For a Local Profile that has never exported, the 30-day period begins with its first Durable OnTime Data creation.
- A **Backup Restore** migrates every older released Backup Format Version forward before replacing active data.
- A **Backup Restore** rejects an unknown newer Backup Format Version before changing active data and directs the user to update OnTime.
- Backup Restore decrypts and completely validates an OnTime Backup before showing a **Restore Preview**.
- A Restore Preview shows the Backup Cutoff, source app version, contained data categories and counts, and that active local data will be replaced.
- Backup Restore requires explicit final confirmation from the Restore Preview before it may replace the Local Data Store.
- Cancelling a Restore Preview removes its staging data and leaves active data unchanged.
- Backup Cutoff, source app version, data categories, and counts remain encrypted inside an OnTime Backup; its plaintext header contains only values required to identify and decrypt the format.
- The **Local-only Transition** never signs in to or fetches data from the legacy OnTime server.
- A new or upgraded installation after the **Local-only Transition** creates a new Local Profile and encrypted Local Data Store through onboarding.
- The Local-only Transition does not reinterpret **Legacy Installation State** as Durable OnTime Data or attempt to reconstruct partial Schedules and Preparations from it.
- The Local-only Transition removes Legacy Installation State, including credentials, remote caches, delivery records, and active sessions, before onboarding and resumes that cleanup after interruption.
- Remote-only records and Legacy Installation State are not recoverable through Local-only OnTime; future installation transfer uses only an OnTime Backup.
- The **Local-only Cutover Marker** is written only after legacy cleanup succeeds and makes the Local-only Transition idempotent across later launches.
- The encrypted Local Data Store uses an identity distinct from every legacy database so a server-backed build cannot open or overwrite it.
- A product release contains only the local-only runtime; it does not ship a server/local feature flag, login fallback, or remote recovery path.
- Returning to a server-backed app version after the Local-only Cutover Marker is not a supported operation.
- Failure after cutover enters Recovery Mode and never reactivates the legacy server runtime.
- Android and iOS are the only **Supported Product Platforms**.
- Web and desktop builds are not **Supported Product Platforms**; a Web build may exist only for development and visual verification.
- Privacy information required for normal use is available within OnTime without network access.
- **User-Initiated External Navigation** is the only product action that may open a network-capable external app.
- **User-Initiated External Navigation** must not include Local Profile data, Schedule identifiers, installation identifiers, or other user data in its destination.
- Every Android and iOS release satisfies the **Product Network Boundary** without relying on runtime connectivity checks or an offline toggle.
- The Product Network Boundary excludes User-Initiated External Navigation because the operating-system destination, not OnTime, performs any resulting network access.
- Debug-only transport used by Flutter development tooling is not product behavior and must not be present in a release artifact.
- Every Android and iOS release passes an **Offline Cold Start** from a clean installation.
- Offline Cold Start covers onboarding, Local Profile creation, Schedule, Place, and Preparation management, calendar and home views, Local Punctuality Score, local delivery settings, OnTime Backup, Backup Restore, and bundled legal information.
- Images, fonts, localizations, time-zone rules, legal text, and every other resource required by Offline Cold Start ship inside the release artifact.
- Failure to complete User-Initiated External Navigation while offline leaves OnTime data and navigation state valid and explains that the external destination is unavailable.
- **Platform-Managed Data Transfer** is not a supported OnTime backup or recovery path.
- OnTime excludes its active data from **Platform-Managed Data Transfer** wherever the Supported Product Platform exposes such control.
- OnTime does not promise that every operating system or device manufacturer will honor the requested exclusion.
- Each app installation has exactly one **Installation Data Key** stored only in device-bound secure storage.
- The **Installation Data Key** is not synchronized, backed up, exported, or included in an OnTime Backup.
- OnTime uses the **Installation Data Key** without requiring a Backup Password or biometric prompt during normal app use.
- Losing the **Installation Data Key** makes active Durable OnTime Data unreadable; recovery requires a readable OnTime Backup or a destructive local-data reset.
- Local-only OnTime does not add an app-specific PIN or biometric lock; access control remains the responsibility of the Supported Product Platform's device lock.
- Creating or changing a future Schedule immediately attempts to include it in **Schedule Notification Coverage**, regardless of how far away it is.
- **Schedule Notification Coverage** prioritizes the nearest eligible future Schedules when platform capacity is limited.
- OnTime recalculates **Schedule Notification Coverage** after app launch or resume, Schedule mutation, Backup Restore, reboot, time or time-zone change, and relevant permission change.
- A future Schedule beyond current platform capacity is reconsidered during the next recalculation rather than being promised immediate delivery.
- **Private Notification Content** is the default for every new Local Profile.
- Private Notification Content does not reveal a Schedule name, Place, note, Preparation name, or Preparation Step on the lock screen.
- The user may explicitly enable **Detailed Notification Content**, which may reveal only the Schedule name and a differing Schedule Time Zone.
- Opening either notification mode routes to full Schedule information only through operating-system device access control.
- The selected notification-content mode is a durable preference included in OnTime Backup.
- A **Local Data Reset** removes the Local Profile, all Durable OnTime Data, active sessions, device-specific state, scheduled notifications and alarms, the encrypted database, and the Installation Data Key.
- A **Local Data Reset** does not and cannot remove an OnTime Backup previously exported outside the app installation.
- An interrupted **Local Data Reset** resumes cleanup on the next launch before OnTime permits creation of a new Local Profile.
- Every Schedule has exactly one **Schedule Time Zone** captured when the Schedule is created or explicitly changed.
- A new Schedule defaults to the current named device time zone, and its creation and edit flows allow the user to select another Schedule Time Zone.
- Changing the device time zone does not change a Schedule's intended civil date and time in its **Schedule Time Zone**.
- Schedule Notification timing is recalculated from the Schedule Time Zone after a device time-zone change.
- An OnTime Backup preserves each Schedule's intended civil date, time, and **Schedule Time Zone**.
- A Schedule displays its intended civil date, time, and **Schedule Time Zone** as the primary commitment time.
- When the device time zone differs, the Schedule also displays the equivalent current-device date and time; when they match, it does not duplicate the time.
- A Schedule Notification using Detailed Notification Content identifies the Schedule Time Zone when it differs from the current device time zone.
- OnTime rejects a **Nonexistent Schedule Time** and identifies the next valid civil time without selecting it automatically.
- An **Ambiguous Schedule Time** requires the user to choose one of the two represented offsets before saving.
- A Schedule and its OnTime Backup preserve the user's chosen occurrence of an **Ambiguous Schedule Time**.
- Time-zone rules are updated only through an OnTime app release, not through a runtime network request.
- After a time-zone rule update, a future Schedule keeps its intended civil date, time, and Schedule Time Zone while OnTime recalculates its absolute instant and Schedule Notification.
- OnTime identifies future Schedules whose absolute notification time changed because of a time-zone rule update; completed and past Schedules remain unchanged.
- The **Local Data Store** is the only authoritative persistence boundary for Durable OnTime Data.
- All durable preferences belong to the Local Data Store together with the Local Profile and user content.
- Storage outside the Local Data Store may contain only the Installation Data Key or **Reconstructible App State** and must not become a second source of Durable OnTime Data.
- OnTime Backup, Backup Restore, and Local Data Reset operate against the Local Data Store as one consistent data boundary.
- A Local Data Store schema migration is atomic: failure leaves the previously readable database state unchanged.
- OnTime enters **Recovery Mode** instead of automatically deleting or recreating a Local Data Store that cannot be opened or migrated.
- Recovery Mode preserves the Local Data Store and Installation Data Key until a Backup Restore succeeds or the user explicitly performs Local Data Reset.
- Recovery Mode permits only retrying startup, Backup Restore, and Local Data Reset; normal product screens and background Schedule Notification processing remain unavailable.
- Only On Time and Late Schedule Outcomes are eligible for the **Local Punctuality Score**; an Abnormal outcome is excluded.
- The Local Punctuality Score equals the On Time eligible outcome count divided by all eligible outcomes since the latest **Punctuality Score Reset**, multiplied by 100.
- With no eligible outcome since the latest Punctuality Score Reset, the Local Punctuality Score is not yet calculated rather than zero.
- Completing a Schedule and registering its eligible score contribution form one atomic local operation, and one Schedule contributes at most once.
- Deleting a completed Schedule does not retroactively change a Local Punctuality Score contribution already registered.
- A Punctuality Score Reset does not delete Schedules or Schedule Outcomes; Local Data Reset removes the complete score history.
- An OnTime Backup preserves the Local Punctuality Score aggregation basis and its latest reset boundary.
- **Schedule History** has no age-based or storage-based automatic expiration.
- Deleting a Schedule removes its name, Place, note, Preparation, Schedule Outcome detail, delivery registrations, and appearance in current backup data.
- After a completed Schedule is deleted, only its non-identifying On Time or Late aggregate contribution may remain for Local Punctuality Score continuity.
- Restoring an OnTime Backup may reintroduce a Schedule deleted after that backup's Backup Cutoff, and Restore Preview warns about that replacement effect.
- A **Schedule** has one effective **Preparation** for calculating preparation timing.
- A **Default Preparation** may seed a new **Schedule** before the user chooses a different preparation.
- A **Custom Preparation** belongs to one **Schedule**.
- A **Recurring Schedule** owns one **Recurring Schedule Preparation**, reused across its scheduled commitments.
- Each **Schedule Occurrence** belongs to exactly one **Recurring Schedule** and may have its own **Custom Preparation**.
- A **Monthly Calendar** displays **Schedules** grouped by calendar day.
- A **Calendar Month Range** starts at the first day of its first month and ends before the first day of the month after its last month.
- A **Monthly Calendar** may extend a **Calendar Month Range** when the user moves to an adjacent month.
- A **Local Profile** may own zero or more **Schedules**.
- A **Schedule** has one **Place**.
- A **Schedule** may use one **Preparation**.
- A **Preparation** contains zero or more **Preparation Steps** in user-defined order.
- A **Preparation Step** belongs to exactly one **Preparation**.
- A **Schedule Notification** uses **Schedule** and **Preparation** timing, but is not itself a **Schedule** or **Preparation**.
- A **Schedule** may have one **Preparation** for that specific commitment.
- A **Preparation** contains zero or more **Preparation Steps** in user-defined order.
- A user's default **Preparation** may be applied to a **Schedule** and then changed for that Schedule.
- A **Schedule** has a **Preparation** whose **Preparation Duration** contributes to preparation-start timing.
- **Preparation Duration**, move time, and **Schedule Spare Time** are distinct schedule timing inputs.
- User-facing copy should call a scheduled notification a **Schedule Notification**, not an **Alarm**, unless it opens an OnTime screen without the user first tapping a notification.
- A **Schedule** has one active **Preparation** selection.
- A **Preparation** contains one or more ordered **Preparation Steps**.
- A **Preparation Start Moment** is derived from the **Schedule**, **Preparation**, movement time, and spare time.
- A **Schedule Preparation Session** belongs to exactly one **Schedule**.
- An **Early Start Session** is a **Schedule Preparation Session** started before the **Preparation Start Moment**.
- A **Schedule Notification** may prompt the user to begin a **Schedule Preparation Session** at the **Preparation Start Moment**.
- The profile setting for upcoming schedule preparation delivery should be called **Schedule Notification Setting**.
- On iOS, user-facing copy may say **Alarm** only when OnTime can deliver an **iOS AlarmKit Alarm**.
- iOS permission prompts should use alarm language only when requesting an **iOS AlarmKit Alarm**; otherwise they should use notification language.
- When an **iOS AlarmKit Alarm** is unavailable or denied but notifications are allowed, user-facing status should say notification rather than expose Time Sensitive terminology.
- A **Schedule Notification** should use **Precise Notification Timing** when the user's device supports it and **Exact Timing Permission** is granted.
- A **Fallback Notification** may back up a **Schedule Notification**, but it does not satisfy **Exact Timing Permission**.
- On Android, OnTime should use an **Android Schedule Notification** unless **Alarm** policy approval is available.
- Android permission prompts for scheduled preparation delivery should say notification, not alarm, unless OnTime is requesting or explaining an **Alarm** experience.
- Android **Exact Timing Permission** copy should explain that the permission is needed to notify the user at the exact preparation time.
- **Exact Timing Permission** is granted only when the device reports it as granted, not when the user taps a permission request button.
- **No Scheduled Notification** does not indicate a missing **Exact Timing Permission**.
- Missing **Exact Timing Permission** means **Approximate Notification Timing**, not disabled notifications, when notification permission is granted.
- Android with **Precise Notification Timing** should show **Precise Notification Status**.
- Android without **Precise Notification Timing** but with notification permission should show **Notification Status**.
- iOS with an **iOS AlarmKit Alarm** should show **Alarm Status**.
- iOS without an available **iOS AlarmKit Alarm** but with notification permission should show **Notification Status**.
- **No Scheduled Notification** should be the user-facing empty state across platforms, even when future delivery may use an **Alarm**.
- A **Preparation Run** records **Preparation Action Events**, not timer ticks or automatic step transitions.
- A **Preparation Action Event** may represent starting preparation, skipping a preparation step, or finishing preparation.
- A **Preparation Run** begins when the user performs the starting **Preparation Action Event**.
- A skipped preparation step ends at the skip **Preparation Action Event** time; its unused planned duration is not treated as elapsed preparation time.
- The current step and completion state of a **Preparation Run** are derived from its starting action, user-performed **Preparation Action Events**, and the current time.
- Automatic step transitions are derived states, not **Preparation Action Events**.
- A **Preparation Run** must not outlive the scheduled commitment it belongs to.
## Example dialogue

> **Dev:** "If the user taps Start before the scheduled notification, is that a separate schedule run?"
> **Domain expert:** "No - it is an **Early Start Session**, which is still the **Schedule Preparation Session** for that **Schedule**."

> **Dev:** "Can a **Schedule Notification** replace the **Schedule** if the user taps it?"
> **Domain expert:** "No. The **Schedule Notification** only prompts preparation for the **Schedule**; the **Schedule** remains the planned commitment."
>
> **Dev:** "Does a lock-screen notification reveal my Schedule name by default?"
> **Domain expert:** "No. Private Notification Content is the default; Schedule name and a differing time zone appear only after you enable Detailed Notification Content."
>
> **Dev:** "Will **Local-only OnTime** synchronize a Schedule after the device reconnects?"
> **Domain expert:** "No. Reconnection changes nothing because the Schedule belongs only to this app installation."
>
> **Dev:** "Can I move my Schedules to a new phone without an account?"
> **Domain expert:** "Yes. Export an **OnTime Backup** yourself, then explicitly restore it on the new installation."
>
> **Dev:** "Can that new phone use the other supported mobile platform?"
> **Domain expert:** "Yes. The OnTime Backup is platform-neutral and restores between Android and iOS after full validation."
>
> **Dev:** "If I edit a Schedule while its backup file is still being encrypted, is that edit inside the backup?"
> **Domain expert:** "Only if it committed before the Backup Cutoff. Later edits remain active and belong in the next backup."
>
> **Dev:** "Does a Fresh backup status prove that the exported file still exists?"
> **Domain expert:** "No. Backup Freshness records the last successful export boundary; the user remains responsible for the external file."
>
> **Dev:** "Can OnTime reset the **Backup Password** if I forget it?"
> **Domain expert:** "No. If the old installation still has the active data, create a new **OnTime Backup** with a new password."
>
> **Dev:** "Can a backup still restore if an encrypted chunk was removed or reordered?"
> **Domain expert:** "No. Its Backup Cryptographic Suite authenticates the complete ordered stream and rejects any altered or incomplete backup."
>
> **Dev:** "Does OnTime require an uppercase letter, number, and symbol in a Backup Password?"
> **Domain expert:** "No. It requires sufficient length, accepts Unicode and spaces, and preserves the complete case-sensitive password."
>
> **Dev:** "Will a **Backup Restore** combine my current Schedules with the backup?"
> **Domain expert:** "No. It validates the whole backup first and then replaces the current Local Profile data as one operation."
>
> **Dev:** "Can choosing a valid backup file immediately overwrite my current data?"
> **Domain expert:** "No. OnTime first shows a Restore Preview and replaces data only after your final confirmation."
>
> **Dev:** "Will restoring a backup resume the timer that was running on my old phone?"
> **Domain expert:** "No. Active sessions are not **Durable OnTime Data**; OnTime restores the Schedule and recalculates future Schedule Notifications."
>
> **Dev:** "Can the current app restore an OnTime Backup from an older release?"
> **Domain expert:** "Yes. Its **Backup Format Version** selects the required forward migrations before any local data is replaced."
>
> **Dev:** "Will the local-only release download my old server Schedules once?"
> **Domain expert:** "No. The **Local-only Transition** never contacts the legacy server and does not promote incomplete Legacy Installation State into user data."
>
> **Dev:** "If the new local database fails to start, can the app temporarily return to the server version?"
> **Domain expert:** "No. Cutover is one-way; startup failure enters Recovery Mode and never restores a server runtime."
>
> **Dev:** "What email address belongs to the **Local Profile**?"
> **Domain expert:** "None. It owns local data and preferences but does not identify the person using the installation."
>
> **Dev:** "Does a working Widgetbook Web build make Web a **Supported Product Platform**?"
> **Domain expert:** "No. Product support is limited to Android and iOS; Web is a development and visual-verification target."
>
> **Dev:** "Does opening the public privacy page mean OnTime is online?"
> **Domain expert:** "Only if the user explicitly chooses **User-Initiated External Navigation**; OnTime itself does not fetch or embed the page."
>
> **Dev:** "Can an unused Firebase or HTTP client remain in the release if no screen calls it?"
> **Domain expert:** "No. The Product Network Boundary excludes the capability itself, not only known requests."
>
> **Dev:** "Can the first launch require one successful connection to download legal text or time-zone data?"
> **Domain expert:** "No. Offline Cold Start requires every core resource to ship in the release artifact."
>
> **Dev:** "Can I rely on my phone's automatic backup instead of an **OnTime Backup**?"
> **Domain expert:** "No. **Platform-Managed Data Transfer** is excluded where possible and is not a supported recovery path."
>
> **Dev:** "Can the **Installation Data Key** unlock an OnTime Backup on my new phone?"
> **Domain expert:** "No. The installation key never leaves its device; a **Backup Password** unlocks the portable backup."
>
> **Dev:** "Is a Schedule one month away too far away to notify me?"
> **Domain expert:** "No. Distance is not the boundary; **Schedule Notification Coverage** includes the nearest future Schedules up to the platform's capacity."
>
> **Dev:** "Does **Local Data Reset** delete the OnTime Backup I saved in Files?"
> **Domain expert:** "No. It removes everything owned by this installation, but an exported backup remains under the user's control."
>
> **Dev:** "If I travel, does my 9:00 Seoul Schedule become 9:00 in the new device time zone?"
> **Domain expert:** "No. Its **Schedule Time Zone** keeps the commitment at 9:00 Seoul time until you explicitly edit it."
>
> **Dev:** "Why did my Seoul Schedule notify me on the previous afternoon in Los Angeles?"
> **Domain expert:** "The Schedule shows both its 9:00 Seoul commitment and the equivalent current-device time so the delivery is explainable."
>
> **Dev:** "Will OnTime silently move a Schedule out of a daylight-saving gap?"
> **Domain expert:** "No. A **Nonexistent Schedule Time** cannot be saved, and an **Ambiguous Schedule Time** requires an explicit occurrence choice."
>
> **Dev:** "What happens if a country changes its time-zone law after I create a Schedule?"
> **Domain expert:** "The future Schedule keeps its intended local time, OnTime recalculates the notification from the updated rules, and tells you if the absolute time changed."
>
> **Dev:** "Can a preference file or remote response contain newer Schedule data than the database?"
> **Domain expert:** "No. Durable OnTime Data has one authority: the Local Data Store. Everything else is either a device-bound key or reconstructible state."
>
> **Dev:** "Should a failed database migration start over with an empty profile?"
> **Domain expert:** "No. Enter Recovery Mode and preserve the data until restore succeeds or the user explicitly resets it."
>
> **Dev:** "Should an Abnormal completion or a deleted completed Schedule rewrite the punctuality percentage?"
> **Domain expert:** "No. Abnormal outcomes are never eligible, and deleting a Schedule does not erase a score contribution already registered."
>
> **Dev:** "Does preserving a deleted Schedule's score contribution also preserve its name or Place?"
> **Domain expert:** "No. Deletion removes the Schedule details and leaves only a non-identifying aggregate contribution."

## Flagged ambiguities

- "Offline-only" could mean temporary disconnected operation with later synchronization; resolved: **Local-only OnTime** has no remote synchronization path.
- "Backup" could imply automatic cloud synchronization; resolved: an **OnTime Backup** is a user-initiated portable copy, not synchronization.
- "Portable backup" could mean only another device on the same platform; resolved: an OnTime Backup is a versioned platform-neutral representation that restores between Android and iOS.
- "Backup time" could mean either snapshot or file completion time; resolved: the **Backup Cutoff** is the single data snapshot time represented by the backup.
- "Backup is fresh" could imply that OnTime can still access the external file; resolved: **Backup Freshness** compares local revisions with the last successful export and does not guarantee file existence.
- "Backup file" could imply a readable export; resolved: every **OnTime Backup** is encrypted.
- "Encrypted backup" could mean confidentiality without tamper detection; resolved: the **Backup Cryptographic Suite** authenticates the header, ordered content, and complete stream.
- "Backup password recovery" could imply a server-held recovery path; resolved: a forgotten **Backup Password** cannot be retrieved or reset.
- "Remember backup password" could imply device or biometric retention; resolved: OnTime requires the **Backup Password** for every export and restore attempt.
- "Strong backup password" could imply mandatory character classes; resolved: Backup Password strength is length-based, permits Unicode and spaces, and imposes no composition rule.
- "Import" could imply merging selected records; resolved: a **Backup Restore** replaces all current Local Profile data and never performs a merge.
- "Restore confirmation" could mean confirming only the file picker; resolved: the user confirms again from a verified **Restore Preview** after seeing the backup summary and replacement impact.
- "All data" in a backup could include device-bound runtime state; resolved: an **OnTime Backup** contains **Durable OnTime Data** and excludes active sessions, permissions, registrations, caches, and logs.
- "Encrypt the backup" could imply that active app data remains readable at rest; resolved: **Durable OnTime Data** is encrypted both inside the installation and inside an **OnTime Backup**.
- "Backup version" could mean an app or database version; resolved: **Backup Format Version** is an independent compatibility contract.
- "Migration" could imply a final legacy-server import or salvage of local caches; resolved: the **Local-only Transition** fetches nothing, removes Legacy Installation State, and starts a new Local Profile.
- "Cutover flag" could imply a reversible local/server feature switch; resolved: the **Local-only Cutover Marker** records completed one-way cleanup and provides no server fallback.
- "Supported platform" could mean any platform Flutter can compile; resolved: a **Supported Product Platform** is Android or iOS only.
- "External link" could imply an in-app network request; resolved: **User-Initiated External Navigation** leaves OnTime through an operating-system app and carries no OnTime user data.
- "No server use" could mean merely avoiding known API calls; resolved: the **Product Network Boundary** removes network clients and verifies that release artifacts cannot initiate product network requests.
- "Works offline" could mean only after a connected warm-up; resolved: **Offline Cold Start** begins from a clean installation in airplane mode with no preloaded cache.
- "Device backup" could be mistaken for an OnTime recovery guarantee; resolved: **Platform-Managed Data Transfer** is excluded where possible and only an **OnTime Backup** is supported.
- "Encryption key" could mean either active-data or backup protection; resolved: an **Installation Data Key** protects active local data, while a **Backup Password** protects one portable OnTime Backup.
- "No login" could imply a replacement app lock; resolved: Local-only OnTime adds no app-specific PIN or biometric gate.
- "Profile" could imply a named account; resolved: a **Local Profile** contains no personal identity or authentication state.
- "Delete account" implied a remote identity and server-side deletion; resolved: **Local Data Reset** removes installation-owned data and has no server effect.
- "Schedule time" could mean a floating device-local clock value; resolved: it is fixed by the Schedule's intended civil date, time, and **Schedule Time Zone**.
- "Displayed Schedule time" could mean either commitment time or current-device time; resolved: commitment time is primary and the device equivalent is secondary only when zones differ.
- "Default time zone" could imply an unchangeable device setting; resolved: a new Schedule starts with the current device zone but the user may explicitly select another **Schedule Time Zone**.
- "Invalid DST time" could mean either a missing or repeated civil time; resolved: **Nonexistent Schedule Time** is rejected, while **Ambiguous Schedule Time** requires an explicit occurrence.
- "Time-zone update" could imply online rule synchronization; resolved: rules change only with an app release, and affected future Schedule notifications are recalculated locally.
- "Local storage" could imply several equally authoritative files and caches; resolved: only the Local Data Store owns Durable OnTime Data, while other storage is limited to the Installation Data Key or Reconstructible App State.
- "Migration fallback" could imply silently creating an empty database; resolved: an unreadable or failed migration enters Recovery Mode without deleting the existing Local Data Store or Installation Data Key.
- "Punctuality score" could imply a server-owned or lifetime value; resolved: the **Local Punctuality Score** uses only eligible outcomes since the latest Punctuality Score Reset and is uncalculated before the first eligible result.
- "Keep history" could imply hidden permanent retention after deletion; resolved: Schedule History lasts until explicit deletion, after which only a non-identifying punctuality aggregate may remain.
- "Alarm window" could imply a fixed server or seven-day range; resolved: **Schedule Notification Coverage** is capacity-based and prioritizes the nearest future Schedules.
- "User" was overloaded as both the human actor and stored profile; resolved: use **Local Profile** for the stored installation-bound concept and plain user only for the person performing an action.
- "Account", "login", "logout", and "member withdrawal" implied server identity; resolved: **Local-only OnTime** has one **Local Profile**, and the destructive user action is a local-data reset.
- "Schedule" was used near notification and alarm flows; resolved: a **Schedule** is the planned commitment, while notifications and alarms are delivery experiences for preparation timing.
- "Notification details" could imply that all Schedule fields are safe on the lock screen; resolved: Private Notification Content is the default, and Detailed Notification Content is opt-in and limited to Schedule name and a differing Schedule Time Zone.
- "Preparation state" was ambiguous between step progress and display styling; resolved: **Preparation Step** progress belongs to preparation language, while visual labels should not redefine the domain.
- "Schedule preparation session" was implicit in code but not in the glossary; resolved: the canonical term is **Schedule Preparation Session**, with **Early Start Session** for sessions started before the **Preparation Start Moment**.
- "Preparation" was ambiguous between the user's fallback steps and a schedule-specific edited set; resolved: use **Default Preparation** for the fallback and **Custom Preparation** for the schedule-specific version.
- "Alarm permission" was ambiguous between **Exact Timing Permission** and notification permission; resolved: notification permission may enable a **Fallback Notification**, but does not mean **Exact Timing Permission** is granted.
- "Pending" was ambiguous for notification status; resolved: the canonical state is **No Scheduled Notification** when notifications are enabled but no upcoming Schedule Notification is armed.
- "Allowed" was ambiguous for permission requests; resolved: a request action is not the same as granted **Exact Timing Permission**.
- "Native alarm" was ambiguous on Android; resolved: Android can use an **Android Schedule Notification** without promising an **Alarm**.
- "Fallback" was ambiguous as either a backup delivery path or permission bypass; resolved: Android's notification-only path should not be labeled fallback when it is the intended policy-safe path.
- "Notification-only alarm" was ambiguous as either approximate or precise; resolved: Android should keep **Precise Notification Timing** while using an **Android Schedule Notification** presentation.
- "Notification" was ambiguous as either a user-facing alarm concept or a platform presentation; resolved: user-facing copy should say **Schedule Notification** unless the experience is an **Alarm**.
- "Allow alarms" was ambiguous on Android; resolved: permission prompts should say notifications when the resulting user experience is notification-based.
- "Denied exact timing" was ambiguous as either disabled delivery or degraded delivery; resolved: with notification permission granted, it means **Approximate Notification Timing**.
- "Schedule alarm setting" was ambiguous after Android moved to notification-based delivery; resolved: the profile control is **Schedule Notification Setting**.
- "iOS alarm" was ambiguous across OS versions; resolved: iOS copy may say **Alarm** only when **iOS AlarmKit Alarm** is available.
- "iOS alarm permission" was ambiguous across OS versions; resolved: iOS permission prompts use alarm language only for **iOS AlarmKit Alarm**.
- "Time Sensitive" was too platform-specific for default user-facing status; resolved: fallback iOS delivery should be called notification.
- "Status label" was ambiguous across platforms; resolved: Android uses precise notification or notification status, while iOS uses alarm status only for **iOS AlarmKit Alarm**.
- "No scheduled alarm" was too capability-specific for an empty state; resolved: use **No Scheduled Notification** across platforms.
- "Step action events" was ambiguous as either user actions or automatic timer movement; resolved: the canonical term is **Preparation Action Event**, and automatic step transitions are derived rather than recorded as events.
- "Preparation chain" describes storage reconstruction, not product language; resolved: the domain concept is an ordered **Preparation** made of **Preparation Steps**.
- "Total duration" was ambiguous between **Preparation Duration** and the broader preparation-start timing calculation; resolved: **Preparation Duration** is steps only, while move time and **Schedule Spare Time** are separate inputs.
