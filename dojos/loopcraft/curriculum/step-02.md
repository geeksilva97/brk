---
step: 2
title: Tool definitions in the Modelfile
spine: workspace/agent.ts
kind: build
reference: agent.ts
---

# Step 2 — Tool definitions in the Modelfile

## Frame
A plain text model can't fetch weather or search the web — it can only generate text. But what if we taught it a convention: "when you need data you don't have, respond with a JSON array describing which tool to call." That's **prompt emulation** — no formal API, just a system prompt that tells the model *how to ask for tools*. Today you'll add tool definitions to the Modelfile and watch the model switch from plain text to structured JSON when it needs external data.

## Teach the mechanism  (tool definitions + RULES + prompt emulation are NEW)
- **Prompt emulation**: instead of using a formal tool-calling API (like OpenAI's function calling), we embed tool definitions in the SYSTEM prompt. The model follows text instructions to output JSON when it needs a tool. There is no special API — it's just text in, text out, but the text is structured by convention.
- **Tool definition format**: each tool has a name, description, and parameter schema. The model reads these like a menu — when a user question matches a tool's description, it knows to use it. Example:
  ```
  [TOOL: get_weather]
  Description: Get current weather for a location
  Parameters: {"location": "string — city name"}
  Returns: {"temperature": number, "condition": "string", "humidity": "number"}
  ```
- **The RULES block**: tells the model when and how to use tools. The critical rule: "If you need a tool, respond with ONLY a JSON array. If you can answer directly, respond with plain text." This binary switch is the heart of prompt emulation — the model decides based on the question and available tools.
- **What happens next**: the model sees "What's the weather in Tokyo?" → matches the `get_weather` tool description → follows the RULES → outputs `[{"tool": "get_weather", "args": {"location": "Tokyo"}}]` instead of guessing the weather. A plain question like "What is 2+2?" → no tool match → plain text answer.

**How you'll validate it:** you'll rebuild the model, send "What's the weather in Tokyo?", and watch the model respond with JSON instead of plain text. Then send "What is 2+2?" and watch it answer directly — no JSON. You'll also import `parseToolCalls` from `utils.ts` to verify the JSON parses correctly.

**Read first:** `docs/modelfile.md` (for the SYSTEM directive format and how to add tools/RULES).

## Spine  (the learner modifies `workspace/Modelfile` and `workspace/agent.ts`)
- Update `workspace/Modelfile` SYSTEM prompt to include:
  1. `[TOOL: get_weather]` definition with description, parameters, and return type
  2. `[TOOL: calculate]` definition (simple arithmetic — for testing when the model answers directly)
  3. `RULES` block: "If you need a tool, respond with ONLY a JSON array of tool calls. If you can answer directly, respond with plain text."
- Rebuild: `ollama create loopcraft -f workspace/Modelfile`
- Modify `workspace/agent.ts`: import `chat` and `parseToolCalls` from `./utils.ts`. Send "What's the weather in Tokyo?" and print the raw response. Then call `parseToolCalls` on it and print the parsed result.
- Also test "What is 2+2?" — should return plain text (no tool calls, `parseToolCalls` returns an empty array).

Example `agent.ts` for this step:
```typescript
import { chat, parseToolCalls } from './utils.ts';

async function main() {
  // Test 1: a question that needs a tool
  const response1 = await chat('loopcraft', [
    { role: 'user', content: "What's the weather in Tokyo?" }
  ]);
  console.log('Raw response:', response1);
  console.log('Parsed tool calls:', parseToolCalls(response1));

  // Test 2: a question the model can answer directly
  const response2 = await chat('loopcraft', [
    { role: 'user', content: 'What is 2+2?' }
  ]);
  console.log('Raw response:', response2);
  console.log('Parsed tool calls:', parseToolCalls(response2));
}

main().catch(console.error);
```

Run with: `node --experimental-strip-types workspace/agent.ts`

## Agent role
- `[explain]` How prompt emulation works: the model doesn't "know" about tools in the API sense — it follows text instructions in the system prompt. When it sees "respond with JSON if you need a tool," it complies. The JSON format is a convention we chose; the model follows it because the SYSTEM prompt tells it to.
- `[review]` Check the Modelfile has complete tool definitions (name, description, parameters, returns) and the RULES block. Check the script imports from `./utils.ts` and prints both the raw response and the parsed tool calls.

## Gotchas
- The model sometimes wraps JSON in markdown backticks (```json ... ```) or adds explanatory text ("Let me check that for you:" before the JSON). `parseToolCalls` in `utils.ts` handles all these cases — you don't need to write a parser.
- `/no_think` in the Modelfile helps reduce noise (some models add `<think>` blocks before the JSON). Add it if you see thinking blocks in the output.
- If the SYSTEM prompt is too long, some models may not follow the format perfectly — keep tool definitions concise.
- Some models tend to always use tools even when they could answer directly. The RULES block helps, but model behavior varies.
- Don't forget to rebuild the model after editing the Modelfile — changes to `workspace/Modelfile` don't take effect until you run `ollama create loopcraft -f workspace/Modelfile` again.

## Success check  (local — node)
1. Rebuild succeeds: `ollama create loopcraft -f workspace/Modelfile`
2. `node --experimental-strip-types workspace/agent.ts` — "What's the weather in Tokyo?" → raw response contains JSON with `tool: "get_weather"` and `args.location: "Tokyo"`. `parseToolCalls` returns a parsed array with one tool call.
3. "What is 2+2?" → raw response is plain text. `parseToolCalls` returns an empty array.

The learner must explain *how the model knows to output JSON* before the step counts as done.

## Consolidate  (free-text questions — AFTER the success check passes)
<!-- The tutor asks these questions; the learner types their understanding in their own words. The tutor scores 1-5 based on whether the answer covers the key concepts, gives feedback, and retries once if score < 3. -->

**Question 1:** What determines whether the model outputs JSON (a tool call) or plain text?
A good answer covers: the question combined with tool descriptions and the RULES block, if the question matches a tool's description the model follows the RULES and outputs JSON, if it can answer from its own knowledge it outputs plain text, it's not random and there's no formal API deciding — it's text instructions in the prompt.

**Question 2:** This is "prompt emulation" — the model emulates tool calling through text instructions. What's the advantage of understanding this?
A good answer covers: it reveals what's really happening — tool calls are structured text the model generates that an orchestrator parses and executes, formal APIs add validation and convenience but the mechanism is the same (text in, text out), understanding the mechanism makes you a better agent builder.