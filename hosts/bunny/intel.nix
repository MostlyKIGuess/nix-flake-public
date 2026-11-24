{ pkgs, ... }:
{
  hardware.cpu.intel.updateMicrocode = true;

  # Arc 140T (Xe-LPG+, PCI ID 7d51).
  # Check with `lspci -k | grep -A3 VGA`.
  boot.kernelParams = [
    "i915.force_probe=!7d51"
    "xe.force_probe=7d51"
  ];

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
