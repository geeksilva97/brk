// agent.ts — Reference implementation (Step 7 complete)
// The learner builds this incrementally across 7 steps.
// This file shows the FINAL state; each step adds a piece.
//
// Run with: node --experimental-strip-types workspace/agent.ts
// (On Node 23.6+, just: node workspace/agent.ts)
//
// The utility functions (chat, parseToolCalls, getWeather, searchWeb, etc.)
// are PROVIDED in workspace/utils.ts — the learner imports them.
// The learner writes THE LOOP: the logic that calls the model,
// parses responses, dispatches tools, and decides when to stop.

import * as readline from 'node:readline/promises';
import { stdin as input, stdout as output } from 'node:process';
import { chat, parseToolCalls, executeTool, scanSkills } from './utils.ts';

// Types the learner defines in their own agent.ts
interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface ToolCall {
  tool: string;
  args: Record<string, string>;
}

// ─── The agent loop (Steps 4-5) ──────────────────────────────
async function agentLoop(userMessage: string, messages: ChatMessage[]): Promise<string> {
  messages.push({ role: 'user', content: userMessage });

  const MAX_ITERATIONS = 10;

  for (let i = 0; i < MAX_ITERATIONS; i++) {
    const text = await chat('loopcraft', messages);
    const toolCalls: ToolCall[] = parseToolCalls(text);

    if (toolCalls.length === 0) {
      // Model answered directly — we're done
      messages.push({ role: 'assistant', content: text });
      return text;
    }

    // Model requested tool calls
    messages.push({ role: 'assistant', content: text });

    // Execute all tool calls and collect results
    const results: string[] = [];
    for (const tc of toolCalls) {
      const result = await executeTool(tc.tool, tc.args);
      results.push(`[Tool result: ${tc.tool}]\n${result}`);
    }

    // Inject all results as a single user message
    messages.push({ role: 'user', content: results.join('\n\n') });
  }

  return 'Sorry, I reached the maximum number of iterations. Please try again.';
}

// ─── Main interactive loop (Step 5) ──────────────────────────
async function main() {
  console.log('🤖 Loopcraft — Type a message (or Ctrl+C to exit)\n');

  const rl = readline.createInterface({ input, output });

  while (true) {
    const userMessage = await rl.question('You: ');
    if (!userMessage.trim()) continue;
    const messages: ChatMessage[] = [];
    const response = await agentLoop(userMessage, messages);

    console.log(`\nAgent: ${response}\n`);
  }
}

main().catch(console.error);