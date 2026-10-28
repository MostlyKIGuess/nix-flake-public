{ pkgs, ... }:
{
  hardware.cpu.intel.updateMicrocode = true;

  # Arc 140T (Xe-LPG+): the kernel picks the DRM driver itself; confirm with
  # `lspci -k | grep -A3 VGA` after install and only pin a module if it guesses
  # wrong.
  hardware.graphics.extraPackages = with pkgs; [
    intel-media-driver # VA-API (iHD)
    vpl-gpu-rt # oneVPL runtime, used by newer ffmpeg/OBS
    intel-compute-runtime # OpenCL / Level Zero
  ];

  environment.variables.LIBVA_DRIVER_NAME = "iHD";

  services.thermald.enable = true;

  environment.systemPackages = with pkgs; [
    intel-gpu-tools # intel_gpu_top
  ];
}
