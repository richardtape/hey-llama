# Milestone 4: LLM Integration

## Overview

For general project context, see:
- [`CLAUDE.md`](../../CLAUDE.md) - Quick reference for architecture and patterns
- [`docs/spec.md`](../spec.md) - Complete technical specification (Section 7: Configuration)

## Goal

Integrate an LLM provider so the app can turn a wake-word command into a **text response**.

This milestone is intentionally **LLM-only**:

- **No spoken response / TTS yet** (that will be a future milestone)
- **No tools/skills registry yet** (that will be Milestone 5)

## Prerequisites

- Milestone 3 complete (speaker identification working)

---

## Phase 1: Design

Key design decisions for this milestone:

- [ ] Confirm default LLM provider: Apple Intelligence (preferred) vs local OpenAI-compatible
- [ ] Confirm Apple Intelligence availability strategy (version gating + graceful fallback)
- [ ] Confirm local OpenAI-compatible server contract:
  - [ ] Base URL (example: `http://localhost:11434/v1`)
  - [ ] Optional API key
  - [ ] Model selection (typed or discovered via `/v1/models`)
- [ ] Confirm system prompt:
  - [ ] concise, conversational responses suitable for UI display (not speech)
  - [ ] includes speaker name substitution
- [ ] Confirm error handling: show user-friendly errors in menu bar UI

---

## Phase 2: Test Setup

### Create Test Infrastructure

- [ ] Create `LLMServiceTests.swift` in test target
- [ ] Create `MockLLMService.swift` in `HeyLlamaTests/Mocks/`

### Write LLMService Tests (RED)

- [ ] Test: provider selection routes to correct underlying provider
- [ ] Test: Apple Intelligence provider is treated as configured when supported
- [ ] Test: OpenAI-compatible provider `isConfigured` returns false when base URL missing
- [ ] Test: OpenAI-compatible provider `isConfigured` returns false when model missing
- [ ] Test: OpenAI-compatible provider `isConfigured` returns true when base URL + model set (API key optional)
- [ ] Test: System prompt includes speaker name substitution
- [ ] Test: Request body format matches OpenAI-compatible `POST /v1/chat/completions`
- [ ] Test: Response parsing extracts content correctly
- [ ] Test: Network errors throw appropriate error type

### Write Integration Tests with Mocks

- [ ] Test: Full pipeline with MockSTT, MockSpeaker, MockLLM
- [ ] Test: Command flows from wake word to LLM call
- [ ] Test: Speaker context included in LLM prompt
- [ ] Test: Error in LLM shows user-friendly error state/message

### Create MockLLMService

- [ ] Implement `LLMServiceProtocol`
- [ ] Allow setting `mockResponse: String`
- [ ] Track `lastPrompt: String?` and `lastContext: CommandContext?`
- [ ] Allow simulating errors with `shouldThrowError: Bool`

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
- [ ] (Optional placeholder) Keep other config groups for future milestones, but do not implement them here
- [ ] Conform to `Codable`
- [ ] Implement `static var `default`: AssistantConfig`

#### LLMConfig

- [ ] Define `provider: LLMProvider = .appleIntelligence`
- [ ] Define `systemPrompt: String` with default “helpful assistant” prompt (no tool/skill calling yet)
- [ ] Define `appleIntelligence: AppleIntelligenceConfig`
- [ ] Define `openAICompatible: OpenAICompatibleConfig`

#### AppleIntelligenceConfig

- [ ] Define `enabled: Bool = true`
- [ ] Define `preferredModel: String?` (optional; depends on Apple API surface)

#### OpenAICompatibleConfig

- [ ] Define `enabled: Bool = true`
- [ ] Define `baseURL: String = "http://localhost:11434/v1"`
- [ ] Define `apiKey: String? = nil` (optional)
- [ ] Define `model: String = ""` (required; user selects)
- [ ] Define `timeoutSeconds: Int = 60`

#### LLMProvider Enum

- [ ] Define cases: `.appleIntelligence`, `.openAICompatible`
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
- [ ] Store provider selection + provider configs
- [ ] Implement `isConfigured` based on selected provider requirements

#### Implement AppleIntelligenceProvider ⚡

- [ ] Create `AppleIntelligenceProvider.swift` in `Services/LLM/LLMProviders/`
- [ ] Implement minimal `complete(...)` using Apple’s on-device model APIs when available
- [ ] Return a clear error if unsupported on this macOS/device

#### Implement OpenAICompatibleProvider ⚡

- [ ] Create `OpenAICompatibleProvider.swift` in `Services/LLM/LLMProviders/`
- [ ] Build HTTP request to `{baseURL}/chat/completions`
- [ ] Set headers:
  - [ ] `Authorization: Bearer <apiKey>` (only if apiKey provided)
  - [ ] `Content-Type: application/json`
- [ ] Build request body with `model`, `messages`
- [ ] Prefer structured output controls where supported (JSON mode / schema), otherwise enforce JSON via prompt
- [ ] Parse response to extract assistant content
- [ ] Handle common API errors (401/403/404/429/5xx) with friendly messaging

#### Build Prompt with Context

- [ ] Replace `{speaker_name}` in system prompt with actual name
- [ ] Use "Guest" if speaker is `nil`
- [ ] Keep responses concise and suitable for on-screen display

---

## Phase 4: Integration

### Add to Coordinator

- [ ] Add `llmService: LLMServiceProtocol` to coordinator
- [ ] Accept optional protocols in init (for testing)
- [ ] Load config from ConfigStore

### Implement Command Processing

- [ ] Create `processCommand(_ command: String, speaker: Speaker?, source: AudioSource) async`
- [ ] Build `CommandContext`
- [ ] Set state to `.responding`
- [ ] Call `llmService.complete()` to produce a text response
- [ ] On success: store the response for UI display (e.g. `lastResponse`)
- [ ] On error: show user-friendly error message/state
- [ ] Return to `.listening` state

### Update Utterance Processing

- [ ] After extracting command via wake word
- [ ] Call `processCommand()` instead of logging
- [ ] Ensure proper state transitions

### Handle Missing Provider Configuration

- [ ] If OpenAI-compatible selected and base URL/model not set: show prompt to open settings
- [ ] If Apple Intelligence selected but unavailable: show prompt to select fallback provider
- [ ] Show status in menu bar dropdown

### Create Settings UI

#### GeneralSettingsView

- [ ] Create `GeneralSettingsView.swift` in `UI/Settings/`
- [ ] Wake phrase text field
- [ ] Launch at login toggle (placeholder for M6)

#### LLM Settings Section

- [ ] Add to SettingsView or create separate tab
- [ ] Provider picker (Apple Intelligence / Local OpenAI-compatible)
- [ ] Apple Intelligence: availability status + enable toggle
- [ ] Local OpenAI-compatible:
  - [ ] Base URL field
  - [ ] Optional API key field
  - [ ] Model picker / text field
  - [ ] “Refresh models” button (optional: fetch `/v1/models`)
- [ ] System prompt text editor
- [ ] Test connection button

### Update Menu Bar UI

- [ ] Show "Responding..." during LLM call
- [ ] Display last response (truncated)
- [ ] Show warning if AI provider is not configured / unavailable

---

## Phase 5: Verification

### Test Suite

- [ ] Run all unit tests in Xcode (`Cmd+U`)
- [ ] All LLMService tests pass (GREEN)
- [ ] Integration tests with mocks pass
- [ ] Previous milestone tests still pass

### Manual Testing

- [ ] Configure provider in settings (Apple Intelligence or local OpenAI-compatible)
- [ ] Say "Hey Llama, what time is it?"
- [ ] Verify response text appears in the menu bar UI
- [ ] Test various commands
- [ ] Verify speaker context in responses (if personalized)
- [ ] Test error handling (OpenAI-compatible): stop local server or break URL
- [ ] Test with invalid API key (if provided)
- [ ] Verify settings persist across restart

### Regression Check

- [ ] Speaker identification still works
- [ ] Wake word detection still works
- [ ] All previous functionality intact

---

## Phase 6: Completion

### Git Commit

```bash
git add .
git commit -m "Milestone 4: LLM integration (text responses)

- Add LLM provider abstraction (Apple Intelligence + OpenAI-compatible local)
- Create AssistantConfig and ConfigStore
- Add LLM settings UI (provider selection, local server config)
- Handle provider/network errors with user-friendly messages
- Produce and display text responses from the LLM"
```

### Ready for Next Milestone

- [ ] All Phase 5 verification items pass
- [ ] Code committed to version control
- [ ] Ready to proceed to [Milestone 5: Tools/Skills Registry](./05-tools-registry.md)

---

## Deliverable

LLM-backed assistant for local microphone that produces **text responses**. User says "Hey Llama, [command]" and the app shows the LLM response in the menu bar UI. Supports Apple Intelligence or a local OpenAI-compatible server via settings.
