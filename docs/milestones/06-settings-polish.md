# Milestone 6: Settings & Polish

## Overview

For general project context, see:
- [`CLAUDE.md`](../../CLAUDE.md) - Quick reference for architecture and patterns
- [`docs/spec.md`](../spec.md) - Complete technical specification (Sections 7, 10)

## Goal

Complete the user experience with comprehensive settings, error handling, logging, onboarding flow, and production polish. Prepare the app for daily use.

## Prerequisites

- Milestone 5 complete (API server working)

---

## Phase 1: Design

Key design decisions for this milestone:

- [ ] Confirm onboarding flow: permissions → API key → optional enrollment
- [ ] Confirm logging: to file with rotation, keep 7 days
- [ ] Confirm keyboard shortcut: Cmd+Shift+L to toggle listening
- [ ] Confirm launch at login: using SMAppService
- [ ] Confirm error UX: speak errors, show in menu bar

---

## Phase 2: Test Setup

This milestone focuses on polish and UX. Testing is primarily manual verification with some error scenario tests.

### Write Error Handling Tests (RED)

- [ ] Test: Microphone permission denied shows appropriate error
- [ ] Test: Network error during LLM call triggers error speech
- [ ] Test: Invalid API key triggers specific error message
- [ ] Test: Storage read/write errors handled gracefully
- [ ] Test: Audio device disconnection handled

### Write Config Persistence Tests

- [ ] Test: Settings save correctly
- [ ] Test: Settings load on startup
- [ ] Test: Invalid config file falls back to defaults
- [ ] Test: Migration from older config versions (if applicable)

---

## Phase 3: Implementation

### Complete Settings UI Structure

- [ ] Create main `SettingsView.swift` with `TabView`
- [ ] Add "General" tab
- [ ] Add "Audio" tab
- [ ] Add "Speakers" tab
- [ ] Add "LLM" (or "AI") tab
- [ ] Add "API" tab
- [ ] Add "About" tab
- [ ] Apply consistent styling

### Implement AudioSettingsView

- [ ] Create `AudioSettingsView.swift` in `UI/Settings/`
- [ ] Query available input devices
- [ ] Query available output devices
- [ ] Input device picker
- [ ] Output device picker
- [ ] Silence threshold slider
- [ ] Live audio level meter
- [ ] "Test Microphone" button
- [ ] Save selections to config

### Implement Audio Device Selection

- [ ] Query devices from CoreAudio
- [ ] Apply selection to AudioEngine
- [ ] Handle device disconnection
- [ ] Fall back to default if unavailable
- [ ] Persist selection

### Enhance GeneralSettingsView

- [ ] Wake phrase text field
- [ ] Wake word sensitivity slider
- [ ] "Launch at Login" toggle via `SMAppService`
- [ ] "Play sounds" toggle for chimes
- [ ] "Show notifications" toggle (future)

### Enhance LLM Settings

- [ ] Test connection button with result display
- [ ] Temperature slider for creativity
- [ ] Max tokens configuration
- [ ] System prompt preview with variable substitution
- [ ] API key validation before save

### Implement Logging Infrastructure

- [ ] Create `Logging.swift` in `Utilities/`
- [ ] Define levels: `.debug`, `.info`, `.warning`, `.error`
- [ ] Create `log(_ message: String, level: LogLevel, file: String, function: String)`
- [ ] Log to console in debug builds
- [ ] Log to file: `~/Library/Logs/HeyLlama/`
- [ ] Implement log rotation (keep 7 days)
- [ ] Include timestamp and context

### Create Debug/Logs View

- [ ] Create `LogsView.swift` in `UI/`
- [ ] Display recent log entries
- [ ] Filter by log level
- [ ] Search functionality
- [ ] "Copy Logs" button
- [ ] "Clear Logs" button
- [ ] Access from menu bar or settings

### Implement Error Handling

#### Define Error Types

- [ ] Create `HeyLlamaError` enum
- [ ] Cases for each failure mode:
  - `.microphonePermissionDenied`
  - `.modelLoadFailed(String)`
  - `.networkError(String)`
  - `.apiKeyInvalid`
  - `.apiRateLimited`
  - `.storageError(String)`
  - `.audioDeviceError(String)`

#### Handle Errors Gracefully

- [ ] Catch errors at coordinator level
- [ ] Map to user-friendly messages
- [ ] Speak critical errors
- [ ] Show in menu bar dropdown
- [ ] Log detailed info

### Implement Onboarding Flow

- [ ] Create `OnboardingView.swift` in `UI/`
- [ ] Detect first launch (no config exists)

#### Onboarding Steps

- [ ] Step 1: Welcome screen with overview
- [ ] Step 2: Request microphone permission
- [ ] Step 3: Enter Anthropic API key
- [ ] Step 4: Enroll first speaker (optional, skip button)
- [ ] Step 5: Test with sample command
- [ ] Step 6: Complete with tips

#### First Launch Detection

- [ ] Check for config file on launch
- [ ] Show onboarding if missing
- [ ] Store "onboardingCompleted" flag
- [ ] Option to re-run from settings

### Create About View

- [ ] App name and icon
- [ ] Version and build number
- [ ] Link to documentation
- [ ] Link to report issues
- [ ] Open source licenses
- [ ] Credits: Anthropic, WhisperKit, FluidAudio

### Polish Menu Bar UI

- [ ] Refine icons for each state
- [ ] Subtle state change animations
- [ ] Last command/response preview
- [ ] Mute/unmute toggle
- [ ] Error notification badge
- [ ] Compact vs detailed mode option

### Implement Keyboard Shortcuts

- [ ] Global shortcut: Cmd+Shift+L to toggle listening
- [ ] Register with `NSEvent.addGlobalMonitorForEvents`
- [ ] Make shortcut configurable
- [ ] Show hint in menu bar

### Implement Mute/Pause

- [ ] "Pause Listening" menu item
- [ ] Stop audio capture when paused
- [ ] Change icon to indicate paused
- [ ] Resume on unpause
- [ ] Auto-resume timeout (optional)

### Handle System Events

#### Sleep/Wake

- [ ] Register for `NSWorkspace` sleep notifications
- [ ] Stop audio before sleep
- [ ] Restart audio on wake
- [ ] Reconnect API clients
- [ ] Reload models if needed

#### Device Changes

- [ ] Listen for audio device configuration changes
- [ ] Handle microphone disconnect
- [ ] Switch to default if needed
- [ ] Notify user

### Implement Data Export/Import

- [ ] Export speakers to JSON
- [ ] Import speakers from JSON
- [ ] Export configuration
- [ ] Import configuration
- [ ] Validation on import

### Performance Optimization

- [ ] Profile memory usage
- [ ] Check for leaks with Instruments
- [ ] Optimize audio buffer management
- [ ] Reduce idle CPU usage
- [ ] Test extended operation (hours)

### Accessibility

- [ ] VoiceOver compatibility
- [ ] Accessibility labels on all elements
- [ ] Keyboard navigation in settings
- [ ] Test with accessibility features

### Localization Preparation

- [ ] Extract strings to `Localizable.strings`
- [ ] Use `NSLocalizedString` throughout
- [ ] Prepare for future translations

---

## Phase 4: Integration

### Wire Up New Settings

- [ ] Connect audio settings to AudioEngine
- [ ] Connect launch at login to SMAppService
- [ ] Connect keyboard shortcut registration
- [ ] Connect mute state to coordinator

### Update AppDelegate

- [ ] Show onboarding on first launch
- [ ] Register for sleep/wake notifications
- [ ] Register for device change notifications
- [ ] Set up keyboard shortcuts

### Update Menu Bar

- [ ] Add all new menu items
- [ ] Wire up mute toggle
- [ ] Add debug logs access
- [ ] Add about item

---

## Phase 5: Verification

### Test Suite

- [ ] Run all unit tests: `xcodebuild test -scheme HeyLlama`
- [ ] All error handling tests pass
- [ ] All config persistence tests pass
- [ ] All previous milestone tests pass

### Manual Testing Checklist

#### Fresh Install

- [ ] Onboarding appears on first launch
- [ ] Microphone permission flow works
- [ ] API key entry works
- [ ] Optional speaker enrollment works
- [ ] Test command works

#### Settings

- [ ] All settings tabs accessible
- [ ] Audio device selection works
- [ ] Voice/rate/volume settings work
- [ ] Wake phrase change works
- [ ] API key update works
- [ ] All settings persist across restart

#### Core Functionality

- [ ] Wake word detection reliable
- [ ] Transcription accurate
- [ ] Speaker identification accurate
- [ ] LLM responses appropriate
- [ ] TTS clear and natural

#### Error Handling

- [ ] Network disconnect: speaks error
- [ ] Invalid API key: helpful message
- [ ] Microphone disconnect: recovers

#### System Events

- [ ] Sleep/wake: recovers correctly
- [ ] Device change: handles gracefully
- [ ] Extended operation: stable for hours

#### Polish

- [ ] Keyboard shortcut works
- [ ] Mute toggle works
- [ ] About view displays correctly
- [ ] Logs view works

### Performance Testing

- [ ] Memory stable over time
- [ ] No leaks in Instruments
- [ ] CPU reasonable when idle
- [ ] Responsive during use

### Accessibility Testing

- [ ] VoiceOver navigable
- [ ] Keyboard accessible

---

## Phase 6: Completion

### Documentation

- [ ] Update README with setup instructions
- [ ] Document keyboard shortcuts
- [ ] Document API endpoints
- [ ] Add troubleshooting section
- [ ] Create user guide (optional)

### Prepare for Distribution

- [ ] Set up code signing
- [ ] Configure notarization
- [ ] Create DMG or installer
- [ ] Test on clean system
- [ ] Create release notes

### Git Commit

```bash
git add .
git commit -m "Milestone 6: Settings and polish for v1.0

- Complete settings UI with all tabs
- Implement audio device selection
- Add comprehensive error handling
- Create onboarding flow for first launch
- Implement logging with rotation
- Add keyboard shortcuts
- Add mute/pause functionality
- Handle sleep/wake and device changes
- Add accessibility support
- Prepare for distribution"
```

### Release

- [ ] All Phase 5 verification items pass
- [ ] Code committed to version control
- [ ] Documentation complete
- [ ] Ready for v1.0 release

---

## Deliverable

Production-ready v1.0 application with complete settings UI, robust error handling, onboarding flow, and polished user experience. Ready for daily use as a home voice assistant.
