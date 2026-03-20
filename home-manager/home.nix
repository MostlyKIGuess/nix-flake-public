{ lib, ... }:
{
  home.username = "mostlyk";
  home.homeDirectory = "/home/mostlyk";

  xresources.properties = {
    "Xcursor.size" = lib.mkDefault 16;
    "Xft.dpi" = 192;
  };

  imports = [
    ./packages.nix
    ./modules
  ];

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
}
