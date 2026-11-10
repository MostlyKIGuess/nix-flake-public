{ pkgs, inputs, ... }:
let
  stable = import inputs.nixpkgs-stable {
    system = pkgs.stdenv.hostPlatform.system;
    config.allowUnfree = true;
  };
in
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
    stable.lutris
    transmission_4-gtk
    wineWow64Packages.stable
    protonup-qt
    mangohud
  ];
}
