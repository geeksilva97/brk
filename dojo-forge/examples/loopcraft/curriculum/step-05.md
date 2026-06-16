---
step: 5
title: The agent loop
spine: workspace/agent.ts
kind: build
reference: agent.ts
---

# Step 5 — The agent loop

## Frame
Steps 2–4 are manual: you call the model, parse the tool call, execute it, inject the result, call again. A real agent does this automatically. The agent loop is a `while` that repeats until the model responds with plain text (no tool call). This is the birth of the agent — three manual steps become one loop. From now on, you type a question and the agent handles everything: deciding which tool, executing it, getting the result, and answering in natural language.

## Teach the mechanism  (the loop + conversation accumulation are NEW)
- **The loop**: `while (true)` — call the model, check the response. If it's a tool call, execute it, inject the result, and loop. If it's plain text, break and print the answer. That's the entire agent loop.
- **Message accumulation**: each iteration adds to the messages array. The model sees the full conversation: user question → assistant tool-call → user tool-result → assistant response (or another tool-call). This is how the model maintains context across multiple tool calls.
- **The max iteration guard**: a safety net. If the model gets stuck in a cycle (calling tools forever), the guard breaks the loop after N turns. 10 is reasonable for this dojo. In production, you'd add more sophisticated stopping conditions, but this prevents infinite loops.
- **Interactive mode**: add a readline loop so the user can type questions. Each question starts a new agent loop. The conversation resets between questions (for now — conversation memory across questions is a later enhancement).

**How you'll validate it:** you'll type "What's the weather in Tokyo?" and the agent will: call the model → parse tool call → execute get_weather → inject result → call model again → print natural-language answer. All automatic, one user prompt.

## Spine  (the learner modifies `workspace/agent.ts`)
- Wrap the call → parse → execute → inject cycle in a `while (true)` loop.
- If `parseToolCalls` returns empty (model answered directly), break and print the answer.
- If it returns tool calls, execute each one, format results, inject as user message, and continue the loop.
- Add a `maxIterations` guard (10): if the loop runs more than 10 times, break with an error.
- Add interactive readline: `import * as readline from 'node:readline'`, prompt for input, run the agent loop, print the answer, repeat. Use `process.stdin`/`process.stdout`.

## Agent role
- `[explain]` Why `while(true)` with a break condition (not a condition in the while), why accumulate messages, why the guard.
- `[review]` Check the loop structure: call → parse → if empty break → execute → inject → loop. Check the guard is in place. Check messages accumulate correctly.

## Gotchas
- The model can emit multiple tool calls in one response — handle that with a for-loop over the parsed array, even though we only have one tool right now. (This prepares for Step 6 where we add a second tool.)
- Don't forget to accumulate all tool results into one user message before sending back to the model.
- Interactive readline can be tricky with async — use the callback-based `readline.createInterface` or `readline/promises` for cleaner async code.
- Reset the messages array for each new user question — otherwise the model carries context from previous questions (which can confuse it).

## Success check  (local — node)
1. "What's the weather in Tokyo?" → agent calls get_weather → executes → injects → answers in natural language. All automatic, one user prompt.
2. "What is 2+2?" → model answers directly, no tool call, loop exits immediately.
3. A confusing or ambiguous prompt doesn't cause an infinite loop (the guard breaks after 10 iterations).

The learner must explain *why the loop needs a guard* before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)
<!-- The tutor composes each quiz at runtime based on what the learner built, where they struggled,
     and what they observed. The angles below guide the tutor — they are NOT verbatim questions. -->

**Quiz topic 1 — Diagnose:**
Why does the loop need a max iteration guard? (Angle: the model can get stuck in a cycle — calling a tool, getting a result, deciding it needs another, etc. Without a guard, a confused model loops forever. It's not about API rate limits or context windows — it's about logical infinite loops.)

**Quiz topic 2 — Reflect:**
What's the key difference between this loop and the if/else from Steps 3–4? (Angle: a single if/else handles one tool call then stops. The loop handles *any number* of tool calls in sequence — the model can call a tool, get a result, realize it needs more information, call another. The loop is what makes it an agent instead of a script.)