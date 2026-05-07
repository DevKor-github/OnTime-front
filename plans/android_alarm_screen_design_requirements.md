# Android Alarm Screen Design Brief

## Purpose

Design the full-screen Android alarm screen for OnTime.

This is the urgent screen users see when it is time to start preparing for a schedule. It should feel closer to a phone alarm than a normal app page or notification.

The design goal is:

- Wake the user.
- Make the schedule context immediately clear.
- Give one obvious primary action: start preparing.
- Let the user dismiss the alarm without friction.

## User Situation

The user may be:

- Asleep or distracted.
- Looking at the lock screen.
- Holding the phone in low light.
- In a hurry.
- Confused about why the alarm is ringing.

The screen should be readable, calm, and decisive. It should not require careful scanning.

## Design Principles

- Full-screen and focused.
- Large touch targets.
- Minimal text.
- No decorative elements that compete with the action.
- Primary action should be unmistakable.
- Secondary action should be available but visually quieter.
- The experience should feel native and alarm-like, not like a marketing screen or dashboard.

## Screen States

### 1. Ringing

This is the default state when the alarm fires.

Required content:

- Schedule title.
- Short alarm message.
- Visual indication that the alarm is active.
- Primary button: `Start preparing`.
- Secondary button: `Dismiss`.

Recommended hierarchy:

- Top or center: alarm/schedule identity.
- Middle: schedule title and short message.
- Bottom: large actions.

Example content:

- Title: `Team Meeting`
- Message: `It is time to get ready.`
- Primary button: `Start preparing`
- Secondary button: `Dismiss`

### 2. Stopped / Missed

After the alarm rings for the maximum duration, sound and vibration stop, but the screen can remain visible.

Required content:

- Same schedule title.
- Message explaining that the alarm stopped.
- Primary button remains available: `Start preparing`.
- Secondary button remains available: `Dismiss`.

Example message:

- `Alarm stopped. You can still start preparing.`

This state should feel less urgent than the ringing state, but still actionable.

### 3. Dismissed

The screen closes after dismissal.

No dedicated design is required unless the product wants a transition state.

## Actions

### Start Preparing

Primary action.

Design requirements:

- Most prominent button on screen.
- Easy to tap with one hand.
- Should be visually clear even on a locked or dim screen.

Behavior after tap:

- Alarm stops.
- The app opens the existing preparation flow.
- User should land on the active preparation screen, not home.

### Dismiss

Secondary action.

Design requirements:

- Clearly visible.
- Less visually dominant than `Start preparing`.
- Should not look destructive.

Behavior after tap:

- Alarm stops.
- Screen closes.
- No backend/state-changing dismissal is shown to the user.

## Layout Requirements

- Must work on small Android phones.
- Must work on tall Android phones.
- Important text must not be clipped.
- Buttons must remain visible without scrolling.
- Avoid dense layouts.
- Use safe spacing around edges.
- Support lock-screen viewing distance.

Recommended minimum touch target:

- 48dp height minimum.
- Prefer larger for the two main actions.

## Visual Direction

The screen may use a dark background for alarm readability.

Recommended feel:

- Calm but urgent.
- Simple geometry.
- OnTime brand presence can be subtle.
- Avoid heavy illustration unless it reinforces the alarm state without distracting.

Possible visual cues:

- Alarm icon.
- Pulsing/ringing indicator.
- Time-related accent.
- Gentle motion while ringing.
- Reduced motion or static version for stopped state.

Avoid:

- Card-heavy layouts.
- Long explanations.
- Tiny close icons as the main dismissal method.
- Notification-style compact UI.
- Home-screen/dashboard patterns.

## Copy Requirements

Keep copy short.

Required labels:

- `Start preparing`
- `Dismiss`

Recommended message for ringing:

- `It is time to get ready.`

Recommended message for stopped/missed:

- `Alarm stopped. You can still start preparing.`

If Korean copy is needed, provide equivalent short labels for:

- Start preparing
- Dismiss
- It is time to get ready
- Alarm stopped

## Accessibility

- Text should remain readable with large font settings.
- Buttons need strong contrast in both normal and pressed states.
- Do not rely on color alone to communicate ringing vs stopped.
- If motion is used, it should be subtle and not required to understand the state.

## Designer Deliverables

Please provide:

- Ringing state design.
- Stopped/missed state design.
- Small phone layout.
- Tall phone layout.
- Button pressed/disabled visual states if applicable.
- Color, typography, spacing specs.
- Icon or motion direction if used.
- Korean and English text placement if localization affects layout.

## Product Acceptance Criteria

- User immediately understands which schedule is alarming.
- User can start preparation with one obvious tap.
- User can dismiss with one obvious tap.
- The design feels like a real alarm experience, not a normal notification.
- The stopped/missed state is visually distinct from the ringing state.
- The layout remains readable and tappable on common Android phone sizes.
