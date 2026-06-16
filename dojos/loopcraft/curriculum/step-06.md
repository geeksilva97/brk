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

## Teach the mechanism  (tool routing is NEW)
- **Tool routing**: there is no routing code. The model reads the tool descriptions in the SYSTEM prompt and decides which tool (or tools) to call based on the user's question. "Weather" matches get_weather's description; "news" or "latest" matches search_web's description. The model is the router.
- **searchWeb is PROVIDED**: `searchWeb(query)` already lives in `utils.ts`. It searches DuckDuckGo via raw `fetch` (no API key, no npm packages needed), extracts the top 5 results, and returns them as a formatted string. You do NOT write it — you just tell the model it exists by updating the Modelfile.
- **executeTool already dispatches it**: the `executeTool` function in `utils.ts` already handles `search_web` → `searchWeb`. Your loop already iterates over tool calls. The only code change is adding the tool definition to the Modelfile so the model knows search_web is available.
- **Parallel calls**: the model can emit multiple tool calls in one response: `[{"tool": "get_weather", "args": {"location": "Tokyo"}}, {"tool": "get_weather", "args": {"location": "London"}}]`. Your loop already handles this — it iterates over the parsed array.

## Spine  (the learner modifies `workspace/Modelfile` only)
- Update `workspace/Modelfile` SYSTEM to add `[TOOL: search_web]` definition:
  ```
  [TOOL: search_web]
  Description: Search the web for current information, news, or facts
  Parameters: {"query": "string — search query"}
  Returns: list of search results with titles, snippets, and URLs
  ```
- Rebuild: `ollama create loopcraft -f workspace/Modelfile`
- Test routing: "What's the weather in Tokyo?" → calls get_weather. "What happened in tech news today?" → calls search_web. "Compare weather in Tokyo and London" → calls get_weather twice (parallel).

## Agent role
- `[explain]` How the model routes based on descriptions (no if/else), how searchWeb works (DuckDuckGo via raw fetch in utils.ts — no npm packages needed), and how parallel calls work.
- `[review]` Check the Modelfile has both tool definitions. Confirm the learner did NOT write searchWeb — it's provided in utils.ts. Confirm executeTool already dispatches search_web.

## Gotchas
- The model might call search_web when it could answer directly (e.g., "What is 2+2?"). This is a model quality issue, not a code bug. The RULES block in the SYSTEM prompt helps, but doesn't guarantee perfect routing.
- Some queries trigger both tools (e.g., "What's the weather in Tokyo and what's happening there recently?"). The model should emit two tool calls in one response. Your loop already handles this.
- If the model isn't routing correctly, the fix is almost always in the tool descriptions — make them specific enough that the model can distinguish when to use each one.

## Success check  (local — node)
1. Rebuild succeeds: `ollama create loopcraft -f workspace/Modelfile`
2. "What's the weather in Tokyo?" → calls get_weather (not search_web)
3. "What happened in tech news today?" → calls search_web
4. "Compare weather in Tokyo and London" → calls get_weather twice (parallel)
5. The agent correctly routes each question to the right tool based on intent

The learner must explain *how the model decides which tool to call* before the step counts as done.

## Consolidate  (free-text questions — AFTER the success check passes)
<!-- The tutor asks these questions; the learner types their understanding in their own words. The tutor scores 1-5 based on whether the answer covers the key concepts, gives feedback, and keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' answers do NOT count — the tutor re-explains and asks again. -->

**Question 1:** How does the model decide between get_weather and search_web?
A good answer covers: it matches the user's intent against the tool descriptions in the SYSTEM prompt; it's semantic matching, not keyword filtering or trying both tools; there is no hardcoded if/else routing.

**Question 2:** Why does parallel tool calling (two weather calls for two cities) matter for the agent loop?
A good answer covers: latency reduction — two round-trips become one; the result is the same but the wait doubles without parallel calls.

**Question 3:** If you added a third tool (e.g., a calculator), what would you need to change?
A good answer covers: just add the tool definition to the Modelfile's SYSTEM prompt and ensure executeTool dispatches it; no routing logic to update — the model handles it based on descriptions.