# ansible-all

## Agent workflow (overrides the global worktree-isolation rule for this repo)

- Agents work in the main working tree (`/Users/gamma/git/personal/ansible-all`) on the branch currently checked out — no `isolation: "worktree"`. The owner reviews changes in place.
- If the current branch is `main`, create a new branch first (`<issue-number>-<short-description>`).
- Agent briefs carry the line `WORKTREE-OPT-OUT: /Users/gamma/git/personal/ansible-all (repo rule)` so the PreToolUse hook allows the non-isolated agent.
- One writing agent at a time in this tree.
