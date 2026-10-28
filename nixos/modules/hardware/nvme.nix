{ pkgs, ... }:
{
  # Tooling only. Drive-specific quirks (e.g. the APST workaround on og's
  # Kingston NV2) live in the host that needs them.
  environment.systemPackages = with pkgs; [
    nvme-cli
    smartmontools
  ];
}
