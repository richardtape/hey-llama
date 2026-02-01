# HeyLlama: Developer Quick Start

## What We're Building

A native macOS menu bar app that:
1. Listens continuously for "Hey Llama"
2. Transcribes what you say after the wake word
3. Identifies who's speaking (Rich, Partner, or Guest)
4. Sends the command to an LLM and speaks the response
5. Accepts audio/text from external devices via API

## Tech Stack

| Component | Technology |
|-----------|------------|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI |
| Audio Capture | AVFoundation (AVAudioEngine) |
| Voice Activity Detection | FluidAudio (Silero VAD) |
| Speech-to-Text | WhisperKit |
| Speaker Identification | FluidAudio |
| Networking | Network.framework |
| LLM | Anthropic Claude API |
| Text-to-Speech | AVSpeechSynthesizer |

## Key Concepts

### 1. Menu Bar App
The app has no dock icon. It lives in the menu bar (top-right of screen) and runs continuously. Users interact with it via:
- The menu bar dropdown
- Voice commands
- The Settings window

### 2. Audio Pipeline
```
Microphone → AudioEngine → VAD → [on speech end] → STT + Speaker ID → Command Processor → LLM → TTS
```

The VAD (Voice Activity Detection) is crucial. It tells us when someone starts and stops speaking, so we know when to transcribe.

### 3. State Machine
The app is always in one of these states:
- **Listening**: Waiting for someone to speak
- **Capturing**: Someone is speaking, recording audio
- **Processing**: Running STT and speaker ID
- **Responding**: Speaking the LLM's response

### 4. AssistantCoordinator
This is the "brain" of the app. It:
- Owns all the services
- Manages state transitions
- Publishes state for the UI to observe

## Getting Started

### Prerequisites
- macOS 14+ (Sonoma)
- Xcode 15+
- Apple Silicon Mac (M1/M2/M3/M4)

### Setup
```bash
# Clone repo
git clone <repo-url>
cd HeyLlama

# Open in Xcode
open HeyLlama.xcodeproj

# Build and run (Cmd+R)
```

### First Run
1. App will request microphone permission → Grant it
2. Open Settings (click menu bar icon → Preferences)
3. Enter your Anthropic API key
4. Say "Hey Llama, hello!"

## Project Structure (Simplified)

```
HeyLlama/
├── App/
│   └── HeyLlamaApp.swift    # Entry point
│
├── UI/
│   ├── MenuBarView.swift          # Menu bar dropdown
│   └── SettingsView.swift         # Settings window
│
├── Core/
│   └── AssistantCoordinator.swift # The brain
│
├── Services/
│   ├── AudioEngine.swift          # Mic capture
│   ├── VADService.swift           # Voice activity detection
│   ├── STTService.swift           # Speech-to-text
│   ├── SpeakerService.swift       # Speaker identification
│   ├── LLMService.swift           # Claude API
│   ├── TTSService.swift           # Text-to-speech
│   └── APIServer.swift            # HTTP/WebSocket server
│
└── Models/
    ├── Speaker.swift
    └── AudioChunk.swift
```

## Development Order

Build these in order. Each milestone builds on the previous:

### Milestone 1: Audio Foundation
Get audio capture and VAD working. When you speak, the app should show "Capturing". When you stop, it should show "Listening".

**Files to create:**
- `AudioEngine.swift`
- `AudioBuffer.swift`
- `VADService.swift`
- Basic `MenuBarView.swift`

### Milestone 2: Speech-to-Text
Add WhisperKit. When VAD detects speech end, transcribe it. Print the transcription to the console.

**Files to create:**
- `STTService.swift`

### Milestone 3: Wake Word + Commands
Parse the transcription. If it starts with "Hey Llama", extract the command.

**Files to create:**
- `CommandProcessor.swift`

### Milestone 4: Speaker ID
Add FluidAudio speaker embeddings. Create enrollment UI. Identify speakers.

**Files to create:**
- `SpeakerService.swift`
- `SpeakerEmbedding.swift`
- `EnrollmentView.swift`

### Milestone 5: LLM + TTS
Connect to Claude API. Speak the response.

**Files to create:**
- `LLMService.swift`
- `TTSService.swift`

### Milestone 6: API Server
Add HTTP and WebSocket servers so satellites can connect.

**Files to create:**
- `APIServer.swift`
- `APIRouter.swift`

## Common Patterns

### Publishing State for UI
```swift
@MainActor
class AssistantCoordinator: ObservableObject {
    @Published private(set) var state: AssistantState = .listening
}

// In SwiftUI:
struct MenuBarView: View {
    @EnvironmentObject var coordinator: AssistantCoordinator
    
    var body: some View {
        Text(coordinator.state.statusText)
    }
}
```

### Async Service Calls
```swift
func processUtterance(_ audio: AudioChunk) async {
    // Run in parallel
    async let transcription = sttService.transcribe(audio)
    async let speaker = speakerService.identify(audio)
    
    let (text, who) = await (transcription, speaker)
    // Continue processing...
}
```

### Audio Chunk Processing
```swift
audioEngine.audioChunkPublisher
    .sink { [weak self] chunk in
        let vadResult = self?.vadService.process(chunk)
        // Handle VAD result...
    }
    .store(in: &cancellables)
```

## Testing Tips

1. **Test VAD first**: Make sure it reliably detects speech start/end before adding STT
2. **Use mock services**: Create mock versions of STTService, SpeakerService, LLMService for unit tests
3. **Log everything initially**: Add print statements at each pipeline stage
4. **Test with noise**: Try with TV/music in background

## Helpful Resources

- [WhisperKit Documentation](https://github.com/argmaxinc/WhisperKit)
- [FluidAudio Documentation](https://github.com/FluidInference/FluidAudio)
- [AVAudioEngine Guide](https://developer.apple.com/documentation/avfaudio/avaudioengine)
- [Network.framework Guide](https://developer.apple.com/documentation/network)
- [SwiftUI MenuBarExtra](https://developer.apple.com/documentation/swiftui/menubarextra)

## Questions?

If something in the spec is unclear, ask before implementing. The main spec.md document has much more detail on each component.