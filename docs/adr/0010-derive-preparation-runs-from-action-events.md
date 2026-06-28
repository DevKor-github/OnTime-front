# Derive Preparation Runs from Action Events

OnTime will model local preparation progress as a Preparation Run that starts at the user's start action and is adjusted by user-performed Preparation Action Events such as skipping a step or finishing preparation. The app will derive the current step, elapsed time, and completion state from the run start time, action events, current time, and the current schedule fingerprint instead of treating timer ticks or elapsed-time snapshots as the source of truth. This prevents sleep, background suspension, and delayed timers from making preparation progress drift while keeping the first implementation local to the app rather than expanding the backend API.

## Consequences

- Timer ticks may refresh UI state, but they must not be persisted as preparation history.
- Automatic step transitions are derived during restore, resume, and tick refresh; they are not stored as events.
- Stored Preparation Runs are valid only while the schedule fingerprint still matches and must be cleared when the schedule is finished or deleted.
