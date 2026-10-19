---
name: env-only-overrides
description: App roles set only env vars that differ from the app's code defaults; no defaults/env lines for values the app already defaults; template each file once
metadata:
  type: feedback
---

In an app role, `defaults/main.yml` and the env template carry only what must be overridden on a host (listen addr, URLs, secrets). A variable whose code default is already right (e.g. sender-api `SENDER_ENV`, `SENDER_COOKIE_SECURE`, `SENDER_QUOTA_ENFORCEMENT`, `SENDER_SCHEDULER_INTERVAL`) gets no role var, no env line, no commented placeholder. Copy the compose file in one task only, not in both configure and launch.

**Why:** owner 2026-10-19 on the sender-api role: "для такого простого ПО так много дефолтов? всё что тянется с дефолт кода и не требует переопределения не делаем"; they removed the second compose copy themselves.

Production values the app needs (another service's URL, the loopback listen address under host networking) belong in the role's `defaults/main.yml`, never as code defaults in the app; host group_vars carry only the version and secrets.

**How to apply:** read the app's config loader first, list which vars the host must change, write only those. Related: [[no-unrequested-guards]], [[roles-work-on-defaults]].
