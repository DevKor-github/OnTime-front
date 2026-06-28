# Repository Guidelines

## Project Structure & Module Organization

This Flutter app uses layered code under `lib/`. Platform services, database, DI, and networking live in `lib/core/`; data sources, DAOs, models, tables, and repository implementations in `lib/data/`; entities, repository contracts, and use cases in `lib/domain/`; screens, blocs, cubits, and shared widgets in `lib/presentation/`. Localization is in `lib/l10n/`. Tests mirror app paths under `test/`, with helpers in `test/helpers/`. Assets and fonts are in `assets/`; platform projects are in `android/`, `ios/`, `web/`, `macos/`, `linux/`, and `windows/`. Docs are in `docs/`; agent plans belong in `plans/`.

## Build, Test, and Development Commands

- `flutter pub get`: install Dart and Flutter dependencies.
- `dart run build_runner build --delete-conflicting-outputs`: regenerate Drift, JSON, Injectable, Mockito, Freezed, and Widgetbook Dart outputs as ignored local build artifacts.
- `flutter analyze`: run analyzer checks using `analysis_options.yaml`.
- `flutter test`: run the full test suite.
- `flutter test --coverage`: run tests and update `coverage/lcov.info`.
- `flutter run -d chrome`: run the web app locally.
- `cd widgetbook && flutter run -d chrome`: run the Widgetbook project.

Do not use `npm test`; the root `package.json` placeholder script intentionally fails.

## Coding Style & Naming Conventions

Follow `package:flutter_lints/flutter.yaml`. Use standard Dart formatting with two-space indentation; run `dart format lib test` before broad Dart edits are submitted. File names use `snake_case.dart`; classes, blocs, cubits, entities, and models use `PascalCase`; methods and fields use `camelCase`. Generated Dart outputs (`*.g.dart`, `*.config.dart`, `*.freezed.dart`, `*.mocks.dart`, including Widgetbook directories output) are ignored build artifacts; regenerate them before analyze/test but do not stage or commit them. Preserve clean-architecture boundaries: UI should depend on domain use cases, not remote data sources.

## Testing Guidelines

Place tests next to the matching layer path under `test/`, and name files `*_test.dart` (for example, `test/data/repositories/schedule_repository_impl_test.dart`). Prefer unit tests for domain/data changes and widget tests for presentation behavior. For blocs or cubits, cover events, emitted states, and repository failure cases.

## Commit & Pull Request Guidelines

Commits follow Conventional Commits through commitlint, such as `feat: add schedule refresh` or `chore: update widget layout`; the configured header limit is 500 characters. PRs should include a description, linked issue when applicable, test results, and screenshots or recordings for UI changes. Call out generator or source changes when they affect generated Dart output, but do not include ignored generated Dart files in PRs.

## Agent-Specific Instructions

Store implementation plans in `plans/`. If work remains at handoff, create a handoff note in `handoff/` describing status, blockers, and next steps. Treat files in `rule/`, when present, as persistent instructions for later agent work and consult them before making changes.
