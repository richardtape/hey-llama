# Development Milestones

## Overview

For general project context, see:
- [`CLAUDE.md`](../../CLAUDE.md) - Quick reference for architecture and patterns
- [`docs/spec.md`](../spec.md) - Complete technical specification
- [`docs/quick-start.md`](../quick-start.md) - Developer quick start guide

## Milestone Order

Build these in sequence. Each milestone depends on the previous ones being complete.

| # | Milestone | Goal | Key Deliverable |
|---|-----------|------|-----------------|
| 0 | [Project Setup](./00-project-setup.md) | Xcode project, dependencies, app shell | Buildable menu bar app |
| 1 | [Audio Foundation](./01-audio-foundation.md) | Audio capture, VAD | Shows "Capturing..." when speaking |
| 2 | [Speech-to-Text](./02-speech-to-text.md) | WhisperKit, wake word | Transcribes and detects "Hey Llama" |
| 3 | [Speaker Identification](./03-speaker-identification.md) | FluidAudio, enrollment | Identifies enrolled speakers |
| 4 | [LLM Integration](./04-llm-integration.md) | Apple Intelligence / local OpenAI-compatible LLM | Text responses from the LLM |
| 5 | [Tools/Skills Registry](./05-tools-registry.md) | Skills registry + structured JSON tool calling | Weather + Reminders skills (text confirmations) |
| 6 | [API Server](./06-api-server.md) | HTTP/WebSocket, Bonjour | External clients can connect |
| 7 | [Settings & Polish](./07-settings-polish.md) | Error handling, onboarding, skills toggles | Production-ready v1.0 |

---

## Phase Structure

Each milestone follows a consistent 6-phase structure designed for test-driven development:

### Phase 1: Design
Confirm key design decisions before implementation. This prevents rework and ensures alignment.

### Phase 2: Test Setup
**Write tests BEFORE implementation (TDD).** Create test files, write failing tests (RED), and set up mock services. This phase ensures you know what success looks like before coding.

### Phase 3: Implementation
Build the actual code. Implement models, protocols, and services. Make the tests pass (GREEN). Tasks marked with ⚡ can be developed in parallel.

### Phase 4: Integration
Wire components together. Connect services to the coordinator, update UI bindings, and ensure the system works as a whole.

### Phase 5: Verification
Run the full test suite and perform manual testing. Check for regressions against previous milestones. **Do not proceed until all verification passes.**

### Phase 6: Completion
Commit your work with a descriptive message. Verify you're ready for the next milestone.

---

## How to Use These Documents

### Following the Phases

1. **Start with Phase 1** - Confirm design decisions match your requirements
2. **Write tests in Phase 2** - This is TDD: tests come before implementation
3. **Implement in Phase 3** - Make the tests pass
4. **Integrate in Phase 4** - Wire everything together
5. **Verify in Phase 5** - All tests pass, manual testing complete
6. **Complete in Phase 6** - Commit and move on

### Parallelization

Tasks marked with ⚡ can be developed in parallel. For example:
- M1: AudioChunk ⚡ AudioSource (independent models)
- M3: SpeakerEmbedding ⚡ Speaker (independent models)
- M4: LLMService ⚡ Provider implementations (no dependencies)
- M5: SkillsRegistry ⚡ individual skills (independent skills)
- M5: HTTP Server ⚡ WebSocket Server (independent servers)

### Using Superpowers Skills

These milestones are designed to work with the superpowers methodology:

| Phase | Relevant Skill |
|-------|---------------|
| Design | `brainstorming` |
| Test Setup | `test-driven-development` |
| Implementation | `executing-plans`, `subagent-driven-development` |
| Verification | `verification-before-completion` |
| Completion | `finishing-a-development-branch` |

### Progress Tracking

Use the checkboxes in each milestone document to track progress:

```markdown
- [x] Completed task
- [ ] Pending task
```

---

## Incremental Value

Each milestone provides usable functionality:

- **After M0**: App runs as menu bar application
- **After M1**: App responds to speech visually
- **After M2**: App understands what you say
- **After M3**: App knows who is speaking
- **After M4**: App can generate responses via LLM (text)
- **After M5**: App can run registered skills (Weather, Reminders) via structured actions
- **After M6**: App accepts commands from other devices
- **After M7**: App is ready for daily use
