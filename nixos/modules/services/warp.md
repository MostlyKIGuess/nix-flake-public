# Cloudflare WARP setup

This machine uses Cloudflare WARP in normal WARP mode, but keeps a few local
and infrastructure domains out of the tunnel so Nix, Nvidia downloads, and
IIIT intranet services keep working.

## Desired state

- WARP runs in `warp` mode, not proxy-only mode.
- `cache.nixos.org` bypasses WARP.
- `download.nvidia.com` bypasses WARP.
- `iiit.ac.in` uses the local network DNS fallback instead of WARP DNS.
- Private campus routes, such as `10.0.0.0/8`, should stay reachable over Wi-Fi.

## One-time setup

```bash
warp-cli mode warp

warp-cli tunnel host add cache.nixos.org
warp-cli tunnel host add download.nvidia.com
warp-cli tunnel host add scholar.google.com

warp-cli dns fallback add iiit.ac.in
```

If IIIT services resolve to `10.x.x.x` addresses but traffic still goes through
WARP, exclude the campus private range too:

```bash
warp-cli tunnel ip add 10.0.0.0/8
```

Then reconnect WARP:

```bash
warp-cli disconnect
warp-cli connect
```

## Check current config

```bash
warp-cli status
warp-cli settings list
warp-cli tunnel host list
warp-cli tunnel ip list
warp-cli dns fallback list
```

Expected important entries:

```text
cache.nixos.org
download.nvidia.com
iiit.ac.in
```

## IIIT debugging

Campus services should resolve to internal addresses while on IIITH Wi-Fi:

```bash
dig courses.iiit.ac.in
```

Expected shape:

```text
courses.iiit.ac.in. A 10.x.x.x
```

Routing should stay on Wi-Fi, not through WARP:

```bash
ip route get 10.x.x.x
```

Expected shape:

```text
10.x.x.x via 10.2.128.1 dev wlp4s0 ...
```

If DNS is the only failing piece, force the mapping once to prove TLS and routing are fine:

```bash
curl -vk --resolve courses.iiit.ac.in:443:10.x.x.x https://courses.iiit.ac.in
```

If that works but normal `curl https://courses.iiit.ac.in` does not, the problem is WARP DNS fallback/split DNS, not the route.
