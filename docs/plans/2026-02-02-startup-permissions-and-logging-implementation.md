# Startup Permissions and Logging Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Ensure startup logs show active LLM and skills/permissions, and preflight/request permissions for enabled skills so the first command works without opening Settings.

**Architecture:** Centralize a startup preflight in `AssistantCoordinator.start()` that (1) logs config/skill state and (2) checks or requests required OS permissions for enabled skills. Fix skill execution to use a single permission snapshot to avoid inconsistent status.

**Tech Stack:** Swift 5.9+, Foundation, OS permissions (EventKit, CoreLocation), XCTest (manual verification exception approved).

---

### Task 1: Fix permission snapshot in skill execution

**Files:**
- Modify: `HeyLlama/Core/AssistantCoordinator.swift`

**Step 1: Write the failing test**
Manual reproduction in the app:
- Launch app, immediately ask for weather.
- Observe log sequence:
  - `location status: undetermined` then `location status: granted`
  - Response: "requires  permission" (blank permission name).

**Step 2: Verify failure**
Run app and confirm the blank permission response occurs when the two checks disagree.

**Step 3: Write minimal implementation**
In `executeSkillCalls`:
- Replace the `hasAllPermissions` + `missingPermissions` double-check with a single call:
  - `let missing = await permissionManager.missingPermissions(for: skill)`
  - If `missing.isEmpty` proceed, else build the message from `missing`.

**Step 4: Manual verification**
Repeat the same command; the blank permission response should no longer occur.

**Step 5: Commit**
```bash
git add HeyLlama/Core/AssistantCoordinator.swift
git commit -m "fix(skills): use single permission snapshot"
```

---

### Task 2: Startup preflight for skills and permissions

**Files:**
- Modify: `HeyLlama/Core/AssistantCoordinator.swift`

**Step 1: Write the failing test**
Manual reproduction:
- Launch app, do not open Settings.
- Ask a skills-based command and observe that permissions only appear after visiting Settings.

**Step 2: Verify failure**
Confirm startup does not log skill/permission status and does not request missing permissions.

**Step 3: Write minimal implementation**
Add a startup preflight called from `start()` after microphone permission:
- Log active LLM provider from config (`config.llm.provider`).
- Log enabled skills and, for each enabled skill:
  - Log required permissions and current status.
  - If status is `.undetermined`, request permission and log the result.

**Step 4: Manual verification**
- Clean/build/run.
- On startup logs, see:
  - LLM provider
  - Skills enabled list
  - Permission status lines and request results (if undetermined)
- Ask weather immediately; should not require visiting Settings to update status.

**Step 5: Commit**
```bash
git add HeyLlama/Core/AssistantCoordinator.swift
git commit -m "feat(startup): preflight skills permissions and log config"
```
