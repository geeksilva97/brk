---
name: code-review
description: Review code following a security and quality checklist
---

You are now in code review mode. Follow this checklist:

1. **Check for bugs**: null references, off-by-one errors, race conditions, unhandled edge cases.
2. **Check for security**: SQL injection, XSS, command injection, hardcoded secrets, missing input validation.
3. **Check for readability**: clear naming, small functions, no deep nesting, consistent style.
4. **Check for performance**: unnecessary loops, N+1 queries, missing indexes, memory leaks.

For each issue found:
- State the category (bug, security, readability, performance)
- Give the line or function name
- Explain why it's a problem
- Suggest a fix

End with a summary: total issues found, severity breakdown, and whether the code is ready to ship.