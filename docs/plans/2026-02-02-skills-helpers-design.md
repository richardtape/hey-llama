---
title: Skills Helpers Refactor Design
date: 2026-02-02
status: draft
---

# Skills Helpers Refactor Design

## Context
The current skills implementation contains multiple low-level utilities embedded directly in skill files (for example, location normalization, geocoding, current-location retrieval, EventKit list lookup, and ISO8601 due-date parsing). As we add more skills, these utilities should be shared and kept consistent while preserving the enum-based `RegisteredSkill` architecture.

## Goals
- Extract reusable helpers into `HeyLlama/Services/Skills/Helpers/`.
- Keep skill structs focused on orchestration and formatting.
- Maintain current behavior and error messages.
- Add small unit tests for helper logic that does not require OS services.

## Non-Goals
- Change the `RegisteredSkill` enum design.
- Introduce new app-wide utilities outside the skills layer.
- Change user-facing text or skill schemas.

## Proposed Structure
```
HeyLlama/Services/Skills/Helpers/
  LocationHelpers.swift
  RemindersHelpers.swift
  SkillArgumentParsing.swift
```

### LocationHelpers.swift
- `normalizeLocationToken(_:) -> String?` for tokens like “user”, “here”, “current location”.
- `LocationFetcher` actor moved from `WeatherForecastSkill`.
- `getCurrentLocation()` and `geocodeLocation(_:)` extracted as helper functions.

### RemindersHelpers.swift
- `findReminderList(named:in:)` to resolve EventKit calendars and provide standard “list not found” error.
- `parseDueDateISO8601(_:) -> DateComponents?` to reuse the same parsing logic across skills.

### SkillArgumentParsing.swift
- A generic `decodeArguments<T: Decodable>(from:)` to centralize JSON decoding and error mapping to `SkillError.invalidArguments`.

## Data Flow
Skills call helper functions for low-level operations (location retrieval, geocoding, list resolution, JSON decoding) and remain responsible for:
- Permission checks
- Skill orchestration and control flow
- Response formatting

## Testing Strategy
- Add unit tests for location token normalization.
- Add unit tests for ISO8601 date parsing.
- Add unit tests for argument decode failures.
- Keep integration tests unchanged.

## Rollout
1. Add helpers and tests.
2. Update `WeatherForecastSkill` and `RemindersAddItemSkill` to use helpers.
3. Run tests in Xcode.
