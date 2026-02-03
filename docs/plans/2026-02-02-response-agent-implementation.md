# Response Agent Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Implement a Response Agent that always produces the final user-facing response using the configured LLM provider and structured skill summaries.

**Architecture:** Skills emit structured summaries; the action-plan execution collects summaries and invokes a Response Agent (text-only) after all skill calls complete. Per-skill metadata in `SkillsRegistry` controls whether summaries are included.

**Tech Stack:** Swift 5.9+, Foundation, XCTest.

---

### Task 1: Add structured summary model

**Files:**
- Create: `HeyLlama/Models/SkillSummary.swift`
- Test: `HeyLlamaTests/SkillSummaryTests.swift`

**Step 1: Write the failing test**
```swift
import XCTest
@testable import HeyLlama

final class SkillSummaryTests: XCTestCase {
    func testSummaryEncodesToJSON() throws {
        let summary = SkillSummary(
            skillId: "weather.forecast",
            status: .success,
            summary: "Weather retrieved",
            details: ["temperature": 12.3]
        )

        let data = try summary.toJSONData()
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["skillId"] as? String, "weather.forecast")
        XCTAssertEqual(json?["status"] as? String, "success")
    }
}
```

**Step 2: Run test to verify it fails**
Run: `Cmd+U` and confirm `SkillSummaryTests` fails due to missing type.

**Step 3: Write minimal implementation**
Create `SkillSummary` with:
- `skillId: String`
- `status: Status` enum (`success`, `failed`)
- `summary: String`
- `details: [String: Any]`
- `toJSONData()` helper using `JSONSerialization`.

**Step 4: Run test to verify it passes**
Run: `Cmd+U`, confirm `SkillSummaryTests` passes.

**Step 5: Commit**
```bash
git add HeyLlama/Models/SkillSummary.swift HeyLlamaTests/SkillSummaryTests.swift
git commit -m "feat(response): add SkillSummary model"
```

---

### Task 2: Add per-skill response metadata

**Files:**
- Modify: `HeyLlama/Services/Skills/SkillsRegistry.swift`
- Test: `HeyLlamaTests/SkillsRegistryTests.swift`

**Step 1: Write the failing test**
```swift
import XCTest
@testable import HeyLlama

final class SkillsRegistryTests: XCTestCase {
    func testSkillsIncludeResponseAgentMetadata() {
        XCTAssertTrue(RegisteredSkill.weatherForecast.includesInResponseAgent)
        XCTAssertTrue(RegisteredSkill.remindersAddItem.includesInResponseAgent)
    }
}
```

**Step 2: Run test to verify it fails**
Run: `Cmd+U`, confirm `SkillsRegistryTests` fails due to missing property.

**Step 3: Write minimal implementation**
Add `includesInResponseAgent: Bool` to `RegisteredSkill` with:
- `true` for weather + reminders

**Step 4: Run test to verify it passes**
Run: `Cmd+U`, confirm `SkillsRegistryTests` passes.

**Step 5: Commit**
```bash
git add HeyLlama/Services/Skills/SkillsRegistry.swift HeyLlamaTests/SkillsRegistryTests.swift
git commit -m "feat(response): add per-skill response metadata"
```

---

### Task 3: Add ResponseAgent service

**Files:**
- Create: `HeyLlama/Services/LLM/ResponseAgent.swift`
- Test: `HeyLlamaTests/ResponseAgentTests.swift`

**Step 1: Write the failing test**
```swift
import XCTest
@testable import HeyLlama

final class ResponseAgentTests: XCTestCase {
    func testBuildPromptIncludesSpeakerAndSummaries() {
        let summaries = [
            SkillSummary(skillId: "weather.forecast", status: .success, summary: "Cloudy", details: [:])
        ]
        let prompt = ResponseAgent.buildPrompt(
            userRequest: "What's the weather?",
            speakerName: "Rich",
            summaries: summaries
        )
        XCTAssertTrue(prompt.contains("Rich"))
        XCTAssertTrue(prompt.contains("weather.forecast"))
    }
}
```

**Step 2: Run test to verify it fails**
Run: `Cmd+U`, confirm `ResponseAgentTests` fails due to missing type.

**Step 3: Write minimal implementation**
Create `ResponseAgent` with:
- `buildPrompt(userRequest:speakerName:summaries:) -> String`
- `generateResponse(...)` that calls configured LLM provider with text-only prompt.

**Step 4: Run test to verify it passes**
Run: `Cmd+U`, confirm `ResponseAgentTests` passes.

**Step 5: Commit**
```bash
git add HeyLlama/Services/LLM/ResponseAgent.swift HeyLlamaTests/ResponseAgentTests.swift
git commit -m "feat(response): add response agent service"
```

---

### Task 4: Wire response agent after skill calls

**Files:**
- Modify: `HeyLlama/Core/AssistantCoordinator.swift`
- Modify: `HeyLlama/Services/Skills/WeatherForecastSkill.swift`
- Modify: `HeyLlama/Services/Skills/RemindersAddItemSkill.swift`
- Test: `HeyLlamaTests/AssistantCoordinatorSkillsTests.swift`

**Step 1: Write the failing test**
```swift
import XCTest
@testable import HeyLlama

final class AssistantCoordinatorSkillsTests: XCTestCase {
    func testResponseAgentRunsAfterSkillCalls() async throws {
        let mockLLM = MockLLMService()
        await mockLLM.setMockResponse("Personalized response")

        let coordinator = AssistantCoordinator(llmService: mockLLM)
        let result = try await coordinator.processActionPlan(
            from: """
            {"type":"call_skills","calls":[{"skillId":"weather.forecast","arguments":{"when":"today"}}]}
            """
        )

        XCTAssertEqual(result, "Personalized response")
    }
}
```

**Step 2: Run test to verify it fails**
Run: `Cmd+U`, confirm test fails because response agent not wired.

**Step 3: Write minimal implementation**
- Update `SkillResult` to include `summary: SkillSummary`.
- Update weather/reminders skills to populate `SkillSummary`.
- In `executeSkillCalls`, collect summaries for skills with `includesInResponseAgent`.
- Call `ResponseAgent.generateResponse(...)` with user request, speaker name, summaries.
- If ResponseAgent fails, fallback to deterministic concatenation of summaries.

**Step 4: Run test to verify it passes**
Run: `Cmd+U`, confirm test passes.

**Step 5: Commit**
```bash
git add HeyLlama/Core/AssistantCoordinator.swift HeyLlama/Services/Skills/WeatherForecastSkill.swift HeyLlama/Services/Skills/RemindersAddItemSkill.swift HeyLlama/Models/SkillSummary.swift HeyLlama/Services/LLM/ResponseAgent.swift HeyLlamaTests/AssistantCoordinatorSkillsTests.swift
git commit -m "feat(response): wire response agent into skill flow"
```
