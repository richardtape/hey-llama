# Milestone 0: Project Setup

## Overview

For general project context, see:
- [`CLAUDE.md`](../../CLAUDE.md) - Quick reference for architecture and patterns
- [`docs/spec.md`](../spec.md) - Complete technical specification

## Goal

Create the Xcode project structure, configure dependencies, and establish the foundational app shell as a menu bar application.

## Prerequisites

- macOS 14+ (Sonoma)
- Xcode 15+
- Apple Silicon Mac (M1/M2/M3/M4)

---

## Phase 1: Design

This milestone is primarily setup with minimal design decisions:

- [ ] Confirm project name: `HeyLlama`
- [ ] Confirm bundle identifier format: `com.yourname.HeyLlama`
- [ ] Confirm minimum deployment target: macOS 14.0

---

## Phase 2: Test Setup

Minimal for this milestone since we're creating the project structure. Testing infrastructure comes in Milestone 1.

- [ ] Create `HeyLlamaTests/` group in Xcode
- [ ] Create `Mocks/` subgroup for future mock services
- [ ] Verify test target builds (even with no tests yet)

---

## Phase 3: Implementation

### Create Xcode Project

- [ ] Create new Xcode project named "HeyLlama"
- [ ] Select macOS App template with SwiftUI
- [ ] Set minimum deployment target to macOS 14.0
- [ ] Enable Swift strict concurrency checking

### Configure as Menu Bar App

- [ ] Add `LSUIElement = YES` to Info.plist (hides dock icon)
- [ ] Configure app as menu bar only (no main window)

### Configure Swift Package Dependencies

- [ ] Add WhisperKit package (`https://github.com/argmaxinc/WhisperKit.git`, from 0.9.0)
- [ ] Add FluidAudio package (`https://github.com/FluidInference/FluidAudio.git`, from 0.10.0)
- [ ] Verify packages resolve successfully

### Set Up Project Structure

Create the following groups in Xcode:

- [ ] `App/` - Entry point, AppDelegate
- [ ] `UI/` with subgroups:
  - [ ] `MenuBar/`
  - [ ] `Settings/`
  - [ ] `Enrollment/`
  - [ ] `Components/`
- [ ] `Core/` - Coordinator, state machine
- [ ] `Services/` with subgroups:
  - [ ] `Audio/`
  - [ ] `Speech/`
  - [ ] `Speaker/`
  - [ ] `LLM/`
  - [ ] `TTS/`
  - [ ] `API/`
- [ ] `Models/`
- [ ] `Storage/`
- [ ] `Utilities/`
- [ ] `Resources/`

### Create App Entry Point

- [ ] Create `HeyLlamaApp.swift` in `App/`
- [ ] Add `@main` attribute
- [ ] Configure `MenuBarExtra` scene for menu bar presence
- [ ] Configure `Settings` scene for preferences window
- [ ] Configure `Window` scene for enrollment (opens on demand)

### Create AppDelegate

- [ ] Create `AppDelegate.swift` in `App/`
- [ ] Implement `NSApplicationDelegate` conformance
- [ ] Implement `applicationDidFinishLaunching` with `NSApp.setActivationPolicy(.accessory)`
- [ ] Implement `applicationWillTerminate` for cleanup placeholder
- [ ] Add placeholder for permission requests

### Configure Entitlements

- [ ] Add microphone usage description to Info.plist (`NSMicrophoneUsageDescription`)
- [ ] Add network client entitlement (for LLM API calls)
- [ ] Add network server entitlement (for API server)

### Create Basic Menu Bar UI

- [ ] Create `MenuBarView.swift` in `UI/MenuBar/`
- [ ] Display app name and version
- [ ] Add "Preferences..." menu item (opens Settings window)
- [ ] Add separator
- [ ] Add "Quit" menu item

---

## Phase 4: Integration

- [ ] Wire `AppDelegate` to app via `@NSApplicationDelegateAdaptor`
- [ ] Ensure `MenuBarView` displays in menu bar dropdown
- [ ] Verify Settings window opens from menu item
- [ ] Verify Quit terminates the app

---

## Phase 5: Verification

### Build Verification

- [ ] Project builds without errors: `xcodebuild build -scheme HeyLlama`
- [ ] Project builds without warnings (or only expected dependency warnings)
- [ ] Test target builds: `xcodebuild build-for-testing -scheme HeyLlama`

### Runtime Verification

- [ ] App launches successfully
- [ ] Menu bar icon appears in system menu bar
- [ ] No dock icon appears (LSUIElement working)
- [ ] Menu bar dropdown displays correctly
- [ ] "Preferences..." opens Settings window
- [ ] "Quit" terminates the app cleanly
- [ ] No crashes or console errors on launch

### Dependency Verification

- [ ] WhisperKit imports without errors (add `import WhisperKit` to test file)
- [ ] FluidAudio imports without errors (add `import FluidAudio` to test file)

---

## Phase 6: Completion

### Git Commit

```bash
git add .
git commit -m "Milestone 0: Project setup with menu bar app shell

- Create HeyLlama Xcode project with SwiftUI
- Configure as menu bar app (LSUIElement)
- Add WhisperKit and FluidAudio dependencies
- Set up project group structure
- Implement basic MenuBarView with Quit/Preferences
- Configure entitlements for mic and network"
```

### Ready for Next Milestone

- [ ] All Phase 5 verification items pass
- [ ] Code committed to version control
- [ ] Ready to proceed to [Milestone 1: Audio Foundation](./01-audio-foundation.md)

---

## Deliverable

A buildable menu bar app shell with all dependencies configured and project structure in place. The app shows in the menu bar, displays a dropdown menu, and can be quit. No dock icon appears.
