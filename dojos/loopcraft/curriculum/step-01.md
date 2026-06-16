---
step: 1
title: Ollama + Modelfile
spine: workspace/agent.ts
kind: build
reference: agent.ts
---

# Step 1 — Ollama + Modelfile

## Frame
Every AI agent starts with one thing: sending text to a model and getting text back. Before tools, before loops, before any intelligence — there's a raw call. You'll set up Ollama, create a Modelfile that bakes a system prompt into a custom model, and make your first chat call from TypeScript. The model answers in plain English. That's the floor — everything else builds on top.

## Teach the mechanism  (Modelfile + chat API are NEW — explain before they build)
- **Modelfile**: a recipe for creating a custom model on top of a base model. `FROM` specifies the base, `SYSTEM` sets the system prompt. Running `ollama create` bakes that prompt into the model so it's always there — no need to send it with every request.
- **Ollama chat API**: the `chat()` function (provided in `workspace/utils.ts`) sends a POST to `http://localhost:11434/api/chat` with a JSON body containing `model`, `messages`, and `stream: false`. Each message has a `role` (`user`, `assistant`, `system`) and `content`. The model has no memory between calls — you must send the full conversation history every time. The response is JSON with `message.content` holding the reply.
- **The model**: any model you have pulled locally. `ollama pull llama3:8b` gets you a good one, but `llama3`, `gemma3`, `mistral` — whatever you have works. The dojo doesn't depend on a specific model.
- **Provided utilities**: `workspace/utils.ts` is already in place — it contains `chat`, `parseToolCalls`, `executeTool`, and other helpers you'll use across the dojo. You don't write it; you import from it. This step only uses `chat()`.

**How you'll validate it:** once the Modelfile is created and the model built, you'll run your script, send "Hello", and see a plain text response. Then you'll ask it a question that needs real-time data ("What's the weather in Tokyo?") and watch it *try to answer from memory* — which is wrong. That wrong answer is the motivation for Step 2.

**Read first:** `docs/ollama-api.md`, `docs/modelfile.md`.

## Spine  (the learner types `workspace/agent.ts`, ~5 lines)
Type it by hand — this whole spine is the lesson:
- Create `workspace/Modelfile`:
  ```
  FROM llama3:8b
  SYSTEM You are a helpful assistant. Respond concisely.
  ```
  (Replace `llama3:8b` with whatever model you have pulled. If you don't have one, run `ollama pull llama3:8b`.)
- Run `ollama create loopcraft -f workspace/Modelfile`
- Write `workspace/agent.ts`:
  ```ts
  import { chat } from './utils.ts';

  const response = await chat('loopcraft', [
    { role: 'user', content: 'Hello' },
  ]);
  console.log(response);
  ```
  That's it — import `chat` from the provided `utils.ts`, call it, print the result.
- Run with `node --experimental-strip-types workspace/agent.ts` (Node 23.6+: just `node workspace/agent.ts`)

No `npm install`, no `package.json`, no build step — Node 22+ runs TypeScript natively.

## Agent role
- `[explain]` From `docs/ollama-api.md`: how the chat API works, what messages look like, why the conversation must be sent in full each time. Also explain that `chat()` in `utils.ts` wraps the raw `fetch` call so the learner doesn't have to think about the HTTP layer — but the mechanism is the same.
- `[review]` Check that the Modelfile has FROM and SYSTEM, that `ollama create` was run, and that the script imports `chat` from `./utils.ts` and calls it with the correct model name.

## Gotchas
- Forgetting to run `ollama create` after editing the Modelfile — the model won't pick up changes until you rebuild.
- Using the base model name (`llama3:8b`) instead of the custom name (`loopcraft`) — the system prompt won't be active.
- `/no_think` — some models (like Qwen3) have a thinking mode. If the model outputs `<think>...</think>` blocks, add `/no_think` to the Modelfile to suppress them. This is model-specific and optional.
- Not using `await` with `chat()` — it's async, needs `await`.
- Don't try to write `utils.ts` yourself — it's provided by the dojo setup. If it's missing, re-run setup.

## Success check  (local — node)
1. `ollama create loopcraft -f workspace/Modelfile` → prints `success`.
2. `node --experimental-strip-types workspace/agent.ts` → prints a plain text response.
3. Change the message to "What's the weather in Tokyo?" → the model answers from its training data (which is wrong/outdated). That wrong answer is expected — it's the motivation for adding tools.

The learner must explain *why* the model can't give real-time weather before the step counts as done.

## Consolidate  (free-text questions — AFTER the success check passes)
<!-- The tutor asks these questions; the learner types their understanding in their own words. The tutor scores 1-5 based on whether the answer covers the key concepts, gives feedback, and retries once if score < 3. -->

**Question 1:** Why can't the model tell you the current weather?
A good answer covers: frozen training data vs. real-time access, the model generates text from patterns not live data, this is why tools exist.

**Question 2:** What does `chat()` in `utils.ts` actually do under the hood?
A good answer covers: it wraps a fetch POST to Ollama's /api/chat endpoint, the full conversation is sent each time, it's a convenience wrapper over raw HTTP.

**Question 3:** What would the model need to give real-time weather?
A good answer covers: a way to call an external tool and inject the result back, the model can't fetch data itself but can request data if we teach it how, bigger models don't solve this.