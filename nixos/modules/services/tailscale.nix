{ pkgs, ... }:
let
  rule = "fwmark 0x80000/0xff0000 lookup 65743 priority 5200";
in
{
  services.tailscale = {
    enable = true;
    openFirewall = true;
    extraSetFlags = [ "--accept-dns=false" ];
  };

  systemd.services.tailscale-through-warp = {
    description = "Send tailscaled's own traffic through the WARP routing table";
    after = [ "tailscaled.service" "cloudflare-warp.service" ];
    wantedBy = [ "multi-user.target" ];
    path = [ pkgs.iproute2 ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    script = ''
      ip -4 rule del ${rule} 2>/dev/null || true
      ip -6 rule del ${rule} 2>/dev/null || true
      ip -4 rule add ${rule}
      ip -6 rule add ${rule}
    '';
    preStop = ''
      ip -4 rule del ${rule} 2>/dev/null || true
      ip -6 rule del ${rule} 2>/dev/null || true
    '';
  };
}
