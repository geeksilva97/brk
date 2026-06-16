---
step: 7
title: Skills as tools
spine: workspace/agent.ts
kind: build
reference: agent.ts
---

# Step 7 — Skills as tools

## Frame
You've built an agent that can call tools for data. Now you'll make it *learn new behaviors dynamically*. A skill is just another tool — one that reads a markdown file and injects its instructions into the conversation. The model decides when to load a skill based on its description, just like it decides when to call get_weather. This is the final pattern: **tools return data, skills change behavior**. Both are context injection. By the end, you'll have a fully functional agent that can fetch real-time data, search the web, and adapt its behavior on the fly — all from a single TypeScript file and a Modelfile.

## Teach the mechanism  (skills + dynamic tool discovery are NEW)
- **A skill is a markdown file**: `skills/explain-like-5/SKILL.md` contains instructions like "Use simple words. No jargon. Use analogies to everyday things." When the model calls the `skill` tool with `name: "explain-like-5"`, your code reads that file and injects it into the conversation. The model now *behaves differently* — it explains things simply.
- **Tools return data, skills change behavior**: get_weather returns `{temperature: 22, condition: "partly cloudy"}`. A skill returns instructions that alter how the model responds for the rest of the conversation. Both are context injection, but they inject different things.
- **Dynamic tool discovery**: at startup, your agent scans the `skills/` directory, reads each `SKILL.md` frontmatter, and builds the skill tool description dynamically. Drop a new `skills/whatever/SKILL.md` directory and restart — the agent automatically picks it up. No code changes needed. This is the same pattern as Claude Code plugins or shell PATH: dynamic discovery beats static lists.
- **The same mechanism as tool calling**: the model outputs `{"tool": "skill", "args": {"name": "explain-like-5"}}` exactly like `{"tool": "get_weather", "args": {"location": "Tokyo"}}`. The agent just reads a file instead of calling an API. Same loop, same parser, same everything.

**How you'll validate it:** you'll ask "Explain how a database index works, keep it simple" and watch the model call the skill tool, load explain-like-5's instructions, and answer in simple language. Then "What's the weather in Tokyo?" and watch it call get_weather — no skill needed.

## Spine  (the learner modifies `workspace/agent.ts` and `workspace/Modelfile`)
- Update `workspace/Modelfile` SYSTEM to add `[TOOL: skill]` definition:
  ```
  [TOOL: skill]
  Description: Load a skill that changes how you respond. Available skills will be listed dynamically.
  Parameters: {"name": "string — name of the skill to load"}
  Returns: the skill's instructions, which you should follow for the rest of the conversation
  ```
- Add `loadSkill(name: string)`: read `skills/${name}/SKILL.md`, strip YAML frontmatter (between `---` markers), return the content.
- Add `scanSkills()`: read `skills/*/SKILL.md`, parse frontmatter for name and description, return a list. Call this at startup and append the skill descriptions to the Modelfile's SYSTEM prompt (or rebuild the model — the learner chooses).
- Extend `executeTool` to handle `skill` → call `loadSkill`, return the content as a tool result. The model will follow those instructions for the rest of the conversation.
- Create example skills:
  - `workspace/skills/explain-like-5/SKILL.md`: "Explain things in simple terms a 5-year-old would understand. Use analogies to everyday things (toys, food, animals). Keep sentences short."
  - `workspace/skills/code-review/SKILL.md`: "Review code following this checklist: 1. Check for bugs 2. Check for security issues 3. Check for readability 4. Check for performance. Be specific and give line numbers."
- Rebuild the model with the updated Modelfile.

## Agent role
- `[explain]` How skills are the same mechanism as tools (JSON in, file read, content injected), how they differ (data vs. behavior), and why dynamic discovery is better than hardcoding.
- `[review]` Check `scanSkills` reads all skill directories, `loadSkill` strips frontmatter correctly, and the dispatch handles `skill`. Check the Modelfile includes the skill tool definition with dynamic descriptions.

## Gotchas
- The skill description in the Modelfile must be rebuilt when skills change — either rebuild the model or update the SYSTEM prompt dynamically at startup.
- The model might try to call a skill that doesn't exist — handle gracefully with an error message like "Skill 'foo' not found."
- Skills are loaded *into the conversation*, not cached between sessions — each new conversation starts fresh.
- Frontmatter stripping: the content between the first two `---` markers is YAML metadata (name, description). The content after the second `---` is the actual instructions. Only inject the instructions, not the metadata.
- The `scanSkills` function should run once at startup and build the list of available skills with their descriptions. This list goes into the skill tool definition so the model knows what's available.

## Success check  (local — node)
1. "Explain how a database index works, keep it simple" → model calls skill tool with name "explain-like-5" → loads the SKILL.md → answers in simple language.
2. "Review this code: def login(user, pw): return db.query(f'SELECT * FROM users WHERE name={user} AND pass={pw}')" → model calls skill tool with name "code-review" → follows the checklist.
3. "What's the weather in Tokyo?" → model calls get_weather (not skill) — it routes correctly based on intent.
4. Adding a new skill directory and restarting makes it automatically available — no code changes needed.

The learner must explain *the difference between a tool call and a skill call* before the step counts as done.

## Consolidate  (dynamic quiz — AFTER the success check passes)
<!-- The tutor composes each quiz at runtime based on what the learner built, where they struggled,
     and what they observed. The angles below guide the tutor — they are NOT verbatim questions. -->

**Quiz topic 1 — Diagnose:**
What's the key difference between a tool call (weather, search) and a skill call? (Angle: a tool call returns *data* — weather JSON, search results. A skill call returns *instructions* that change how the model behaves for the rest of the conversation. Both are context injection, but tools add facts while skills add behavior. It's not about internal/external or power level.)

**Quiz topic 2 — Reflect:**
Why scan skills at startup instead of hardcoding the list? (Angle: so the agent can learn new skills without code changes. Drop a new `skills/whatever/SKILL.md` directory and restart — the agent automatically picks it up. Dynamic discovery beats static lists, like shell PATH or plugin systems. Scanning is slower but more flexible.)