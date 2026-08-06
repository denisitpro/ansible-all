# amneziawg2-install

Provisions an **AmneziaWG 2.0** VPN server on Ubuntu using the **kernel module**
from `ppa:amnezia/ppa`. Sibling to the legacy `roles/amnezia-install`; this one
adds the 2.0 obfuscation keys and fixes several bugs from the legacy role.

---

## TL;DR — context for future work on this role

- **2.0 datapath here = the AmneziaWG kernel module from `ppa:amnezia/ppa`.**
  No userspace binary, no manual build. `apt install amneziawg` (state: latest)
  pulls a build that already speaks 2.0.
- **Do NOT trust the PPA version string.** The kmod reports `1.0.0` and the
  tools report `1.0.20210914` — these are frozen labels inherited from
  wireguard, they do **not** indicate protocol version. The actual 2026-06 PPA
  build is compiled from 2.0 source (verified below). Judging "legacy vs 2.0"
  by the version number is wrong and cost an earlier analysis a full detour.
- **This role covers 2.0 minus the imitators:** `Jc/Jmin/Jmax`, `S1`–`S4`,
  `H1`–`H4`. The `I1`–`I5` signature packets are **not** in the kernel module
  (userspace-only) — see below.
- **It is a migration, not an in-place tweak.** `state: latest` upgrades the
  package and bounces `awg0` into 2.0 mode; all existing client configs must be
  reissued (2.0 is wire-incompatible with v1.x).

---

## Why the PPA is enough for 2.0 (verified from source, 2026-07-21)

- Kernel module `amnezia-vpn/amneziawg-linux-kernel-module` (`version.h =
  1.0.20260611`) has `junk_size[4]` (= `S1`/`S2`/`S3`/`S4`) and `headers[4]`
  (= `H1`–`H4`). So S3/S4 padding + magic headers are implemented in the module.
- Tools `amnezia-vpn/amneziawg-tools` @ commit `61e7417` (the PPA build dated
  2026-06-19) parse `S3`/`S4`/`I1`–`I5` in `src/config.c`.
- The actively-maintained community installer `bivlked/amneziawg-installer`
  (labelled "AmneziaWG 2.0") confirms the pattern: on x86 it installs the PPA
  kernel module via DKMS; on ARM it ships its own prebuilt `.deb`. It does
  **not** use `amneziawg-go`.

So: same install path as the legacy role, just a newer package + the extra
config keys.

## What is NOT included: `I1`–`I5` "imitator" packets

The signature/imitator packets `I1`–`I5` (make traffic look like DNS / QUIC /
SIP — the headline feature of the 2.0 announcement) are implemented **only in
the userspace `amneziawg-go`** datapath (`ipackets[5]`, `newObfChain` in
`device/uapi.go`). The kernel module has **no such field**, so setting them
here would do nothing / error.

If you specifically want the imitators, this role must be swapped to a
**userspace variant**:

- Build `amneziawg-go` from source — tag `v0.2.19` carries 2.0, needs **Go
  1.24.4**. Upstream publishes **no prebuilt binary** (git tags only, no release
  assets), which is why it isn't wired in by default.
- Run `awg-quick` against it (it falls back to `${WG_QUICK_USERSPACE_IMPLEMENTATION:-amneziawg-go}`
  when no `amneziawg` kernel module is loaded), plus a systemd unit.
- A full userspace variant of this role was drafted earlier in the same task and
  then replaced by this kernel-module version — it can be restored on request.

Note: `I1`–`I5` are structured obfuscation-chain strings (tag DSL like
`<b 0x…>`, `<c>`, `<t>`, `<r …>`), **not** random integers — they come from the
Amnezia app config and cannot be auto-generated.

## Obfuscation parameters

Generated once and persisted in `/etc/amnezia/amneziawg/server_params.yml`
(never regenerated on later runs, so keys/params stay stable):

| Key | Meaning | How set |
|---|---|---|
| `Jc` / `Jmin` / `Jmax` | junk packet count / size bounds | random, generated |
| `S1` / `S2` / `S3` / `S4` | padding: init / response / cookie / transport | random, generated (S3/S4 new in 2.0) |
| `H1` / `H2` / `H3` / `H4` | magic headers: init / response / cookie / transport | random, generated |

All of these must be **identical on server and every client** — the role
renders the same persisted values into `awg0.conf` and each `client.conf`.

## Migration note

AmneziaWG 2.0 is wire-incompatible with legacy v1.x. When migrating an existing
host, client configs must be **regenerated and redistributed** to devices.

**Do not run this role on the same host as the legacy `amnezia-install` role** —
they share `awg-quick@<iface>` and `/etc/amnezia/amneziawg`. Pick one per host.

## Layout

```
tasks/
  main.yml                 # import pipeline
  05-prefly.yml            # apt cache, ip_forward v4/v6, working dirs
  30-install.yml           # ppa:amnezia/ppa → apt amneziawg (latest) → dkms → modprobe
  40-generate-configs.yml  # server keys + Jc/S1-S4/H1-H4, persisted once; render awg0.conf
  60-add-clients.yml       # client keys, client.conf + QR, enable awg-quick@ (unit from deb)
  80-manage-clients.yml    # per-client key material → amneziawg_clients_data
  99-clean.yml             # teardown: stop svc, purge package, remove dirs/sysctl
templates/
  awg0.conf.j2             # server [Interface] + NAT PostUp/PostDown + [Peer]s
  client.conf.j2           # per-client config (0.0.0.0/0, ::/0 full tunnel)
handlers/main.yml          # "Rebuild AmneziaWG DKMS" (dkms autoinstall) + "restart amneziawg"
defaults/main.yml          # interface/port/subnets/wan/endpoint + amneziawg_clients
```

The `awg-quick@.service` systemd unit is provided by the `amneziawg` deb — the
role does not template its own.

## Bugs fixed vs the legacy `amnezia-install` role

- **IPv6 client key bug:** legacy used `'ipv6': item.item.ipv6 | default(omit)`
  inside a dict literal, where `omit` is **not** stripped (it becomes a
  placeholder string, so `ipv6 is defined` was always true → garbage rendered
  for ipv6-less clients). Fixed with `combine({'ipv6': …} if … is defined)`.
- **Hardcoded DKMS version:** legacy pinned `dkms install amneziawg/1.0.0` and a
  literal `/var/lib/dkms/amneziawg/1.0.0/...` path → breaks on any version
  change. Now: glob-find the dkms dir(s) + `dkms autoinstall`.
- **Double server-config render:** legacy rendered `awg0.conf` twice (once
  peerless). Now rendered once, after clients are known.
- `creates:` guard on the client key-generation shell.
- **Derived MTU breaks on AWS:** wg-quick auto-derives the tunnel MTU from the
  WAN interface MTU (e.g. 9001 on AWS jumbo-frame ENIs → 8921), which
  black-holes packets over a 1500 path. MTU is now set explicitly
  (`amneziawg_mtu`) in both `awg0.conf` and `client.conf`.

## Config / variables

Per-host config goes in `env/<env>/group_vars/<group>/`. Key vars
(`defaults/main.yml`):

- `amneziawg_interface` (`awg0`), `amneziawg_port` (`49666`)
- `amneziawg_mtu` (`1380`) — explicit tunnel MTU, see bugs-fixed section
- `amneziawg_subnet` (`10.9.9.1/24` — server address), `amneziawg_ipv6_subnet`
- `amnezia_wan_interface` (auto from `ansible_default_ipv4.interface`)
- `amnezia_endpoint_address` (auto from `ansible_host`)
- `amneziawg_clients` — list of `{name, ip, ipv6?}`; keys are generated and
  stored under `/etc/amnezia/amneziawg/clients/`, configs + QR PNGs land in
  `/opt/awg/`.

Client private keys are generated **server-side** (stored under
`/etc/amnezia/amneziawg/clients/` and `/opt/awg/*.conf`) — same trade-off as the
legacy role; a host compromise exposes all client keys.

## Running

Wire the role into any playbook that targets the VPN host(s), then run with
the role tags:

```sh
ansible-playbook -i inventory playbook.yml --tags amneziawg2
```

## Tags

`amneziawg2` (all), `-prefly`, `-install`, `-generate`, `-add-client`, and
`amneziawg2-clean` (teardown, `never` by default).
