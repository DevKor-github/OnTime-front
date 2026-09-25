# Android Schedule Notification delivery verification

Issue: [A01 / #583](https://github.com/DevKor-github/OnTime-front/issues/583).

The product uses local Schedule Notifications. This check requires no account,
server, Firebase configuration, or network connection in the product runtime.
Receiver configuration and actual OS delivery are separate acceptance checks.

## Automated artifact check

Run the source contract and its negative fixtures:

```sh
python3 -B -m unittest discover -s test/tool -p 'test_*.py' -v
python3 tool/check_android_notification_manifest.py android/app/src/main/AndroidManifest.xml
```

The Android Notification Contract workflow builds the release configuration with
a newly generated, disposable **validation-only key**. It checks both the Gradle
merged manifest and the manifest extracted from the resulting APK. Its artifact
contains the source SHA, APK SHA-256, manifest paths and verification results.
This APK is not store-signed and must not be promoted to production or installed
over an existing user's installation. The disposable key is deleted after the
job; it cannot provide an update pair for the device test below.

Use the same checker on the actual store-candidate merged manifest and extracted
APK/AAB manifest. Verify that both plugin receiver classes are enabled and not
exported, the boot permission is present, and all four documented boot/update
actions are connected. NativeAlarmReceiver is a separate component and cannot
substitute for the plugin's PendingIntent target.

## Device delivery evidence

Use a dedicated QA device/installation with synthetic schedule data. Keep the
same candidate artifact for each row. The update test additionally needs an
identified predecessor signed with the same QA/store signing identity. Do not
uninstall a user's app to bypass a signature mismatch.

Record source SHA, version name/code, signing identity description, APK/AAB
digest, device model, OS version, notification permission, channel settings,
battery/OEM restrictions, preparation start, actual receipt time and evidence.
Do not record backup passwords, private schedule details or signing secrets.

| Scenario | Procedure | Expected | Result/evidence |
|---|---|---|---|
| Background | Schedule a sufficiently future preparation, then background app | Notification arrives | Not run |
| Locked | Lock device before scheduled preparation | Notification arrives with private content | Not run |
| Recent-app removal | Remove app from recents; record OEM behavior | Scheduled delivery still works where OS allows | Not run |
| Process death | End process without force-stopping package; record method/PID | Receiver delivers without Flutter process | Not run |
| Reboot | Reboot with future notification, unlock, do not launch OnTime | Restored notification arrives once | Not run |
| Update | Replace predecessor with same-identity candidate, do not launch app | Restored notification arrives once | Not run |
| Duplicate check | Observe reboot and update cases through delivery | No duplicate notification | Not run |

Android Settings force-stop is an OS-restricted state, not equivalent to normal
process death. Record it separately if observed; A01 does not promise delivery
while force-stopped. QUICKBOOT action declarations are checked automatically;
OEM-specific quickboot behavior needs a suitable device and cannot be marked
passed without one.

The current scheduling mode is inexact. Record observed delay without claiming
that A01 provides precise timing. A13 owns the precise/approximate timing policy,
A12 owns notification-tap cold launch routing, and A14 owns permission/provider
reconciliation. Keep A01 open while required actual-device evidence is missing.
