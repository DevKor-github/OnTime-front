# Schedule Notification Flow

This page records the platform-specific schedule delivery flow for OnTime. The
product language is intentional:

- **Notification** means the user is alerted through an OS notification.
- **Alarm** means OnTime can present a stronger alarm experience without the
  user first tapping a notification.
- Android currently uses notification-based schedule delivery.
- iOS uses alarm language only when AlarmKit is available and authorized.

## Android Flow

Android separates notification display permission from exact timing permission.
Users may still receive schedule notifications when exact timing is denied, but
delivery is approximate.

```mermaid
flowchart TD
    A["Install or sign in"] --> B["Request notification permission"]
    B --> C{"Notification permission granted?"}
    C -- "No" --> D["Block schedule delivery\nStatus: Notification permission needed"]
    C -- "Yes" --> E["Request exact timing permission\nExplain: needed to notify at the exact preparation time"]
    E --> F{"Exact timing permission granted?"}
    F -- "Yes" --> G["Schedule with Android exact timing\nUser copy: Schedule notifications\nStatus: Precise notification"]
    F -- "No or later" --> H["Keep notification delivery enabled\nUse regular notification fallback\nStatus: Notification"]
    G --> I{"Upcoming schedule notification armed?"}
    H --> I
    I -- "Yes" --> J["Notify user at preparation time\nTap opens preparation flow"]
    I -- "No" --> K["Status: No scheduled notifications"]
```

## iOS Flow

iOS is capability-aware. Alarm language is correct only when AlarmKit can be used
for the current device and build. Otherwise, OnTime uses notification language.

```mermaid
flowchart TD
    A["Install or sign in"] --> B{"AlarmKit available\nfor this device and build?"}
    B -- "Yes" --> C["Request AlarmKit authorization\nUser copy: Allow alarms"]
    C --> D{"AlarmKit authorized?"}
    D -- "Yes" --> E["Schedule iOS AlarmKit alarm\nUser copy: Schedule alarm\nStatus: Alarm"]
    D -- "No or later" --> F["Request notification permission\nUser copy: Allow notifications"]
    B -- "No" --> F
    F --> G{"Notification permission granted?"}
    G -- "No" --> H["Block schedule delivery\nStatus: Notification permission needed"]
    G -- "Yes" --> I["Schedule local notification delivery\nUser copy: Schedule notifications\nStatus: Notification"]
    E --> J{"Upcoming delivery armed?"}
    I --> J
    J -- "Yes" --> K["Alarm or notification opens preparation flow"]
    J -- "No" --> L["Status: No scheduled notifications"]
```

## Profile Status Labels

| Platform / capability state | User-facing status |
| --- | --- |
| Android exact timing armed | Precise notification |
| Android notification fallback armed | Notification |
| iOS AlarmKit armed | Alarm |
| iOS notification fallback armed | Notification |
| Notification permission missing | Notification permission needed |
| No upcoming delivery armed | No scheduled notifications |
| User disabled schedule delivery | Off |

## Copy Rules

- Android permission prompts should say **notification**, not alarm.
- Android exact timing copy should explain why the extra permission exists:
  OnTime needs it to notify the user at the exact time to start preparing.
- iOS prompts may say **alarm** only when requesting AlarmKit authorization.
- Empty states should stay platform-neutral: **No scheduled notifications**.

## Source Of Truth

- Domain language: `CONTEXT.md`
- Android decision: `docs/adr/0008-use-notification-based-schedule-delivery-on-android.md`
- iOS decision: `docs/adr/0009-use-alarm-language-only-for-ios-alarmkit.md`
- Permission gate: `lib/presentation/app/cubit/alarm_gate_cubit.dart`
- Startup allow screen: `lib/presentation/alarm_allow/screens/alarm_allow_screen.dart`
- Profile status: `lib/presentation/my_page/my_page_screen.dart`
