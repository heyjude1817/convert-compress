# Repository Guidelines

## Project Structure & Module Organization
`convert-compress/` contains the macOS app target. Core app entry points live in `App/`, domain models and constants in `Core/`, image pipeline code in `Processing/`, service-layer logic in `Services/`, shared UI building blocks in `Theme/`, state management in `ViewModels/`, and SwiftUI screens in `Views/`. Assets and localization live in `Assets.xcassets/`, `Localizable.xcstrings`, and `InfoPlist.xcstrings`.

Tests are split by target: `convert-compress-tests/` for unit tests and `convert-compress-ui-tests/` for UI coverage. Planning and product notes live in `docs/`.

## Build, Test, and Development Commands
Use Xcode or `xcodebuild` from the repo root:

```bash
xcodebuild -scheme convert-compress -configuration Debug build
xcodebuild -scheme convert-compress test
open convert-compress.xcodeproj
```

The build command validates the app target. The test command runs the shared scheme’s unit-test action. Open the project in Xcode when working on SwiftUI previews, StoreKit configuration, or signing-related settings.

## Coding Style & Naming Conventions
Follow existing Swift conventions: 4-space indentation, `UpperCamelCase` for types, `lowerCamelCase` for properties and methods, and one primary type per file when practical. Keep view models split by concern using extension files such as `ImageToolsViewModel+Processing.swift`.

Prefer small service types under `Services/` and keep UI-only code in `Views/` or `Theme/`. No repo-wide `SwiftLint` or `SwiftFormat` config is checked in, so match the surrounding file style and let Xcode formatting be the baseline.

## Testing Guidelines
Tests use `XCTest`. Name test files after the subject under test, for example `NamingTemplateResolverTests.swift`, and name methods by behavior, such as `testBatchCollisionResolution`. Add unit tests for new pipeline, service, and model behavior; add UI tests only for app-flow changes that need launch-level coverage.

## Commit & Pull Request Guidelines
Recent history uses Conventional Commit prefixes: `feat:`, `fix:`, `docs:`, and `chore:`. Keep commits focused and descriptive, for example `fix: prevent duplicate export filenames`.

Pull requests should include a short summary, the user-visible impact, test coverage notes, and screenshots or recordings for UI changes. Link related issues or planning docs when applicable.
