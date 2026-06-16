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

**How you'll validate it:** you'll ask "Explain how a database index works, keep it simple" and watch the model call the skill tool, load explain-like-5's instructions, and answer in simple language. Then "What's the weather in Tokyo?" and watch it call get_weather — no skill needed.

## Spine  (the learner modifies `workspace/Modelfile` and tests routing)
- `loadSkill`, `scanSkills`, and the `skill` dispatch in `executeTool` are all **provided in utils.ts**. You don't write them.
- Update `workspace/Modelfile` SYSTEM to add `[TOOL: skill]` definition:
  ```
  [TOOL: skill]
  Description: Load a skill that changes how you respond. Available skills will be listed dynamically.
  Parameters: {"name": "string — name of the skill to load"}
  Returns: the skill's instructions, which you should follow for the rest of the conversation
  ```
- At startup, call `scanSkills()` and append the results to the tool description in the SYSTEM prompt, or rebuild the model. The tutor can help you decide which approach to use.
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
- Rebuild: `ollama create loopcraft -f workspace/Modelfile`
- Run: `node --experimental-strip-types workspace/agent.ts`

## Agent role
- `[explain]` How skills are the same mechanism as tools (JSON in, file read, content injected), how they differ (data vs. behavior), and why dynamic discovery is better than hardcoding.
- `[review]` Check the Modelfile includes the skill tool definition. Check that `scanSkills()` runs at startup and its output appears in the SYSTEM prompt. Verify `executeTool` (in utils.ts) already handles `skill` → `loadSkill`.

## Gotchas
- The skill description in the Modelfile must be rebuilt when skills change — either rebuild the model or update the SYSTEM prompt dynamically at startup.
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