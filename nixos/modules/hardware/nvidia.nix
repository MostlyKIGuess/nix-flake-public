{ config, ... }:
{
  hardware.nvidia = {
    powerManagement = {
      enable = true;
      finegrained = true;
    };

    dynamicBoost.enable = true;
    modesetting.enable = true;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = true;
      };
      amdgpuBusId = "PCI:6:0:0";
      nvidiaBusId = "PCI:1:0:0";
    };

    nvidiaSettings = true;
    nvidiaPersistenced = true;

    package = config.boot.kernelPackages.nvidiaPackages.stable;
    open = false;
  };

  services.xserver.videoDrivers = [ "nvidia" ];
}
