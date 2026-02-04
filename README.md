# HeyLlama

HeyLlama is a native macOS menu bar voice assistant that listens for a wake word, transcribes speech, identifies the speaker, and executes skills (like Weather and Reminders) through an LLM-driven action plan.

## Pipeline Overview

```
Microphone → AudioEngine → VAD → STT → Speaker ID → Wake Word → LLM → Action Plan → Skills → Response
```

### Voice + Speaker Detection

- **Audio capture:** `AudioEngine` records 16kHz mono audio and publishes chunks.
- **Voice activity detection:** `VADService` detects speech start/end to isolate utterances.
- **Speech-to-text:** `STTService` transcribes the utterance into text.
- **Speaker identification:** `SpeakerService` matches the voice to enrolled speakers and exposes the current speaker.

### Wake Word Processing

- **Wake phrase matching:** `CommandProcessor` checks for “hey llama” (and common variants).
- **Command extraction:** everything after the wake phrase becomes the command (leading punctuation trimmed).

### LLM Request + Action Plan

- **Context build:** `AssistantCoordinator` creates a `CommandContext` with speaker + conversation history.
- **Skills manifest:** enabled skills are turned into a manifest describing tool IDs and argument schemas.
- **LLM call:** `LLMService` routes to the configured provider.
- **Action plan parsing:** `LLMActionPlan` parses JSON (with code-fence stripping + JSON extraction) into:
  - `respond` (text response), or
  - `call_skills` (one or more skill calls).

### Skill Execution

- **Registry + enablement:** `SkillsRegistry` resolves skill IDs and checks enabled skills.
- **Permissions:** `SkillPermissionManager` checks or requests permissions (Reminders, Location).
- **Run:** the skill executes and returns text + optional data.
- **Response:** the final text is shown in the UI and added to conversation history.

## LLM Provider Differences

Both providers feed the **same action-plan pipeline**, but they produce action plans differently:

### Apple Intelligence (Foundation Models)
- Uses **native tool calling** with `LanguageModelSession`.
- Tool calls are mapped into `LLMActionPlan` JSON inside `AppleIntelligenceProvider`.
- Instructions **avoid JSON-only constraints** to reduce guardrail refusals.

### OpenAI-Compatible (Local/Remote)
- Returns **JSON action plans directly**.
- Uses a JSON-only system prompt + skills manifest to enforce structured output.

## Prompts by Provider

- **Apple Intelligence:** instructions are conversational and tool-focused. JSON-only rules are stripped.
- **OpenAI-Compatible:** instructions demand a single JSON object with `respond` or `call_skills`.

## Local Xcode Project File

This repo ignores `HeyLlama.xcodeproj/project.pbxproj` to avoid personal signing settings. If you clone the repo, Xcode will generate this file locally when you open the project.

To run locally:
- Open `HeyLlama.xcodeproj` in Xcode.
- In **Signing & Capabilities**, select your team and enable automatic signing.
- Xcode will regenerate and maintain `project.pbxproj` on your machine.

## Learn More

- Full spec: `docs/spec.md`
- Developer quick start: `docs/quick-start.md`
- Milestones: `docs/milestones/README.md`

## Future


- A memory agent
- More 'natural' conversation after the initial wake word - not needing to use the wake word again when it makes sense
- Add a calendar skill
- Add the ability to message (iMessage) someone
- Apple Music integration
- Homekit integration
- Run shortcuts
- Think through running things on a cron (i.e. to be able to get a morning update ahead of time)
- Natural voice output (the new Qwen model?)
- Reworked 'fresh start'/onboarding guiding people through registering voices, enabling skills/permissions and choosing the AI Model
- Permissions - should guests be able to run skills?