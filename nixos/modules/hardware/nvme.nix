{ pkgs, ... }:
{
  boot.kernelParams = [ "nvme_core.default_ps_max_latency_us=0" ];

  environment.systemPackages = with pkgs; [
    nvme-cli
    smartmontools
  ];
}
