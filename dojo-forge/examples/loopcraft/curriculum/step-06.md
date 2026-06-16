---
step: 6
title: Web search tool
spine: workspace/agent.ts
kind: build
reference: agent.ts
---

# Step 6 — Web search tool

## Frame
One tool is a demo. Two tools is a decision. When you ask "What's the weather in Tokyo?" the model calls get_weather. When you ask "What happened in tech news today?" it calls search_web. When you ask "What's the weather in Tokyo and what's happening there?" it might call both. The model decides based on the tool descriptions in the SYSTEM prompt — no hard-coded routing. This is where the agent starts to feel intelligent.

## Teach the mechanism  (DuckDuckGo + tool routing are NEW)
- **DuckDuckGo search**: the simplest way to search the web from code. No API key needed, no npm package needed. You'll use raw `fetch` to the html endpoint (the cheatsheet shows the exact URL and query format). Parse the results using regex — no external dependencies.
- **Tool routing**: there is no routing code. The model reads the tool descriptions in the SYSTEM prompt and decides which tool (or tools) to call based on the user's question. "Weather" matches get_weather's description; "news" or "latest" matches search_web's description. The model is the router.
- **Parallel calls**: the model can emit multiple tool calls in one response: `[{"tool": "get_weather", "args": {"location": "Tokyo"}}, {"tool": "get_weather", "args": {"location": "London"}}]`. Your loop already handles this — it iterates over the parsed array.

**Read first:** `docs/duckduckgo-cheatsheet.md` — the DuckDuckGo endpoint, query format, and how to extract results.

## Spine  (the learner modifies `workspace/agent.ts` and `workspace/Modelfile`)
- Update `workspace/Modelfile` SYSTEM to add `[TOOL: search_web]` definition:
  ```
  [TOOL: search_web]
  Description: Search the web for current information, news, or facts
  Parameters: {"query": "string — search query"}
  Returns: list of search results with titles, snippets, and URLs
  ```
- Rebuild: `ollama create loopcraft -f workspace/Modelfile`
- Use raw `fetch` to call DuckDuckGo's HTML endpoint — no npm packages needed. The cheatsheet shows the endpoint and how to parse it.
- Add `searchWeb(query: string)`: call DuckDuckGo, extract top 5 results (title, snippet, URL), return as formatted string.
- Extend `executeTool` to handle `search_web` → call `searchWeb`.
- Test routing: "What's the weather in Tokyo?" calls get_weather. "What happened in tech news today?" calls search_web. "Compare weather in Tokyo and London" calls get_weather twice (parallel).

## Agent role
- `[explain]` How DuckDuckGo search works (no API key, raw `fetch` to the HTML endpoint — no npm packages needed), how the model routes based on descriptions (no if/else), and how parallel calls work.
- `[review]` Check the Modelfile has both tool definitions. Check `searchWeb` handles errors (network timeout, no results). Check the dispatch handles `search_web`.

## Gotchas
- DuckDuckGo html scraping can be flaky — add error handling and a timeout (5 seconds is reasonable).
- The model might call search_web when it could answer directly (e.g., "What is 2+2?"). This is a model quality issue, not a code bug. The RULES block in the SYSTEM prompt helps, but doesn't guarantee perfect routing.
- Some queries trigger both tools (e.g., "What's the weather in Tokyo and what's happening there recently?"). The model should emit two tool calls in one response. Your loop already handles this.
- Search results can be noisy — return only the top 5 and format them clearly so the model can synthesize an answer.

## Success check  (local — node)
1. Rebuild succeeds: `ollama create loopcraft -f workspace/Modelfile`
2. "What's the weather in Tokyo?" → calls get_weather (not search_web)
3. "What happened in tech news today?" → calls search_web
4. "Compare weather in Tokyo and London" → calls get_weather twice (parallel)
5. The agent correctly routes each question to the right tool based on intent

The learner must explain *how the model decides which tool to call* before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)
<!-- The tutor composes each quiz at runtime based on what the learner built, where they struggled,
     and what they observed. The angles below guide the tutor — they are NOT verbatim questions. -->

**Quiz topic 1 — Diagnose:**
How does the model decide between get_weather and search_web? (Angle: it matches the user's intent against the tool descriptions in the SYSTEM prompt — semantic matching, not keyword filtering or trying both tools. No hardcoded if/else routing.)

**Quiz topic 2 — Reflect:**
Why does parallel tool calling (two weather calls for two cities) matter for the agent loop? (Angle: latency reduction — two round-trips become one. The result is the same but the wait doubles without parallel calls.)