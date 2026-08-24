# github-runner-org-pool

Ephemeral GitHub Actions self-hosted runner pools, **organization-scoped**. Each pool is one Docker Compose service scaled to N replicas. **Multiple organizations per host** are supported — every pool lives in its own compose project under `<github_runner_pool_compose_path>/<org_name>`.

Model:
- One `runner` service per pool in `docker-compose.yml`, no `container_name`.
- Each replica is an **ephemeral** runner: it registers with a random name, picks up **one** job, deregisters, and the container exits. `restart: unless-stopped` brings up a fresh container → fresh registration.
- Scope is `org` — one pool serves all repositories of its organization; no per-repo configuration.
- Pools are defined in the `github_runner_pools` list. Each gets an isolated compose project (separate dir, env-file and `ACCESS_TOKEN`), so orgs never share a PAT or a project.
- Authentication: GitHub PAT (`ACCESS_TOKEN`). The upstream image fetches a short-lived registration token from the GitHub API on every container start.
- Docker-in-jobs is provided via host socket binding (`/var/run/docker.sock`). This is **not** DinD — the host `dockerd` is shared across all concurrent jobs. Image cache is shared; isolation happens inside the runner container, not at the Docker layer.

This role does **not** replace `github-runner-docker`. The old role is kept for classic long-lived, per-repo runners. Use this new role when you want an org-level ephemeral pool.

## Configuration

Define one or more pools in `group_vars/<your_group>/github_runner_pool.yml`:

```yaml
github_runner_pools:
  - org_name: your-org
    access_token: "{{ vault_dict_users_secret_g2.github_runner_token.github_runner_pool_pat }}"
    # Optional per-pool overrides (fall back to the github_runner_pool_* defaults):
    # size: 10
    # labels: [linux, x64, ephemeral, org-pool]
    # tag: "2.334.0-ubuntu-noble"
    # name_prefix: "gha-myhost"
    # runner_group: "self-hosted-pool"
    # github_host: "github.example.com"   # GHES only
    # restart: "unless-stopped"

  - org_name: another-org
    access_token: "{{ vault_dict_users_secret_g2.another_org_token.github_runner_pool_pat }}"

# Host-wide defaults shared by pools that omit the matching key:
# github_runner_pool_size: 10            # per-host overridable in inventory
# github_runner_pool_tag: "2.334.0-ubuntu-noble"
# github_runner_pool_labels: [linux, x64, ephemeral, org-pool]
# github_runner_pool_cleanup_hour: 3     # host-level cleanup cron (one per host)
# github_runner_pool_cleanup_age_hours: 24
```

The role does not validate variables — an empty `github_runner_pools` (the default) keeps the role parseable on any inventory but produces no pools until you configure it. Misconfiguration surfaces at runtime as GitHub API errors in container logs.

`size` is resolved per pool as `item.size | default(github_runner_pool_size)`, and `github_runner_pool_size` is itself overridable per host in the inventory — so a single host var resizes every pool on that host at once unless a pool pins its own `size`.

> **Migration note (single-pool → multi-pool).** Earlier revisions ran one pool with its compose project directly in `github_runner_pool_compose_path`. On the first run after upgrading, `05-prefly.yml` detects that legacy `docker-compose.yml`, tears the old project down and removes its files before the per-org subdirectories are created. This is a **one-time interruption** of the previously running pool. Run the full role (`-t github-runner-pool`), not just `-config`, so the prefly migration executes.

`inventory_hostname_short` is appended to `LABELS` automatically so workflows can target a specific host if needed.

### Required PAT scopes

For registration at the **organization** level:

- Classic PAT: `admin:org`.
- Fine-grained PAT (org-wide): `Self-hosted runners: Read and write` on the organization. Repository access can be set to `Public repositories (read-only)` — repository permissions are not needed for org-level runner registration.

Store the PAT in Ansible Vault; the role renders it into `/opt/docker/github-runner-pool/runner.env` (mode 0600, root) and references it via `env_file:` in compose — it never ends up in the compose file itself.

## Tags

| Tag | What it runs |
|---|---|
| `github-runner-pool` | everything (prefly + configure + maintenance) |
| `github-runner-pool-prefly` | only directory creation |
| `github-runner-pool-config` / `github-runner-pool-compose` | render env + compose + ensure scale |
| `github-runner-pool-mantaince` | install host docker cleanup cron |
| `github-runner-pool-clean` | **destructive**, behind `never` tag — tears the pool down |

Example:

```bash
# Initial deploy
ansible-playbook -i inventory site.yml -t github-runner-pool

# Resize the pool only (no image pull, no recreate — existing jobs survive
# if scaling up; scaling down may interrupt in-flight jobs of removed replicas)
ansible-playbook -i inventory site.yml -t github-runner-pool-config

# Full teardown
ansible-playbook -i inventory site.yml -t github-runner-pool-clean
```

## Scale behaviour

- Per-pool replica count is `item.size | default(github_runner_pool_size)`.
- `30-configure.yml` issues `docker compose up` with `scale: { runner: N }` per pool (no forced recreate). Safe for live resize.
- The `recreate-docker github-runner-pool` handler fires **only** for the pools whose `runner.env` or `docker-compose.yml` changed (`github_runner_pools_changed`) — it does `recreate: always` + `pull: always`, which interrupts in-flight jobs **of those pools**. Other pools on the host are untouched. Schedule config changes during quiet periods.

## Maintenance cron

Installs (when `github_runner_pool_internal_cron_enabled: true`, default) a daily cron at `github_runner_pool_cleanup_hour` (default `3`):

```
docker image prune -af --filter until=24h
docker builder prune -f --filter "until=24h"
```

Aggressive `-af` prune is acceptable here because the interval is daily and the filter `until=24h` only removes images/cache layers untouched for the past day. Active workflow images are protected by their last-used timestamp.

The cron name is `Docker cleanup old images and builder cache (github-runner-pool)` — suffixed to avoid collision with other roles that install similarly named cleanup jobs.

Disable with `github_runner_pool_internal_cron_enabled: false`.

## Security notes

- `UNSET_CONFIG_VARS=true` is enabled by default. This wipes `ACCESS_TOKEN`, `APP_*`, `RUNNER_TOKEN` and related env vars from the process environment **before** the runner starts the job, so workflows cannot exfiltrate the PAT via `env` or `printenv`.
- `DISABLE_AUTO_UPDATE=true` is enabled by default to keep the actions/runner version locked to the pinned image tag.
- PAT lives in `runner.env` (0600 root:root) and is referenced via `env_file:` — it is not embedded in `docker-compose.yml`.
- Host Docker socket is mounted: jobs on this pool have full control over the host's Docker daemon. Do **not** attach this pool to repositories with unvetted third-party workflows.
- **Multiple orgs on one host share the same `dockerd` and host.** There is no isolation between pools of different organizations — a job in one org's pool can reach the containers/images of another. Only co-locate orgs that are within the same trust boundary.

## Known limitations

- No autoscaling by load. To grow the pool, bump `github_runner_pool_size` and rerun the role (or add more hosts).
- No graceful drain on handler-triggered recreate — in-flight jobs are interrupted.
- GitHub App authentication (`APP_ID` + `APP_PRIVATE_KEY`) is **not** supported in this version. Use PAT.
- Socket binding, not DinD: image/layer cache is shared across concurrent jobs on the same host.
- For true autoscaling by job queue depth consider Actions Runner Controller (ARC) on Kubernetes — out of scope here.
