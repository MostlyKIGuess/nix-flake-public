{ pkgs, host, ... }:
{
  home.username = "mostlyk";
  home.homeDirectory = "/home/mostlyk";

  home.pointerCursor = {
    enable = true;
    gtk.enable = true;
    x11.enable = true;
    name = "Bibata-Modern-Ice";
    package = pkgs.bibata-cursors;
    size = 24;
  };

  xresources.properties = {
    # Matches the niri output scale in modules/niri/settings.nix:
    # og runs 2x, bunny's 14" 3K panel runs 1.5x.
    "Xft.dpi" = if host == "bunny" then 144 else 192;
  };

  imports = [
    ./packages.nix
    ./modules
  ];

  home.stateVersion = if host == "bunny" then "26.05" else "24.05";
  programs.home-manager.enable = true;
}
