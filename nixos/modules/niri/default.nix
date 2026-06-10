{ inputs, pkgs, ... }:
let
  stablePkgs = import inputs.nixpkgs-stable {
    system = "x86_64-linux";
    config.allowUnfree = true;
  };
in
{
  nixpkgs.overlays = [
    (_final: _prev: {
      gdm = stablePkgs.gdm;
      gnome-control-center = stablePkgs.gnome-control-center;
      gnome-session = stablePkgs.gnome-session;
      gnome-shell = stablePkgs.gnome-shell;
      mutter = stablePkgs.mutter;
    })
  ];

  programs.niri.enable = true;

  services.displayManager.gdm.enable = true;
  services.blueman.enable = true;

  xdg.portal.enable = true;
  xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gtk ];

  services.gnome.gnome-keyring.enable = true;
  security.pam.services.gdm.enableGnomeKeyring = true;
  security.pam.services.gdm-password.enableGnomeKeyring = true;

  environment.systemPackages = with pkgs; [ polkit_gnome ];

  programs.xfconf.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
}
