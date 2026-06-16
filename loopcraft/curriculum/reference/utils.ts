// utils.ts — PROVIDED scaffolding for the loopcraft dojo.
// You do NOT need to write or modify this file.
// It contains the building blocks your agent loop will call.
//
// Run your agent with: node --experimental-strip-types workspace/agent.ts
// (On Node 23.6+, just: node workspace/agent.ts)

import { readdir, readFile } from 'node:fs/promises';
import { join } from 'node:path';

// ─── Ollama HTTP client ────────────────────────────────────────
const OLLAMA_URL = 'http://localhost:11434/api/chat';

interface ChatMessage {
  role: 'system' | 'user' | 'assistant';
  content: string;
}

interface OllamaResponse {
  message: { role: string; content: string };
  done: boolean;
}

// The ChatMessage type — define it in your agent.ts like this:
//   interface ChatMessage { role: 'system' | 'user' | 'assistant'; content: string }
// (Can't export interfaces with --experimental-strip-types, so define it yourself.)

/** Send messages to Ollama and get a response. */
export async function chat(model: string, messages: { role: 'system' | 'user' | 'assistant'; content: string }[]): Promise<string> {
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

// ─── Tool types ────────────────────────────────────────────────
// Define ToolCall in your agent.ts like this:
//   interface ToolCall { tool: string; args: Record<string, string> }

// ─── Parse tool calls from model response ──────────────────────
/** Extract tool calls from the model's output.
 *  Handles: clean JSON, markdown-wrapped JSON, single objects, raw arrays.
 *  Returns empty array if the model answered directly (no tool call). */
export function parseToolCalls(text: string): { tool: string; args: Record<string, string> }[] {
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

// ─── City coordinates (for weather) ────────────────────────────
export const COORDINATES: Record<string, [number, number]> = {
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

// ─── Tool: get_weather ─────────────────────────────────────────
/** Fetch current weather for a city from Open-Meteo (free, no key needed). */
export async function getWeather(location: string): Promise<string> {
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

// ─── Tool: search_web ──────────────────────────────────────────
/** Search the web using DuckDuckGo HTML (free, no API key needed). */
export async function searchWeb(query: string): Promise<string> {
  try {
    const url = `https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`;
    const response = await fetch(url, {
      headers: { 'User-Agent': 'Mozilla/5.0 (loopcraft)' },
      signal: AbortSignal.timeout(5000),
    });
    const html = await response.text();

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

// ─── Tool: skill (load a skill file) ──────────────────────────
/** Load a skill's instructions from the skills directory. */
export async function loadSkill(name: string): Promise<string> {
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

// ─── Scan available skills ─────────────────────────────────────
/** Scan the skills directory and return a list of available skills. */
export async function scanSkills(): Promise<string> {
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

// ─── Tool dispatcher ───────────────────────────────────────────
/** Route a tool name to the right function and execute it. */
export async function executeTool(name: string, args: Record<string, string>): Promise<string> {
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