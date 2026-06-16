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
- **Dynamic tool discovery**: at startup, your agent calls `scanSkills()` (provided in utils.ts) to get a list of available skills with their descriptions. Drop a new `skills/whatever/SKILL.md` directory and restart — the agent automatically picks it up. No code changes needed. This is the same pattern as Claude Code plugins or shell PATH: dynamic discovery beats static lists.
- **The same mechanism as tool calling**: the model outputs `{"tool": "skill", "args": {"name": "explain-like-5"}}` exactly like `{"tool": "get_weather", "args": {"location": "Tokyo"}}`. Your loop already handles this — `executeTool` dispatches to `loadSkill`, which reads the file. Same loop, same parser, same everything.
- **A `system` message OVERRIDES the Modelfile — it does not append**: this is the one trap of this step. Ollama replaces the model's baked SYSTEM with whatever `system` message you put in the `messages` array. So if you inject a bare skill list as `{ role: 'system', content: "Available skills:\n..." }`, you *wipe out* every tool definition and RULE from the Modelfile — the model forgets it can call tools at all (and often reads the skill list as a command, e.g. literally "explaining like a 5-year-old"). Verify it yourself: send a custom system message + "What's the weather in Tokyo?" and watch the `get_weather` tool call disappear. The fix is below: send the *complete* prompt, not a fragment.

**How you'll validate it:** you'll ask "Explain how a database index works, keep it simple" and watch the model call the skill tool, load explain-like-5's instructions, and answer in simple language. Then "What's the weather in Tokyo?" and watch it call get_weather — no skill needed.

## Spine  (the learner modifies `workspace/Modelfile` AND `workspace/agent.ts`)
- `loadSkill`, `scanSkills`, and the `skill` dispatch in `executeTool` are all **provided in utils.ts**. You don't write them.
- Update `workspace/Modelfile` SYSTEM to add `[TOOL: skill]` definition. Make it **emphatic about the indirection** — small models (e.g. llama3:8b) tend to call `{"tool": "explain-like-5"}` (treating the skill *name* as a tool) unless you spell out that the name is an *argument* and show the exact shape:
  ```
  [TOOL: skill]
  Description: Change your behavior by loading a skill. The skill NAME is an ARGUMENT to this tool, NOT a tool itself. To use one, call: {"tool": "skill", "args": {"name": "<skill-name>"}}. Available skill names are listed below.
  Parameters: {"name": "string — one of the skill names listed below"}
  Returns: the skill's instructions, which you should follow for the rest of the conversation
  ```
  It also helps to add a RULE like: `The only valid tool names are get_weather, search_web, skill — skill names are never tool names.`
- **Inject the skill list at runtime — and send the COMPLETE system prompt, not a fragment.** Because a `system` message overrides the Modelfile's baked SYSTEM (see the teach note above), do this in `agent.ts`'s `main()`, once at startup:
  1. Read `workspace/Modelfile` and extract its SYSTEM block — the regex `/SYSTEM\s+"""([\s\S]*?)"""/` captures everything between the triple quotes in group 1. This is your single source of truth for tool defs + RULES.
  2. Call `await scanSkills()` to get the live skill list.
  3. Concatenate them: `systemText + "\n\nAvailable skills (load via the skill tool by name):\n" + skillList`.
  4. Seed every fresh conversation with that as a single `{ role: 'system', content: ... }` message (replace the empty `messages = []` from Step 5 with `messages = [systemMsg]`).
- This keeps tool defs in the Modelfile, makes the skill list dynamic, and means **dropping a skill + restarting** (no `ollama create`, no code change) picks it up — because the baked SYSTEM is read fresh and overridden every run. Putting the skill list next to an *emphatic* `[TOOL: skill]` definition (see above) is what gets the model to call `{tool: skill, args: {name: ...}}` instead of treating the skill name as its own tool — a weak description alone is not enough on small models.
- Create example skills in `workspace/skills/`:
  - `workspace/skills/explain-like-5/SKILL.md`:
    ```
    ---
    name: explain-like-5
    description: Explain things in simple terms a 5-year-old would understand
    ---
    Explain things in simple terms a 5-year-old would understand. Use analogies to everyday things (toys, food, animals). Keep sentences short.
    ```
  - `workspace/skills/code-review/SKILL.md`:
    ```
    ---
    name: code-review
    description: Review code for bugs, security issues, readability, and performance
    ---
    Review code following this checklist: 1. Check for bugs 2. Check for security issues 3. Check for readability 4. Check for performance. Be specific and give line numbers.
    ```
- Rebuild once so the model picks up the new `[TOOL: skill]` definition: `ollama create loopcraft -f workspace/Modelfile`. (After this, skill *changes* need only a restart — `agent.ts` reads the Modelfile SYSTEM at runtime and `scanSkills()` re-reads the directory.)
- Run: `node --experimental-strip-types workspace/agent.ts`

## Agent role
- `[explain]` How skills are the same mechanism as tools (JSON in, file read, content injected), how they differ (data vs. behavior), and why dynamic discovery is better than hardcoding.
- `[review]` Check the Modelfile includes the skill tool definition. Check that `agent.ts` reads the Modelfile SYSTEM, appends `scanSkills()`, and sends the combined text as ONE `system` message seeded into each conversation — not a bare skill list (which would override the Modelfile and break tool calling). Verify `executeTool` (in utils.ts) already handles `skill` → `loadSkill`.

## Gotchas
- Because `agent.ts` reads the Modelfile SYSTEM at startup and sends it as a `system` message, you do NOT need to `ollama create` when skills change — just restart the agent and `scanSkills()` re-reads the directory. (You only rebuild if you edit the Modelfile's tool definitions and want the baked default in sync; the runtime override means the baked SYSTEM isn't actually used while the agent runs.)
- A `system` message in the `messages` array OVERRIDES the Modelfile's baked SYSTEM — it does not merge. Always send the full prompt (Modelfile SYSTEM + skill list), never a bare fragment, or the model loses its tool definitions.
- The model might try to call a skill that doesn't exist — `loadSkill` in utils.ts handles this gracefully with an error message like "Skill 'foo' not found."
- Skills are loaded *into the conversation*, not cached between sessions — each new conversation starts fresh.
- Frontmatter stripping: the content between the first two `---` markers is YAML metadata (name, description). The content after the second `---` is the actual instructions. `loadSkill` in utils.ts strips this automatically.
- `scanSkills()` reads all SKILL.md files and returns a formatted list. Call it once at startup and use the result in your SYSTEM prompt.

## Success check  (local — node --experimental-strip-types)
1. "Explain how a database index works, keep it simple" → model calls skill tool with name "explain-like-5" → loads the SKILL.md → answers in simple language.
2. "Review this code: def login(user, pw): return db.query(f'SELECT * FROM users WHERE name={user} AND pass={pw}')" → model calls skill tool with name "code-review" → follows the checklist.
3. "What's the weather in Tokyo?" → model calls get_weather (not skill) — it routes correctly based on intent.
4. Adding a new skill directory and restarting makes it automatically available — no code changes needed.

The learner must explain *the difference between a tool call and a skill call* before the step counts as done.

## Consolidate  (free-text questions — AFTER the success check passes)
<!-- The tutor asks these questions; the learner types their understanding in their own words. The tutor scores 1-5 based on whether the answer covers the key concepts, gives feedback, and keeps asking until the learner gives a substantive answer (score ≥ 3). Nonsense, vague, or 'I don't know' answers do NOT count — the tutor re-explains and asks again. -->

**Question 1:** What's the key difference between a tool call (weather, search) and a skill call?
A good answer covers: a tool call returns data — weather JSON, search results; a skill call returns instructions that change how the model behaves for the rest of the conversation; both are context injection, but tools add facts while skills add behavior.

**Question 2:** Why scan skills at startup instead of hardcoding the list?
A good answer covers: so the agent can learn new skills without code changes; drop a new `skills/whatever/SKILL.md` directory and restart — the agent automatically picks it up; this is the same pattern as Claude Code plugins or shell PATH — dynamic discovery beats static lists.

**Question 3:** You want to add a "translate" skill that makes the model respond in a specific language. What do you need to change in agent.ts?
A good answer covers: nothing — create `workspace/skills/translate/SKILL.md` with the instructions, restart the agent, and `scanSkills()` will pick it up automatically; the Modelfile already defines the skill tool; `executeTool` already handles `skill` → `loadSkill`; this is the power of dynamic discovery — no code changes needed.

## Congratulations 🎉
You've built a complete AI agent from scratch. You now understand:
- **How agents work**: a loop that calls an LLM, parses tool calls, executes them, injects results, and repeats until the model answers directly.
- **Prompt emulation**: tool calling is just structured text — a system prompt tells the model how to ask for tools, and your code parses the response.
- **The agent loop**: the core pattern that makes a chatbot into an agent — automatic tool execution with conversation history.
- **Skills vs. tools**: both are context injection, but tools return data and skills change behavior.
- **Dynamic discovery**: scanning for skills at startup means the agent grows without code changes.

This is the foundation that every agent framework (LangChain, AutoGPT, Claude Code) builds on. The loop you wrote *is* the agent loop. Everything else is convenience and scale.

**Next:** add more skills, more tools, or connect it to a real application. The agent is yours.