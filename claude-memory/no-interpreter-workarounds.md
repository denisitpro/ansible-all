---
name: no-interpreter-workarounds
description: "ansible-all: never pin ansible_python_interpreter for localhost; rewrite controller-side tasks to raw+curl instead"
metadata:
  node_type: memory
  type: feedback
  originSessionId: c562eef9-8a0f-4443-91db-3ad12333cb60
  modified: 2026-10-23T11:01:38.945Z
---

Do not add `ansible_python_interpreter` overrides (host_vars/localhost, `ansible_playbook_python`) to paper over a broken controller Python (Homebrew python3 upgrades break ansible-core modules every few months). Let roles fail loudly; when a role must survive it, rewrite its localhost tasks to `ansible.builtin.raw` + curl like `infisical-get-secrets-direct-g1`.

**Why:** owner called the interpreter pin a crutch (2026-10-23); a loud failure is the signal to rewrite the role python-free.

**How to apply:** for localhost/delegated tasks failing on module import, propose or do the raw+curl rewrite of that role only; no global interpreter fixes. See [[no-unrequested-guards]].
