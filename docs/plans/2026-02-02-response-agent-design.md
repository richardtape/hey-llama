# Response Agent Design

## Goal
Introduce a Response Agent that always produces the final user-facing response
after skill execution, using the configured LLM provider, with personalized,
natural language based on structured skill summaries.

## Architecture
- Response Agent runs after all skill calls complete.
- It always runs (even if no skills were called), to unify tone.
- It uses the configured LLM provider in text-only mode.
- Skills emit structured summaries (no raw text) and a per-skill metadata flag
  indicating whether their summaries should be included in the response agent.
- Response Agent prompt includes:
  - Original user request
  - Speaker name
  - List of structured summaries (filtered by per-skill metadata)

## Data Flow
1. LLM generates action plan (as today).
2. Skills execute and return summaries + status.
3. Response Agent builds a prompt and requests a response from the configured
   LLM provider.
4. The Response Agent returns final text, which is sent to the UI.

## Per-Skill Metadata
Add per-skill metadata in `SkillsRegistry` (code-based for now):
- `includesInResponseAgent: Bool`
- Skills like weather and reminders set `true`.
- Internal or operational tools can be set `false` later.

## Structured Summary Shape (per skill)
Each summary includes:
- `skillId`: String
- `status`: "success" | "failed"
- `summary`: String (short, factual)
- `details`: [String: Any] (optional, structured facts)

## Error Handling
- If Response Agent fails, fall back to a deterministic concatenation of
  summaries (no personalization).
- Skill failures are included in summaries with status + error message, so the
  Response Agent can acknowledge them politely.

## Testing
- Unit tests for summary generation in each skill.
- Manual verification in app:
  - Weather → warm, personalized response.
  - Reminders add → warm, personalized response with item and list.
  - Multi-skill chain → single cohesive response.
- Debug log the summary payload during early development.
