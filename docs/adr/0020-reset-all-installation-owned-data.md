---
status: accepted
---

# Reset all installation-owned data

The former account-deletion flow will become Local Data Reset: it removes the Local Profile, all durable records and preferences, active preparation and early-start state, device-specific registries, scheduled notifications and alarms, the encrypted database, and the Installation Data Key, then returns to onboarding. Exported OnTime Backups remain untouched because they are outside the installation's control. Reset progress must be recoverable so an interrupted operation finishes cleanup on the next launch before a new Local Profile can be created. This provides a truthful deletion boundary without pretending that a server account or externally stored backup can be deleted by the app.
