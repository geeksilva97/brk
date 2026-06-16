// agent.ts — Reference implementation (Step 7 complete)
// The learner builds this incrementally across 7 steps.
// This file shows the FINAL state; each step adds a piece.
//
// Run with: node workspace/agent.ts
//
// TypeScript native features only:
//   - node:readline/promises for input
//   - node:fs/promises for skill loading
//   - global fetch (Node 18+) for Ollama HTTP API
//   - No external npm packages needed

import * as readline from 'node:readline/promises';
import { stdin as input, stdout as output } from 'node:process';
import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';

// ─── Ollama HTTP client (Step 1) ─────────────────────────────────
const OLLAMA_URL = 'http://localhost:11434/api/chat';

interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface OllamaResponse {
  message: { role: string; content: string };
  done: boolean;
}

async function chat(model: string, messages: ChatMessage[]): Promise<string> {
  const response = await fetch(OLLAMA_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ model, messages, stream: false }),
  });

  if (!response.ok) {
    throw new Error(`Ollama error: ${response.status} ${response.statusText}`);
  }

  const data = (await response.json()) as OllamaResponse;
  return data.message.content;
}

// ─── City coordinates (Step 3) ────────────────────────────────────
const COORDINATES: Record<string, [number, number]> = {
  "tokyo":      [35.6762, 139.6503],
  "new york":   [40.7128, -74.0060],
  "london":     [51.5074, -0.1278],
  "paris":      [48.8566, 2.3522],
  "são paulo":  [-23.5505, -46.6333],
  "sydney":     [-33.8688, 151.2093],
  "mumbai":     [19.0760, 72.8777],
  "cairo":      [30.0444, 31.2357],
  "berlin":     [52.5200, 13.4050],
  "moscow":     [55.7558, 37.6173],
};

// ─── Tool types (Step 2) ──────────────────────────────────────────
interface ToolCall {
  tool: string;
  args: Record<string, string>;
}

// ─── Parse tool calls from model response (Step 3) ───────────────
function parseToolCalls(text: string): ToolCall[] {
  // Try direct JSON parse first
  try {
    const parsed = JSON.parse(text);
    if (Array.isArray(parsed)) return parsed;
    if (parsed.tool) return [parsed];
  } catch {}

  // Try extracting from markdown code blocks
  const codeBlockMatch = text.match(/```(?:json)?\s*\n?([\s\S]*?)\n?\s*```/);
  if (codeBlockMatch) {
    try {
      const parsed = JSON.parse(codeBlockMatch[1]);
      if (Array.isArray(parsed)) return parsed;
      if (parsed.tool) return [parsed];
    } catch {}
  }

  // Try finding JSON array or object in the text
  const arrayMatch = text.match(/\[[\s\S]*?\]/);
  if (arrayMatch) {
    try { return JSON.parse(arrayMatch[0]); } catch {}
  }
  const objectMatch = text.match(/\{[\s\S]*?"tool"[\s\S]*?\}/);
  if (objectMatch) {
    try { return [JSON.parse(objectMatch[0])]; } catch {}
  }

  return []; // No tool calls found — model answered directly
}

// ─── Tool: get_weather (Step 3) ───────────────────────────────────
async function getWeather(location: string): Promise<string> {
  const key = location.toLowerCase().trim();
  const coords = COORDINATES[key];

  if (!coords) {
    return `I don't have coordinates for "${location}". Available cities: ${Object.keys(COORDINATES).join(', ')}`;
  }

  const [lat, lon] = coords;
  try {
    const response = await fetch(
      `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current_weather=true`
    );
    const data = await response.json() as any;
    const weather = data.current_weather;
    return JSON.stringify({
      temperature: weather.temperature,
      windspeed: weather.windspeed,
      weathercode: weather.weathercode,
      location,
    });
  } catch (error) {
    return `Weather lookup failed: ${error}`;
  }
}

// ─── Tool: search_web (Step 6) ────────────────────────────────────
async function searchWeb(query: string): Promise<string> {
  // Using DuckDuckGo HTML endpoint (no API key needed)
  try {
    const url = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`;
    const response = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (loopcraft)' },
      signal: AbortSignal.timeout(5000),
    });
    const html = await response.text();

    // Extract results using regex (simplified)
    const results: { title: string; snippet: string; href: string }[] = [];
    const resultRegex = /class="result__a"[^>]*href="([^"]*)"[^>]*>(.*?)<\/a>/g;
    const snippetRegex = /class="result__snippet"(?:[^>]*)>(.*?)<\/a>/g;

    let match;
    let i = 0;
    while ((match = resultRegex.exec(html)) !== null && i < 5) {
      results.push({
        href: match[1],
        title: match[2].replace(/<[^>]*>/g, '').trim(),
        snippet: '',
      });
      i++;
    }

    // Try to get snippets
    i = 0;
    while ((match = snippetRegex.exec(html)) !== null && i < results.length) {
      if (results[i]) {
        results[i].snippet = match[1].replace(/<[^>]*>/g, '').trim();
      }
      i++;
    }

    if (results.length === 0) {
      return `No results found for "${query}".`;
    }

    return results
      .slice(0, 5)
      .map((r, idx) => `${idx + 1}. ${r.title}\n   ${r.snippet}\n   ${r.href}`)
      .join('\n\n');
  } catch (error) {
    return `Search failed: ${error}. Try a different query.`;
  }
}

// ─── Tool: skill (Step 7) ─────────────────────────────────────────
async function loadSkill(name: string): Promise<string> {
  const skillDir = join(process.cwd(), 'workspace', 'skills', name);
  const skillFile = join(skillDir, 'SKILL.md');

  try {
    const content = await readFile(skillFile, 'utf-8');
    // Strip YAML frontmatter (between first two --- markers)
    const stripped = content.replace(/^---[\s\S]*?---\n*/, '');
    return stripped.trim();
  } catch {
    return `Skill "${name}" not found. Available skills are listed in the tool description.`;
  }
}

// ─── Scan available skills (Step 7) ──────────────────────────────
async function scanSkills(): Promise<string> {
  const skillsDir = join(process.cwd(), 'workspace', 'skills');
  const descriptions: string[] = [];

  try {
    const dirs = await readdir(skillsDir);
    for (const dir of dirs) {
      try {
        const content = await readFile(join(skillsDir, dir, 'SKILL.md'), 'utf-8');
        const nameMatch = content.match(/^name:\s*(.+)$/m);
        const descMatch = content.match(/^description:\s*(.+)$/m);
        const name = nameMatch ? nameMatch[1].trim() : dir;
        const desc = descMatch ? descMatch[1].trim() : '';
        descriptions.push(`- ${name}: ${desc}`);
      } catch { /* skip invalid skills */ }
    }
  } catch { /* skills dir doesn't exist yet */ }

  return descriptions.length > 0
    ? descriptions.join('\n')
    : 'No skills available yet.';
}

// ─── Tool dispatcher (Steps 3-7) ──────────────────────────────────
async function executeTool(name: string, args: Record<string, string>): Promise<string> {
  switch (name) {
    case 'get_weather':
      return await getWeather(args.location || '');
    case 'search_web':
      return await searchWeb(args.query || '');
    case 'skill':
      return await loadSkill(args.name || '');
    default:
      return `Unknown tool: ${name}`;
  }
}

// ─── The agent loop (Step 5) ─────────────────────────────────────
async function agentLoop(userMessage: string, messages: ChatMessage[]): Promise<string> {
  messages.push({ role: 'user', content: userMessage });

  const MAX_ITERATIONS = 10;

  for (let i = 0; i < MAX_ITERATIONS; i++) {
    const text = await chat('loopcraft', messages);
    const toolCalls = parseToolCalls(text);

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

// ─── Main interactive loop (Step 5) ──────────────────────────────
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