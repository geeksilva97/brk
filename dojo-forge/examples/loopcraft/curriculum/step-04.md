---
step: 4
title: Inject + re-prompt
spine: workspace/agent.ts
kind: build
reference: agent.ts
---

# Step 4 — Inject + re-prompt

## Frame
You have the weather data. Now what? You send it back to the model so it can turn raw JSON into a natural-language answer. This is the "inject" step — the tool result goes into the conversation, and the model gets a second chance. "It's 22°C and partly cloudy in Tokyo" is something only the model can produce from raw data. This is the key insight: the model is the *language* layer, and the tools are the *data* layer.

## Teach the mechanism  (conversation history + context injection are NEW)
- **Conversation history**: every call to the chat API must include the full conversation — system message, user question, assistant tool-call response, and now the tool result. The model has no memory between calls. You maintain the messages array.
- **The tool result message**: format the result as a user message: `[Tool result: get_weather]\n{"temperature": 22, "windspeed": 15, "weathercode": 2}`. This goes into the messages array after the assistant's tool-call response.
- **Why keep the assistant's tool-call response**: if you don't include it, the model sees a user question, then a random piece of weather data with no context. "Why is the user sending me weather data?" The tool-call message provides the bridge between question and data.

**How you'll validate it:** you'll ask "What's the weather in Tokyo?" and the agent will: (1) get the model's tool call, (2) execute get_weather, (3) inject the result, (4) send the full history back, (5) receive a natural-language answer like "It's currently 22°C with light wind in Tokyo."

## Spine  (the learner modifies `workspace/agent.ts`)
- After executing the tool, format the result as: `[Tool result: ${toolName}]\n${JSON.stringify(result)}`
- Append it to the messages array as a `user` message (in prompt emulation, there's no `tool_result` role — it's a user message).
- Call the chat API again with the full conversation: `[{role: 'user', content: question}, {role: 'assistant', content: toolCallJSON}, {role: 'user', content: toolResult}]`.
- Print the model's final answer.

## Agent role
- `[explain]` Why the conversation must include all messages (model has no memory), why the tool result is a user message (no formal tool_result role in prompt emulation), and why the assistant's tool-call must be in the history (context for the result).
- `[review]` Check that the messages array has all four entries: user question, assistant tool-call, user tool-result, assistant final answer. Check the tool result format.

## Gotchas
- Don't forget to include the assistant's tool-call response in the messages array — without it, the tool result appears out of context and the model is confused.
- The tool result must be a `user` message, not `assistant`. In prompt emulation, the model reads it as user input about the tool execution.
- Don't create a new messages array — append to the existing one. Each turn adds messages; the full history goes to the model.

## Success check  (local — node)
1. Ask "What's the weather in Tokyo?" → the agent prints a natural-language answer like "It's currently 22°C with light wind in Tokyo."
2. The messages array (log it) has 4 entries: user question, assistant tool-call JSON, user tool-result, assistant final answer.
3. The final answer references real data from Open-Meteo (not a hallucinated temperature).

The learner must explain *why the assistant's tool-call message must be in the history* before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)
<!-- The tutor composes each quiz at runtime based on what the learner built, where they struggled,
     and what they observed. The angles below guide the tutor — they are NOT verbatim questions. -->

**Quiz topic 1 — Diagnose:**
Why do we send the tool result as a user message instead of a special "tool" message type? (Angle: in prompt emulation there's no formal tool_result type — the conversation is just user/assistant turns. We format it as a user message so the model reads it naturally. It's not about priority or the model being unable to read assistant messages.)

**Quiz topic 2 — Reflect:**
What would happen if you sent the tool result but didn't include the assistant's original tool-call message in the history? (Angle: the model would see a user question then a random piece of JSON with no context for why — it would be confused. The tool-call message is essential context, not optional.)