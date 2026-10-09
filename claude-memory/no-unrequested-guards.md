---
name: no-unrequested-guards
description: "In ansible roles, do not add asserts/preflight guards or safety checks the owner didn't ask for"
metadata:
  node_type: memory
  type: feedback
  originSessionId: f3002232-c3eb-4695-9924-5bc5d3f56105
  modified: 2026-10-09T07:43:43.337Z
---

Do not add assert tasks, placeholder-detection checks or other "safety" guards to roles unless asked. Copy the sibling role (e.g. rate-hub) and stop.

**Why:** lux-l7 role (2026-10-09): owner asked for the token as a role default they replace before deploy; I added a preflight assert failing on the placeholder — owner was angry ("не наворачивай космический корабль"). They own the deploy step and know to change it.

**How to apply:** minimal role mirroring the sibling; the app's own startup validation is enough. Mention a risk in one line in chat if needed, never encode it as an extra task.
