---
status: accepted
---

# Encrypt backups with a user password

Every OnTime Backup will be encrypted with a password chosen by the user during export and will require that password for cross-device restore. OnTime will retain the password only for the active export or restore attempt, will not save it in app storage or a device keychain, and will not offer biometric autofill. A device-bound key was rejected because it would prevent restoration on another installation, while an OnTime-managed recovery path was rejected because local-only OnTime has no account or server capable of recovering secrets. A forgotten password therefore makes that backup permanently unreadable without affecting active data or other backups.
