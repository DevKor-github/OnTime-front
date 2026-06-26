# Use Alarm Language Only for iOS AlarmKit

iOS schedule preparation delivery will use alarm language only when the current build and device can deliver an AlarmKit alarm. On iOS versions or builds where AlarmKit is unavailable, or when AlarmKit authorization is denied but notifications remain available, OnTime will use notification language instead. This keeps user-facing copy aligned with the actual OS experience while preserving the stronger alarm model where Apple provides it.

## Consequences

- iOS permission prompts must be capability-aware: AlarmKit paths may say alarm, notification paths should say notification.
- Profile status may show alarm only for active iOS AlarmKit delivery.
- Empty states should remain platform-neutral and say there are no scheduled notifications.
