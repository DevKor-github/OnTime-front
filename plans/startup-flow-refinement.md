# Startup Flow Refinement Plan

## Current Flow

App launch currently follows this path:

1. `main.dart` blocks startup on date formatting, DI setup, Firebase initialization, and notification permission lookup.
2. `App` creates `AuthBloc` and immediately dispatches `AuthUserSubscriptionRequested`.
3. `GoRouter` starts at `/home`.
4. Because `AuthBloc` is seeded with `UserEntity.empty()`, the first router redirect often treats the user as unauthenticated and sends them to `/signIn`.
5. `AuthBloc` calls `LoadUserUseCase`, then listens to `userStream`. When a real user arrives, router refresh redirects again based on auth/onboarding status.
6. Authenticated users who enter from sign-in or onboarding routes get a notification permission check inside the router redirect, then may be sent to `/allowNotification` or `/home`.
7. Users with incomplete onboarding are sent to `/onboarding/start`, then manually push `/onboarding`.

## Why It Feels Unnatural

The app has no explicit startup resolution state. A returning signed-in user can briefly be routed as signed out because the initial auth state is `unauthenticated` before persisted user loading finishes.

The initial route is optimistic (`/home`), but the first meaningful state is pessimistic (`unauthenticated`). That can cause visible route churn: home target, sign-in redirect, then home/onboarding/notification redirect.

Notification permission is treated as a router-side auth redirect only after sign-in/onboarding routes. That means a user can reach `/home` directly while permission is missing, but after certain transitions the same state routes to `/allowNotification`. The rule is inconsistent.

The router performs async side-effect-like work by checking notification permission during redirect. Redirects should ideally be fast, deterministic mappings from app state to route.

Onboarding has two separate entry routes (`/onboarding/start` and `/onboarding`) and the start button uses `push`. That leaves a back-stack relationship between the welcome screen and form, while the auth guard also forces users back to the start screen from other routes.

After onboarding submit, navigation depends on `OnboardUseCase` calling `getUser()`, the repository stream emitting a completed user, `AuthBloc` updating, and router refresh firing. There is no explicit success/loading/error state in the onboarding UI, so completion can feel delayed or ambiguous.

Schedule startup can also affect launch later: once authenticated, `AuthBloc` starts schedule subscription, and `ScheduleBloc` can imperatively push `/scheduleStart` when preparation begins. That is useful for alarms, but it is separate from router guards and should remain isolated from the auth/onboarding first-run flow.

## Target Flow

The startup experience should resolve app state once, then move forward:

1. Launch shows a stable splash/loading surface while startup state is unknown.
2. Auth state resolves to one of: unauthenticated, onboarding required, notification prompt needed, ready.
3. Router maps that state to exactly one top-level destination.
4. User actions use `go` when crossing app phases, not `push`.
5. Notification prompt is optional and consistent: either always shown once after onboarding/sign-in when needed, or handled as a non-blocking in-home prompt.
6. Onboarding submit shows progress and errors locally, then transitions intentionally.

## Proposed Implementation

### 1. Add An Explicit Auth Bootstrap State

Add an `AuthStatus.initial` or `AuthStatus.loading` state. Start `AuthBloc` in that state instead of deriving unauthenticated from `UserEntity.empty()` before `LoadUserUseCase` completes.

In `AuthUserSubscriptionRequested`, await or track the initial load result enough to avoid routing to `/signIn` before persisted token/user resolution has completed. If `getUser()` fails with a non-auth error, expose an auth error state or keep the startup screen with retry.

Expected result: returning users no longer see sign-in as a transient launch screen.

### 2. Introduce A Startup Route

Change `initialLocation` from `/home` to a neutral route such as `/startup` or `/splash`.

Add a lightweight startup screen using the app logo/character and no navigation controls. The router should keep users there while auth status is loading.

Expected result: launch has one stable first screen instead of route churn.

### 3. Make Redirects Pure And Complete

Move notification permission knowledge into app state, for example an `AppGateCubit`, `NotificationPermissionCubit`, or an expanded auth/startup gate state. The router should read a cached status rather than awaiting `NotificationService.instance.checkNotificationPermission()` inside `redirect`.

Define route groups:

- Public: `/startup`, `/signIn`
- Onboarding: `/onboarding/start`, `/onboarding`
- Notification gate: `/allowNotification`
- Authenticated app: `/home`, `/myPage`, `/calendar`, schedule routes, settings routes

Then make redirect rules exhaustive:

- Loading -> `/startup`
- Unauthenticated -> `/signIn`, unless already public
- Onboarding required -> `/onboarding/start` or current onboarding route
- Authenticated + notification required -> `/allowNotification`, unless already there
- Ready -> `/home` when currently on startup/sign-in/onboarding/allow-notification
- Ready + already on an authenticated deep route -> stay there

Expected result: direct `/home`, post-login, and post-onboarding all behave consistently.

### 4. Decide Notification Gate Product Behavior

Choose one of two product behaviors before implementation:

- Blocking soft gate: show `/allowNotification` once after sign-in/onboarding if permission is not authorized, with `Do it later` continuing to home.
- Non-blocking prompt: send users to home and show notification education there or from My Page.

If keeping `/allowNotification`, persist a local `notificationPromptDismissed` flag so users who tap `Do it later` are not routed back to the prompt on every auth transition.

Expected result: notification permission feels like part of onboarding, not an unpredictable detour.

### 5. Normalize Phase Transitions

Use `context.go('/onboarding')` from onboarding start instead of `push`, because moving from intro to form is a phase transition within the guarded onboarding flow.

After onboarding submit, show a submitting state on the button, prevent double taps, and handle failure with an inline/dialog error. On success, either update auth/startup state explicitly or ensure the user stream update is awaited before the router transition.

Expected result: onboarding completion feels deliberate and recoverable.

### 6. Keep Schedule Auto-Navigation Separate

Do not let schedule status influence auth/startup redirects except for preserving current schedule routes when already authenticated.

Longer term, consider moving the imperative `/scheduleStart` push behind a coordinator that checks the current route, so launch-time auth routing and alarm routing do not race each other.

Expected result: time-sensitive schedule behavior remains intact without making app launch harder to reason about.

## Suggested Work Order

1. Add `AuthStatus.loading` and adjust `AuthBloc` initial loading behavior.
2. Add `/startup` screen and set it as `initialLocation`.
3. Refactor router redirect into named helpers with route-group predicates.
4. Move notification permission check out of `redirect`; add a small cached gate state.
5. Add notification dismissed persistence if `/allowNotification` remains a soft gate.
6. Update onboarding navigation from `push` to `go`, add submit loading/error state.
7. Add tests for startup redirects and onboarding completion.

## Test Plan

Add focused router/auth tests for:

- Cold launch with persisted authenticated user goes `startup -> home` without visiting sign-in.
- Cold launch with no valid token goes `startup -> signIn`.
- New social user goes `signIn -> onboarding/start -> onboarding -> allowNotification or home`.
- Completed user with notification already authorized goes directly to `/home`.
- Completed user with notification not determined goes to the chosen notification experience.
- Tapping `Do it later` reaches `/home` and does not immediately re-route back.
- Deep link to authenticated route is preserved after auth loading when allowed.

Run:

```sh
flutter analyze
flutter test
```

