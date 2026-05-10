# Android Developer Verification

Use this checklist to complete and record the Play Console developer
verification and Android package-name registration status for OnTime.

This work requires Google Play Console access for the developer account that
owns `club.devkor.ontime`. Do not paste government IDs, addresses, phone
verification codes, payment profile details, keystores, private keys, or
unredacted Play Console screenshots into git, issues, pull requests, or chat.

## Required Access

- Google Play Console access for the OnTime developer account.
- Permission to view developer account verification status.
- Permission to create or inspect the Play Console app for package
  `club.devkor.ontime`.
- Access to the release signing owner if package registration requires the
  SHA-256 certificate fingerprint or a signed proof APK.

## Console Checks

1. Open Play Console for the OnTime developer account.
2. Check the developer account verification banner, Home tasks, and account
   verification pages.
3. Record whether identity verification is complete, pending, rejected, or not
   yet available for this account.
4. Open or create the Play Console app whose package name is
   `club.devkor.ontime`.
5. Check whether Google has automatically registered the package name for the
   verified Play developer identity.
6. If manual package-name registration is required, register
   `club.devkor.ontime` with the release signing certificate SHA-256
   fingerprint.
7. If Google requires proof for an existing package name, follow the Play
   Console ownership flow using a signed APK generated with the matching
   private signing key.
8. Record any deadline, rejected field, blocked step, or Google support case.

Google's current package-name registration guidance says package registration
is blocked until Android developer identity verification is complete, and that
Google planned to try automatic registration for Play apps before the broader
Android developer verification launch. Confirm the actual status in the OnTime
Play Console account because rollout timing and account eligibility are
account-specific.

Reference:

- Play Console Help: Registering Android package names -
  https://support.google.com/googleplay/android-developer/answer/16761053
- Play Console Help: Verify your developer identity information -
  https://support.google.com/googleplay/android-developer/answer/10841920
- Play Console Help: Create and set up your app -
  https://support.google.com/googleplay/android-developer/answer/9859152

## Status Record

Fill this section after checking Play Console. Keep sensitive identity and
signing details in the secure account record, not in this repository.

```text
Checked by:
Checked date:
Play Console account:
Developer account type: personal / organization / other
Developer identity verification status:
Verification deadline:
Package name: club.devkor.ontime
Play Console app exists: yes / no
Package auto-registered by Google: yes / no / not shown
Manual package registration required: yes / no / unclear
Signing certificate SHA-256 source: Play App Signing / upload key / local release key / not needed
Package registration status:
Google support case:
Remaining follow-up:
Evidence location:
```

## Completion Criteria

- Developer identity verification status is known.
- Package-name registration status for `club.devkor.ontime` is known.
- Manual registration is completed if Play Console requires it.
- Any follow-up deadline or Google support case is recorded in the secure
  release account record and summarized in the release issue without sensitive
  details.
