# Milestone 4: LLM Integration

## Overview

For general project context, see:
- [`CLAUDE.md`](../../CLAUDE.md) - Quick reference for architecture and patterns
- [`docs/spec.md`](../spec.md) - Complete technical specification (Section 7: Configuration)

## Goal

Connect to the Anthropic Claude API to process commands and generate responses. Implement text-to-speech to speak responses aloud. This completes the core voice assistant loop.

## Prerequisites

- Milestone 3 complete (speaker identification working)

---

## Phase 1: Design

Key design decisions for this milestone:

- [ ] Confirm default LLM: Anthropic Claude (claude-sonnet-4-20250514)
- [ ] Confirm system prompt: concise, conversational responses for voice
- [ ] Confirm TTS engine: AVSpeechSynthesizer (system)
- [ ] Confirm chime behavior: short acknowledgment sound on wake word
- [ ] Confirm error handling: speak user-friendly error messages

---

## Phase 2: Test Setup

### Create Test Infrastructure

- [ ] Create `LLMServiceTests.swift` in test target
- [ ] Create `MockLLMService.swift` in `HeyLlamaTests/Mocks/`
- [ ] Create `MockTTSService.swift` in `HeyLlamaTests/Mocks/`

### Write LLMService Tests (RED)

- [ ] Test: `isConfigured` returns `false` when API key empty
- [ ] Test: `isConfigured` returns `true` when API key present
- [ ] Test: System prompt includes speaker name substitution
- [ ] Test: Request body format matches Anthropic API spec
- [ ] Test: Response parsing extracts content correctly
- [ ] Test: Network errors throw appropriate error type

### Write Integration Tests with Mocks

- [ ] Test: Full pipeline with MockSTT, MockSpeaker, MockLLM
- [ ] Test: Command flows from wake word to LLM call
- [ ] Test: Speaker context included in LLM prompt
- [ ] Test: Error in LLM triggers error speech

### Create MockLLMService

- [ ] Implement `LLMServiceProtocol`
- [ ] Allow setting `mockResponse: String`
- [ ] Track `lastPrompt: String?` and `lastContext: CommandContext?`
- [ ] Allow simulating errors with `shouldThrowError: Bool`

### Create MockTTSService

- [ ] Implement `TTSServiceProtocol`
- [ ] Track `spokenTexts: [String]`
- [ ] Track `playedChimes: [ChimeType]`
- [ ] Implement `isSpeaking` as settable

---

## Phase 3: Implementation

### Define Configuration Models

#### AssistantConfig

- [ ] Create `AssistantConfig.swift` in `Storage/`
- [ ] Define `wakePhrase: String = "hey llama"`
- [ ] Define `wakeWordSensitivity: Float = 0.5`
- [ ] Define `apiPort: UInt16 = 8765`
- [ ] Define `apiEnabled: Bool = true`
- [ ] Define nested `llm: LLMConfig`
- [ ] Define nested `tts: TTSConfig`
- [ ] Define nested `audio: AudioConfig`
- [ ] Conform to `Codable`
- [ ] Implement `static var `default`: AssistantConfig`

#### LLMConfig

- [ ] Define `provider: LLMProvider = .anthropic`
- [ ] Define `apiKey: String = ""`
- [ ] Define `model: String = "claude-sonnet-4-20250514"`
- [ ] Define `systemPrompt: String` with default voice assistant prompt

#### TTSConfig

- [ ] Define `voice: String` (system default)
- [ ] Define `rate: Float = 0.5`
- [ ] Define `volume: Float = 1.0`

#### AudioConfig

- [ ] Define `inputDevice: String?`
- [ ] Define `outputDevice: String?`
- [ ] Define `silenceThresholdMs: Int = 300`

#### LLMProvider Enum

- [ ] Define cases: `.anthropic`, `.openai`, `.local`
- [ ] Conform to `String`, `Codable`, `CaseIterable`

### Implement ConfigStore

- [ ] Create `ConfigStore.swift` in `Storage/`
- [ ] Implement `loadConfig() -> AssistantConfig`
- [ ] Implement `saveConfig(_ config: AssistantConfig) throws`
- [ ] Store at `~/Library/Application Support/HeyLlama/config.json`
- [ ] Return default if file not found

### Implement Services ⚡ (Parallelizable)

#### Define LLMServiceProtocol ⚡

- [ ] Create `LLMServiceProtocol.swift` in `Services/LLM/`
- [ ] Define `func complete(prompt: String, context: CommandContext) async throws -> String`
- [ ] Define `var isConfigured: Bool { get }`

#### Implement LLMService ⚡

- [ ] Create `LLMService.swift` in `Services/LLM/`
- [ ] Conform to `LLMServiceProtocol`
- [ ] Accept `LLMConfig` in init
- [ ] Store API key, model, system prompt
- [ ] Implement `isConfigured` based on API key presence

#### Implement AnthropicProvider ⚡

- [ ] Create `AnthropicProvider.swift` in `Services/LLM/LLMProviders/`
- [ ] Build HTTP request to `https://api.anthropic.com/v1/messages`
- [ ] Set headers: `x-api-key`, `anthropic-version`, `content-type`
- [ ] Build request body with messages array
- [ ] Parse response to extract assistant content
- [ ] Handle rate limiting (429) with retry
- [ ] Handle authentication errors (401)
- [ ] Handle other API errors

#### Build Prompt with Context

- [ ] Replace `{speaker_name}` in system prompt with actual name
- [ ] Use "Guest" if speaker is `nil`
- [ ] Include instruction for concise, conversational responses

#### Define TTSServiceProtocol ⚡

- [ ] Create `TTSServiceProtocol.swift` in `Services/TTS/`
- [ ] Define `func speak(_ text: String) async`
- [ ] Define `func playChime(_ chime: ChimeType) async`
- [ ] Define `func stop()`
- [ ] Define `var isSpeaking: Bool { get }`

#### Define ChimeType Enum ⚡

- [ ] Create `ChimeType` enum
- [ ] Define `.acknowledged` (wake word detected)
- [ ] Define `.error` (something went wrong)
- [ ] Define `.ready` (optional, model loaded)

#### Implement TTSService ⚡

- [ ] Create `TTSService.swift` in `Services/TTS/`
- [ ] Conform to `TTSServiceProtocol`
- [ ] Use `AVSpeechSynthesizer`
- [ ] Accept `TTSConfig` in init
- [ ] Implement `AVSpeechSynthesizerDelegate` for state tracking

#### TTSService Methods ⚡

- [ ] Implement `speak(_ text: String) async`
  - Create `AVSpeechUtterance`
  - Configure voice, rate, volume
  - Speak and wait for completion

- [ ] Implement `playChime(_ chime: ChimeType) async`
  - Use `NSSound` or bundled audio
  - Keep short and unobtrusive

- [ ] Implement `stop()` - stop immediately

---

## Phase 4: Integration

### Add to Coordinator

- [ ] Add `llmService: LLMServiceProtocol` to coordinator
- [ ] Add `ttsService: TTSServiceProtocol` to coordinator
- [ ] Accept optional protocols in init (for testing)
- [ ] Load config from ConfigStore

### Implement Command Processing

- [ ] Create `processCommand(_ command: String, speaker: Speaker?, source: AudioSource) async`
- [ ] Play acknowledgment chime immediately
- [ ] Build `CommandContext`
- [ ] Set state to `.responding`
- [ ] Call `llmService.complete()`
- [ ] On success: call `ttsService.speak()` with response
- [ ] On error: speak user-friendly error message
- [ ] Return to `.listening` state

### Update Utterance Processing

- [ ] After extracting command via wake word
- [ ] Call `processCommand()` instead of logging
- [ ] Ensure proper state transitions

### Handle Missing API Key

- [ ] Check if API key configured on startup
- [ ] If not: show prompt to open settings
- [ ] Disable voice commands until configured
- [ ] Show status in menu bar dropdown

### Create Settings UI

#### GeneralSettingsView

- [ ] Create `GeneralSettingsView.swift` in `UI/Settings/`
- [ ] Wake phrase text field
- [ ] Launch at login toggle (placeholder for M6)

#### LLM Settings Section

- [ ] Add to SettingsView or create separate tab
- [ ] Secure text field for API key
- [ ] Provider picker (Anthropic/OpenAI)
- [ ] Model name text field
- [ ] System prompt text editor
- [ ] Test connection button

#### TTS Settings Section

- [ ] Voice picker (list system voices)
- [ ] Rate slider (0.0 - 1.0)
- [ ] Volume slider (0.0 - 1.0)
- [ ] Preview button

### Update Menu Bar UI

- [ ] Show "Responding..." during LLM call
- [ ] Show "Speaking..." during TTS
- [ ] Display last response (truncated)
- [ ] Show warning if API key not configured

---

## Phase 5: Verification

### Test Suite

- [ ] Run all unit tests: `xcodebuild test -scheme HeyLlama`
- [ ] All LLMService tests pass (GREEN)
- [ ] Integration tests with mocks pass
- [ ] Previous milestone tests still pass

### Manual Testing

- [ ] Configure API key in settings
- [ ] Say "Hey Llama, what time is it?"
- [ ] Verify acknowledgment chime plays
- [ ] Verify spoken response
- [ ] Test various commands
- [ ] Verify speaker context in responses (if personalized)
- [ ] Test error handling: disconnect network
- [ ] Test with invalid API key
- [ ] Verify settings persist across restart

### TTS Testing

- [ ] Test different voice settings
- [ ] Test rate adjustment
- [ ] Test volume adjustment
- [ ] Verify preview button works

### Regression Check

- [ ] Speaker identification still works
- [ ] Wake word detection still works
- [ ] All previous functionality intact

---

## Phase 6: Completion

### Git Commit

```bash
git add .
git commit -m "Milestone 4: LLM integration with TTS

- Implement LLMService with Anthropic Claude API
- Implement TTSService with AVSpeechSynthesizer
- Add acknowledgment chime on wake word detection
- Create AssistantConfig and ConfigStore
- Add LLM and TTS settings UI
- Handle API errors with spoken messages
- Complete core voice assistant loop"
```

### Ready for Next Milestone

- [ ] All Phase 5 verification items pass
- [ ] Code committed to version control
- [ ] Ready to proceed to [Milestone 5: API Server](./05-api-server.md)

---

## Deliverable

Fully functional voice assistant for local microphone. User says "Hey Llama, [command]", hears acknowledgment chime, and receives spoken response from Claude. Settings allow API key configuration and TTS customization.
