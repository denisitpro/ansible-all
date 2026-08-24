# github-arc-install

Installs **GitHub Actions Runner Controller (ARC)** and registers one or more
**autoscaling runner scale sets**.

Used in two contexts with the same tasks:

- **single-node k3s** — the role runs directly on the node
  (`runner-k3s-arc-c3-infra.yml`); helm/`kubectl` use the local
  `/etc/rancher/k3s/k3s.yaml`.
- **kubeadm cluster** — the role is imported into `k8s-components-install` and
  **delegated** to the master init host (`k8s_components_arc_c3_infra`), so helm
  runs against that cluster's `/etc/kubernetes/admin.conf`. Enable it by adding
  `github-arc` to `helm_componets_list` and supplying `arc_runner_scale_sets`
  (+ the org PATs in Vault) in the components group_vars. The controller and the
  privileged dind runner pods schedule on a **worker** node (kubeadm masters keep
  the `control-plane:NoSchedule` taint), so nothing comes up until a worker has
  joined. Do **not** label the runner namespaces with a `restricted` Pod
  Security policy, or dind will refuse to start.

The kubeconfig path is always `k8s_config_path`; the role is otherwise
host-agnostic.

This uses the modern *Autoscaling Runner Scale Sets* mode (charts
`gha-runner-scale-set-controller` + `gha-runner-scale-set`), **not** the
deprecated `RunnerDeployment` / `HorizontalRunnerAutoscaler` CRDs.

- **Controller** (`gha-runner-scale-set-controller`) is installed once in
  `arc-systems`. It needs **no** GitHub credential and watches all namespaces.
- **Runner scale sets** (`gha-runner-scale-set`) are installed one per GitHub
  scope (org / repo / enterprise), each in its own namespace, each with its own
  GitHub credential. The controller manages them all.
- Runners are **ephemeral**: one job per pod, then the pod is replaced. Idle
  cost is `minRunners` pods (default 0 → scale to zero).

## Why dind / privileged

The goal is that workflows written for GitHub-hosted runners run here **without
rewriting the steps**. Hosted runners give jobs a working Docker daemon, so
`docker build`, `services:` containers, testcontainers, etc. are everywhere.

`containerMode.type: dind` makes the chart inject a **privileged** `docker:dind`
sidecar (`securityContext.privileged: true`) plus an `init-dind-externals`
container, and points the runner at it via `DOCKER_HOST`. That is the
"privileged mode" ARC needs for hosted-runner parity. k3s allows privileged pods
by default (no restricted Pod Security admission), so nothing extra is required
on the node — but do **not** label the runner namespaces with a `restricted`
Pod Security policy or dind will fail to start.

Alternative modes (`kubernetes`, `kubernetes-novolume`) are supported via
`container_mode` but are **not** drop-in compatible with hosted-runner
workflows (no `--privileged`, Docker behaves differently, RWO/RWX volume
required). Keep `dind` unless you have a specific reason.

## ⚠️ The one unavoidable workflow change: `runs-on`

GitHub **reserves** the hosted labels (`ubuntu-latest`, `ubuntu-22.04`,
`windows-latest`, …) for hosted runners. A self-hosted runner can **never**
match `runs-on: ubuntu-latest` — that is a platform rule, not a config option.

With scale-set ARC the *only* label a job can target is the **scale-set name**
(`runnerScaleSetName`, defaults to the Helm release `name`). So the single
required edit to an imported workflow is:

```yaml
jobs:
  build:
    runs-on: arc-self-dind   # the scale-set name, not ubuntu-latest
    steps: ...
```

Everything inside the job (docker, tooling that the runner image ships, etc.)
runs unchanged. For closer tool parity with hosted runners, point
`runner_image` at a "fat" image instead of the minimal default
`ghcr.io/actions/actions-runner`.

Two scale sets in two orgs may share the same label (e.g. both named
`arc-self-dind`) as long as they live in **different namespaces** — chart
resource names derive from the scale-set name, so same name + same namespace
collides.

## Authentication

Per scale set, either:

- **GitHub App (recommended):** `github_app_id`, `github_app_installation_id`,
  `github_app_private_key`. Higher GitHub API rate limits (important when the
  listener polls), not tied to a person. App permission required:
  *Organization → Self-hosted runners: Read and write*. One App can be installed
  on several orgs — same `github_app_id` + `github_app_private_key`, a distinct
  `github_app_installation_id` per org.
- **PAT:** `github_token`. Classic PAT with `admin:org` for org-level
  registration. Simpler, lower rate limits, tied to a user.

Store credentials in Vault. The role renders them into a values file
(`mode 0600`, `no_log`) only for the duration of the `helm upgrade`, then
deletes it — they are never written to the Helm release in plaintext beyond the
Kubernetes Secret the chart creates. Store the App private key in Vault as a
real multi-line PEM (with newlines), not an escaped single line.

## Configuration

```yaml
arc_enabled: true

arc_runner_scale_sets:
  - name: arc-self-dind                       # = release name = runs-on label
    namespace: arc-runners-infra              # unique ns per same-named set
    github_config_url: "https://github.com/your-org"
    github_app_id: "{{ vault_dict_users_secret_g2.arc_github_app.github_app_id }}"
    github_app_installation_id: "{{ vault_dict_users_secret_g2.arc_github_app.installation_id_your_org }}"
    github_app_private_key: "{{ vault_dict_users_secret_g2.arc_github_app.github_app_private_key }}"
    # optional overrides:
    # min_runners: 0
    # max_runners: 5
    # runner_group: "default"
    # container_mode: "dind"
    # runner_image: "ghcr.io/actions/actions-runner"
    # runner_image_tag: "2.334.0"
    # runner_resources: {requests: {cpu: "500m", memory: "1Gi"}}
```

Host-wide defaults that any entry inherits when it omits the key live in
`defaults/main.yml` (`arc_min_runners`, `arc_max_runners`, `arc_container_mode`,
`arc_runner_image`, `arc_runner_image_tag`, `arc_chart_version`, …).

Empty `arc_runner_scale_sets` (the default) installs only the controller.
`arc_enabled: false` makes the whole role a no-op.

## Tags

| Tag | What it runs |
|---|---|
| `github-arc` | everything (preflight + controller + scale sets) |
| `github-arc-prefly` | helm check + credential validation only |
| `github-arc-controller` | install/upgrade the controller only |
| `github-arc-runners` | install/upgrade the runner scale sets only |
| `github-arc-clean` | **destructive**, behind `never` — `helm uninstall` all |

```bash
ansible-playbook -i env/c3-infra/hosts runner-k3s-arc-c3-infra.yml -t github-arc
```

## Requirements / assumptions

- `helm` is already on the node — `k3s-install` installs it (for Cilium) earlier
  in the playbook. The role only checks `helm version`.
- `kubeconfig` at `k8s_config_path` (`/etc/rancher/k3s/k3s.yaml` on these nodes).
- **Outbound** egress (443) open from the node to `github.com`,
  `api.github.com`, `*.actions.githubusercontent.com`, `ghcr.io` and
  `docker.io` (dind image). ARC pulls jobs outbound; no inbound is needed.
- k3s default Pod Security (no restricted enforcement) so dind can run
  privileged.

## Sizing

Each scale set scales `min_runners..max_runners` independently, so the worst
case on one node is `(number of scale sets) × max_runners` dind pods — each pod
is a runner + a privileged docker daemon. Set `arc_max_runners` (and per-set
`max_runners`) to what the node can hold.

## Resource limits

By default the role sets **no** CPU/memory requests or limits on anything
(`arc_runner_resources` and `arc_controller_resources` are both `{}`), so every
pod lands in the `BestEffort` QoS class — the **first** to be OOM-killed or
evicted when the node is under memory pressure. Combined with a high
`max_runners` that shows up as jobs dying mid-run / flaky CI rather than a clean
failure. Set requests/limits once you know the worker node size.

**Runner container** — `runner_resources` per `arc_runner_scale_sets` entry, or
`arc_runner_resources` as the host-wide fallback. Same shape as a normal
`resources:` block; it is templated straight onto the `runner` container:

```yaml
arc_runner_resources:
  requests:
    cpu: "500m"
    memory: "1Gi"
  limits:
    memory: "2Gi"        # cap memory; prefer NOT to set a cpu limit — dind
                         # builds throttle badly, rely on requests + node capacity
```

**Controller** — `arc_controller_resources` (single deployment, light load,
e.g. `{requests: {cpu: 100m, memory: 128Mi}}`).

**⚠️ The dind sidecar is NOT covered by `runner_resources`.** With
`container_mode: dind` the chart injects the privileged `docker:dind` container
itself, and this role's `runner-scale-set-values.yaml.j2` only sets resources on
the `runner` container — so the docker daemon (where `docker build` actually
burns RAM) currently runs **unbounded**. If a single build OOMs the node,
capping the runner alone will not help: you have to bound dind too, which means
extending the template to emit a second container named `dind` with its own
`resources:`. Until then, control the dind blast radius with `max_runners`
(see Sizing).
