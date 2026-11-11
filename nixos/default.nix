# Shared NixOS configuration, imported by every host in ../hosts.
# Anything that differs between machines belongs in hosts/<name>/, not here.
{ pkgs, ... }:
{
  imports = [
    ./modules
  ];

  # Same on both machines by choice: the flake output name (og/bunny) is what
  # distinguishes them, not the hostname. See hosts/*/default.nix for why that
  # means rebuilds must name the host explicitly.
  networking.hostName = "mostlyk";
  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [ networkmanager-openvpn ];
  };

  time.timeZone = "Asia/Kolkata";
  services.timesyncd.enable = true;

  services.xserver.enable = true;
  services.fwupd.enable = true;
  services.printing.enable = true;
  services.libinput.enable = true;

  networking.firewall.enable = true;

  users.users.mostlyk = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "dialout" "libvirtd" ];
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.optimise.automatic = true;

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://mostlyk.cachix.org"
      "https://niri.cachix.org/"
      "https://noctalia.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "mostlyk.cachix.org-1:nsaS16kwEs4fRnKYpCpOtIDzjkdOqD7rbgj0/KFku7k="
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "noctalia.cachix.org-1:pCOR47nnMEo5thcxNDtzWpOxNFQsBRglJzxWPp3dkU4="
    ];
    narinfo-cache-negative-ttl = 0;
  };

  environment.shells = with pkgs; [ zsh ];
  users.defaultUserShell = pkgs.zsh;
  programs.zsh.enable = true;

  programs.nix-ld = {
    enable = true;
    package = pkgs.nix-ld;
  };

  environment.variables.EDITOR = "nvim";

  environment.systemPackages = with pkgs; [
    wget
    curl
    git
  ];

  programs.nh = {
    enable = true;
    clean.enable = true;
    clean.dates = "daily";
    clean.extraArgs = "--keep-since 7d --keep 10";
    flake = "/home/mostlyk/.dotfiles";
  };

  virtualisation.libvirtd.enable = true;
}
