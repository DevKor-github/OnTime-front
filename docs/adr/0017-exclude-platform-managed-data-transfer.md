---
status: accepted
---

# Exclude platform-managed data transfer

OnTime will request exclusion of its active data from Android cloud backup, Android device-transfer rules, and iOS system backup, making an encrypted user-created OnTime Backup the only supported portable recovery path. Platform-managed backup and transfer were rejected because they can move readable app state outside OnTime's explicit password-protected flow and make local-only behavior platform-dependent. The exclusion is best-effort because operating systems and device manufacturers may not honor every app request, so product and privacy documentation must not promise absolute prevention.
