# Reference implementations (for `/c10k-dojo:reveal`)

`/c10k-dojo:reveal` shows the canonical answer for a step and diffs it against the learner's
attempt. Each step's `reference:` frontmatter names the source. Two canonical references already
exist in the repo:

| Step(s) | Reference (in the repo) | Status |
|---|---|---|
| 1, 4, 5, 6, 11, 15 | `../../first_socket.rb` | exists — raw socket / process scaffolding |
| 2, 7, 8, 9, 10, 13, 14, 16, 17 | `../../rack_based_servers/server.rb` | exists — protocol-http1 + Rack reference |

The remaining per-model canonical servers (fork, preforking, master, puma-like, falcon-like,
ractor) are authored by the instructor (Antonio) during the dry-run pass (build-order step 6 in the
plan): build each once with the agent, confirm it passes its tier, and drop a copy here named to
match the step's `reference:` pointer. Until then, `/c10k-dojo:reveal` falls back to the two files
above plus a live instructor demo — which is exactly the intended safety net.

**Do not ship these to learners' read paths by default** — `/reveal` is the instructor escape hatch.
Gate it to instructor mode if you don't want learners skipping the struggle (see the plan's open items).
