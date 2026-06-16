---
step: 3
title: Parse + execute weather
spine: workspace/agent.ts
kind: build
reference: agent.ts
---

# Step 3 — Parse + execute weather

## Frame
The model asked for the weather — now you have to actually get it. You'll build two things: a parser that extracts JSON from the model's messy output (backticks, explanatory text, single objects vs arrays), and a weather function that calls Open-Meteo (free, no API key). This is where the agent stops being a chatbot and starts being... an agent. It can *act* on the world.

## Teach the mechanism  (parsing + API calls are NEW)
- **parseToolCalls(text)**: the model's output isn't always clean JSON. It might wrap it in markdown, add text before/after, or return a single object instead of an array. Your parser must:
  1. Try `JSON.parse` directly (clean output).
  2. If that fails, look for content inside ```json ... ``` blocks.
  3. If that fails, scan for the first `[` or `{` and extract to the matching bracket.
  4. Return an array of tool calls (even if there's only one).
- **getWeather(location)**: calls Open-Meteo's free endpoint. The tricky part is the model says "Tokyo" but Open-Meteo needs latitude/longitude. You'll use a simple lookup table (provided in the cheatsheet) for ~10 major cities.
- **The dispatch pattern**: a `switch` or `if/else` that routes tool names to functions. `get_weather` → call `getWeather`, `calculate` → call a simple eval. This is the beginning of a tool registry.

**Read first:** `docs/open-meteo-cheatsheet.md` — the exact endpoint URL, parameters, and response format. You don't need to research the API — it's all there.

## Spine  (the learner modifies `workspace/agent.ts`)
- Add `parseToolCalls(text: string)`: try direct JSON parse → extract from backticks → bracket scan. Return `ToolCall[]` array or empty array if no tool calls found.
- Add `COORDINATES: Record<string, [number, number]>`: a lookup table for ~10 cities (Tokyo, New York, London, Paris, São Paulo, Sydney, Mumbai, Cairo, Berlin, Moscow).
- Add `getWeather(location: string)`: look up coordinates, `fetch` Open-Meteo, extract `current_weather`, return `{ temperature, windspeed, weathercode }`.
- Add `executeTool(name: string, args: Record<string, string>)`: dispatch on tool name.
- Wire in `agent.ts`: after getting the model response, parse it. If tool calls found, execute each and print results. If no tool calls, print the text answer.

## Agent role
- `[explain]` Why parsing is necessary (models are messy), why a lookup table (Open-Meteo needs lat/lon), and how the dispatch pattern works.
- `[review]` Check that `parseToolCalls` handles backtick-wrapped JSON, single objects, and plain arrays. Check that `getWeather` uses the correct Open-Meteo endpoint. Check the dispatch routes correctly.

## Gotchas
- Open-Meteo requires latitude and longitude, not city names. The lookup table is a GIVEN scaffold — don't waste time on geocoding APIs.
- `fetch` is available in Node 18+ — no need for `node-fetch`.
- The model might output `{"tool": "get_weather", "args": {"location": "Tokyo"}}` (single object) or `[{"tool": ...}]` (array). `parseToolCalls` must handle both.
- Open-Meteo `weathercode` is a number (0=clear, 1-3=partly cloudy, 45/48=fog, 51-55=drizzle, 61-65=rain, 71-75=snow, 80-82=showers, 95=thunderstorm). Include a small mapping or just return the raw code.

## Success check  (local — node)
1. `parseToolCalls('Here you go: [{"tool": "get_weather", "args": {"location": "Tokyo"}}]')` returns a parsed array with one tool call.
2. `parseToolCalls('```json\n{"tool": "get_weather", "args": {"location": "Paris"}}\n```')` returns a parsed array with one tool call (object, not array).
3. `getWeather("Tokyo")` returns a JSON object with `temperature`, `windspeed`, and `weathercode`.
4. Running `node workspace/agent.ts` with "What's the weather in Tokyo?" prints the Open-Meteo data.

The learner must explain *why the parser needs to handle messy output* before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)
<!-- The tutor composes each quiz at runtime based on what the learner built, where they struggled,
     and what they observed. The angles below guide the tutor — they are NOT verbatim questions. -->

**Quiz topic 1 — Diagnose:**
Why can't you just `JSON.parse` the model's response? (Angle: the model wraps JSON in markdown backticks, adds explanatory text, or outputs a single object instead of an array. A robust parser handles all these cases — it's not about performance or YAML, it's about robustness against messy LLM output.)

**Quiz topic 2 — Reflect:**
Your COORDINATES table has 10 cities. What happens when the model asks for a city not in the table? (Angle: the function should return a clear error. The agent loop injects this as a tool result and the model responds honestly. A crash means missing error handling — graceful degradation is part of building a robust agent.)