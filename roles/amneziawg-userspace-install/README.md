# amneziawg-userspace-install

Provisions an **AmneziaWG** VPN server using the **userspace `amneziawg-go`**
datapath, installed from **prebuilt, checksum-pinned binaries** published as
a GitHub Release, instead of the kernel DKMS module used by the sibling
`roles/amneziawg2-install`. Do not run both roles on the same host — they
share `awg-quick@<iface>` and `/etc/amnezia/amneziawg`.

---

## Why userspace instead of the kernel module

`roles/amneziawg2-install` covers AmneziaWG 2.0 **minus the imitators**:
`Jc/Jmin/Jmax` (junk packets) and `H1`-`H4`/`S1`-`S4` (magic headers + padding
sizes) only. That was sufficient while H1-H4/S1-S4 alone threw off TSPU
heuristics, but it is no longer enough on its own — DPI has adapted to that
fixed set of fields. The actual headline feature of AmneziaWG 2.0, `I1`-`I5`
("custom signature packets" / imitators, which reshape the **handshake**
itself to look like DNS/QUIC/other protocols), is **not implemented in the
public kernel module at all**:

- `amnezia-vpn/amneziawg-linux-kernel-module` only has `junk.c/.h` (Jc/Jmin/
  Jmax) and `magic_header.c/.h` (H1-H4). Grepping `src/device.c` and
  `src/uapi/wireguard.h` for `i1`/`special`/`cps` returns nothing.
- Upstream issue #169 ("Where can I find the source code of the AmneziaWG 2.0
  kernel module?", opened 2026-04-27) is still unanswered — the kernel side of
  the imitator feature has never been published.

I1-I5 **are** real and implemented on the userspace datapath:

- `amneziawg-go` `device/uapi.go` `handleDeviceLine()` accepts UAPI keys
  `i1`..`i5`, storing each as a parsed obfuscation chain in
  `device.ipackets[0..4]`.
- `device/obf.go` implements the tag-DSL parser (`newObfChain()`) that builds
  those chains.
- `device/send.go` (`SendHandshakeInitiation`, ~lines 136-141) actually sends
  them, in order I1→I5, **before** the WireGuard init message and before the
  junk packets — this is the real handshake-masking path, not a stub.
- `amneziawg-tools` `src/config.c` parses `I1`..`I5` in `[Interface]` and over
  UAPI (`i1`..`i5`) — matching CLI/config support on the same commit we pin.

So this role installs the pieces that actually speak I1-I5 — rather than
following the officially documented install path, which is desktop-app-driven
and doesn't apply here (see "Rejected alternatives").

## Why a self-hosted release instead of building from source

Neither `amneziawg-go` nor `amneziawg-tools` publishes GitHub release
binaries themselves (releases API returns `[]`) — source only. An earlier
version of this role compiled both from source on the target host, which
meant every run needed a compiler, ~250 MB Go toolchain, and — because
`amneziawg-go` has no `vendor/` directory — HTTPS egress to
`proxy.golang.org` at build time. That last requirement is a real problem on
a host that sits behind a censored network, which is exactly where this role
is most likely to run.

This role now consumes a self-hosted mirror release
(`denisitpro/amnezia-binary`, tag `awg-v3.0.2-tools-v3.0.20260730`) that
packages prebuilt binaries for both projects with a `SHA256SUMS` asset,
giving a reproducible, checksum-pinned artifact identity without a
build step on the target host.

## Pinned versions

| Component | Tag | Upstream commit |
|---|---|---|
| `amneziawg-go` | `v3.0.2` | `0527dfa47639714dd8f5c9ffbd9d40d19083f0ba` |
| `amneziawg-tools` | `v3.0.20260730` | `d09ecc38425082e472368dd2bf8c4c42d10cae03` |

Release consumed: `denisitpro/amnezia-binary`, tag
`awg-{{ amneziawg_go_tag }}-tools-{{ amneziawg_tools_tag }}` →
`awg-v3.0.2-tools-v3.0.20260730`. Assets:

| Asset | Installed to | Notes |
|---|---|---|
| `amneziawg-go-linux-amd64` | `amneziawg_go_bin` (`/usr/local/bin/amneziawg-go`) | Fully static ELF, linux/amd64 only |
| `awg-linux-amd64` | `amneziawg_awg_bin` (`/usr/local/bin/awg`) | Dynamically linked PIE, built against glibc 2.35 (Ubuntu 22.04); forward-compatible with glibc 2.39 (Ubuntu 24.04) |
| `awg-quick` | `amneziawg_awg_quick_bin` (`/usr/local/bin/awg-quick`) | Architecture-independent bash script |

The three `amneziawg_*_sha256` vars in `defaults/main.yml` are copied
**verbatim** from that release's own `SHA256SUMS` asset — never invented.
`amneziawg_go_tag` / `amneziawg_tools_tag` are a **matched pair**: they
compose the release tag, so bumping one without the other can pull in a
tools build that doesn't speak the datapath's current feature set (e.g. a
3.x datapath paired with pre-2.0 tools would silently lose every AmneziaWG
2.0 feature). Bumping either tag requires updating **all three** SHA256 vars
from the new release's `SHA256SUMS`.

**amd64-only limitation:** the release publishes `linux/amd64` assets only —
there is no `arm64` `amneziawg-go` build. `30-install.yml` asserts
`ansible_facts['architecture'] == 'x86_64'` and fails loudly otherwise.

**Version history note:** CPS/imitator support existed as far back as
`amneziawg-go` `v0.2.13-beta-awg-1.5-fix` (2025-07-04) in a pre-refactor form
(`device/awg/special_handshake_handler.go`), refactored into today's
`device/obf*.go` at v0.2.16+. `v0.2.19` was module path
`github.com/amnezia-vpn/amneziawg-go` with `go 1.24.4`; `v3.0.0`+ renamed the
module to `github.com/amnezia-vpn/amneziawg-go/v3` with `go 1.25.0` — which is
why this role's datapath tag is `v3.0.2`, not the earlier `v0.2.19` line an
earlier draft of this work assumed.

## Rejected alternatives

- **`ppa:amnezia/ppa` standalone `amneziawg-tools` deb.** The PPA does publish
  a tools-only deb (no DKMS). Rejected because: (a) it previously burned us
  with a moving DKMS build tied to the same PPA, and (b) PPAs drop old
  versions, so pinning an exact apt version string rots — there's no
  guarantee the same build stays published. A checksum-pinned release asset
  is reproducible indefinitely.
- **The documented Amnezia install flow.** Both
  `docs.amnezia.org/documentation/instructions/install-vpn-on-server` and
  `.../installing-app-on-linux/` describe an install driven by the
  **AmneziaVPN desktop app** (self-hosted `.run` installer flow) and never
  mention `amneziawg-go` or a userspace binary at all. Only
  `docs.amnezia.org/documentation/amnezia-wg/` documents the actual parameter
  semantics. There is no vendor install script to run — this role installs
  the server side directly instead.

## `I1`-`I5`: what they are, and why no value ships here

`amneziawg_i1` .. `amneziawg_i5` default to empty strings and are rendered
**only when non-empty** (see Templates below) — **never** as an empty
`I1 = ` line.

This is not just cosmetic: `amneziawg-tools` issue #40 reports that an
**empty** `I1`-`I5` line (as exported by Amnezia's self-hosted flow) is
silently accepted at config-parse time but **crashes `awg-quick` at
interface bring-up**; the fix (PR #41) was still open at verification time.
Separately, issue #35 (tools `1.0.20250903-1`) reports an unresolved "Invalid
argument" error with a well-formed `I1 = <b 0x...>` value. Our pinned tools
tag (`v3.0.20260730`) is materially newer than both reports, but flag this
as a **known area of upstream instability** if I1-I5 misbehave in practice.

**No usable example value exists anywhere upstream.** The one CPS example on
`docs.amnezia.org/documentation/amnezia-wg/` (a DNS-mimicking string) carries
an explicit disclaimer: *"The example above only illustrates CPS syntax; it
is not a reference signature to reuse. Do not use it as the value for
parameters I1-I5."* The `amneziawg-go`/`amneziawg-tools` READMEs, source, and
tests contain no example values either. **This role does not paste that
example in anywhere — not as a default, not as a commented-out sample** —
inventing or reusing a plausible-looking value would be worse than leaving
the field empty. The operator must compose real `I1`-`I5` values themselves,
typically from a captured real protocol snapshot (e.g. a QUIC Initial or DNS
query), following the tag DSL:

| Tag | Meaning |
|---|---|
| `<b 0xHEX>` | static bytes, hex; must be even-length hex (odd → parse error) |
| `<t>` | 4-byte big-endian Unix timestamp |
| `<r N>` | N cryptographically random bytes |
| `<rc N>` | N random ASCII letters `[a-zA-Z]` |
| `<rd N>` | N random decimal digits `[0-9]` |

Sent in order I1→I2→I3→I4→I5; per upstream README, "if there is no value
specified, the packet is skipped" (this is what an unset/empty
`amneziawg_i*` here achieves — via omitting the line entirely, working around
the empty-line crash above).

I1-I5 affect only the **handshake-time** packets sent before the WireGuard
init message — they do not add to the size of ongoing data packets, so they
don't change the MTU arithmetic below.

## MTU rationale

Worst case per-packet overhead on top of the WireGuard payload:

```
20 (IP)  + 8 (UDP) + 16 (WG transport header) + 16 (Poly1305 tag) + S4(<=27) (junk padding)
= 87 bytes
```

On a 1500-byte path that leaves `1500 - 87 = 1413` safe. The default
`amneziawg_mtu: 1380` sits comfortably under that, leaving room for a client
behind PPPoE (typically MTU 1492) too. An IPv6 outer path costs 20 more bytes
than IPv4 (40-byte IPv6 header vs 20-byte IPv4), which the 1380 default also
absorbs. As noted above, `I1`-`I5` do not change this — they're
handshake-only.

## Layout

```
tasks/
  main.yml                 # import pipeline
  05-prefly.yml            # kernel-module guard, apt deps, ip_forward v4/v6,
                            # tun module + persistence, working dirs
  30-install.yml           # arch guard -> download+checksum the 3 release
                            # assets -> write the systemd unit
  40-generate-configs.yml  # server keys + Jc/S1-S4/H1-H4, persisted once
  60-add-clients.yml       # client configs + QR, render server conf, start service
  70-verify.yml            # read-only: interface up, UAPI socket, peer count
  80-manage-clients.yml    # per-client key material -> amneziawg_clients_data
  99-clean.yml             # full teardown, exact parity with what install created
                            # (plus leftovers from the old build-from-source version)
templates/
  awg-quick@.service.j2    # systemd unit (the release ships none)
  awg0.conf.j2             # server [Interface] + NAT PostUp/PostDown + [Peer]s
  client.conf.j2           # per-client config (0.0.0.0/0, ::/0 full tunnel)
handlers/main.yml          # "restart amneziawg" + "daemon reload"
defaults/main.yml          # shared knobs (same names as amneziawg2-install) +
                            # release/checksum pins + optional I1-I5
```

## Install pipeline (`30-install.yml`)

1. Assert `ansible_facts['architecture'] == 'x86_64'`; fails loudly otherwise
   (the release is amd64-only, see "amd64-only limitation" above).
2. Three `get_url` tasks download `amneziawg-go-linux-amd64`,
   `awg-linux-amd64`, and `awg-quick` from
   `amneziawg_release_base_url` straight to their final
   `/usr/local/bin` paths, each with an explicit `checksum: sha256:...`.
   `get_url` verifies the checksum itself and fails the task on a mismatch —
   a corrupted or tampered download never reaches disk in a "successful"
   state. It is also idempotent: when the destination already matches the
   checksum, the download is skipped and the task reports OK, not `changed`.
3. `stat` + `assert` over all three destination paths, confirming the
   binaries are actually present — a task never reports OK without the
   artifact being there.
4. Installs the systemd unit (`templates/awg-quick@.service.j2`) to
   `/etc/systemd/system/awg-quick@.service`, since the release ships
   binaries only (no unit, no man pages, no bash completion). The template
   sets `WG_QUICK_USERSPACE_IMPLEMENTATION={{ amneziawg_go_bin }}` directly
   in the unit, forcing the userspace datapath explicitly rather than
   relying on `command -v amneziawg-go` PATH resolution at service-start
   time — no separate per-interface drop-in is needed for this.

Binaries live in `/usr/local/bin`, not `/usr/bin`: they are not
distro-packaged, and `/usr/local/bin` avoids ever clobbering an apt-owned
`/usr/bin/awg`. `awg-quick` still finds `awg` unconditionally because the
shipped script prepends its own directory to `PATH` — see its `SELF`/`PATH`
line — so `awg-quick` and `awg` living together in `/usr/local/bin` is
sufficient; no PATH change on the host is required.

### Idempotency & clean parity

- **Fresh (fully cleaned) host, one run:** all three `get_url` tasks
  download and checksum-verify; the unit is templated fresh.
- **Second consecutive run on a fully installed host:** all three
  downloads are skipped (checksum already matches) and the templated unit
  is unchanged — a true no-op.
- **`99-clean.yml` removes exactly what `30-install.yml`/`60-add-clients.yml`
  created** (the three binaries, the systemd unit, config/working dirs,
  sysctl file, modules-load.d file, runtime socket dir) and nothing else — it
  does **not** unload the shared `tun` module and does **not** touch apt
  sources (this role never adds any). It additionally removes known leftover
  paths from the previous build-from-source version of this role (old
  `/usr/bin` binaries, man pages, bash completions, the per-interface
  drop-in, the upstream-shipped unit/target under
  `/usr/lib/systemd/system`), so the clean tag still fully cleans a host that
  ran an earlier version. A plain `install` run after `clean` reconstructs
  everything from scratch, including fresh server/client keys and
  obfuscation params (deliberate — same as the kernel role, `/etc/amnezia/
  amneziawg` is wiped wholesale on clean).

## Obfuscation parameters

Generated once and persisted in `/etc/amnezia/amneziawg/server_params.yml`
(never regenerated on later runs, so keys/params stay stable):

| Key | Meaning | How set |
|---|---|---|
| `Jc` / `Jmin` / `Jmax` | junk packet count / size bounds | random, generated |
| `S1` / `S2` / `S3` / `S4` | padding: init / response / cookie / transport | random, generated |
| `H1` / `H2` / `H3` / `H4` | magic headers: init / response / cookie / transport | random, generated |
| `I1`-`I5` | imitator/CPS strings | operator-supplied var, empty by default, **never** generated or persisted to `server_params.yml` |

- `S1`-`S4` and `H1`-`H4` **must** be identical on server and every client — they change the on-wire framing both sides parse.
- `Jc`/`Jmin`/`Jmax` and `I1`-`I5` do **not** have to match: the receiver does not validate junk or imitator packets, so each side can run its own values. This role nevertheless renders the same persisted values into the server config and every `client.conf`, because one shared set is simpler to reason about.
- The must-match/need-not-match distinction is documented in the community installer's `ADVANCED.md` rather than proven in upstream source; treat the "need not match" cases as documentation-level confidence, while the "must match" cases for S/H are the safer assumption either way.

## Verification (`70-verify.yml`)

Read-only checks, run every time as the last pipeline phase:

- interface `{{ amneziawg_interface }}` exists (`ip link show`);
- `/var/run/amneziawg/{{ amneziawg_interface }}.sock` exists — the positive
  proof that `amneziawg-go`, not the kernel module, owns the interface;
- `{{ amneziawg_awg_bin }} show {{ amneziawg_interface }}` lists exactly
  `amneziawg_clients | length` peers.

**Deliberately not checked:** whether `I1`-`I5` show up anywhere in `awg show`
output. There is no verified evidence (source or docs) that the imitator
strings are exposed by the standard show command at all — asserting on it
would be inventing behavior, so it's left out. If you need to confirm I1-I5
are active, do it out-of-band (packet capture of the handshake).

## Client private keys live on the server

Same trade-off as `roles/amneziawg2-install`: client private keys are
generated server-side, stored under `/etc/amnezia/amneziawg/clients/` and
rendered into `{{ amnezia_working_dir }}/*.conf` (+ QR PNGs) for
distribution. A host compromise exposes all client keys.

## Variables (`defaults/main.yml`)

Shared knobs use the **same names** as `roles/amneziawg2-install` so existing
`env/<env>/group_vars/<group>/vars.yml` files apply unchanged:

- `amneziawg_interface` (`awg0`), `amneziawg_port` (`49666`)
- `amneziawg_mtu` (`1380`), `amneziawg_subnet`, `amneziawg_ipv6_subnet`
- `amnezia_working_dir` (`/opt/awg`), `amnezia_wan_interface` (auto),
  `amnezia_endpoint_address` (auto)
- `amneziawg_clients` — list of `{name, ip, ipv6?}`

Release/checksum pins (new to this role):

- `amneziawg_go_tag` (`v3.0.2`) / `amneziawg_tools_tag` (`v3.0.20260730`) —
  functional, matched pair; see "Pinned versions" above
- `amneziawg_release_repo` (`denisitpro/amnezia-binary`), `amneziawg_release_tag`,
  `amneziawg_release_base_url` — composed from the two tags above
- `amneziawg_go_sha256`, `amneziawg_awg_sha256`, `amneziawg_awg_quick_sha256`
  — copied verbatim from the release's `SHA256SUMS`, never invented
- `amneziawg_bin_dir` (`/usr/local/bin`), `amneziawg_go_bin`,
  `amneziawg_awg_bin`, `amneziawg_awg_quick_bin` — final binary paths,
  derived from `amneziawg_bin_dir`

Optional imitators: `amneziawg_i1` .. `amneziawg_i5` (all `""` by default —
see "I1-I5" above).

Deliberately **not** exposed as variables (hardcoded, same as the kernel
role): client DNS servers, `PersistentKeepalive`, iptables rule shape,
obfuscation generation ranges, systemd unit dir, `amneziawg-go` log level.

## Cosmetic note

Unless `WG_PROCESS_FOREGROUND=1` is set, `amneziawg-go` prints a boxed
warning to the journal on start ("Running amneziawg-go is not required
because this kernel has first class support...") — this is cosmetic noise,
not an error, and expected on every start since the kernel module is
intentionally absent. No variable is provided for it, and the templated
systemd unit does not set `WG_PROCESS_FOREGROUND` — `awg-quick` relies on
`amneziawg-go` forking to the background.

## Running

Wire the role into any playbook that targets the VPN host(s), then run with
the role tags:

```sh
ansible-playbook -i inventory playbook.yml --tags awg-userspace
```

## Tags

`awg-userspace` (all), `-prefly`, `-install`, `-generate`, `-add-client`,
`-verify`, and `awg-userspace-clean` (teardown, `never` by default).

## Mutual exclusion

Do not run this role and `roles/amneziawg2-install` on the same host — both
own `awg-quick@<iface>` and `/etc/amnezia/amneziawg`. Pick one per host. This
role's `05-prefly.yml` refuses to proceed if the AmneziaWG kernel module is
either **loaded** (`/sys/module/amneziawg` exists) or merely **installed and
available** (`modinfo amneziawg` succeeds), because an installed-but-unloaded
module gets auto-loaded via the rtnl-link alias when `awg-quick` runs `ip link
add ... type amneziawg`, which would win the fallback race and silently disable
I1-I5. The `amneziawg-dkms` package must therefore be removed (via the kernel
role's `--tags amneziawg2-clean`), not just unloaded.
