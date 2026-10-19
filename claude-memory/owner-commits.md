---
name: owner-commits
description: "ansible-all: owner reviews and commits changes themselves; never commit, never ask \"commit?\" — just report the diff"
metadata:
  node_type: memory
  type: feedback
  originSessionId: f5904946-fc48-4e25-9455-81b26a1a8da9
  modified: 2026-10-19T07:35:49.628Z
---

In ansible-all the owner reviews the working tree and commits themselves. Leave changes uncommitted and end the report with what changed; do not ask "Коммитить?" or offer to commit/open a PR.

**Why:** 2026-10-19, shared Postgres task: owner said up front "код пишешь не комитешь без моего указания"; I still closed two reports with "Коммитить?" and the owner was angry ("я сказал что комитеть сам буду").

**How to apply:** after edits in this repo, stop at the report. Related: [[agent-current-branch]].
