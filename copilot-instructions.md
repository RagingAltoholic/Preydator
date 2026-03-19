# Copilot Instructions

- Never use git commands, git diff tools, or repository inspection unless explicitly requested.
- If a tool call fails, do not repeat the same action.
- After one failed attempt, try at most one different approach.
- If the alternative also fails, stop and ask instead of retrying again.
- Do not retry cancelled tool calls.
- Prefer minimal edits with apply_patch.
- Do not use terminal-based bulk file rewrites for Lua files unless explicitly requested.
- When blocked, summarize the blocker briefly and wait for direction.
- Prefer Blizzard Built systems before writing code to stay lean and optimized.