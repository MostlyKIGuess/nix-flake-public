{ pkgs, ... }:
{
  programs.gamemode.enable = true;

  environment.systemPackages = with pkgs; [
    lutris
    transmission_4-gtk
    wineWow64Packages.stable
    protonup-qt
  ];
}
