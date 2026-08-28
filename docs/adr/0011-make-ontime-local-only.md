---
status: accepted
---

# Make OnTime local-only

OnTime will keep active user data within the current app installation and will not depend on an OnTime backend, social authentication, push messaging, or an analytics provider during normal app behavior. Each installation has one non-identifying Local Profile created through onboarding; names, email addresses, social identity, credentials, tokens, login, and logout are removed, while the former account-deletion action becomes a destructive local-data reset. Product Usage Events, experiments, and the Analytics Preference are removed rather than retained as device-only analytics; development diagnostics are not product analytics. Device-provided local notification and alarm capabilities remain in scope. A user may explicitly export or restore a portable OnTime Backup through an OS-managed file location, but OnTime will not automatically synchronize or communicate with a storage provider. Privacy information required for normal use will be bundled in the app; only an explicit user action may open a public legal, support, email, or store destination in an external operating-system app, without attaching OnTime user data. This trades cross-device synchronization, account recovery, remote push, and product analytics for deterministic offline operation, lower operating cost, and a smaller privacy boundary.
