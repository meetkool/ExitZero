# AGENTS.md - ExitZero Coding Guidelines

## Build Commands

```bash
# Install dependencies
flutter pub get

# Build Android APK (debug)
flutter build apk --debug

# Build Android APK (release)
flutter build apk --release

# Build web
flutter build web

# Clean build artifacts
flutter clean
```

## Test Commands

```bash
# Run all tests
flutter test

# Run a single test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage

# Run specific test by name
flutter test --name="Counter increments"
```

## Lint Commands

```bash
# Analyze code for issues
flutter analyze

# Format all Dart files
dart format .

# Check formatting without changes
dart format --output=none --set-exit-if-changed .

# Apply fixes automatically
dart fix --apply
```

## Code Style Guidelines

### Imports
- Order: Dart SDK → Flutter packages → Third-party → Local (relative)
- Use single quotes for imports: `import 'package:flutter/material.dart';`
- Group local imports separately with blank line separation

### Formatting
- Use `dart format` (line width: 80 characters)
- Trailing commas for multi-line parameters and collections
- 2-space indentation (Flutter standard)

### Naming Conventions
- **Classes/Pages**: PascalCase (e.g., `DashboardPage`, `AuthService`)
- **Files**: snake_case (e.g., `dashboard_page.dart`, `auth_service.dart`)
- **Private members**: prefix with underscore (e.g., `_layoutState`)
- **Constants**: camelCase for local, SCREAMING_SNAKE_CASE for static const
- **Widgets**: Suffix with widget type (e.g., `Page`, `Card`, `Button`)

### Types
- Prefer `const` constructors when possible
- Use `final` for immutable variables
- Avoid `dynamic` - use explicit types
- Nullable types: Use `?` suffix, avoid `late` unless necessary

### Widget Structure
- Extend `StatelessWidget` or `StatefulWidget`
- Use `const` keyword for widget constructors
- Extract reusable widgets to separate files in `lib/widgets/`
- Keep `build()` methods under 100 lines

### State Management
- Use `setState()` for local state
- Prefer `StatefulWidget` over external state for simple cases
- Initialize state in `initState()`, dispose in `dispose()`
- Use `SharedPreferences` for persistence (see dashboard_page.dart)

### Error Handling
- Use `try/catch` for async operations
- Log errors: `// Ignore malformed state` pattern acceptable
- Provide fallback UI for error states
- Validate inputs before API calls

### Comments
- Use `///` for public API documentation
- Use `//` for inline explanations
- Document complex logic and business rules
- Add `// TODO:` for incomplete features

### File Organization
```
lib/
├── main.dart              # Entry point
├── app.dart              # Root widget & routes
├── pages/                # Screen widgets
│   ├── dashboard/
│   └── *_page.dart
├── widgets/              # Reusable UI components
├── services/             # API & business logic
└── theme/                # Colors, themes, styles
```

## CI/CD
- GitLab CI runs on `main` branch only
- Builds release APK automatically
- Publishes to GitLab Package Registry

## Testing Best Practices
- Widget tests in `test/` directory
- Test widget interactions with `WidgetTester`
- Use `find.byType()`, `find.text()`, `find.byIcon()`
- Call `tester.pump()` after state changes
- Test both success and error states

## Dependencies
- Add to `pubspec.yaml` under `dependencies:` or `dev_dependencies:`
- Run `flutter pub get` after changes
- Pin versions: `package_name: ^major.minor.patch`
