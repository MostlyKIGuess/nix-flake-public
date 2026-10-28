{ config, lib, ... }:
let
  warp-cli = "${config.services.cloudflare-warp.package}/bin/warp-cli --accept-tos";

  excludedHosts = [
    "iiit.ac.in"
    "courses.iiit.ac.in"
    "dining.iiit.ac.in"
    "cache.nixos.org"
    "download.nvidia.com"
    "scholar.google.com"
    "scholar.google.co.in"
    "google.com"
    "*.google.com"
    "gstatic.com"
    "*.gstatic.com"
    "reddit.com"
    "*.reddit.com"
    "redditstatic.com"
    "*.redditstatic.com"
    "redd.it"
    "*.redd.it"
    "ieeexplore.ieee.org"
    "steampowered.com"
    "store.steampowered.com"
    "gov.in"
    "www.fellowship.indiaai.gov.in"
    "car-soccer.net"
  ];

  fallbackDomains = [ "iiit.ac.in" ];
in
{
  services.cloudflare-warp.enable = true;

  systemd.services.warp-split-tunnel = {
    description = "Apply Cloudflare WARP split tunnel hosts";
    after = [ "cloudflare-warp.service" ];
    requires = [ "cloudflare-warp.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      for _ in $(seq 30); do
        ${warp-cli} status >/dev/null 2>&1 && break
        sleep 1
      done
      current=$(${warp-cli} tunnel host list)
      for h in ${lib.escapeShellArgs excludedHosts}; do
        grep -qF "  $h " <<<"$current" || ${warp-cli} tunnel host add "$h"
      done
      fallback=$(${warp-cli} dns fallback list)
      for d in ${lib.escapeShellArgs fallbackDomains}; do
        grep -qF "  $d " <<<"$fallback" || ${warp-cli} dns fallback add "$d"
      done
    '';
  };
}
