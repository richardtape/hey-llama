# Milestone 5: Tools/Skills Registry

## Overview

For general project context, see:
- [`CLAUDE.md`](../../CLAUDE.md) - Quick reference for architecture and patterns
- [`docs/spec.md`](../spec.md) - Complete technical specification (Sections 5, 7, 10)

## Goal

Create a **registerable tools/skills system** that the app can use to execute actions from voice commands, and expose those skills throughout the app:

- A central **SkillsRegistry** (aka tools registry) that can be extended over time
- A **visible list of available skills** in Settings, with per-skill enable/disable
- A way to require **structured outputs** (JSON) from the LLM so it can request skill execution deterministically
- A way to request and track **macOS permissions** needed by skills (e.g. Reminders)

This milestone introduces two starter skills:

- **Weather Forecast** (`weather.forecast`)
- **Add Reminder Item** (`reminders.add_item`) (adds to a named Reminders list)

## Prerequisites

- Milestone 4 complete (LLM produces text responses)

---

## Phase 1: Design

Key design decisions for this milestone:

- [ ] Confirm terminology: “skills” vs “tools” (use one term consistently in UI/docs)
- [ ] Confirm how skills are invoked:
  - [ ] LLM returns strict JSON describing desired skill call(s)
  - [ ] App validates JSON, validates skill is enabled, then executes
- [ ] Confirm permission model:
  - [ ] Each skill declares required permissions
  - [ ] App requests permission on first use (and/or via Settings)
- [ ] Confirm safety model:
  - [ ] Allow running skills without confirmation by default, or require confirmation for “write” actions (e.g. Reminders)
- [ ] Confirm weather data source approach for v1:
  - [ ] Prefer WeatherKit (requires location permission + entitlement considerations), OR
  - [ ] Use a simple no-key HTTP forecast source (if acceptable), OR
  - [ ] “Stub” weather skill initially with clear TODOs (not ideal, but acceptable for scaffolding)

---

## Phase 2: Test Setup

### Create Test Infrastructure

- [ ] Create `SkillsRegistryTests.swift` in test target
- [ ] Create `SkillActionPlanTests.swift` in test target
- [ ] Create `MockSkillsRegistry.swift` in `HeyLlamaTests/Mocks/` (optional)
- [ ] Create `MockWeatherSkill.swift` and `MockRemindersSkill.swift` in `HeyLlamaTests/Mocks/` (optional)

### Write Skills Registry Tests (RED)

- [ ] Test: registry exposes a stable list of registered skills
- [ ] Test: registry filters enabled skills based on config
- [ ] Test: registry can generate a “skills manifest” (name/description/schema) for prompt injection

### Write Action Plan Parsing Tests (RED)

- [ ] Test: valid `{"type":"respond","text":"..."}` decodes
- [ ] Test: valid `{"type":"call_skills","calls":[...]}` decodes
- [ ] Test: unknown skillId fails validation cleanly
- [ ] Test: invalid JSON triggers a user-friendly error

### Write Integration Tests (RED)

- [ ] Test: when LLM requests an enabled skill, coordinator executes it and returns final text response
- [ ] Test: when LLM requests a disabled skill, coordinator refuses and returns a helpful message
- [ ] Test: reminders skill requests permission when missing and returns a helpful message

---

## Phase 3: Implementation

### Define Skill Protocol + Registry

- [ ] Create `SkillProtocol.swift` in `Services/Skills/`
- [ ] Define a `Skill` protocol with:
  - [ ] `id: String` (stable identifier, e.g. `reminders.add_item`)
  - [ ] `name: String` (UI label)
  - [ ] `description: String`
  - [ ] `requiredPermissions: [SkillPermission]`
  - [ ] `argumentSchemaJSON: String` (JSON Schema injected into prompt)
  - [ ] `func run(argumentsJSON: String, context: CommandContext) async throws -> SkillResult`
- [ ] Create `SkillResult` model (text + optional structured fields)
- [ ] Create `SkillsRegistry.swift` in `Services/Skills/`:
  - [ ] Holds all skills available in the build
  - [ ] Filters enabled skills via config
  - [ ] Generates a “skills manifest” string for LLM prompt injection

### Define Skill Permissions

- [ ] Create `SkillPermission.swift` in `Services/Skills/`
- [ ] Define cases (initial):
  - [ ] `.reminders`
  - [ ] `.location` (if weather needs it)
  - [ ] `.network` (if weather uses HTTP)
- [ ] Add helpers for checking/requesting permissions (where applicable)

### Define LLM ⇄ Skills JSON Contract

- [ ] Create `LLMActionPlan.swift` in `Models/` (or `Services/LLM/`)
- [ ] Standardize one JSON output shape, for example:
  - [ ] `{"type":"respond","text":"..."}`
  - [ ] `{"type":"call_skills","calls":[{"skillId":"...","arguments":{...}}]}`
- [ ] Validate JSON strictly; on invalid JSON:
  - [ ] Return a clear error path suitable for UI
  - [ ] Log raw model output for debugging

### Implement Initial Skills

#### Weather Forecast Skill

- [ ] Create `WeatherForecastSkill.swift` in `Services/Skills/`
- [ ] Skill ID: `weather.forecast`
- [ ] Arguments (first pass):
  - [ ] `when`: `"today" | "tomorrow" | "next_7_days"`
  - [ ] `location`: optional string (if omitted, use configured/default location)
- [ ] Implement with the chosen data source (as decided in Phase 1)

#### Reminders Add Item Skill

- [ ] Create `RemindersAddItemSkill.swift` in `Services/Skills/`
- [ ] Skill ID: `reminders.add_item`
- [ ] Arguments (first pass):
  - [ ] `listName`: string
  - [ ] `itemName`: string
  - [ ] `notes`: optional string
  - [ ] `dueDateISO8601`: optional string
- [ ] Use EventKit Reminders APIs
- [ ] If permission missing: request permission and return a helpful message

### Update Prompt Construction (LLM Side)

- [ ] Inject the enabled skills manifest into the prompt context
- [ ] Instruct the model to return **strict JSON** for action planning
- [ ] Include examples of valid JSON outputs in the prompt (few-shot)

---

## Phase 4: Integration

### Add to Coordinator

- [ ] Add `skillsRegistry: SkillsRegistry` to `AssistantCoordinator`
- [ ] Update command processing flow:
  - [ ] First LLM call returns an action plan JSON
  - [ ] If `respond`: show text response
  - [ ] If `call_skills`: execute skills, then produce a final text response (templated or LLM follow-up)

### Add Settings UI for Skills

- [ ] Create `SkillsSettingsView.swift` in `UI/Settings/`
- [ ] List all available skills with:
  - [ ] Name + description
  - [ ] Enabled toggle
  - [ ] Required permissions indicator
  - [ ] Permission status + request affordance (where possible)

---

## Phase 5: Verification

### Test Suite

- [ ] Run all unit tests in Xcode (`Cmd+U`)
- [ ] Skills registry + action plan tests pass (GREEN)
- [ ] Previous milestone tests still pass

### Manual Testing

- [ ] In settings, enable/disable Weather skill and verify changes apply
- [ ] In settings, enable Reminders skill and verify permission flow works
- [ ] Say "Hey Llama, what's the weather?"
  - [ ] LLM requests `weather.forecast`
  - [ ] App executes skill
  - [ ] App displays final text response
- [ ] Say "Hey Llama, add deodorant to the groceries list"
  - [ ] App requests Reminders permission (if needed)
  - [ ] Item appears in the correct Reminders list
  - [ ] App displays confirmation text

---

## Phase 6: Completion

### Git Commit

```bash
git add .
git commit -m "Milestone 5: tools/skills registry with Weather and Reminders

- Add SkillsRegistry and Skill protocol
- Add strict JSON action plan parsing/validation
- Implement Weather forecast skill (data source TBD)
- Implement Reminders add-item skill with permission flow
- Add Skills settings UI with per-skill toggles"
```

### Ready for Next Milestone

- [ ] All Phase 5 verification items pass
- [ ] Code committed to version control
- [ ] Ready to proceed to [Milestone 6: API Server](./06-api-server.md)

---

## Deliverable

App can execute registered skills via a central registry, with skills enabled/disabled in Settings, and with structured JSON action planning from the LLM. Includes initial Weather + Reminders skills (text confirmations only; no TTS yet).
