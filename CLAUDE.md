# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Llama Voice Assistant is a native macOS menu bar application providing always-listening voice assistant functionality with wake word detection ("Hey Llama"), speaker identification, and API extensibility for satellite devices and mobile clients. This is currently a **specification repository** containing architectural documentation for future implementation.

## Documentation

- **`docs/spec.md`**: Complete technical specification with code examples, data models, API design, and implementation details
- **`docs/quick-start.md`**: Developer quick start guide with simplified overview
- **`docs/milestones/`**: Task-oriented implementation guides with checkboxes for tracking progress
  - Start with [`docs/milestones/README.md`](docs/milestones/README.md) for the milestone overview

Read these documents for full context before implementing features.

## Technology Stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI (menu bar app, no dock icon)
- **Audio**: AVFoundation (AVAudioEngine) at 16kHz mono
- **VAD**: FluidAudio (Silero VAD)
- **STT**: WhisperKit
- **Speaker ID**: FluidAudio embeddings
- **LLM**: Anthropic Claude API
- **TTS**: AVSpeechSynthesizer
- **Networking**: Network.framework (HTTP/WebSocket), Bonjour/mDNS
- **Requirements**: macOS 14+, Apple Silicon (M1+), Xcode 15+

## Build Commands (When Implementation Exists)

```bash
# Open project
open HeyLlama.xcodeproj

# Build
xcodebuild build -project HeyLlama.xcodeproj -scheme HeyLlama

# Run tests
xcodebuild test -project HeyLlama.xcodeproj -scheme HeyLlama
```

## Architecture

### Core Flow
```
Microphone → AudioEngine → VAD → [speech end] → STT + Speaker ID (parallel) → Command Processor → LLM → TTS
```

### State Machine
`idle` → `listening` → `capturing` (speech detected) → `processing` (STT/speaker ID) → `responding` (TTS) → `listening`

### Key Components

**AssistantCoordinator** (`Core/AssistantCoordinator.swift`): Central orchestrator that owns all services and manages state transitions. Uses `@MainActor` and `ObservableObject` for UI binding.

**AudioEngine** (`Services/Audio/AudioEngine.swift`): Wraps AVAudioEngine, captures at 16kHz mono, publishes 30ms chunks via Combine.

**AudioBuffer** (`Services/Audio/AudioBuffer.swift`): 15-second rolling buffer that marks speech start and extracts utterances.

**VADService** (`Services/Audio/VADService.swift`): Silero VAD wrapper detecting speech start/end with 300ms silence threshold.

**STTService** (`Services/Speech/STTService.swift`): WhisperKit wrapper for transcription.

**SpeakerService** (`Services/Speaker/SpeakerService.swift`): FluidAudio embeddings for speaker identification using cosine distance.

**APIServer** (`Services/API/APIServer.swift`): HTTP REST (port 8765) and WebSocket (port 8766) server for external clients.

### Design Patterns

- **Protocol-based services**: All services have protocol counterparts (`STTServiceProtocol`, etc.) for testability
- **Combine publishers**: Audio chunks flow through `PassthroughSubject` pipelines
- **Async/await concurrency**: STT and speaker ID run in parallel with `async let`
- **Observable state**: UI reacts via `@Published` properties on coordinator

## Project Structure

```
HeyLlama/
├── App/                    # Entry point, AppDelegate
├── UI/                     # MenuBarView, Settings, Enrollment
├── Core/                   # AssistantCoordinator, state machine
├── Services/
│   ├── Audio/              # AudioEngine, AudioBuffer, VADService
│   ├── Speech/             # STTService
│   ├── Speaker/            # SpeakerService, embeddings
│   ├── LLM/                # Claude API client
│   ├── TTS/                # Text-to-speech
│   └── API/                # HTTP/WebSocket server
├── Models/                 # Speaker, AudioChunk, Command
└── Storage/                # JSON persistence to ~/Library/Application Support/HeyLlama/
```

## API Design

**REST** (`http://<ip>:8765/api/v1`): `/health`, `/command`, `/speakers`, `/config`, `/status`

**WebSocket** (`ws://<ip>:8766/ws`): Audio streaming for satellites. Client sends `hello`, server responds with `welcome` including sample rate, then client streams binary audio chunks.

**Service Discovery**: Bonjour/mDNS as `_llama._tcp.local.`

## Dependencies (SPM)

```swift
.package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0")
.package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.10.0")
```

## Development Milestones

1. **Audio Foundation**: AudioEngine + VAD + menu bar state display
2. **Speech-to-Text**: WhisperKit integration, wake word detection
3. **Speaker Identification**: FluidAudio embeddings, enrollment UI
4. **LLM Integration**: Claude API, TTS response
5. **API Server**: HTTP/WebSocket for external clients
6. **Settings & Polish**: Full settings UI, error handling, onboarding

## Configuration

Config stored at `~/Library/Application Support/HeyLlama/config.json`:
- `wakePhrase`: default "hey llama"
- `apiPort`: default 8765
- `llm.apiKey`: Anthropic API key
- `llm.model`: default "claude-sonnet-4-20250514"

## Key Implementation Notes

- Menu bar app: Use `NSApp.setActivationPolicy(.accessory)` to hide from dock
- Wake word extraction: Case-insensitive substring match, extract everything after wake phrase
- Speaker matching: Cosine distance threshold on 256/512-dim embeddings
- Audio format: Always convert to 16kHz mono Float32 for ML models
