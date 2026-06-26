# Use Notification-Based Schedule Delivery on Android

Android schedule preparation delivery will not promise a full-screen alarm UI unless the required Google Play full-screen intent approval is available. On Android, OnTime will keep precise timing as the product goal, but present schedule preparation through notifications and explain exact timing permission separately from notification display permission. This avoids misleading users with "alarm" language for a notification-based experience and reduces Play policy risk while preserving the core requirement that preparation starts at the intended time.

## Consequences

- Android user-facing copy should say notification, not alarm, for scheduled preparation delivery.
- Android permission flow should separate notification display permission from exact timing permission.
- Android status labels should distinguish precise notification timing from approximate notification timing instead of treating exact timing denial as disabled delivery.
