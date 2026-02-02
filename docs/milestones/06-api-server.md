# Milestone 6: API Server

## Overview

For general project context, see:
- [`CLAUDE.md`](../../CLAUDE.md) - Quick reference for architecture and patterns
- [`docs/spec.md`](../spec.md) - Complete technical specification (Section 4: API Design)

## Goal

Implement HTTP REST and WebSocket servers to accept commands and audio streams from external clients (Raspberry Pi satellites, iOS app). Enable service discovery via Bonjour/mDNS.

## Prerequisites

- Milestone 5 complete (tools/skills registry available)

---

## Phase 1: Design

Key design decisions for this milestone:

- [ ] Confirm HTTP port: 8765
- [ ] Confirm WebSocket port: 8766 (HTTP port + 1)
- [ ] Confirm Bonjour service type: `_llama._tcp.local.`
- [ ] Confirm response modes: api, speaker, both (speaker mode is future if/when TTS exists)
- [ ] Confirm authentication: simple token (optional for local network)

---

## Phase 2: Test Setup

### Create Test Infrastructure

- [ ] Create `APIRouterTests.swift` in test target
- [ ] Create `APIModelsTests.swift` in test target
- [ ] Create test helpers for HTTP request/response simulation

### Write APIRouter Tests (RED)

- [ ] Test: `GET /api/v1/health` returns 200 with status
- [ ] Test: `POST /api/v1/command` with valid body returns response
- [ ] Test: `GET /api/v1/status` returns current state
- [ ] Test: `GET /api/v1/speakers` returns speaker list
- [ ] Test: `GET /api/v1/speakers/{id}` returns speaker or 404
- [ ] Test: `DELETE /api/v1/speakers/{id}` removes speaker
- [ ] Test: Unknown path returns 404
- [ ] Test: Invalid method returns 405
- [ ] Test: Malformed JSON returns 400

### Write API Models Tests (RED)

- [ ] Test: `CommandRequest` decodes correctly
- [ ] Test: `CommandResponse` encodes correctly
- [ ] Test: `StatusResponse` includes all required fields
- [ ] Test: `SpeakerInfo` maps from `Speaker` correctly

### Write WebSocket Protocol Tests (RED)

- [ ] Test: Hello message parsing
- [ ] Test: Welcome message generation
- [ ] Test: Binary audio frame handling
- [ ] Test: Response message encoding

---

## Phase 3: Implementation

### Define API Models

- [ ] Create `APIModels.swift` in `Services/API/`

#### Request/Response Models

- [ ] Define `CommandRequest`: text, speakerId?, source, respondVia
- [ ] Define `ResponseMode` enum: `.api`, `.speaker`, `.both`
- [ ] Define `CommandResponse`: success, response?, speaker?, processingTimeMs
- [ ] Define `StatusResponse`: state, isListening, connectedClients, lastCommand?
- [ ] Define `LastCommandInfo`: text, speaker?, timestamp
- [ ] Define `SpeakerInfo`: id, name, enrolledAt, commandCount
- [ ] Define `HealthResponse`: status, version, uptime
- [ ] Define `ConfigResponse`: non-sensitive config fields
- [ ] Conform all to `Codable`

#### WebSocket Messages

- [ ] Define `HelloMessage`: type="hello", source
- [ ] Define `WelcomeMessage`: type="welcome", sampleRate, chunkSize
- [ ] Define `VADEventMessage`: type="vad", event
- [ ] Define `TranscriptionMessage`: type="transcription", text, speaker?
- [ ] Define `ResponseMessage`: type="response", text
- [ ] Define `ErrorMessage`: type="error", message

### Implement APIRouter

- [ ] Create `APIRouter.swift` in `Services/API/`
- [ ] Parse HTTP request: method, path, headers, body
- [ ] Route to handlers based on path pattern
- [ ] Return HTTP response with status, headers, body

#### Route Handlers

- [ ] `GET /api/v1/health` → health info
- [ ] `GET /api/v1/status` → assistant status
- [ ] `POST /api/v1/command` → process command
- [ ] `GET /api/v1/speakers` → list speakers
- [ ] `GET /api/v1/speakers/{id}` → get speaker
- [ ] `DELETE /api/v1/speakers/{id}` → delete speaker
- [ ] `GET /api/v1/config` → get config (non-sensitive)
- [ ] `PATCH /api/v1/config` → update config

### Implement APIServer Core

- [ ] Create `APIServer.swift` in `Services/API/`
- [ ] Import Network framework
- [ ] Define `port: UInt16` property
- [ ] Create private `httpListener: NWListener?`
- [ ] Create private `wsListener: NWListener?`
- [ ] Maintain `connections: [String: ClientConnection]`

#### Combine Publishers

- [ ] Create `audioReceivedPublisher: PassthroughSubject<(AudioChunk, AudioSource), Never>`
- [ ] Create `textReceivedPublisher: PassthroughSubject<(String, AudioSource), Never>`

### Implement Server Lifecycle

- [ ] Implement `start() async throws`
  - Start Bonjour advertisement
  - Start HTTP listener
  - Start WebSocket listener

- [ ] Implement `stop()`
  - Cancel listeners
  - Close all connections
  - Stop Bonjour

### Implement Servers ⚡ (Parallelizable)

#### Implement HTTP Server ⚡

- [ ] Create NWListener with TCP parameters
- [ ] Set `newConnectionHandler`
- [ ] Start on configured port
- [ ] Handle incoming connections
- [ ] Receive request data
- [ ] Route through APIRouter
- [ ] Send response and close

#### Implement WebSocket Server ⚡

- [ ] Create NWListener with WebSocket protocol options
- [ ] Set `newConnectionHandler`
- [ ] Start on port + 1
- [ ] Create ClientConnection for each connection

#### Implement Bonjour Advertisement ⚡

- [ ] Configure NWListener for Bonjour
- [ ] Advertise as `_llama._tcp.local.`
- [ ] Include port in TXT record
- [ ] Handle advertisement errors

### Implement ClientConnection

- [ ] Create `ClientConnection.swift` in `Services/API/`
- [ ] Store `id: String` (UUID)
- [ ] Store `connection: NWConnection`
- [ ] Store `source: String` (from hello message)
- [ ] Define callbacks: `onAudioReceived`, `onTextReceived`, `onDisconnect`

#### ClientConnection Methods

- [ ] Implement `start()` - begin receiving messages
- [ ] Implement `close()` - cancel gracefully
- [ ] Implement `send(_ message: Encodable)` - encode and send

#### Message Handling

- [ ] Handle "hello" → store source, send "welcome"
- [ ] Handle binary frames → convert to AudioChunk, publish
- [ ] Handle text frames → parse JSON, route appropriately

### Implement Response Routing

- [ ] Implement `sendResponse(_ response: String, to source: AudioSource)`
- [ ] Implement `getSpeakerForSource(_ source: AudioSource) -> Speaker?`

---

## Phase 4: Integration

### Add to Coordinator

- [ ] Add `apiServer: APIServer` to coordinator
- [ ] Initialize with port from config
- [ ] Call `apiServer.start()` in `start()` method
- [ ] Call `apiServer.stop()` in `shutdown()` method

### Subscribe to API Publishers

- [ ] Subscribe to `audioReceivedPublisher`
- [ ] Process audio through same pipeline as local mic
- [ ] Subscribe to `textReceivedPublisher`
- [ ] Process text commands (skip wake word)

### Implement Text Command Processing

- [ ] Create `processTextCommand(_ text: String, source: AudioSource) async`
- [ ] Look up speaker for source (if configured)
- [ ] Call `processCommand()` directly
- [ ] Handle response routing based on `respondVia`

### Handle Response Modes

- [ ] `.api` → return in HTTP response only
- [ ] `.speaker` → (future) speak through Mac only (requires TTS milestone)
- [ ] `.both` → (future) do both
- [ ] WebSocket clients always get response message

### Create APISettingsView

- [ ] Create `APISettingsView.swift` in `UI/Settings/`
- [ ] Toggle for API enabled/disabled
- [ ] Port number configuration
- [ ] Server status indicator
- [ ] Connected clients list
- [ ] Local IP address display

### Update Menu Bar UI

- [ ] Show connected client count
- [ ] Indicate external command source
- [ ] Show source identifier in activity

---

## Phase 5: Verification

### Test Suite

- [ ] Run all unit tests in Xcode (`Cmd+U`)
- [ ] All APIRouter tests pass (GREEN)
- [ ] All API model tests pass (GREEN)
- [ ] Previous milestone tests still pass

### HTTP API Testing

```bash
# Health check
curl http://localhost:8765/api/v1/health

# Status
curl http://localhost:8765/api/v1/status

# Send command
curl -X POST http://localhost:8765/api/v1/command \
  -H "Content-Type: application/json" \
  -d '{"text":"what time is it","source":"curl-test","respondVia":"api"}'

# List speakers
curl http://localhost:8765/api/v1/speakers
```

- [ ] Health endpoint returns valid response
- [ ] Command endpoint processes and returns LLM response
- [ ] Status endpoint shows current state
- [ ] Speakers endpoint returns enrolled list
- [ ] Invalid endpoints return 404

### WebSocket Testing

- [ ] Connect with WebSocket client
- [ ] Send hello message, receive welcome
- [ ] Stream audio, verify processing
- [ ] Receive transcription and response messages

### Bonjour Testing

- [ ] Verify service advertised on network
- [ ] Discover from another device: `dns-sd -B _llama._tcp`
- [ ] Resolve address: `dns-sd -L HeyLlama _llama._tcp`

### Integration Testing

- [ ] External command returns text response via API
- [ ] Response mode "api" returns text only

### Regression Check

- [ ] Local voice commands still work
- [ ] All previous functionality intact

---

## Phase 6: Completion

### Git Commit

```bash
git add .
git commit -m "Milestone 6: API server with HTTP and WebSocket

- Implement HTTP REST server on port 8765
- Implement WebSocket server on port 8766
- Add Bonjour/mDNS service advertisement
- Create API models and router
- Handle audio streaming from satellites
- Handle text commands from clients
- Add API settings UI with status display"
```

### Ready for Next Milestone

- [ ] All Phase 5 verification items pass
- [ ] Code committed to version control
- [ ] Ready to proceed to [Milestone 7: Settings & Polish](./07-settings-polish.md)

---

## Deliverable

HTTP REST API and WebSocket server accepting commands from external clients. Satellites can stream audio, mobile apps can send text commands. Bonjour enables automatic service discovery on the local network.
