---
status: accepted
---

# Encrypt active data with a device-bound key

Each installation will encrypt Durable OnTime Data with a randomly generated Installation Data Key held only in device-bound operating-system secure storage. The key will be used automatically during normal app operation and will not be synchronized, included in platform backup, exported, or placed in an OnTime Backup. Local-only OnTime will not add an app-specific PIN or biometric gate; access control remains the device lock's responsibility. This adds protection if the database file escapes the app container without turning every app launch, alarm, or notification route into an authentication flow. If the secure key is lost or corrupted, the active database is intentionally unrecoverable; the supported choices are restoring a password-protected OnTime Backup or performing a destructive local-data reset.
