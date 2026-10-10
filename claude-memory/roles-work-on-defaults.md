---
name: roles-work-on-defaults
description: "Ansible roles must render and run on defaults alone; every vault lookup gets | default('changeme'); no risk lectures"
metadata:
  node_type: memory
  type: feedback
  originSessionId: 3258b15b-6228-4202-ad55-5df89aecc215
  modified: 2026-10-10T13:00:06.056Z
---

Every role must work on its defaults alone. Vault-backed vars always carry a fallback, e.g. `"{{ vault_dict_users_secret_g2.x.password | default('changeme') }}"` (bugsink-install pattern). Never write "no default on purpose, missing key must fail".

Do not append "risk" notes about ops consequences (orphaned volumes, migrations, etc.) to reports — the owner is a senior DevOps and finds them insulting.

**Why:** rate-hub rewrite (2026-10-10): owner rejected a no-default vault password and the "risk" paragraph about the old named volume.

**How to apply:** check every new var in defaults renders without vault/group_vars. Related: [[no-unrequested-guards]].
