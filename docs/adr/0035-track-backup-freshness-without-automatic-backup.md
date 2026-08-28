---
status: accepted
---

# Track backup freshness without automatic backup

My Data will expose Backup Freshness as Never Exported, No Changes Since Export, or Unexported Changes. The Local Data Store will record the latest successful export's Backup Cutoff and a monotonic durable-data revision boundary, but it will not retain the external destination, a file permission, or the Backup Password and therefore will not claim that the exported file still exists. Only a successful export on the current installation changes the status to No Changes Since Export; Backup Restore does not. When at least one Durable OnTime Data change remains unexported for 30 days, or 30 days have passed since the first durable record on an installation that has never exported, OnTime will show a dismissible, non-blocking in-app reminder. It will not create an automatic backup, schedule a system reminder, or disable product functionality. Hiding backup age and pretending that a restore proves an accessible recovery file were rejected because OnTime Backup is the only supported installation-transfer and recovery path, while intrusive system reminders were rejected for a user-initiated feature.
