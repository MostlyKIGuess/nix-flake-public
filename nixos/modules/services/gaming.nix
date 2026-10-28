{ pkgs, ... }:
{
  programs = {
    gamemode.enable = true;
    steam.enable = true;
    gamescope = {
      enable = true;
      capSysNice = false;
    };
  };

  environment.systemPackages = with pkgs; [
    lutris
    transmission_4-gtk
    wineWow64Packages.stable
    protonup-qt
    mangohud
  ];
}
