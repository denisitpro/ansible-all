---
name: agent-current-branch
description: In ansible-all, agents work in the main tree on the current branch (new branch if on main), not in worktrees
metadata:
  type: feedback
---

In ansible-all, do not spawn writing agents with `isolation: "worktree"`. They work in the main working tree on the checked-out branch; if that is `main`, they create a new `<issue>-<desc>` branch first. Brief line: `WORKTREE-OPT-OUT: /Users/gamma/git/personal/ansible-all (repo rule)`.

**Why:** owner (2026-10-09): reviewing code in the branch they are on is much simpler than in a hidden worktree.

**How to apply:** one writing agent at a time; rule recorded in repo `CLAUDE.md`. Related: [[no-unrequested-guards]].
