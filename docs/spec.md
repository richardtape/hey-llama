# Llama Voice Assistant: Technical Specification

## Overview

A native macOS menu bar application that provides always-listening voice assistant functionality with custom wake word detection ("Hey Llama"), speaker identification, and extensibility via a local API for satellite devices and mobile clients.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Project Structure](#2-project-structure)
3. [Core Components](#3-core-components)
4. [API Design](#4-api-design)
5. [Data Models](#5-data-models)
6. [Audio Pipeline](#6-audio-pipeline)
7. [Configuration & Storage](#7-configuration--storage)
8. [Dependencies](#8-dependencies)
9. [Development Milestones](#9-development-milestones)
10. [Testing Strategy](#10-testing-strategy)

---

## 1. Architecture Overview

### System Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              Mac Mini                                        │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     HeyLlama (SwiftUI App)                      │  │
│  │                                                                        │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐   │  │
│  │  │   Menu Bar  │  │   Settings  │  │  Enrollment │  │   Logs /    │   │  │
│  │  │     UI      │  │    View     │  │    View     │  │   Debug     │   │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘  └─────────────┘   │  │
│  │         │                                                              │  │
│  │         ▼                                                              │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                      AssistantCoordinator                        │  │  │
│  │  │         (Central orchestrator - ObservableObject)                │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  │         │                                                              │  │
│  │         ├──────────────┬──────────────┬──────────────┬────────────┐   │  │
│  │         ▼              ▼              ▼              ▼            ▼   │  │
│  │  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌─────┐ │  │
│  │  │  Audio    │  │    STT    │  │  Speaker  │  │    LLM    │  │ API │ │  │
│  │  │  Engine   │  │  Service  │  │  Service  │  │  Service  │  │Server│ │  │
│  │  └───────────┘  └───────────┘  └───────────┘  └───────────┘  └─────┘ │  │
│  │                                                                        │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
         ▲                    ▲                    ▲
         │ Audio              │ Audio              │ Text
         │ Stream             │ Stream             │
┌────────┴───────┐  ┌────────┴───────┐  ┌────────┴───────┐
│  Local Mic     │  │  Satellite     │  │  iOS App       │
│  (Built-in)    │  │  (Bedroom Pi)  │  │  (Text/Voice)  │
└────────────────┘  └────────────────┘  └────────────────┘
```

### Key Design Principles

1. **Single Responsibility:** Each service handles one concern
2. **Protocol-Oriented:** Services conform to protocols for testability
3. **Observable State:** UI reacts to state changes via Combine/SwiftUI
4. **Async/Await:** Modern Swift concurrency throughout
5. **Graceful Degradation:** App remains functional if individual services fail

---

## 2. Project Structure

```
HeyLlama/
├── HeyLlama.xcodeproj
├── Package.swift                      # SPM dependencies
│
├── HeyLlama/
│   ├── App/
│   │   ├── HeyLlamaApp.swift   # @main entry point
│   │   ├── AppDelegate.swift          # NSApplicationDelegate for lifecycle
│   │   └── AppState.swift             # Global app state container
│   │
│   ├── UI/
│   │   ├── MenuBar/
│   │   │   ├── MenuBarView.swift      # Menu bar dropdown content
│   │   │   └── StatusItemManager.swift # Menu bar icon management
│   │   │
│   │   ├── Settings/
│   │   │   ├── SettingsView.swift     # Main settings container
│   │   │   ├── GeneralSettingsView.swift
│   │   │   ├── AudioSettingsView.swift
│   │   │   ├── SpeakersSettingsView.swift
│   │   │   └── APISettingsView.swift
│   │   │
│   │   ├── Enrollment/
│   │   │   ├── EnrollmentView.swift   # Speaker enrollment flow
│   │   │   └── EnrollmentPrompts.swift # Phrases for enrollment
│   │   │
│   │   └── Components/
│   │       ├── AudioLevelIndicator.swift
│   │       └── ProcessingIndicator.swift
│   │
│   ├── Core/
│   │   ├── AssistantCoordinator.swift # Central orchestrator
│   │   ├── AssistantState.swift       # State machine for assistant
│   │   └── CommandProcessor.swift     # Wake word detection + command parsing
│   │
│   ├── Services/
│   │   ├── Audio/
│   │   │   ├── AudioEngine.swift      # AVAudioEngine wrapper
│   │   │   ├── AudioBuffer.swift      # Rolling audio buffer
│   │   │   └── VADService.swift       # Voice Activity Detection
│   │   │
│   │   ├── Speech/
│   │   │   ├── STTService.swift       # Speech-to-text (WhisperKit)
│   │   │   └── STTServiceProtocol.swift
│   │   │
│   │   ├── Speaker/
│   │   │   ├── SpeakerService.swift   # Speaker identification
│   │   │   ├── SpeakerEmbedding.swift # Embedding storage/comparison
│   │   │   └── SpeakerServiceProtocol.swift
│   │   │
│   │   ├── LLM/
│   │   │   ├── LLMService.swift       # LLM API client
│   │   │   ├── LLMServiceProtocol.swift
│   │   │   └── LLMProviders/
│   │   │       ├── AnthropicProvider.swift
│   │   │       ├── OpenAIProvider.swift
│   │   │       └── LocalProvider.swift  # Future: local LLM
│   │   │
│   │   ├── TTS/
│   │   │   ├── TTSService.swift       # Text-to-speech
│   │   │   └── TTSServiceProtocol.swift
│   │   │
│   │   └── API/
│   │       ├── APIServer.swift        # HTTP/WebSocket server
│   │       ├── APIRouter.swift        # Route handling
│   │       └── APIModels.swift        # Request/response models
│   │
│   ├── Models/
│   │   ├── Speaker.swift              # Speaker profile model
│   │   ├── AudioChunk.swift           # Audio data container
│   │   ├── TranscriptionResult.swift  # STT output
│   │   ├── Command.swift              # Parsed command
│   │   └── Conversation.swift         # Conversation history
│   │
│   ├── Storage/
│   │   ├── StorageManager.swift       # Persistence coordinator
│   │   ├── SpeakerStore.swift         # Speaker embeddings storage
│   │   └── ConfigStore.swift          # App configuration
│   │
│   ├── Utilities/
│   │   ├── AudioUtilities.swift       # Audio format conversion
│   │   ├── Logging.swift              # Structured logging
│   │   └── Permissions.swift          # Permission request helpers
│   │
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Localizable.strings
│       └── DefaultConfig.json
│
├── HeyLlamaTests/
│   ├── Mocks/
│   │   ├── MockSTTService.swift
│   │   ├── MockSpeakerService.swift
│   │   └── MockLLMService.swift
│   │
│   ├── AudioEngineTests.swift
│   ├── CommandProcessorTests.swift
│   ├── SpeakerServiceTests.swift
│   └── APIServerTests.swift
│
└── README.md
```

---

## 3. Core Components

### 3.1 HeyLlamaApp (Entry Point)

```swift
import SwiftUI

@main
struct HeyLlamaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        // Menu bar app - no dock icon
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Image(systemName: appState.statusIcon)
        }
        
        // Settings window
        Settings {
            SettingsView()
                .environmentObject(appState)
        }
        
        // Enrollment window (opens on demand)
        Window("Speaker Enrollment", id: "enrollment") {
            EnrollmentView()
                .environmentObject(appState)
        }
    }
}
```

### 3.2 AppDelegate

```swift
import AppKit
import AVFoundation

class AppDelegate: NSObject, NSApplicationDelegate {
    var coordinator: AssistantCoordinator?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon
        NSApp.setActivationPolicy(.accessory)
        
        // Request permissions
        Task {
            await requestPermissions()
            await startAssistant()
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        coordinator?.shutdown()
    }
    
    private func requestPermissions() async {
        // Microphone permission
        let granted = await AVCaptureDevice.requestAccess(for: .audio)
        if !granted {
            // Show alert directing user to System Settings
        }
    }
    
    private func startAssistant() async {
        coordinator = AssistantCoordinator()
        await coordinator?.start()
    }
}
```

### 3.3 AssistantCoordinator (Central Orchestrator)

This is the heart of the application. It coordinates all services and manages state transitions.

```swift
import Foundation
import Combine

@MainActor
class AssistantCoordinator: ObservableObject {
    // MARK: - Published State
    @Published private(set) var state: AssistantState = .idle
    @Published private(set) var currentSpeaker: Speaker?
    @Published private(set) var lastTranscription: String?
    @Published private(set) var isListening: Bool = false
    
    // MARK: - Services
    private let audioEngine: AudioEngine
    private let vadService: VADService
    private let sttService: STTServiceProtocol
    private let speakerService: SpeakerServiceProtocol
    private let llmService: LLMServiceProtocol
    private let ttsService: TTSServiceProtocol
    private let apiServer: APIServer
    
    // MARK: - Configuration
    private let config: AssistantConfig
    private let wakePhrase = "hey llama"
    
    // MARK: - Internal State
    private var audioBuffer = AudioBuffer(maxSeconds: 15)
    private var cancellables = Set<AnyCancellable>()
    
    init(
        config: AssistantConfig = .default,
        sttService: STTServiceProtocol? = nil,  // Injectable for testing
        speakerService: SpeakerServiceProtocol? = nil,
        llmService: LLMServiceProtocol? = nil
    ) {
        self.config = config
        self.audioEngine = AudioEngine()
        self.vadService = VADService()
        self.sttService = sttService ?? STTService()
        self.speakerService = speakerService ?? SpeakerService()
        self.llmService = llmService ?? LLMService(config: config.llm)
        self.ttsService = TTSService()
        self.apiServer = APIServer(port: config.apiPort)
        
        setupBindings()
    }
    
    // MARK: - Lifecycle
    
    func start() async {
        // Load models
        await sttService.loadModel()
        await speakerService.loadModel()
        
        // Start API server
        try? await apiServer.start()
        
        // Start audio capture
        audioEngine.start()
        isListening = true
        state = .listening
    }
    
    func shutdown() {
        audioEngine.stop()
        apiServer.stop()
        isListening = false
    }
    
    // MARK: - Audio Processing Pipeline
    
    private func setupBindings() {
        // Audio chunks from microphone → VAD
        audioEngine.audioChunkPublisher
            .sink { [weak self] chunk in
                self?.processAudioChunk(chunk)
            }
            .store(in: &cancellables)
        
        // Audio from API (satellites) → same pipeline
        apiServer.audioReceivedPublisher
            .sink { [weak self] (chunk, source) in
                self?.processAudioChunk(chunk, source: source)
            }
            .store(in: &cancellables)
        
        // Text from API (mobile app) → direct to command processing
        apiServer.textReceivedPublisher
            .sink { [weak self] (text, source) in
                Task {
                    await self?.processTextCommand(text, source: source)
                }
            }
            .store(in: &cancellables)
    }
    
    private func processAudioChunk(_ chunk: AudioChunk, source: AudioSource = .localMic) {
        // Always add to rolling buffer
        audioBuffer.append(chunk)
        
        // Run VAD
        let vadResult = vadService.process(chunk)
        
        switch (state, vadResult) {
        case (.listening, .speechStart):
            state = .capturing
            
        case (.capturing, .speechContinue):
            // Keep capturing
            break
            
        case (.capturing, .speechEnd):
            // Speech finished - process the utterance
            let utterance = audioBuffer.getUtteranceSinceSpeechStart()
            Task {
                await processUtterance(utterance, source: source)
            }
            state = .processing
            
        default:
            break
        }
    }
    
    private func processUtterance(_ audio: AudioChunk, source: AudioSource) async {
        // Run STT and Speaker ID in parallel
        async let transcriptionTask = sttService.transcribe(audio)
        async let speakerTask = speakerService.identify(audio)
        
        let (transcription, speaker) = await (transcriptionTask, speakerTask)
        
        // Update state
        lastTranscription = transcription.text
        currentSpeaker = speaker
        
        // Check for wake word
        guard let command = extractCommand(from: transcription.text) else {
            // No wake word - return to listening
            state = .listening
            return
        }
        
        // Process command
        await processCommand(command, speaker: speaker, source: source)
    }
    
    private func extractCommand(from text: String) -> String? {
        let lowercased = text.lowercased()
        
        // Check for wake phrase
        guard let range = lowercased.range(of: wakePhrase) else {
            return nil
        }
        
        // Extract everything after wake phrase
        let commandStart = range.upperBound
        let command = String(text[commandStart...]).trimmingCharacters(in: .whitespaces)
        
        return command.isEmpty ? nil : command
    }
    
    private func processCommand(_ command: String, speaker: Speaker?, source: AudioSource) async {
        // Play acknowledgment chime
        await ttsService.playChime(.acknowledged)
        
        // Build context
        let context = CommandContext(
            command: command,
            speaker: speaker,
            source: source,
            timestamp: Date()
        )
        
        // Send to LLM
        state = .responding
        
        do {
            let response = try await llmService.complete(
                prompt: command,
                context: context
            )
            
            // Speak response
            await ttsService.speak(response)
            
            // Send response to source if from API
            if source != .localMic {
                apiServer.sendResponse(response, to: source)
            }
            
        } catch {
            await ttsService.speak("Sorry, I encountered an error processing that request.")
        }
        
        state = .listening
    }
    
    private func processTextCommand(_ text: String, source: AudioSource) async {
        // Text commands skip wake word detection
        let speaker = apiServer.getSpeakerForSource(source)
        await processCommand(text, speaker: speaker, source: source)
    }
    
    // MARK: - Speaker Enrollment
    
    func enrollSpeaker(name: String, audioSamples: [AudioChunk]) async throws -> Speaker {
        let speaker = try await speakerService.enroll(name: name, samples: audioSamples)
        return speaker
    }
    
    func removeSpeaker(_ speaker: Speaker) async {
        await speakerService.remove(speaker)
    }
}
```

### 3.4 AssistantState

```swift
enum AssistantState: Equatable {
    case idle           // Not started
    case listening      // Waiting for wake word
    case capturing      // Recording speech after VAD detected start
    case processing     // Running STT + Speaker ID
    case responding     // Speaking response
    case error(String)  // Error state
    
    var statusIcon: String {
        switch self {
        case .idle: return "waveform.slash"
        case .listening: return "waveform"
        case .capturing: return "waveform.badge.mic"
        case .processing: return "brain"
        case .responding: return "speaker.wave.2"
        case .error: return "exclamationmark.triangle"
        }
    }
    
    var statusText: String {
        switch self {
        case .idle: return "Idle"
        case .listening: return "Listening..."
        case .capturing: return "Capturing..."
        case .processing: return "Processing..."
        case .responding: return "Speaking..."
        case .error(let msg): return "Error: \(msg)"
        }
    }
}
```

---

## 4. API Design

The API server enables satellites (Raspberry Pi) and mobile clients to interact with Llama.

### 4.1 Protocol Choice

**WebSocket** for audio streaming (real-time, bidirectional)
**HTTP REST** for text commands and configuration (simple, stateless)

### 4.2 Service Discovery

Use **Bonjour/mDNS** so clients can automatically find the server:

```swift
// Server advertises as:
_llama._tcp.local.
```

### 4.3 REST Endpoints

```
Base URL: http://<mac-mini-ip>:8765/api/v1

┌────────────────────────────────────────────────────────────────────────────┐
│ Endpoint                      │ Method │ Description                       │
├────────────────────────────────────────────────────────────────────────────┤
│ /health                       │ GET    │ Health check                      │
│ /command                      │ POST   │ Send text command                 │
│ /speakers                     │ GET    │ List enrolled speakers            │
│ /speakers/{id}                │ GET    │ Get speaker details               │
│ /speakers/{id}                │ DELETE │ Remove speaker                    │
│ /config                       │ GET    │ Get current configuration         │
│ /config                       │ PATCH  │ Update configuration              │
│ /status                       │ GET    │ Get assistant status              │
└────────────────────────────────────────────────────────────────────────────┘
```

### 4.4 API Models

```swift
// POST /command
struct CommandRequest: Codable {
    let text: String
    let speakerId: String?      // Optional: if client knows who's speaking
    let source: String          // e.g., "iphone-rich", "satellite-bedroom"
    let respondVia: ResponseMode
    
    enum ResponseMode: String, Codable {
        case api        // Return response in API response
        case speaker    // Speak through Mac speakers
        case both       // Both
    }
}

struct CommandResponse: Codable {
    let success: Bool
    let response: String?
    let speaker: SpeakerInfo?
    let processingTimeMs: Int
}

// GET /status
struct StatusResponse: Codable {
    let state: String
    let isListening: Bool
    let connectedClients: Int
    let lastCommand: LastCommandInfo?
}

struct LastCommandInfo: Codable {
    let text: String
    let speaker: String?
    let timestamp: Date
}

// GET /speakers
struct SpeakerInfo: Codable {
    let id: String
    let name: String
    let enrolledAt: Date
    let commandCount: Int       // How many commands from this speaker
}
```

### 4.5 WebSocket Protocol

```
WebSocket URL: ws://<mac-mini-ip>:8765/ws

Connection Flow:
1. Client connects
2. Client sends: { "type": "hello", "source": "satellite-bedroom" }
3. Server sends: { "type": "welcome", "sampleRate": 16000, "chunkSize": 480 }
4. Client streams audio chunks as binary frames
5. Server sends events as JSON:
   - { "type": "vad", "event": "speech_start" }
   - { "type": "vad", "event": "speech_end" }
   - { "type": "transcription", "text": "...", "speaker": "Rich" }
   - { "type": "response", "text": "..." }
```

### 4.6 API Server Implementation

```swift
import Network
import Foundation

class APIServer {
    private let port: UInt16
    private var httpListener: NWListener?
    private var wsListener: NWListener?
    private var connections: [String: ClientConnection] = [:]
    
    // Publishers for coordinator
    let audioReceivedPublisher = PassthroughSubject<(AudioChunk, AudioSource), Never>()
    let textReceivedPublisher = PassthroughSubject<(String, AudioSource), Never>()
    
    init(port: UInt16 = 8765) {
        self.port = port
    }
    
    func start() async throws {
        // Start Bonjour advertisement
        advertiseBonjourService()
        
        // Start HTTP server for REST API
        try startHTTPServer()
        
        // Start WebSocket server for audio streaming
        try startWebSocketServer()
    }
    
    func stop() {
        httpListener?.cancel()
        wsListener?.cancel()
        connections.values.forEach { $0.close() }
        connections.removeAll()
    }
    
    private func advertiseBonjourService() {
        // NWListener automatically handles Bonjour when configured
    }
    
    private func startHTTPServer() throws {
        let params = NWParameters.tcp
        httpListener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port))
        
        httpListener?.newConnectionHandler = { [weak self] connection in
            self?.handleHTTPConnection(connection)
        }
        
        httpListener?.start(queue: .main)
    }
    
    private func startWebSocketServer() throws {
        let params = NWParameters.tcp
        let wsOptions = NWProtocolWebSocket.Options()
        params.defaultProtocolStack.applicationProtocols.insert(wsOptions, at: 0)
        
        wsListener = try NWListener(using: params, on: NWEndpoint.Port(integerLiteral: port + 1))
        
        wsListener?.newConnectionHandler = { [weak self] connection in
            self?.handleWebSocketConnection(connection)
        }
        
        wsListener?.start(queue: .main)
    }
    
    // MARK: - HTTP Handling
    
    private func handleHTTPConnection(_ connection: NWConnection) {
        connection.start(queue: .main)
        
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            guard let data = data else { return }
            self?.routeHTTPRequest(data, connection: connection)
        }
    }
    
    private func routeHTTPRequest(_ data: Data, connection: NWConnection) {
        // Parse HTTP request and route to appropriate handler
        let router = APIRouter()
        let response = router.route(data)
        
        connection.send(content: response, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }
    
    // MARK: - WebSocket Handling
    
    private func handleWebSocketConnection(_ connection: NWConnection) {
        let clientId = UUID().uuidString
        let clientConnection = ClientConnection(id: clientId, connection: connection)
        connections[clientId] = clientConnection
        
        clientConnection.onAudioReceived = { [weak self] chunk in
            let source = AudioSource.satellite(clientId)
            self?.audioReceivedPublisher.send((chunk, source))
        }
        
        clientConnection.onDisconnect = { [weak self] in
            self?.connections.removeValue(forKey: clientId)
        }
        
        clientConnection.start()
    }
    
    // MARK: - Outgoing
    
    func sendResponse(_ response: String, to source: AudioSource) {
        guard case .satellite(let clientId) = source,
              let connection = connections[clientId] else { return }
        
        let message = ResponseMessage(type: "response", text: response)
        connection.send(message)
    }
    
    func getSpeakerForSource(_ source: AudioSource) -> Speaker? {
        // Look up pre-authenticated speaker for this source
        // Could be configured in settings (e.g., "bedroom satellite = Rich")
        return nil
    }
}
```

---

## 5. Data Models

### 5.1 Speaker

```swift
import Foundation

struct Speaker: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    let enrolledAt: Date
    var embedding: SpeakerEmbedding
    var metadata: SpeakerMetadata
    
    struct SpeakerMetadata: Codable, Equatable {
        var commandCount: Int = 0
        var lastSeenAt: Date?
        var preferredResponseMode: ResponseMode = .speaker
    }
}

struct SpeakerEmbedding: Codable, Equatable {
    let vector: [Float]     // 256 or 512 dimensional embedding
    let modelVersion: String
    
    func distance(to other: SpeakerEmbedding) -> Float {
        // Cosine distance
        guard vector.count == other.vector.count else { return 1.0 }
        
        var dotProduct: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        
        for i in 0..<vector.count {
            dotProduct += vector[i] * other.vector[i]
            normA += vector[i] * vector[i]
            normB += other.vector[i] * other.vector[i]
        }
        
        let similarity = dotProduct / (sqrt(normA) * sqrt(normB))
        return 1 - similarity  // Convert to distance
    }
}
```

### 5.2 AudioChunk

```swift
import AVFoundation

struct AudioChunk {
    let samples: [Float]        // Normalized audio samples
    let sampleRate: Int         // Always 16000 for our pipeline
    let timestamp: Date
    let source: AudioSource
    
    var duration: TimeInterval {
        Double(samples.count) / Double(sampleRate)
    }
    
    init(samples: [Float], sampleRate: Int = 16000, source: AudioSource = .localMic) {
        self.samples = samples
        self.sampleRate = sampleRate
        self.timestamp = Date()
        self.source = source
    }
    
    init(buffer: AVAudioPCMBuffer, source: AudioSource = .localMic) {
        // Convert AVAudioPCMBuffer to [Float]
        let frameLength = Int(buffer.frameLength)
        let channelData = buffer.floatChannelData![0]
        self.samples = Array(UnsafeBufferPointer(start: channelData, count: frameLength))
        self.sampleRate = Int(buffer.format.sampleRate)
        self.timestamp = Date()
        self.source = source
    }
}

enum AudioSource: Equatable, Hashable {
    case localMic
    case satellite(String)  // Client ID
    case iosApp(String)     // Device ID
    
    var identifier: String {
        switch self {
        case .localMic: return "local"
        case .satellite(let id): return "satellite-\(id)"
        case .iosApp(let id): return "ios-\(id)"
        }
    }
}
```

### 5.3 TranscriptionResult

```swift
struct TranscriptionResult {
    let text: String
    let confidence: Float
    let words: [WordTiming]?
    let language: String
    let processingTimeMs: Int
    
    struct WordTiming {
        let word: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let confidence: Float
    }
}
```

### 5.4 Command

```swift
struct Command {
    let rawText: String             // Full transcription
    let commandText: String         // Text after wake word
    let speaker: Speaker?
    let source: AudioSource
    let timestamp: Date
    let confidence: Float
}

struct CommandContext {
    let command: String
    let speaker: Speaker?
    let source: AudioSource
    let timestamp: Date
    let conversationHistory: [ConversationTurn]?
}

struct ConversationTurn {
    let role: Role
    let content: String
    let timestamp: Date
    
    enum Role {
        case user
        case assistant
    }
}
```

---

## 6. Audio Pipeline

### 6.1 AudioEngine

```swift
import AVFoundation
import Combine

class AudioEngine: ObservableObject {
    private let engine = AVAudioEngine()
    private let sampleRate: Double = 16000
    private let chunkSize: AVAudioFrameCount = 480  // 30ms at 16kHz
    
    let audioChunkPublisher = PassthroughSubject<AudioChunk, Never>()
    
    @Published private(set) var isRunning = false
    @Published private(set) var audioLevel: Float = 0
    
    func start() {
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        
        // Convert to 16kHz mono
        let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        )!
        
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat)!
        
        inputNode.installTap(
            onBus: 0,
            bufferSize: chunkSize,
            format: inputFormat
        ) { [weak self] buffer, time in
            self?.processBuffer(buffer, converter: converter, outputFormat: outputFormat)
        }
        
        do {
            try engine.start()
            isRunning = true
        } catch {
            print("Failed to start audio engine: \(error)")
        }
    }
    
    func stop() {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }
    
    private func processBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat
    ) {
        // Convert to 16kHz mono
        let frameCapacity = AVAudioFrameCount(
            Double(buffer.frameLength) * sampleRate / buffer.format.sampleRate
        )
        
        guard let convertedBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: frameCapacity
        ) else { return }
        
        var error: NSError?
        converter.convert(to: convertedBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        // Create chunk and publish
        let chunk = AudioChunk(buffer: convertedBuffer)
        audioChunkPublisher.send(chunk)
        
        // Update audio level for UI
        updateAudioLevel(convertedBuffer)
    }
    
    private func updateAudioLevel(_ buffer: AVAudioPCMBuffer) {
        let channelData = buffer.floatChannelData![0]
        let frameLength = Int(buffer.frameLength)
        
        var sum: Float = 0
        for i in 0..<frameLength {
            sum += abs(channelData[i])
        }
        
        let average = sum / Float(frameLength)
        
        DispatchQueue.main.async {
            self.audioLevel = average
        }
    }
}
```

### 6.2 AudioBuffer (Rolling Buffer)

```swift
import Foundation

class AudioBuffer {
    private var buffer: [Float] = []
    private let maxSamples: Int
    private let sampleRate: Int = 16000
    private var speechStartIndex: Int?
    
    private let lock = NSLock()
    
    init(maxSeconds: Int = 15) {
        self.maxSamples = maxSeconds * sampleRate
    }
    
    func append(_ chunk: AudioChunk) {
        lock.lock()
        defer { lock.unlock() }
        
        buffer.append(contentsOf: chunk.samples)
        
        // Trim if exceeds max
        if buffer.count > maxSamples {
            let excess = buffer.count - maxSamples
            buffer.removeFirst(excess)
            
            // Adjust speech start index if needed
            if let startIndex = speechStartIndex {
                speechStartIndex = max(0, startIndex - excess)
            }
        }
    }
    
    func markSpeechStart() {
        lock.lock()
        defer { lock.unlock() }
        
        // Mark slightly before current position to catch the start
        let lookbackSamples = Int(0.3 * Double(sampleRate))  // 300ms
        speechStartIndex = max(0, buffer.count - lookbackSamples)
    }
    
    func getUtteranceSinceSpeechStart() -> AudioChunk {
        lock.lock()
        defer { lock.unlock() }
        
        let startIndex = speechStartIndex ?? 0
        let samples = Array(buffer[startIndex...])
        
        // Reset for next utterance
        speechStartIndex = nil
        
        return AudioChunk(samples: samples)
    }
    
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        buffer.removeAll()
        speechStartIndex = nil
    }
}
```

### 6.3 VADService

```swift
import FluidAudio

class VADService {
    private let vad: SileroVAD
    private var speechActive = false
    private var silenceFrames = 0
    private let silenceThreshold = 10  // ~300ms of silence to end speech
    
    init() {
        vad = SileroVAD()
    }
    
    enum VADResult {
        case silence
        case speechStart
        case speechContinue
        case speechEnd
    }
    
    func process(_ chunk: AudioChunk) -> VADResult {
        let probability = vad.process(chunk.samples)
        let isSpeech = probability > 0.5
        
        if isSpeech {
            silenceFrames = 0
            
            if !speechActive {
                speechActive = true
                return .speechStart
            } else {
                return .speechContinue
            }
        } else {
            if speechActive {
                silenceFrames += 1
                
                if silenceFrames >= silenceThreshold {
                    speechActive = false
                    silenceFrames = 0
                    return .speechEnd
                } else {
                    return .speechContinue  // Brief pause, keep capturing
                }
            } else {
                return .silence
            }
        }
    }
    
    func reset() {
        speechActive = false
        silenceFrames = 0
    }
}
```

---

## 7. Configuration & Storage

### 7.1 AssistantConfig

```swift
struct AssistantConfig: Codable {
    var wakePhrase: String = "hey llama"
    var wakeWordSensitivity: Float = 0.5  // 0.0 - 1.0
    
    var apiPort: UInt16 = 8765
    var apiEnabled: Bool = true
    
    var llm: LLMConfig
    var tts: TTSConfig
    var audio: AudioConfig
    
    struct LLMConfig: Codable {
        var provider: LLMProvider = .anthropic
        var apiKey: String = ""
        var model: String = "claude-sonnet-4-20250514"
        var systemPrompt: String = """
            You are Llama, a helpful voice assistant. Keep responses concise 
            and conversational, suitable for spoken delivery. The current user 
            is {speaker_name}.
            """
    }
    
    struct TTSConfig: Codable {
        var voice: String = "com.apple.voice.compact.en-US.Samantha"
        var rate: Float = 0.5
        var volume: Float = 1.0
    }
    
    struct AudioConfig: Codable {
        var inputDevice: String?  // nil = default
        var outputDevice: String?
        var silenceThresholdMs: Int = 300
    }
    
    enum LLMProvider: String, Codable, CaseIterable {
        case anthropic
        case openai
        case local
    }
    
    static var `default`: AssistantConfig {
        AssistantConfig(
            llm: LLMConfig(),
            tts: TTSConfig(),
            audio: AudioConfig()
        )
    }
}
```

### 7.2 StorageManager

```swift
import Foundation

class StorageManager {
    static let shared = StorageManager()
    
    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    
    private var baseURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let llamaDir = appSupport.appendingPathComponent("HeyLlama", isDirectory: true)
        
        if !fileManager.fileExists(atPath: llamaDir.path) {
            try? fileManager.createDirectory(at: llamaDir, withIntermediateDirectories: true)
        }
        
        return llamaDir
    }
    
    // MARK: - Config
    
    func loadConfig() -> AssistantConfig {
        let url = baseURL.appendingPathComponent("config.json")
        
        guard let data = try? Data(contentsOf: url),
              let config = try? decoder.decode(AssistantConfig.self, from: data) else {
            return .default
        }
        
        return config
    }
    
    func saveConfig(_ config: AssistantConfig) throws {
        let url = baseURL.appendingPathComponent("config.json")
        let data = try encoder.encode(config)
        try data.write(to: url)
    }
    
    // MARK: - Speakers
    
    func loadSpeakers() -> [Speaker] {
        let url = baseURL.appendingPathComponent("speakers.json")
        
        guard let data = try? Data(contentsOf: url),
              let speakers = try? decoder.decode([Speaker].self, from: data) else {
            return []
        }
        
        return speakers
    }
    
    func saveSpeakers(_ speakers: [Speaker]) throws {
        let url = baseURL.appendingPathComponent("speakers.json")
        let data = try encoder.encode(speakers)
        try data.write(to: url)
    }
}
```

---

## 8. Dependencies

### Swift Package Manager

```swift
// Package.swift (or add via Xcode)

dependencies: [
    // Speech-to-Text
    .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.9.0"),
    
    // VAD + Speaker Embedding
    .package(url: "https://github.com/FluidInference/FluidAudio.git", from: "0.10.0"),
]
```

### System Frameworks

- **AVFoundation** - Audio capture and playback
- **Network** - HTTP/WebSocket server, Bonjour
- **Combine** - Reactive bindings
- **SwiftUI** - User interface
- **Speech** (optional) - Apple's built-in TTS

### Minimum Requirements

- macOS 14.0+ (Sonoma)
- Xcode 15.0+
- Apple Silicon (M1 or later) for optimal ANE performance

---

## 9. Development Milestones

### Milestone 1: Audio Foundation

**Goal:** Continuous audio capture with VAD detection

**Tasks:**
1. Create Xcode project as menu bar app
2. Implement `AudioEngine` with microphone capture
3. Implement `AudioBuffer` for rolling storage
4. Integrate FluidAudio's Silero VAD
5. Create basic menu bar UI showing state (listening/capturing)
6. Test: Verify VAD correctly detects speech start/end

**Deliverable:** App that shows "Capturing..." when you speak, "Listening..." when silent

---

### Milestone 2: Speech-to-Text

**Goal:** Transcribe detected speech

**Tasks:**
1. Integrate WhisperKit
2. Implement `STTService` with model loading and transcription
3. Connect VAD → STT pipeline (on speech end, transcribe)
4. Display transcription in menu bar or debug log
5. Implement wake word detection in `CommandProcessor`
6. Test: Say "Hey Llama, hello world" and verify extraction

**Deliverable:** App that transcribes speech and detects wake word

---

### Milestone 3: Speaker Identification

**Goal:** Identify who is speaking

**Tasks:**
1. Integrate FluidAudio speaker embedding
2. Implement `SpeakerService` with embedding extraction
3. Create speaker enrollment flow UI
4. Implement embedding comparison (cosine distance)
5. Store/load speaker profiles via `StorageManager`
6. Run speaker ID in parallel with STT
7. Test: Enroll two speakers, verify correct identification

**Deliverable:** App that says "Rich said: ..." or "Guest said: ..."

---

### Milestone 4: LLM Integration

**Goal:** Process commands and generate responses

**Tasks:**
1. Implement `LLMService` with Anthropic API client
2. Create configuration UI for API key
3. Build prompt with speaker context
4. Implement `TTSService` using system speech
5. Connect full pipeline: wake word → LLM → TTS
6. Add acknowledgment chime on wake word detection
7. Test: "Hey Llama, what time is it?" → spoken response

**Deliverable:** Fully functional voice assistant (local mic only)

---

### Milestone 5: API Server

**Goal:** Enable external clients (satellites, iOS)

**Tasks:**
1. Implement HTTP server with `Network.framework`
2. Implement REST endpoints (health, command, status)
3. Implement WebSocket server for audio streaming
4. Add Bonjour service advertisement
5. Implement `ClientConnection` for managing WebSocket clients
6. Route satellite audio through same pipeline as local mic
7. Test: Send curl command, receive response

**Deliverable:** API accepting text commands and streaming audio

---

### Milestone 6: Settings & Polish

**Goal:** Production-ready user experience

**Tasks:**
1. Create comprehensive Settings UI
2. Add audio device selection
3. Add LLM provider selection (Anthropic/OpenAI)
4. Implement login item (launch at startup)
5. Add error handling and user-facing error messages
6. Add logging infrastructure
7. Create onboarding flow (permissions, enrollment)
8. Test: Full end-to-end testing with multiple speakers

**Deliverable:** Shippable v1.0

---

## 10. Testing Strategy

### Unit Tests

```swift
// CommandProcessorTests.swift
func testWakeWordDetection() {
    let processor = CommandProcessor(wakePhrase: "hey llama")
    
    XCTAssertNil(processor.extractCommand(from: "Hello world"))
    XCTAssertNil(processor.extractCommand(from: "Hey Lama what time is it"))  // Typo
    XCTAssertEqual(
        processor.extractCommand(from: "Hey Llama what time is it"),
        "what time is it"
    )
    XCTAssertEqual(
        processor.extractCommand(from: "hey llama, turn off the lights"),
        "turn off the lights"
    )
}

// SpeakerServiceTests.swift
func testEmbeddingDistance() {
    let embedding1 = SpeakerEmbedding(vector: [1, 0, 0], modelVersion: "1.0")
    let embedding2 = SpeakerEmbedding(vector: [1, 0, 0], modelVersion: "1.0")
    let embedding3 = SpeakerEmbedding(vector: [0, 1, 0], modelVersion: "1.0")
    
    XCTAssertEqual(embedding1.distance(to: embedding2), 0, accuracy: 0.001)
    XCTAssertEqual(embedding1.distance(to: embedding3), 1, accuracy: 0.001)
}
```

### Integration Tests

```swift
// Use mock services for deterministic testing
func testFullPipelineWithMocks() async {
    let mockSTT = MockSTTService()
    mockSTT.mockResult = TranscriptionResult(text: "Hey Llama what time is it", ...)
    
    let mockSpeaker = MockSpeakerService()
    mockSpeaker.mockResult = Speaker(name: "Rich", ...)
    
    let mockLLM = MockLLMService()
    mockLLM.mockResponse = "It's 3:30 PM"
    
    let coordinator = AssistantCoordinator(
        sttService: mockSTT,
        speakerService: mockSpeaker,
        llmService: mockLLM
    )
    
    // Simulate audio input
    let testAudio = AudioChunk(samples: [...])
    await coordinator.processUtterance(testAudio, source: .localMic)
    
    XCTAssertEqual(mockLLM.lastPrompt, "what time is it")
    XCTAssertEqual(coordinator.lastTranscription, "Hey Llama what time is it")
}
```

### Manual Testing Checklist

- [ ] Microphone permission request works
- [ ] Wake word detected at various volumes
- [ ] Wake word detected with background noise (TV, music)
- [ ] Speaker identification correct for enrolled users
- [ ] Unknown speaker classified as "Guest"
- [ ] LLM responds appropriately
- [ ] TTS speaks response clearly
- [ ] API health endpoint responds
- [ ] WebSocket audio streaming works
- [ ] App survives sleep/wake cycle
- [ ] Settings persist across restart
- [ ] Menu bar icon reflects correct state

---

## Appendix A: iOS Companion App (Future)

The iOS app would share models from `Models/` and `Services/` packages.

**Key differences:**
- Push-to-talk (no background wake word)
- Bonjour discovery to find Mac Mini
- Can use on-device STT or stream to Mac
- SwiftUI shared components where possible

**Shared Swift Package structure:**
```
LlamaCore/
├── Models/
├── Services/
│   ├── Protocols/
│   └── Shared implementations
└── Utilities/
```

---

## Appendix B: Satellite Protocol (Raspberry Pi)

For Python-based satellites, implement this WebSocket protocol:

```python
import asyncio
import websockets
import sounddevice as sd
import numpy as np

async def satellite_client():
    uri = "ws://llama.local:8766/ws"  # Discovered via Bonjour
    
    async with websockets.connect(uri) as ws:
        # Handshake
        await ws.send(json.dumps({
            "type": "hello",
            "source": "satellite-bedroom"
        }))
        
        welcome = json.loads(await ws.recv())
        sample_rate = welcome["sampleRate"]
        
        # Audio streaming
        def audio_callback(indata, frames, time, status):
            asyncio.run(ws.send(indata.tobytes()))
        
        with sd.InputStream(
            samplerate=sample_rate,
            channels=1,
            dtype='float32',
            callback=audio_callback
        ):
            # Listen for responses
            async for message in ws:
                event = json.loads(message)
                if event["type"] == "response":
                    # Play through local speaker
                    play_audio(event["text"])
```
