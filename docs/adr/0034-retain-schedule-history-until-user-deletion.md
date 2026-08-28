---
status: accepted
---

# Retain schedule history until user deletion

Local-only OnTime will not expire Schedule History, Preparation templates, or Schedule Outcome details automatically because age or local storage crosses a threshold. These records remain Durable OnTime Data until the user explicitly deletes them or performs Local Data Reset. Deleting a Schedule will atomically remove its name, Place, note, Preparation relationship and content, detailed Schedule Outcome, and local delivery registrations, and the deleted Schedule will be absent from later OnTime Backups. To preserve the established Local Punctuality Score behavior, an already registered eligible contribution will remain only in non-identifying aggregate On Time or Late counts and will not retain the deleted Schedule identifier or descriptive fields. Restore Preview will explain that replacement with an older Backup Cutoff can reintroduce records deleted after that cutoff. Automatic retention windows and hidden retention of deleted Schedule details were rejected because the former causes unrecoverable offline loss and the latter violates the meaning of explicit deletion.
