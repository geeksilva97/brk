---
step: 3
title: Wire tools into the loop
spine: workspace/agent.ts
kind: build
reference: agent.ts
---

# Step 3 — Wire tools into the loop

## Frame
The model asked for the weather — now you need to act on it. In Step 2 the model learned to *request* tools by outputting JSON. Now you write the code that *reads* that JSON and *does* something with it. This is where the agent stops being a chatbot and becomes an agent: it can *act* on the world. The parsing, weather, and execution functions are all provided in `utils.ts` — your job is to wire them into the loop.

## Teach the mechanism  (the dispatch pattern is NEW — the functions are PROVIDED)
- **parseToolCalls(text)**: extracts structured tool calls from the model's messy output. It handles backtick-wrapped JSON, explanatory text before/after, and single objects vs arrays. You don't write this — it's in `utils.ts`. You import it and call it on the model's response.
- **executeTool(name, args)**: dispatches a tool name to its implementation. `get_weather` → calls `getWeather`, `calculate` → evaluates simple math. You don't write this either — it's in `utils.ts`. You call it with the parsed tool call's `tool` and `args`.
- **COORDINATES & getWeather**: the coordinate lookup and Open-Meteo fetch are provided in `utils.ts`. Open-Meteo needs lat/lon, and the lookup table maps ~10 major city names to coordinates. You don't write these.
- **The wiring**: this is what you write. After getting the model's response, call `parseToolCalls` on it. If there are tool calls, call `executeTool` for each one and print the result. If there are no tool calls, print the text answer. This is the first emergence of **the loop pattern**: call model → parse response → if tool call, execute → print.

**Read first:** `docs/open-meteo-cheatsheet.md` — the exact endpoint URL, parameters, and response format. Understanding what `getWeather` does under the hood helps you reason about the loop.

## Spine  (the learner modifies `workspace/agent.ts`)
- Import from `utils.ts`: `chat`, `parseToolCalls`, `executeTool`, and `ChatMessage`.
- After calling `chat()` and getting the model's response text:
  1. Call `parseToolCalls(text)` — it returns a `ToolCall[]` array (empty array if no tool calls).
  2. If the array is empty, print the text answer — the model answered directly.
  3. If the array has tool calls, loop over them and call `executeTool(tc.tool, tc.args)` for each one.
  4. Print each tool result.
- Run with: `node --experimental-strip-types workspace/agent.ts`

## Agent role
- `[explain]` Why parsing is necessary (models output messy JSON — backticks, explanatory text, single objects vs arrays), why `executeTool` dispatches by name (it's a tool registry — the beginning of extensibility), and how the wiring connects model output to real action.
- `[review]` Check that `parseToolCalls` is called on the model's response text (not the raw API response object). Check that `executeTool` is called with `tc.tool` and `tc.args` from the parsed tool call. Check the import statement matches what's in `utils.ts`.

## Gotchas
- The model's response is `data.message.content` from the Ollama API — a string. `parseToolCalls` takes that string, not the full API response object.
- `executeTool` is async — it returns a Promise. Use `await`.
- The model might output multiple tool calls in one response. Loop over the array — don't assume there's only one.
- Open-Meteo `weathercode` is a number (0=clear, 1-3=partly cloudy, 45/48=fog, 51-55=drizzle, 61-65=rain, 71-75=snow, 80-82=showers, 95=thunderstorm). The `executeTool` function formats this for you.
- This step doesn't yet loop back to the model with the tool result — that's Step 4. For now, you just execute and print.

## Success check  (local — node)
1. Import `{ chat, parseToolCalls, executeTool, ChatMessage }` from `'./utils.ts'` — no errors.
2. Ask "What's the weather in Tokyo?" → the model responds with a JSON tool call → `parseToolCalls` extracts it → `executeTool` runs `getWeather("Tokyo")` → prints temperature, windspeed, weathercode.
3. Ask "What is 2+2?" → the model responds with plain text → `parseToolCalls` returns empty array → prints the text answer directly.
4. Running `node --experimental-strip-types workspace/agent.ts` with "What's the weather in Tokyo?" prints real Open-Meteo data.

The learner must explain *why the parser needs to handle messy output* and *how the wiring connects model output to tool execution* before the step counts as done.

## Consolidate  (free-text questions — AFTER the success check passes)
<!-- The tutor asks these questions; the learner types their understanding in their own words. The tutor scores 1-5 based on whether the answer covers the key concepts, gives feedback, and keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' answers do NOT count — the tutor re-explains and asks again. -->

**Question 1:** Why can't you just `JSON.parse` the model's response?
A good answer covers: the model wraps JSON in markdown backticks, adds explanatory text, or outputs a single object instead of an array; a robust parser handles all these cases; it's about robustness against messy LLM output; the provided `parseToolCalls` handles this so you don't have to.

**Question 2:** What happens when the model asks for a city not in the COORDINATES table?
A good answer covers: `getWeather` returns a clear error message, the agent loop injects this as a tool result and the model responds honestly, a crash would mean missing error handling, graceful degradation is part of building a robust agent, you don't need to add every city — the error propagates naturally through the loop.

**Question 3:** How does this step's wiring relate to the full agent loop you'll build later?
A good answer covers: this is the first half of the loop — call model → parse → execute; the missing piece is sending the result back to the model for a natural-language answer (Step 4); the full loop pattern is call → parse → if tool call, execute → inject result → call again; you just built the first three steps.