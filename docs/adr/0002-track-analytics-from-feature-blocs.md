# Track Analytics from Feature BLoCs

Workflow Milestone Events will be emitted from the feature BLoCs or Cubits that own the completed workflow, using an injected tracking use case. This keeps analytics tied to domain outcomes instead of raw UI interactions, avoids a global BlocObserver that could accidentally observe sensitive form state, and keeps event emission testable without depending on widget navigation.
