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
- **Ollama chat API**: `fetch` sends a POST to `http://localhost:11434/api/chat` with a JSON body containing `model`, `messages`, and `stream: false`. Each message has a `role` (`user`, `assistant`, `system`) and `content`. The model has no memory between calls — you must send the full conversation history every time. The response is JSON with `message.content` holding the reply.
- **The model**: any model you have pulled locally. `ollama pull qwen3:8b` gets you a good one, but `llama3`, `gemma3`, `mistral` — whatever you have works. The dojo doesn't depend on a specific model.

**How you'll validate it:** once the Modelfile is created and the model built, you'll run your script, send "Hello", and see a plain text response. Then you'll ask it a question that needs real-time data ("What's the weather in Tokyo?") and watch it *try to answer from memory* — which is wrong. That wrong answer is the motivation for Step 2.

**Read first:** `docs/ollama-api.md`, `docs/modelfile.md`.

## Spine  (the learner types `workspace/agent.ts`, ~15 lines)
Type it by hand — this whole spine is the lesson:
- Create `workspace/Modelfile`:
  ```
  FROM qwen3:8b
  SYSTEM You are a helpful assistant. Respond concisely.
  ```
  (Replace `qwen3:8b` with whatever model you have pulled. If you don't have one, run `ollama pull qwen3:8b`.)
- Run `ollama create loopcraft -f workspace/Modelfile`
- Write `workspace/agent.ts`: use `fetch` to POST to `http://localhost:11434/api/chat` with `{ model: 'loopcraft', messages: [{ role: 'user', content: 'Hello' }], stream: false }`, parse the JSON response, print `data.message.content`.
- Run with `node workspace/agent.ts`

## Agent role
- `[explain]` From `docs/ollama-api.md`: how the chat API works, what messages look like, why the conversation must be sent in full each time.
- `[review]` Check that the Modelfile has FROM and SYSTEM, that `ollama create` was run, and that the script calls `chat()` with the correct model name.

## Gotchas
- Forgetting to run `ollama create` after editing the Modelfile — the model won't pick up changes until you rebuild.
- Using the base model name (`qwen3:8b`) instead of the custom name (`loopcraft`) — the system prompt won't be active.
- Not awaiting the `fetch()` promise — it's async, needs `await`.
- `/no_think` — some models (like Qwen3) have a thinking mode. If the model outputs `<think>...</think>` blocks, add `/no_think` to the Modelfile to suppress them. This is model-specific and optional.

## Success check  (local — node)
1. `ollama create loopcraft -f workspace/Modelfile` → prints `success`.
2. `node workspace/agent.ts` → prints a plain text response.
3. Ask "What's the weather in Tokyo?" → the model answers from its training data (which is wrong/outdated). That wrong answer is expected — it's the motivation for adding tools.

The learner must explain *why* the model can't give real-time weather before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)
<!-- The tutor composes each quiz at runtime based on what the learner built, where they struggled,
     and what they observed. The angles below guide the tutor — they are NOT verbatim questions. -->

**Quiz topic 1 — Diagnose:**
Why can't the model tell you the current weather? (Angle: frozen knowledge vs. real-time access — the model generates text from patterns, not live data. This is why tools exist.)

**Quiz topic 2 — Reflect:**
What would the model need to give real-time weather? (Angle: a way to call an external tool and inject the result back — the model can't fetch data itself but it can *ask for* data if we teach it how. Bigger models don't solve this.)