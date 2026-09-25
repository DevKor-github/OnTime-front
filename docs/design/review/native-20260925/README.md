# iOS native verification — 2026-09-25

The isolated **OnTime Parity Backup QA 20260925** simulator is iPhone 17 / iOS 26.5, UUID `74CFB493-7B8B-4DFD-9DD6-F0E97E682FA7`, bundle `club.devkor.ontime.ios`, debug build of this worktree. No existing device profile was reset. Its new local profile had one 3-minute preparation step, 30-minute buffer, and no appointments. System language was English; existing My Data screens and user-editable seed names remain Korean.

## Executed, observed results

| Scenario | Observation |
| --- | --- |
| New installation | Welcome → selection → order → numeric 3-minute entry → buffer → local profile saved. Native testing found that the time field's accessibility bounds merged with its row; the row now focuses/selects the real field and the native input succeeded after rebuilding. |
| Notifications | App rationale opened the actual iOS notification prompt. Denying permission continued to the alarm gate. |
| AlarmKit | The actual iOS alarm/timer permission prompt appeared. Denial retained the rationale; defer continued to Home. My Page showed notifications Off. No permission bypass or settings override was used. |
| Export | Entered a QA-only passphrase; the actual iOS Files document export picker opened. Saved `OnTime-20260925.ontimebackup` under On My iPhone. My Data changed to no changes since backup. See [saved state](backup-saved.png). |
| Durable setting change | Changed the default buffer 30→35 minutes and saved. My Page read 35 minutes. See [before restore](buffer-changed-35.png). |
| Import and validation | The native file-open picker showed the same 811-byte file; selecting it successfully decrypted and produced a preview for iOS, 1.1.0+56, zero appointments and one default preparation. See [preview](restore-preview.png). |
| Restore application | Confirmed restore; the app reported success. My Page reloaded the persisted 3-minute preparation and **30-minute** buffer. See [restored values](restored-buffer-30.png). |
| Reset lifecycle | Reset confirmation → busy → complete succeeded. See [completion](reset-complete.png). After full process termination/relaunch, Welcome appeared for a new local profile. See [relaunch](reset-relaunch-welcome.png). |
| External backup preservation | After reset/relaunch, the exported file still existed and its SHA-256 was unchanged. |

File verification: 811 bytes, SHA-256 `339fe8a981377bdc9ef538e3c08cbb970e73862aff1f2768d2a660eb5814989e`. The encrypted bytes did not contain the sample preparation name in plaintext. Successful decryption/preview and the restored buffer value are the substantive restore evidence; filename/size alone would not be sufficient. No backup file or passphrase is committed.

## Native defect repaired

Installed `file_selector_ios` 0.5.3+6 implements open-file selection but does not implement the save-location API previously used by BackupService. Its type filtering also requires `uniformTypeIdentifiers`, which the old backup group omitted. Thus widget tests with a fake service could not establish that the production iOS operation worked.

`BackupFilePicker` now routes iOS export through `on_time_front/backup_files`. Swift writes only the already-encrypted container to a temporary directory and presents [`UIDocumentPickerViewController(forExporting:asCopy:)`](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller/init%28forexporting%3Aascopy%3A%29). The delegate reports success after the user saves, false on cancellation/dismissal, rejects concurrent export, and cleans its temporary files. The password stays in Dart. Non-iOS save-location handling is retained. Import uses the iOS `public.data` type; authenticated format validation determines whether the chosen file is a valid backup.

Tests separately verify encrypted bytes/name crossing the channel, cancellation, native errors, unchanged freshness on failed/cancelled export, completion-only snapshot marking, preview without applying, invalid files and unchanged data, replacement restore, legacy format compatibility and recurring relationships. A second agent reviewed the native diff and found no blocking issue. Unit tests do not substitute for the Files UI observations above.

## Evidence limits

- This run exercised native setup, settings persistence, permission denial/defer, export, import, restore, reset and relaunch. It did not claim successful alarm delivery or a native export-cancel run; those gateway/cancellation paths have automated tests.
- Appointment creation/edit/delete and recurring scope/conflict/ownership are covered by the current widget/database integration suite. Earlier native recurring creation/navigation evidence is dated separately in `docs/design/recurring-schedules/implementation/native-ios/README.md`; it is not re-labelled as this run.
- No physical device was available: `xcrun devicectl list devices` returned the paired iPhones/iPad as unavailable. Physical-device font/layout, background/locked-screen alarm delivery, VoiceOver operation and frame-time/scroll performance remain a device acceptance gate. Debug simulator rendering is not a performance benchmark.
