---
step: 2
title: Tool definitions in the Modelfile
spine: workspace/agent.ts
kind: build
reference: agent.ts
---

# Step 2 — Tool definitions in the Modelfile

## Frame
A plain text model can't fetch weather or search the web — it can only generate text. But what if we taught it a convention: "when you need data you don't have, respond with a JSON array describing which tool to call." That's prompt emulation — no formal API, just a system prompt that tells the model *how to ask for tools*. Today you'll add tool definitions to the Modelfile and watch the model switch from plain text to structured JSON when it needs external data.

## Teach the mechanism  (tool definitions + JSON responses are NEW)
- **Prompt emulation**: instead of using a formal tool-calling API (like OpenAI's function calling), we embed tool definitions in the SYSTEM prompt. The model follows text instructions to output JSON when it needs a tool. This is how every agent worked before formal APIs, and understanding it teaches you what's really happening under the hood.
- **Tool definition format**: each tool has a name, description, and parameter schema. Example:
  ```
  [TOOL: get_weather]
  Description: Get current weather for a location
  Parameters: {"location": "string — city name"}
  Returns: {"temperature": number, "condition": "string", "humidity": "number"}
  ```
- **The RULES block**: tells the model when and how to use tools. The critical rule: "If you need a tool, respond with ONLY a JSON array. If you can answer directly, respond with plain text." This binary switch is the heart of prompt emulation.

**How you'll validate it:** you'll rebuild the model, send "What's the weather in Tokyo?", and watch the model respond with `[{"tool": "get_weather", "args": {"location": "Tokyo"}}]` instead of plain text. Then send "What is 2+2?" and watch it answer directly — no JSON.

**Read first:** `docs/open-meteo-cheatsheet.md` (for the weather tool definition format).

## Spine  (the learner modifies `workspace/agent.ts` and `workspace/Modelfile`)
- Update `workspace/Modelfile` SYSTEM prompt to include:
  1. `[TOOL: get_weather]` definition with parameters
  2. `[TOOL: calculate]` definition (simple arithmetic — for testing when the model answers directly)
  3. `RULES` block: "If you need a tool, respond with ONLY a JSON array of tool calls. If you can answer directly, respond with plain text."
- Rebuild: `ollama create loopcraft -f workspace/Modelfile`
- Modify `workspace/agent.ts`: send "What's the weather in Tokyo?" and print the raw response.
- The model should emit JSON like `[{"tool": "get_weather", "args": {"location": "Tokyo"}}]`
- Then test "What is 2+2?" — should return plain text "4" or similar.

## Agent role
- `[explain]` How prompt emulation works: the model doesn't "know" about tools in the API sense — it follows text instructions in the system prompt. When it sees "respond with JSON if you need a tool," it complies.
- `[review]` Check the Modelfile has complete tool definitions (name, description, parameters) and the RULES block. Check the script sends the message correctly.

## Gotchas
- The model sometimes wraps JSON in markdown backticks (```json ... ```) or adds explanatory text ("Let me check that for you:" before the JSON). The parser needs to handle this — we'll build it in Step 3.
- `/no_think` in the Modelfile helps reduce noise (some models add `<think>` blocks before the JSON).
- If the SYSTEM prompt is too long, some models may not follow the format perfectly — keep tool definitions concise.
- Some models tend to always use tools even when they could answer directly. The RULES block helps, but model behavior varies.

## Success check  (local — node)
1. Rebuild succeeds: `ollama create loopcraft -f workspace/Modelfile`
2. "What's the weather in Tokyo?" → response contains JSON with `tool: "get_weather"` and `args.location: "Tokyo"`
3. "What is 2+2?" → response is plain text (no JSON tool call)

The learner must explain *how the model knows to output JSON* before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)
<!-- The tutor composes each quiz at runtime based on what the learner built, where they struggled,
     and what they observed. The angles below guide the tutor — they are NOT verbatim questions. -->

**Quiz topic 1 — Diagnose:**
What determines whether the model outputs JSON (a tool call) or plain text? (Angle: the question + tool descriptions. If the question matches a tool's description, the model follows the RULES and outputs JSON. If it can answer from its own knowledge, plain text. It's not random and there's no formal API deciding — it's text instructions in the prompt.)

**Quiz topic 2 — Reflect:**
This is "prompt emulation" — the model emulates tool calling through text instructions. What's the advantage of understanding this? (Angle: it reveals what's really happening — tool calls are structured text the model generates, which an orchestrator parses and executes. Formal APIs add validation and convenience, but the mechanism is the same — text in, text out. Understanding the mechanism makes you a better agent builder.)