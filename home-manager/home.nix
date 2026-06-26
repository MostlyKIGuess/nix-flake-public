{ pkgs, ... }:
{
  home.username = "mostlyk";
  home.homeDirectory = "/home/mostlyk";

  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  xresources.properties = {
    "Xft.dpi" = 192;
  };

  imports = [
    ./packages.nix
    ./modules
  ];

  home.stateVersion = "24.05";
  programs.home-manager.enable = true;
}
