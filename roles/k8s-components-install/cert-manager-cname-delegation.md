# cert-manager DNS-01 via CNAME delegation (ash edge k3s)

Runbook for issuing Let's Encrypt certs for `example-ru.com` (and its
subdomains) on the single-node edge cluster **`edge-01.example.org`**.

## Why CNAME delegation (the problem we solved)

`example-ru.com` is served through a third-party geo-routing **"Cloud DNS"**
(Europe → masked Cloudflare-proxied address, Russia → direct IP). Two consequences:

1. **HTTP-01 is impossible** — Let's Encrypt validators hit the EU/Cloudflare
   answer, not our node, so the `/.well-known/acme-challenge` path never matches.
2. **cert-manager has no solver** for that third-party "Cloud DNS" (it is *not*
   Google Cloud DNS), so we cannot let it write TXT records there directly.

Solution: **CNAME delegation**. A single static `_acme-challenge` CNAME in the
geo zone points into the **`example.org`** Cloudflare zone (which cert-manager *can*
write). With `cnameStrategy: Follow`, cert-manager follows that CNAME and
creates/cleans the real TXT inside `example.org`. The production geo-routed zone
keeps **zero automation access** — only one hand-made record lives in it.

```
LE validator ──┐
               │ asks for TXT at  _acme-challenge.example-ru.com
               ▼
   geo "Cloud DNS"  ──CNAME──▶  example-ru-com.acme.example.org   (static, by hand)
                                          ▲
                                          │ cert-manager writes/deletes the TXT here
                                          │ (Cloudflare DNS-01 solver, token = Zone:DNS:Edit on example.org)
                                   example.org  (Cloudflare zone)
```

## What is already in place (do NOT redo)

Merged in PR **#1074** (`add cert manager`). All of it lives under the
`k3s_ash_c3_prod` group / `k3s-ash-c3-prod.yml` playbook in `env/c3-prod/`.

- **ClusterIssuer** `cloudflare-issuer-dns-challenge`
  - ACME **production** endpoint `https://acme-v02.api.letsencrypt.org/directory`
  - email `devops@example.com`
  - Cloudflare DNS-01 solver, `cnameStrategy: Follow`
  - CF API token from Vault `cloudflare/example-org` (key
    `k8s_cert_manager_cloudflare_token`)
- **Config files** (all in `env/c3-prod/group_vars/k3s_ash_c3_prod/`):
  - `cert-manager.yml` — `k8s_cert_manager_type: cloudflare`,
    `k8s_cert_manager_cf_cname_strategy: Follow`,
    `k8s_cert_manager_configured: true`,
    `k8s_cert_manager_monitoring_disabled: true` (no prometheus-operator CRDs on
    this node → ServiceMonitor must stay off, otherwise the helm install fails),
    `cert_manager_cf_name: cloudflare-issuer-dns-challenge`.
  - `secrets.yml` — fetches the CF token into `vault_extend_g2`.
  - `component.yml` — `cert-manager` is in `helm_componets_list`;
    `cert_manager_force_install: true`.
- **Hand-made record in the geo zone** (covers apex + wildcard, see table below):
  ```
  _acme-challenge.example-ru.com.   CNAME   example-ru-com.acme.example.org.
  ```
- **Already issued:** the first *exact-host* cert (per-FQDN, not wildcard).

## The one rule that decides everything: where the challenge lives

The ACME DNS-01 challenge for a cert is always at **`_acme-challenge.<exact FQDN>`**.

| Cert covers | Challenge record name | Covered by the existing CNAME? |
|---|---|---|
| apex `example-ru.com` | `_acme-challenge.example-ru.com` | ✅ yes |
| wildcard `*.example-ru.com` | `_acme-challenge.example-ru.com` | ✅ yes (same name) |
| `app-api-2.example-ru.com` | `_acme-challenge.app-api-2.example-ru.com` | ❌ **no — needs its own CNAME** |

So: **apex and wildcard share one challenge name**; every *specific* subdomain has
its own and needs its own delegation CNAME (unless covered by the wildcard).

## TOMORROW — decide: wildcard vs per-host

### Option A — Wildcard `*.example-ru.com`  (recommended if >1 host)

No new DNS record needed — it reuses the `_acme-challenge.example-ru.com`
CNAME that already exists. One cert then covers `app-api-2` and any other
first-level subdomain.

Caveats:
- `*.example-ru.com` covers **one level only**: `foo.example-ru.com`
  yes, `a.b.example-ru.com` no.
- the wildcard does **not** include the apex `example-ru.com` — add it as a
  second SAN (its challenge is the same name, already delegated).

```yaml
# example-ru-com-wildcard-cert.yml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-ru-com-wildcard
  namespace: <app-namespace>          # must equal the Ingress namespace
spec:
  secretName: example-ru-com-wildcard-tls
  issuerRef:
    name: cloudflare-issuer-dns-challenge
    kind: ClusterIssuer
  commonName: "*.example-ru.com"
  dnsNames:
    - "*.example-ru.com"
    - "example-ru.com"          # apex; same _acme-challenge, already covered
```

### Option B — Per-host cert (one CNAME per FQDN)

For each new host, add **one** static CNAME by hand in the geo zone. Convention:
dots in the FQDN → dashes, under `acme.example.org`.

```
_acme-challenge.app-api-2.example-ru.com.  CNAME  app-api-2-example-ru-com.acme.example.org.
```

The target (`...acme.example.org`) does **not** need to be pre-created — cert-manager
writes/cleans the TXT there itself.

```yaml
# app-api-2-cert.yml
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: app-api-2
  namespace: <app-namespace>
spec:
  secretName: app-api-2-tls
  issuerRef:
    name: cloudflare-issuer-dns-challenge
    kind: ClusterIssuer
  dnsNames:
    - "app-api-2.example-ru.com"
```

## How to issue (commands on the node)

All kubectl on this node goes through `sudo k3s kubectl` (kubeconfig
`/etc/rancher/k3s/k3s.yaml`).

```sh
ssh edge-01.example.org

# 0. Issuer must be ready first
sudo k3s kubectl get clusterissuer cloudflare-issuer-dns-challenge -o wide
#    expect READY: True

# 1. Apply the Certificate manifest (Option A or B)
sudo k3s kubectl apply -f example-ru-com-wildcard-cert.yml   # or app-api-2-cert.yml

# 2. Watch issuance (usually 1-3 min, depends on the geo-zone TTL)
NS=<app-namespace>
sudo k3s kubectl -n "$NS" get certificate -w
sudo k3s kubectl -n "$NS" describe certificate <name>
sudo k3s kubectl -n "$NS" get order,challenge
sudo k3s kubectl -n "$NS" describe challenge | tail -40
```

`READY: True` on the Certificate → the TLS secret is populated.

### Wire it into the Ingress (same namespace, no cert-manager annotation)

```yaml
spec:
  tls:
    - hosts:
        - "*.example-ru.com"
        - "example-ru.com"
      secretName: example-ru-com-wildcard-tls
```

## Re-running the role (prod — run it yourself, never via Claude)

Only needed if the issuer/config itself changed. Issuing a new Certificate does
**not** require a role run — just `kubectl apply` the manifest.

```sh
ansible-playbook -i env/c3-prod/hosts k3s-ash-c3-prod.yml --tags k8s-cert-manager
```

## Troubleshooting

- **ClusterIssuer not `READY: True`** — `describe clusterissuer
  cloudflare-issuer-dns-challenge`. Usually the CF token secret is missing/empty
  → check the Vault fetch ran (`secrets.yml`) and the token still has
  `Zone:DNS:Edit` on `example.org`.

- **helm install fails: `no matches for kind "ServiceMonitor" in
  version "monitoring.coreos.com/v1"`** — the node has no prometheus-operator
  CRDs. `k8s_cert_manager_monitoring_disabled: true` is already set to suppress
  the chart's ServiceMonitor; if it reappears, that flag was lost.

- **helm: `another operation (install/upgrade) is in progress`** — a previous
  release is stuck. Clean it, then re-run the role:
  ```sh
  ssh edge-01.example.org \
    'sudo helm uninstall cert-manager -n cert-manager --kubeconfig /etc/rancher/k3s/k3s.yaml'
  ```

- **Challenge stuck in `pending` / DNS-01 not validating:**
  - Confirm the geo-zone CNAME exists and resolves:
    `dig +short _acme-challenge.<fqdn> CNAME` → must return the `...acme.example.org` target.
  - `acme.example.org` must be a **subdomain inside the `example.org` Cloudflare zone**,
    not a separately delegated zone — otherwise the `example.org` token cannot write
    the TXT there.
  - Watch for the TXT actually appearing:
    `dig +short <target>.acme.example.org TXT` (or in the Cloudflare dashboard).

- **`too many certificates already issued` / rate limit** — Let's Encrypt
  production limits. Wait, or test the flow against staging first
  (`https://acme-staging-v02.api.letsencrypt.org/directory`).

## Quick reference

| Thing | Value |
|---|---|
| Node | `edge-01.example.org` |
| Env / group | `env/c3-prod/` / `k3s_ash_c3_prod` |
| Playbook | `k3s-ash-c3-prod.yml` |
| ClusterIssuer | `cloudflare-issuer-dns-challenge` (LE **prod**) |
| Delegation zone | `example.org` (Cloudflare), targets under `*.acme.example.org` |
| Vault CF token | `cloudflare/example-org` → `k8s_cert_manager_cloudflare_token` |
| Apex/wildcard challenge | `_acme-challenge.example-ru.com` (already delegated) |
| kubectl on node | `sudo k3s kubectl` (`/etc/rancher/k3s/k3s.yaml`) |
