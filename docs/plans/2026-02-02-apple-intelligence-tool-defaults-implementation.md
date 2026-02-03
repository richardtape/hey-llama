# Apple Intelligence Tool Defaults Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Prevent Apple Intelligence tool-call failures when `when` or `location` are missing by applying defaults at the tool boundary.

**Architecture:** Make weather tool arguments tolerant of missing values, then normalize to `"today"` and `nil` before recording tool invocations. Downstream action-plan JSON and skill execution remain unchanged.

**Tech Stack:** Swift 5.9+, FoundationModels (macOS 26+), XCTest (manual verification in app).

---

### Task 1: Default missing weather tool arguments

**Files:**
- Modify: `HeyLlama/Services/LLM/LLMProviders/AppleIntelligenceProvider.swift`

**Step 1: Write the failing test**
Manual reproduction in the app (Apple Intelligence provider enabled):
- Say: "Hey Llama, what's the weather?"
- Expected current behavior: tool-call decoding failure or non-tool response.

**Step 2: Verify failure**
Run the app and confirm the log contains:
`Failed to deserialize a Generable type from model output`
or the model refuses to call the tool for missing fields.

**Step 3: Write minimal implementation**
Update `WeatherForecastTool.Arguments` to:
- Make `when` optional.
- Normalize in `call(arguments:)`:
  - If `when` is nil or blank, set `"today"`.
  - If `location` is nil or blank, omit it (allowing current location).

**Step 4: Manual verification**
Run the app and try:
- "Hey Llama, what's the weather?" → uses current location, today.
- "Hey Llama, what's the weather like in my location?" → current location, today.
- "Hey Llama, what's the weather like for me tomorrow?" → current location, tomorrow.

**Step 5: Commit**
```bash
git add HeyLlama/Services/LLM/LLMProviders/AppleIntelligenceProvider.swift
git commit -m "fix(ai): default missing weather tool arguments"
```
