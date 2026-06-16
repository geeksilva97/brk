---
step: 4
title: Inject + re-prompt
spine: workspace/agent.ts
kind: build
reference: agent.ts
---

# Step 4 — Inject + re-prompt

## Frame
You have the weather data. Now what? You send it back to the model so it can turn raw JSON into a natural-language answer. This is the "inject" step — the tool result goes into the conversation, and the model gets a second chance. "It's 22°C and partly cloudy in Tokyo" is something only the model can produce from raw data. This is the key insight: the model is the *language* layer, and the tools are the *data* layer. Without injection, you just have data. With injection, you have understanding.

## Teach the mechanism  (conversation history + context injection are NEW)
- **Conversation history**: every call to `chat()` must include the full conversation — the user question, the assistant's tool-call response, and now the tool result. The model has no memory between calls. You maintain the messages array. Each call is a fresh start — the only context the model gets is what you send in the messages.
- **The tool result message**: format the result as a user message: `[Tool result: get_weather]\n{"temperature": 22, "windspeed": 15, "weathercode": 2}`. This goes into the messages array as a `user` role message after the assistant's tool-call response. In prompt emulation there's no formal `tool_result` role — it's a user message so the model reads it naturally.
- **Why keep the assistant's tool-call message**: if you don't include it, the model sees a user question, then a random piece of weather JSON with no context. "Why is the user sending me weather data?" The tool-call message provides the bridge — it tells the model *why* the data is there and *what question it answers.
- **The second `chat()` call**: after injecting the tool result, call `chat()` again with the full messages array. The model sees the whole conversation and produces a natural-language answer.

**How you'll validate it:** you'll ask "What's the weather in Tokyo?" and the agent will: (1) get the model's tool call, (2) execute `get_weather`, (3) inject the result as a user message, (4) send the full history back to `chat()`, (5) receive a natural-language answer like "It's currently 22°C with light wind in Tokyo."

## Spine  (the learner modifies `workspace/agent.ts`)
- Import `{ chat, parseToolCalls, executeTool, ChatMessage }` from `'./utils.ts'` — these are all provided.
- After executing the tool with `executeTool`, format the result as: `[Tool result: ${toolName}]\n${result}`
- Append it to the messages array as a `user` message: `messages.push({ role: 'user', content: toolResult })`
- Call `chat()` again with the full conversation history: `const finalAnswer = await chat('loopcraft', messages)`
- Print the model's final answer.

Example `agent.ts` for this step:
```typescript
import { chat, parseToolCalls, executeTool, ChatMessage } from './utils.ts';

async function main() {
  const messages: ChatMessage[] = [
    { role: 'user', content: "What's the weather in Tokyo?" }
  ];

  // Step 1: Get the model's first response (tool call)
  const firstResponse = await chat('loopcraft', messages);
  messages.push({ role: 'assistant', content: firstResponse });

  // Step 2: Parse and execute
  const toolCalls = parseToolCalls(firstResponse);
  for (const tc of toolCalls) {
    const result = await executeTool(tc.tool, tc.args);
    const toolResult = `[Tool result: ${tc.tool}]\n${result}`;
    messages.push({ role: 'user', content: toolResult });
  }

  // Step 3: Send the full history back to the model
  const finalAnswer = await chat('loopcraft', messages);
  console.log(finalAnswer);

  // Debug: log the full conversation
  console.log('\n--- Conversation history ---');
  for (const msg of messages) {
    console.log(`[${msg.role}]: ${msg.content.substring(0, 100)}...`);
  }
  console.log(`[assistant]: ${finalAnswer.substring(0, 100)}...`);
}

main().catch(console.error);
```

Run with: `node --experimental-strip-types workspace/agent.ts`

## Agent role
- `[explain]` Why the conversation must include all messages (the model has no memory between calls — each `chat()` is stateless), why the tool result is a user message (in prompt emulation there's no formal `tool_result` role — the conversation is just user/assistant turns), and why the assistant's tool-call must be in the history (it provides context for the tool result — without it, the model sees random JSON with no explanation).
- `[review]` Check that the messages array has all four entries: user question, assistant tool-call, user tool-result, assistant final answer. Check the tool result format includes the tool name prefix. Check that `chat()` is called a second time with the full accumulated history.

## Gotchas
- Don't forget to include the assistant's tool-call response in the messages array — without it, the tool result appears out of context and the model is confused.
- The tool result must be a `user` message, not `assistant`. In prompt emulation, the model reads it as user input about the tool execution.
- Don't create a new messages array — append to the existing one. Each turn adds messages; the full history goes to the model.
- The `chat()` function is stateless — it doesn't remember the previous call. Every message must be in the array you pass.
- If there are multiple tool calls, inject all results before calling `chat()` again — don't call the model between each tool result.

## Success check  (local — node)
1. Ask "What's the weather in Tokyo?" → the agent prints a natural-language answer like "It's currently 22°C with light wind in Tokyo."
2. The messages array (log it) has 4 entries: user question, assistant tool-call JSON, user tool-result, assistant final answer.
3. The final answer references real data from Open-Meteo (not a hallucinated temperature).
4. Running `node --experimental-strip-types workspace/agent.ts` produces a coherent natural-language answer in one execution.

The learner must explain *why the assistant's tool-call message must be in the history* before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)
<!-- The tutor composes each quiz at runtime based on what the learner built, where they struggled,
     and what they observed. The angles below guide the tutor — they are NOT verbatim questions. -->

**Quiz topic 1 — Diagnose:**
Why do we send the tool result as a user message instead of a special "tool" message type? (Angle: in prompt emulation there's no formal tool_result type — the conversation is just user/assistant turns. We format it as a user message so the model reads it naturally. It's not about priority or the model being unable to read assistant messages.)

**Quiz topic 2 — Reflect:**
What would happen if you sent the tool result but didn't include the assistant's original tool-call message in the history? (Angle: the model would see a user question then a random piece of JSON with no context for why — it would be confused. The tool-call message is essential context, not optional. The model needs to see its own request to understand what the result is answering.)

**Quiz topic 3 — Connect:**
Steps 2–4 form a manual sequence: define tools → parse and execute → inject and re-prompt. How does this relate to a real agent loop? (Angle: this manual sequence IS the loop body. A real agent just wraps these three steps in a `while` loop. You've already built the core logic — the loop just automates it. Step 5 will do exactly that.)