# OnTime Flutter Project - AI Coding Agent Instructions

## Architecture Overview

This is a **Flutter app** following **Clean Architecture** with three layers:

- **Presentation** (`lib/presentation/`): Screens, widgets, BLoC/Cubit state management
- **Domain** (`lib/domain/`): Business logic, entities, use cases, repository interfaces
- **Data** (`lib/data/`): Repository implementations, data sources (remote/local), DAOs, database tables

Data flows: UI → BLoC → UseCase → Repository → DataSource → API/DB

## Critical Build Commands

```bash
# ALWAYS run after pulling or modifying data models, entities, or DI
dart run build_runner build --delete-conflicting-outputs

# Watch mode for development
dart run build_runner watch

# Run tests
flutter test

# Run app
flutter run
```

## Dependency Injection Pattern

- Uses **Injectable** + **GetIt** for DI
- All repositories, use cases, BLoCs, and data sources must be annotated:
  - `@Injectable()` for standard dependencies
  - `@Singleton()` for app-wide singletons (e.g., `ScheduleBloc`, `AppDatabase`)
  - `@LazySingleton()` for lazy-initialized singletons
- After adding `@Injectable()`, run `dart run build_runner build`
- Register as interface: `@Injectable(as: InterfaceName)`

Example:

```dart
@Injectable()
class UpdateScheduleUseCase {
  final ScheduleRepository _repository;
  UpdateScheduleUseCase(this._repository);
}

@Singleton(as: ScheduleRepository)
class ScheduleRepositoryImpl implements ScheduleRepository { ... }
```

## State Management with BLoC

- Use **BLoC** for complex state, **Cubit** for simpler scenarios
- BLoCs live in `lib/presentation/*/bloc/` directories
- Pattern: `on<EventName>(_onEventName)` event handlers
- **Critical**: `ScheduleBloc` is a `@Singleton()` that manages automatic timer system for schedule start notifications (see `docs/Schedule-Timer-System.md`)
- Keep business logic in **use cases**, not BLoCs
- BLoCs coordinate between use cases and UI

Example structure:

```dart
@Injectable()
class MyBloc extends Bloc<MyEvent, MyState> {
  MyBloc(this._useCase) : super(MyState.initial()) {
    on<MyEventHappened>(_onMyEventHappened);
  }

  Future<void> _onMyEventHappened(MyEventHappened event, Emitter<MyState> emit) async {
    final result = await _useCase();
    emit(state.copyWith(data: result));
  }
}
```

## Data Layer Patterns

### Entities (Domain)

- Use **Equatable** for value equality (most entities)
- Or **Freezed** for advanced immutability (e.g., `UserEntity`)
- Live in `lib/domain/entities/`
- Example: `ScheduleEntity`, `PreparationEntity`

### Data Models (Data Layer)

- Use **json_serializable** for API models
- Live in `lib/data/models/`
- Must have `toEntity()` method to convert to domain entities
- Repository boundary: models → entities when leaving data layer

### Database (Drift)

- Tables defined in `lib/data/tables/`
- DAOs in `lib/data/daos/`
- Database: `lib/core/database/database.dart` with `@Singleton()` annotation
- Schema version tracked, migrations in `MigrationStrategy`

### Data Sources

- Abstract interface + implementation pattern
  // ...existing code...
  - Remote sources use Dio client (`lib/core/dio/app_dio.dart`)
  - Local sources use Drift DAOs or SharedPreferences
  - Example: `ScheduleRemoteDataSource` + `ScheduleRemoteDataSourceImpl`

## Reactive Data Fetching Pattern

The app uses a **reactive repository pattern** where UI updates automatically when data changes.

1. **Repository**: Holds a `BehaviorSubject` (Stream) of data.

   - Methods like `getSchedulesByDate` fetch from API/DB and **add the result to the stream**.
   - `scheduleStream` exposes this subject as a broadcast stream.

2. **UseCase**: Transforms the repository stream.

   - Can use `async*` to yield transformed states.
   - Combines multiple data sources if needed.

3. **BLoC**: Subscribes to the UseCase stream.
   // ...existing code...
   - `listen()` to the stream in event handlers.
   - `add()` new events to the BLoC when stream emits.

Example `ScheduleRepositoryImpl`:

```dart
@Singleton(as: ScheduleRepository)
class ScheduleRepositoryImpl implements ScheduleRepository {
  late final _scheduleStreamController = BehaviorSubject<Set<ScheduleEntity>>.seeded({});

  @override
  Stream<Set<ScheduleEntity>> get scheduleStream => _scheduleStreamController.asBroadcastStream();

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(...) async {
    final schedules = await remoteDataSource.getSchedulesByDate(...);
    // Update the stream with new data
    _scheduleStreamController.add(Set.from(_scheduleStreamController.value)..addAll(schedules));
    return schedules;
  }
}
```

## Form Management & Validation

The app uses a **Multi-Step Form Pattern** (e.g., `ScheduleMultiPageForm`):

1. **Parent BLoC**: `ScheduleFormBloc` manages the overall form state and final submission.
2. **Step Cubits**: Each form step has its own Cubit (e.g., `ScheduleNameCubit`) that:
   - Manages local UI state for that step.
   - Communicates updates to the parent `ScheduleFormBloc`.
3. **Validation**:
   - `ScheduleFormState` tracks `isValid` status.
   - `TopBar` enables navigation buttons based on validity.
   - `GlobalKey<FormState>` is used for per-page field validation.

## Data Transfer & Navigation

- **Route Arguments**: Pass IDs (e.g., `scheduleId`) via `GoRouter` path parameters or `extra` object.
- **Screen Initialization**:
  - Screens receive arguments in their constructor.
  - BLoCs are initialized with these arguments (e.g., `ScheduleFormEditRequested(scheduleId)`).
  - BLoCs fetch full data from Repositories/UseCases using the ID.
  - **Avoid** passing full entity objects between screens; pass IDs and refetch/stream data.

## Navigation (GoRouter)

// ...existing code...Example `ScheduleRepositoryImpl`:

```dart
@Singleton(as: ScheduleRepository)
class ScheduleRepositoryImpl implements ScheduleRepository {
  late final _scheduleStreamController = BehaviorSubject<Set<ScheduleEntity>>.seeded({});

  @override
  Stream<Set<ScheduleEntity>> get scheduleStream => _scheduleStreamController.asBroadcastStream();

  @override
  Future<List<ScheduleEntity>> getSchedulesByDate(...) async {
    final schedules = await remoteDataSource.getSchedulesByDate(...);
    // Update the stream with new data
    _scheduleStreamController.add(Set.from(_scheduleStreamController.value)..addAll(schedules));
    return schedules;
  }
}
```

## Navigation (GoRouter)

// ...existing code...## Navigation (GoRouter)

- Configured in `lib/presentation/shared/router/go_router.dart`
- Uses declarative routing with redirect logic based on `AuthBloc` and `ScheduleBloc` state
- Routes defined with path and builder
- NavigationService (`lib/core/services/navigation_service.dart`) provides programmatic navigation

## Code Generation Files

**Never manually edit** generated files (`.g.dart`, `.freezed.dart`, `di_setup.config.dart`). These are created by:

- `build_runner` for JSON serialization, Freezed, Injectable, Drift
- Regenerate after modifying annotated classes

## Testing

- Tests in `test/` mirror `lib/` structure
- Use Mockito for mocking dependencies
- Test helpers in `test/helpers/`
- Run coverage: `flutter test --coverage`

## Commit Message Convention

Follow **Conventional Commits** (enforced by commitlint):

- Format: `<type>(<optional scope>): <description>`
- Types: `feat`, `fix`, `refactor`, `perf`, `style`, `test`, `docs`, `build`, `ops`, `chore`
- Breaking changes: Add `!` before `:` (e.g., `feat(api)!: remove endpoint`)
- See `docs/Git.md` for detailed examples

## Key Project Files

- `lib/main.dart`: App entry point, Firebase initialization, DI setup
- `lib/presentation/app/screens/app.dart`: Root app widget
- `lib/core/di/di_setup.dart`: DI configuration
- `lib/core/database/database.dart`: Drift database setup
- `docs/Architecture.md`: Comprehensive architecture documentation
- `docs/Schedule-Timer-System.md`: Timer system details for ScheduleBloc

## Common Patterns

1. **Creating a new feature**:

   - Add entity in `domain/entities/`
   - Create repository interface in `domain/repositories/`
   - Add use cases in `domain/use-cases/`
   - Implement repository in `data/repositories/`
   - Add data sources (remote/local) in `data/data_sources/`
   - Build UI with BLoC in `presentation/<feature>/`
   - Annotate all with `@Injectable()` and run build_runner

2. **Adding API endpoint**:

   - Create request/response models in `data/models/` with `@JsonSerializable()`
   - Add method to RemoteDataSource interface and implementation
   - Update repository to use new data source method
   - Run `dart run build_runner build`

3. **Adding database table**:
   - Define table in `data/tables/`
   - Create DAO in `data/daos/`
   - Add to `@DriftDatabase` annotation in `database.dart`
   - Increment `schemaVersion` and add migration if needed
   - Run `dart run build_runner build`

## Environment & Configuration

- Environment variables in `lib/core/constants/environment_variable.dart`
- Firebase configuration in `firebase_options.dart`
- Analysis options in `analysis_options.yaml`

## Widgetbook

- Component showcase at `widgetbook/` (separate sub-project)
- Hosted at: https://on-time-front-widgetbook.web.app/
- Use for UI component development and testing
