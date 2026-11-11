# og: ASUS laptop, AMD Zen CPU + AMD iGPU + NVIDIA dGPU (PRIME offload).
#
# Both hosts set networking.hostName = "mostlyk", so hostname-based resolution
# is ambiguous. Rebuild with an explicit host:
#   nh os switch /home/mostlyk/.dotfiles -H og
{ inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./nvidia.nix
    ./pstate.nix
    ./zenpower.nix
  ];

  # GPU passthrough into containers, only meaningful on the host with the dGPU.
  hardware.nvidia-container-toolkit.enable = true;

  services.asusd.enable = true;

  # Kingston NV2 aborts the root filesystem when APST drops it into a deep
  # power state. See commit 5d67650.
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" ];

  networking.firewall.interfaces.wlp4s0 = {
    allowedUDPPorts = [
      53 # DNS
      67 # DHCP
    ];
    allowedTCPPorts = [ 53 ]; # DNS fallback
  };

  services.tailscale.extraSetFlags = [ "--hostname=og" ];

  environment.shellAliases.rebuild = "nh os switch /home/mostlyk/.dotfiles -H og";

  system.stateVersion = "24.05";
}
