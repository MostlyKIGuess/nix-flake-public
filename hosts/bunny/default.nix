# bunny: HP laptop, Intel Core Ultra 7 255H (Arrow Lake-H) + Arc 140T iGPU.
# No discrete GPU, no AMD anything: none of og's nvidia/pstate/zenpower apply.
#
# Both hosts set networking.hostName = "mostlyk", so hostname-based resolution
# is ambiguous. Rebuild with an explicit host:
#   nh os switch /home/mostlyk/.dotfiles -H bunny
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./intel.nix
  ];

  boot.initrd.luks.devices."luks-7b86fea6-f837-47c3-a2f3-15ba444bbf69".device =
    "/dev/disk/by-uuid/7b86fea6-f837-47c3-a2f3-15ba444bbf69";

  boot.resumeDevice = "/dev/mapper/luks-7b86fea6-f837-47c3-a2f3-15ba444bbf69";

  networking.networkmanager.connectionConfig = {
    "ipv4.dhcp-send-hostname" = false;
    "ipv6.dhcp-send-hostname" = false;
  };

  system.autoUpgrade.flake = "/home/mostlyk/.dotfiles#bunny";

  environment.shellAliases.rebuild = "nh os switch /home/mostlyk/.dotfiles -H bunny";

  system.stateVersion = "26.05";
}
