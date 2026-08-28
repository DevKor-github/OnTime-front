---
status: accepted
---

# Schedule future notifications by platform capacity

Local-only OnTime will remove the server-derived seven-day alarm window. Creating or changing a future schedule will immediately attempt to arm its preparation delivery regardless of distance, with the nearest eligible schedules taking priority when a platform limits pending delivery capacity. OnTime will reconcile from local durable data after launch or resume, schedule mutation, backup restore, reboot, clock or time-zone change, and relevant permission change. This improves long-range offline reliability while acknowledging that schedules beyond current platform capacity cannot be promised until a later reconciliation makes room.
