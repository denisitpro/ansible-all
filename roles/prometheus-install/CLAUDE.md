# CLAUDE.md — prometheus-install role

## What `templates/` holds

This role's `templates/` directory holds **Prometheus alert rule templates** (`alerts-*.yml.j2`) plus the `prometheus.yml.j2` config and the docker-compose template. The alert files are rendered to `{{ prometheus_rules_path }}` by `tasks/20-alerts.yml` and validated with `promtool check rules`.

One file per logical group (CPU, memory, disks, postgres, blackbox, ...). The list of files actually rendered is driven by `prometheus_alert_files` in env-level vars — adding a `.j2` here does nothing until it's referenced there.

## House rules for alert templates

1. **Keep templates generic — no company-specific names, hostnames, domains, ticket IDs, team names, or environment labels** baked into expressions, annotations, or alert names. Anything site-specific belongs in env vars (exclusion lists, thresholds), not in the template itself. Project-internal references (`DEVOPS-NNNN`, internal hostnames) are fine only inside comments explaining history.
2. **Every alert that can be scoped per instance must support exclusions by `instance` at minimum**, and ideally also by `tags` (via `node_uname_info`). Use the `excld_inst_<alert_slug>` / `excld_tags_<alert_slug>` variable convention with `| default([])`. If the metric doesn't expose an `instance` label (e.g. some aggregate cluster-wide metrics), it's fine to skip — but prefer adding the exclusion hook when it's supportable.
3. **Don't bulk-refactor existing templates.** Many were imported from older stacks and the goal here is incremental cleanup, not a sweep. Only normalize the file you're actively touching.

## Canonical reference: `alerts-cpu.yml.j2`

When writing or normalizing an alert template, use **`alerts-cpu.yml.j2`** as the model. It demonstrates:

- `{{ ansible_managed | comment }}` header
- Multi-line `expr: |` block (readable, not jammed onto one line)
- Both `instance!~` *and* `tags!~` exclusions, with `| default([])` so empty lists are safe
- The `tags` exclusion uses the `map('regex_replace', '^(.*)$', '.*\\1.*') | join('|')` substring-match idiom — match this exactly so `excld_tags_*` semantics stay consistent across files
- `{% raw %}…{% endraw %}` around Prometheus' own `{{ $labels.instance }}` / `{{ $value }}` so Jinja doesn't try to render them
- Legacy/duplicate rules kept as commented blocks with a one-line reason (`# dl: …` or `# from alerts-migrated-…: kept commented because …`) — preserves history without firing duplicates

`alerts-memory.yml.j2` follows the same pattern and is a fine secondary reference.

## `alerts-migrated-*.yml.j2` files

Files matching `alerts-migrated-*-g2.yml.j2` are **archive imports from the previous (g2) stack and have not been converted to the conventions above.** Treat them as read-only history: rules inside are typically fully commented out, with a header explaining what was migrated 1:1, what was dropped as duplicate, and where the active version now lives. Don't "modernize" them in passing — when something needs to become active, port the rule into the appropriate non-migrated file (following the `alerts-cpu.yml.j2` pattern) rather than editing the migrated file in place.
