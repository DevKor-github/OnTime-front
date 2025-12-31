# OnTime Flutter Project Architecture

This document provides a comprehensive overview of the OnTime Flutter project's architecture, folder structure, and design patterns.

## 🏗️ Architecture Overview

OnTime follows **Clean Architecture** principles with a clear separation of concerns across three main layers:

- **Presentation Layer**: UI components, state management (BLoC/Cubit), and navigation
- **Domain Layer**: Business logic, entities, use cases, and repository interfaces
- **Data Layer**: Repository implementations, data sources (local/remote), and data models

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                       │
├─────────────────────────────────────────────────────────────┤
│  • Screens & Components                                     │
│  • BLoC/Cubit (State Management)                           │
│  • Navigation (GoRouter)                                   │
│  • Theme & Localization                                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                     DOMAIN LAYER                            │
├─────────────────────────────────────────────────────────────┤
│  • Entities (Business Objects)                             │
│  • Use Cases (Business Logic)                              │
│  • Repository Interfaces                                   │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      DATA LAYER                             │
├─────────────────────────────────────────────────────────────┤
│  • Repository Implementations                              │
│  • Data Sources (Remote API, Local Database, Local Storage)│
│  • Data Models (JSON Serialization)                        │
│  • Database Tables & DAOs                                  │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Project Structure

```
lib/
├── 📱 presentation/          # UI Layer (Screens, Widgets, State Management)
│   ├── alarm/               # Alarm and timer functionality
│   ├── app/                 # Main app setup and global BLoC
│   ├── calendar/            # Calendar views and components
│   ├── early_late/          # Early/late arrival screens
│   ├── home/                # Home screen and dashboard
│   ├── login/               # Authentication screens
│   ├── my_page/             # User profile and settings
│   ├── notification_allow/  # Notification permission
│   ├── onboarding/          # User onboarding flow
│   ├── schedule_create/     # Schedule creation and editing
│   └── shared/              # Shared UI components and utilities
│       ├── components/      # Reusable widgets
│       ├── router/          # Navigation configuration
│       ├── theme/           # App theming
│       └── utils/           # UI utilities
│
├── 🏢 domain/               # Business Logic Layer
│   ├── entities/            # Business objects (User, Schedule, etc.)
│   ├── repositories/        # Repository interfaces
│   └── use-cases/           # Business logic operations
│
├── 💾 data/                 # Data Access Layer
│   ├── daos/                # Database Access Objects (Drift)
│   ├── data_sources/        # Data source interfaces/implementations
│   ├── models/              # API request/response models
│   ├── repositories/        # Repository implementations
│   └── tables/              # Database table definitions
│
├── 🔧 core/                 # Core Infrastructure
│   ├── constants/           # App constants and environment variables
│   ├── database/            # Database configuration (Drift)
│   ├── di/                  # Dependency injection setup (Injectable)
│   ├── dio/                 # HTTP client configuration
│   ├── services/            # Core services (navigation, notifications)
│   └── utils/               # Core utilities and converters
│
├── 🌍 l10n/                 # Localization files
├── firebase_options.dart    # Firebase configuration
└── main.dart               # Application entry point
```

## 🛠️ Technology Stack

### Core Framework & Language

- **Flutter**: Cross-platform mobile framework
- **Dart**: Programming language

### State Management

- **BLoC/Cubit**: Business Logic Component pattern for state management
- **Riverpod**: Additional state management for specific use cases
- **Equatable**: Value equality for state objects

### Dependency Injection

- **Injectable**: Code generation for dependency injection
- **GetIt**: Service locator pattern

### Database & Persistence

- **Drift**: Type-safe SQL database library
- **SharedPreferences**: Simple key-value storage
- **FlutterSecureStorage**: Secure token storage

### Networking

- **Dio**: HTTP client with interceptors
- **JSON Annotation**: JSON serialization code generation

### Navigation

- **GoRouter**: Declarative routing solution

### UI Components

- **Material Design**: Google's design system
- **Flutter SVG**: SVG asset support
- **TableCalendar**: Calendar widget

### Authentication

- **Google Sign-In**: Google OAuth integration
- **Kakao SDK**: Kakao social login
- **Firebase Auth**: Authentication backend

### Notifications

- **Firebase Messaging**: Push notifications
- **Flutter Local Notifications**: Local notifications

### Development Tools

- **Freezed**: Code generation for immutable classes
- **Build Runner**: Code generation runner
- **Widgetbook**: Component development environment

## 📋 Architecture Patterns

### 1. Clean Architecture Layers

#### **Presentation Layer**

- **Screens**: Full-screen widgets representing app pages
- **Components**: Reusable UI widgets
- **BLoC/Cubit**: State management following BLoC pattern
- **Navigation**: Declarative routing with GoRouter

#### **Domain Layer**

- **Entities**: Core business objects using Freezed for immutability
- **Use Cases**: Single-responsibility business logic operations
- **Repository Interfaces**: Contracts for data access

#### **Data Layer**

- **Repository Implementations**: Concrete implementations of domain interfaces
- **Data Sources**: Abstraction over remote APIs and local storage
- **Models**: Data transfer objects with JSON serialization

### 2. Dependency Injection

```dart
// Injectable annotation for automatic registration
@Injectable()
class UserRepository implements UserRepositoryInterface {
  // Implementation
}

// GetIt service locator configuration
final getIt = GetIt.instance;

@InjectableInit()
void configureDependencies() => getIt.init();
```

### 3. State Management with BLoC

```dart
// BLoC for handling user authentication state
@Injectable()
class AppBloc extends Bloc<AppEvent, AppState> {
  AppBloc(this._streamUserUseCase, this._signOutUseCase)
      : super(AppState(user: const UserEntity.empty())) {
    on<AppUserSubscriptionRequested>(_onUserSubscriptionRequested);
    on<AppSignOutPressed>(_onSignOutPressed);
  }
}
```

### 4. Data Models with JSON Serialization

```dart
@JsonSerializable()
class GetUserResponseModel {
  final int userId;
  final String email;
  final String name;

  // Conversion to domain entity
  UserEntity toEntity() {
    return UserEntity(
      id: userId.toString(),
      email: email,
      name: name,
    );
  }
}
```

### 5. Database Layer with Drift

```dart
@DriftDatabase(tables: [Users, Schedules, Places], daos: [UserDao, ScheduleDao])
class AppDatabase extends _$AppDatabase {
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (Migrator m) async => await m.createAll(),
  );
}
```

## 🔄 Data Flow

### 1. User Interaction Flow

```
User Input → Widget → BLoC Event → Use Case → Repository → Data Source → API/DB
                ↓
Widget ← BLoC State ← Use Case ← Repository ← Data Source ← Response
```

### 2. Authentication Flow

```
Login Screen → AppBloc → SignInUseCase → UserRepository → AuthDataSource → API
      ↓
Navigation ← AppBloc ← UserEntity ← UserRepository ← AuthDataSource ← Token
```

### 3. Schedule Management Flow

```
Schedule Form → ScheduleBloc → CreateScheduleUseCase → ScheduleRepository
                     ↓
Database ← ScheduleDao ← ScheduleRepository ← ScheduleEntity
```

## 🎯 Key Features Architecture

### 1. **Authentication System**

- **Google OAuth** and **Kakao Login** integration
- **JWT token** management with secure storage
- **Stream-based** user state management
- **Automatic token refresh** via interceptors

### 2. **Schedule Management**

- **CRUD operations** for schedules
- **Calendar integration** with multiple view modes
- **Preparation time calculation** and management
- **Real-time synchronization** between local and remote data
- **Automatic timer system** for schedule start notifications

📖 **Detailed Documentation**: For comprehensive information about the automatic timer system, see [Schedule Timer System](./Schedule-Timer-System.md)

### 3. **Notification System**

- **Firebase push notifications** for schedule reminders
- **Local notifications** for preparation alerts
- **Permission handling** for notification access

### 4. **Offline Support**

- **Local database** with Drift for offline data access
- **Synchronization strategy** for online/offline data consistency
- **Caching mechanisms** for improved performance

### 5. **Error Handling System**

- **Result pattern** for explicit, type-safe error handling
- **Structured failure hierarchy** across all layers (Core, Domain, Data)
- **Automatic logging** to Firebase Crashlytics in production
- **Environment-aware messaging**: detailed errors in debug, user-friendly messages in production
- **Layer-appropriate failures**: Domain failures contain no infrastructure details

📖 **Detailed Documentation**: For comprehensive information about the error handling system, see [Error Handling System](./Error-Handling-Result-System.md)

### 6. **Local Storage for Timed Preparation**

- `PreparationWithTimeLocalDataSource` persists `PreparationWithTimeEntity` per schedule using SharedPreferences.
- Intended for lightweight, per-schedule timer state (elapsed time, completion) that should survive app restarts.
- Repository reads canonical preparation from remote/DB; BLoC can merge it with locally persisted timing state when needed.

## 🧪 Testing Strategy

### Structure

```
test/
├── config/              # Test configuration
├── data/               # Data layer tests
└── helpers/            # Test utilities
```

### Testing Approach

- **Unit Tests**: Use cases, repositories, and business logic
- **Widget Tests**: UI components and screen interactions
- **Integration Tests**: End-to-end user flows
- **Mocking**: Using Mockito for external dependencies

## 📦 Build & Deployment

### Development Environment

- **Flutter SDK**: ^3.5.4
- **Dart SDK**: Latest stable
- **Build Tools**: build_runner for code generation

### Code Generation Commands

```bash
# Generate all code (models, dependency injection, etc.)
dart run build_runner build

# Watch for changes and regenerate
dart run build_runner watch
```

### Platform Support

- **Android**: Native Android build
- **iOS**: Native iOS build
- **Web**: Progressive Web App support

## 🔧 Development Guidelines

### 1. **Code Organization**

- Follow **Clean Architecture** principles
- Separate concerns across layers
- Use **feature-based** folder structure in presentation layer

### 2. **State Management**

- Use **BLoC pattern** for complex state management
- Use **Cubit** for simpler state scenarios
- Keep business logic in **use cases**, not in BLoCs

### 3. **Data Handling**

- Always use **entities** in the domain layer
- Convert **models to entities** at repository boundaries
- Implement **proper error handling** throughout the layers
- Use **Result pattern** for all operations that can fail

📖 **Detailed Documentation**: For comprehensive information about error handling, see [Error Handling System](./Error-Handling-Result-System.md)

### 4. **Naming Conventions**

- **Entities**: `UserEntity`, `ScheduleEntity`
- **Use Cases**: `GetUserUseCase`, `CreateScheduleUseCase`
- **Repositories**: `UserRepository`, `ScheduleRepository`
- **BLoCs**: `UserBloc`, `ScheduleFormBloc`
- **Models**: `GetUserResponseModel`, `CreateScheduleRequestModel`

### 5. **Dependencies**

- Register all dependencies using **@Injectable()** annotation
- Use **interfaces** for repository contracts
- Avoid direct dependencies between layers

## 🚀 Getting Started for New Developers

1. **Setup Environment**

   - Install Flutter SDK
   - Configure IDE (VS Code/Android Studio)
   - Run `flutter pub get` to install dependencies

2. **Code Generation**

   - Run `dart run build_runner build`
   - This generates dependency injection, JSON serialization, and Freezed code

3. **Database Setup**

   - Database migrations are handled automatically
   - Local database files are created on first run

4. **Understanding the Flow**

   - Start with `main.dart` to understand app initialization
   - Explore `presentation/app/` for global app state
   - Check `domain/use-cases/` for business logic
   - Review `data/repositories/` for data access patterns

5. **Making Changes**
   - Create new features following the existing layer structure
   - Add new entities in `domain/entities/`
   - Implement use cases in `domain/use-cases/`
   - Create repository interfaces and implementations
   - Build UI components in `presentation/`

---

_This architecture documentation is maintained alongside the codebase. Please update it when making significant architectural changes._
