# Apple Intelligence Tool Defaults Design

## Goal
Eliminate Apple Intelligence tool-call failures when the model omits required
arguments (notably weather `when`) by applying sensible defaults at the tool
boundary. Default location to current location when missing and default the
time period to today when missing.

## Context
Apple Intelligence tool calling currently fails with:
`Failed to deserialize a Generable type from model output`.
This occurs when tool arguments are missing or malformed. The weather tool
expects `when` and `location` fields in its `@Generable` arguments, and the
model sometimes omits `when` for queries like "what's the weather".

## Proposed Approach
Apply defaults inside the Apple Intelligence provider’s tool argument handling.

- Make `WeatherForecastTool.Arguments.when` optional.
- Treat empty or missing `when` as `"today"`.
- Treat empty or missing `location` as `nil`, allowing the weather skill to
  resolve current location via `LocationHelpers.getCurrentLocation()`.
- Record tool invocations with normalized arguments so downstream JSON action
  plans remain consistent.

This keeps the rest of the skill pipeline unchanged and avoids reliance on
model compliance with instructions.

## Data Flow
1. User utterance triggers Apple Intelligence tool call.
2. FoundationModels decodes optional arguments (no crash).
3. Tool call normalizes defaults and records a `ToolInvocation`.
4. Provider builds an action plan JSON from tool calls.
5. Skills execute as before (location resolved if nil).

## Error Handling
- Missing/empty `when` and `location` are treated as non-errors.
- Invalid values (e.g., unsupported `when`) are still rejected by the skill
  parser and surface as normal `SkillError`.
- If the model returns no tool call, the existing JSON respond path remains.

## Testing
Automated tests are limited because FoundationModels tool decoding is not
available in the unit test target.

Manual verification in the app:
- "what's the weather" → current location + today
- "what's the weather like in my location" → current location + today
- "what's the weather like for me tomorrow" → current location + tomorrow

Supplementary: Location normalization already has unit tests in
`LocationHelpersTests`.
