## Git Strategy

Use trunk-based development with short-lived feature branches and explicit
release branches. Do not use full Git Flow for this repository.

### Branches

- `main`: production-ready history. Every commit on `main` should be
  releasable and test-deployable. Protect this branch and require pull request
  checks.
- `feature/*`: short-lived work branches for normal changes.
- `fix/*`: short-lived bug-fix branches for non-emergency fixes.
- `release/x.y.z`: stabilization branches for real app releases. Only bug
  fixes, localization fixes, version bumps, and release-specific release
  tweaks belong here.
- `hotfix/x.y.z`: urgent production repair branches created from the relevant
  production tag or from `main` when the tag already matches `main`.

Example branch names:

```text
feature/login-refresh
feature/schedule-cache
fix/ios-permission-copy
release/1.4.0
hotfix/1.4.1
```

Use annotated tags named `vX.Y.Z` as the source of truth for real production
releases:

```text
v1.4.0
v1.4.1
```

### Development Flow

Normal work flows through pull requests into `main`:

```text
feature/* -> PR -> main
fix/* -> PR -> main
```

Every PR into `main` must pass:

```sh
dart run build_runner build --delete-conflicting-outputs
flutter analyze
flutter test
```

Merges to `main` are continuously deployable to test channels. `main` maps to
staging/test distribution, not production.

### Release Flow

When the app is ready for a real store candidate, create a release branch from
`main`:

```text
main -> release/1.4.0
```

Use the release branch for final QA builds:

```text
release/1.4.0 -> Android closed/open testing
release/1.4.0 -> TestFlight external testing
```

After QA approval:

```text
tag v1.4.0 from release/1.4.0
v1.4.0 -> Play Store production
v1.4.0 -> App Store production
release/1.4.0 -> merge back to main
```

Production deployments must require manual approval in CI/CD. The tag is the
production release identity; branch names are only workflow staging points.

### Environment Mapping

Use Dart defines for environment selection. Native Flutter flavors can be added
later if the app needs separate bundle identifiers, app icons, or platform
configuration per environment.

```text
feature/* PR builds -> ENV=dev
main builds -> ENV=staging
release/* builds -> ENV=staging
v* tags -> ENV=prod
```

Build examples:

```sh
flutter build apk --dart-define=ENV=staging
flutter build appbundle --release --dart-define=ENV=prod
flutter build ipa --release --dart-define=ENV=prod
```

Keep Android and iOS versioning synchronized through `pubspec.yaml`:

```yaml
version: 1.4.0+123
```

`1.4.0` is the user-visible version. `123` is the build number, and CI may
override it with a generated monotonic build number for store uploads.

## Commit Message Formats

### Default
<pre>
<b><a href="#types">&lt;type&gt;</a></b></font>(<b><a href="#scopes">&lt;optional scope&gt;</a></b>): <b><a href="#description">&lt;description&gt;</a></b>
<sub>empty separator line</sub>
<b><a href="#body">&lt;optional body&gt;</a></b>
<sub>empty separator line</sub>
<b><a href="#footer">&lt;optional footer&gt;</a></b>
</pre>

### Types
* API relevant changes
    * `feat` Commits, that add or remove a new feature
    * `fix` Commits, that fixes a bug
* `refactor` Commits, that rewrite/restructure your code, however, does not change any API behavior
    * `perf` Commits are special `refactor` commits, that improve performance
* `style` Commits, that do not affect the meaning (white-space, formatting, missing semi-colons, etc)
* `test` Commits, that add missing tests or correct existing tests
* `docs` Commits, that affect documentation only
* `build` Commits affect build components like build tool, ci pipeline, dependencies, project version, ...
* `ops` Commits affect operational components like infrastructure, deployment, backup, recovery, ...
* `chore` Miscellaneous commits e.g. modifying `.gitignore`

### Scopes
The `scope` provides additional contextual information.
* Is an **optional** part of the format
* Allowed Scopes depends on the specific project
* Don't use issue identifiers as scopes

### Breaking Changes Indicator
Breaking changes should be indicated by an `!` before the `:` in the subject line e.g. `feat(api)!: remove status endpoint`
* Is an **optional** part of the format

### Description
The `description` contains a concise description of the change.
* Is a **mandatory** part of the format
* Use the imperative, present tense: "change" not "changed" nor "changes"
  * Think of `This commit will...` or `This commit should...`
* Don't capitalize the first letter
* No dot (`.`) at the end

### Body
The `body` should include the motivation for the change and contrast this with previous behavior.
* Is an **optional** part of the format
* Use the imperative, present tense: "change" not "changed" nor "changes"
* This is the place to mention issue identifiers and their relations

### Footer
The `footer` should contain any information about **Breaking Changes** and is also the place to **reference Issues** that this commit refers to.
* Is an **optional** part of the format
* **optionally** reference an issue by its id.
* **Breaking Changes** should start with the word `BREAKING CHANGES:` followed by space or two newlines. The rest of the commit message is then used for this.


### Examples
* ```
  feat: add email notifications on new direct messages
  ```
* ```
  feat(shopping cart): add the amazing button
  ```
* ```
  feat!: remove ticket list endpoint

  refers to JIRA-1337

  BREAKING CHANGES: ticket endpoints no longer support listing all entities.
  ```
* ```
  fix(shopping-cart): prevent ordering an empty shopping cart
  ```
* ```
  fix(api): fix the wrong calculation of the request body checksum
  ```
* ```
  fix: add a missing parameter to a service call

  The error occurred because of <reasons>.
  ```
* ```
  perf: decrease memory footprint to determine uniqe visitors by using HyperLogLog
  ```
* ```
  build: update dependencies
  ```
* ```
  build(release): bump version to 1.0.0
  ```
* ```
  refactor: Implement Fibonacci number calculation as recursion
  ```
* ```
  style: remove empty line
  ```

---
