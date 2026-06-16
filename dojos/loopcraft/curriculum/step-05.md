---
step: 5
title: The agent loop
spine: workspace/agent.ts
kind: build
reference: agent.ts
---

# Step 5 — The agent loop

## Frame

This is it. This is the lesson the entire dojo has been building toward.

Steps 2–4 taught you three manual operations: call the model, parse a tool call, execute and inject the result. You did each one by hand, one time, in sequence. That's not an agent — that's a script with three steps.

**The loop is the agent.** Wrap those three steps in `while(true)`, add a break condition, and you've built something fundamentally different: a system that *decides for itself* how many times to go around. The model might need zero tool calls, one, or five — the loop doesn't care. It runs until the model is done. That autonomy is what makes this an agent and not a chatbot.

Every agent — from a simple weather bot to AutoGPT to Claude Code — is this same loop underneath. The tools change. The model changes. The loop doesn't.

## Teach the mechanism  (the loop is NEW — everything inside it you've already done)

- **The loop**: `while (true)` or a `for` loop with a max — call the model, parse the response. If `parseToolCalls` returns tool calls, execute each one, inject the results as a user message, and loop back. If `parseToolCalls` returns empty (the model answered directly), break and print the answer. That's it. That's the entire agent. Every utility function (`chat`, `parseToolCalls`, `executeTool`) is imported from `utils.ts` — you only write the loop.

- **Message accumulation**: each iteration appends to the messages array. The model sees the full conversation every time: user question → assistant tool-call → user tool-result → assistant response (or another tool-call). Without accumulation, the model has amnesia — it wouldn't know what tool it called or what result it got.

- **The max iteration guard**: the loop needs an escape hatch. A confused model can get stuck calling tools forever — it calls one, gets a result, decides it needs another, loops back, calls again. The guard breaks after N iterations (10 is reasonable). This isn't about API limits. It's about logical infinite loops. Without it, a misbehaving model runs forever.

- **Interactive mode**: wrap the whole agent loop in a readline REPL so the user can type questions. Each question starts fresh with an empty messages array. The conversation resets between questions — persistent memory across turns comes later.

**How you'll validate it:** you'll type "What's the weather in Tokyo?" and the agent will: call the model → parse tool call → execute get_weather → inject result → call model again → print a natural-language answer. All automatic. One user prompt. You don't intervene. That's the loop working.

## Spine  (the learner modifies `workspace/agent.ts`)

- Import `chat`, `parseToolCalls`, `executeTool`, and `ChatMessage` from `./utils.ts`.
- Write an `agentLoop` function that takes a user message and a messages array, pushes the user message, then enters the loop.
- Inside the loop: call `chat('loopcraft', messages)` → `parseToolCalls(text)`.
  - If `parseToolCalls` returns empty → push the assistant message, `return` the answer. The loop ends.
  - If `parseToolCalls` returns tool calls → push the assistant message, loop over each tool call and `executeTool(tc.tool, tc.args)`, format results as `[Tool result: ${toolName}]\n${result}`, join them, push as a single user message, and continue the loop.
- Add a `MAX_ITERATIONS = 10` guard. If the loop exceeds it, return an error message.
- Write a `main` function using `node:readline/promises` that prompts the user in a `while(true)`, creates a fresh `messages: ChatMessage[]` for each question, calls `agentLoop`, and prints the response.
- Run with: `node --experimental-strip-types workspace/agent.ts`

## Agent role

- `[explain]` Why the loop is the agent — a single if/else handles one tool call then stops; the loop handles *any number* and the model decides when it's done. Why the guard exists (the model can cycle forever). Why messages accumulate (the model has no memory between calls — the array IS its memory).
- `[review]` Check the loop structure: call → parse → if empty break → execute → inject → loop. Check the guard. Check that tool results are accumulated into one user message. Check that messages grow correctly across iterations.

## Gotchas

- The model can emit multiple tool calls in one response — loop over the `parseToolCalls` array, even though we only have one tool right now. (Step 6 adds a second tool and this preparation pays off.)
- Accumulate *all* tool results into one user message before sending back to the model. Don't send one message per tool call.
- Use `node:readline/promises` for clean async/await — the callback-based `readline` module is harder with async.
- Reset the messages array for each new user question — otherwise the model carries stale context from previous questions and gets confused.
- Run with `node --experimental-strip-types workspace/agent.ts`, not `npx tsx`.

## Success check  (local — `node --experimental-strip-types workspace/agent.ts`)

1. "What's the weather in Tokyo?" → agent calls get_weather → executes → injects → answers in natural language. All automatic, one user prompt.
2. "What is 2+2?" → model answers directly, no tool call, loop exits immediately on the first iteration.
3. A confusing or ambiguous prompt doesn't cause an infinite loop — the guard breaks after 10 iterations.

The learner must explain **why the loop is what makes this an agent and not a chatbot** before the step counts as done.

## Consolidate  (free-text questions — AFTER the success check passes)
<!-- The tutor asks these questions; the learner types their understanding in their own words. The tutor scores 1-5 based on whether the answer covers the key concepts, gives feedback, and keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' answers do NOT count — the tutor re-explains and asks again. -->

**Question 1:** What makes an "agent" different from a "chatbot"?
A good answer covers: a chatbot responds once and stops, an agent loops — it calls a tool, gets a result, decides if it needs more, and goes again; the while-loop is the only structural difference; without it you have a script, with it you have an autonomous system that decides its own path through tool calls; the model's intelligence is the same in both cases — the loop is what gives it agency.

**Question 2:** You remove the `while` and replace it with a single if/else. What can the system no longer do?
A good answer covers: it can only handle zero or one tool call; if the model calls a tool, gets a result, and realizes it needs another tool call — it can't; the if/else runs once and stops; the loop is what enables multi-step reasoning: call → observe → decide → call again.

**Question 3:** Why does the loop need a max iteration guard?
A good answer covers: the model can get stuck in a cycle — calling a tool, getting a result, deciding it needs more, calling again, forever; this is a logical infinite loop, not an API limit; the guard is the difference between a runaway process and a bounded one; 10 is generous for this dojo; in production you might use smaller limits or smarter heuristics.