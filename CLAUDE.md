# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Convert & Compress is a native macOS image conversion/compression utility built entirely in Swift with SwiftUI/AppKit. It supports batch image processing: format conversion, resize, crop, flip, background removal (Vision framework), and metadata stripping. Distributed via Mac App Store with StoreKit 2 monetization.

Bundle ID: `raffistudio.image-tools`

## Build & Run

```bash
# Build
xcodebuild -scheme convert-compress -configuration Debug build

# Run tests
xcodebuild -scheme convert-compress test

# Open in Xcode
open convert-compress.xcodeproj
```

No external dependency managers — uses Swift Package Manager via Xcode for SDWebImageWebPCoder, SDWebImageAVIFCoder, and libavif.

## Architecture

**Pattern:** MVVM with service-oriented design.

**Core data flow:**
1. Images enter via `IngestionCoordinator` (drag-drop, paste, Finder service, URL open)
2. `ImageToolsViewModel` holds all app state as `@Published` properties
3. Export builds a `ProcessingPipeline` via `PipelineBuilder`, applies `ImageOperation`s (resize, crop, flip, background removal), then encodes via `ImageExporter`

**Key types:**
- `ImageAsset` — represents one image with metadata and UUID tracking
- `ProcessingConfiguration` — immutable config snapshot for an export operation
- `ProcessingPipeline` — orchestrates transforms and encoding for a batch
- `ImageExporter` — encodes CIImage to target format (PNG, JPEG, HEIC, AVIF, WebP)
- `ImageOperations` — protocol-based transforms: `ResizeOperation`, `CropOperation`, `FlipVerticalOperation`, `RemoveBackgroundOperation`
- `VectorImageSupport` — handles SVG and PDF rasterization

**Directory layout:**
- `App/` — entry point (`ConvertCompressApp`), menu commands, window config
- `Core/` — models (`ImageAsset`, `Preset`, `ProcessingConfiguration`), constants
- `Processing/` — pipeline, encoders (AVIF, WebP), image operations
- `Services/` — ingestion, persistence, preview estimation, sandbox access, temp files, purchase/paywall/usage/rating
- `Theme/` — design system components (buttons, toggles, badges, glassmorphism)
- `ViewModels/` — `ImageToolsViewModel` (split across extensions)
- `Views/` — SwiftUI view hierarchy rooted at `MainView`

**Singleton pattern:** `AppDelegate.sharedViewModel` holds the single `ImageToolsViewModel` instance, created in `ConvertCompressApp.init()`.

## Localization

The app supports 15+ languages via `Localizable.xcstrings`. When adding or modifying user-facing strings, translate to all languages present in the strings catalog. Respect linguistic nuances per language rather than doing literal translations.

## Image Format Support

- **Read:** PNG, JPEG, HEIC, GIF, TIFF, SVG, PDF, WebP
- **Write:** PNG, JPEG, HEIC, AVIF, WebP

AVIF encoding uses a custom `AVIFEncoder` wrapping libavif directly (not SDWebImage's encoder). WebP uses SDWebImageWebPCoder.

## macOS Integration

- Registers as a Finder service (right-click context menu on images)
- Sandbox-aware file access via security-scoped bookmarks (`SandboxAccessManager`)
- Supports folder structure preservation on export
