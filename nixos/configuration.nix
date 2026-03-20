{ pkgs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules
  ];

  networking.hostName = "mostlyk";
  networking.networkmanager = {
    enable = true;
    plugins = with pkgs; [ networkmanager-openvpn ];
  };

  time.timeZone = "Asia/Kolkata";

  services.xserver.enable = true;
  services.fwupd.enable = true;
  services.printing.enable = true;
  services.libinput.enable = true;
  networking.firewall.enable = true;
  networking.firewall.trustedInterfaces = [ "docker0" ];

  users.users.mostlyk = {
    isNormalUser = true;
    extraGroups = [ "networkmanager" "wheel" "dialout" "docker" "libvirtd" ];
    packages = with pkgs; [ firefox ];
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings.trusted-users = [ "root" "@wheel" ];
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.optimise.automatic = true;

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://mostlyk.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "mostlyk.cachix.org-1:nsaS16kwEs4fRnKYpCpOtIDzjkdOqD7rbgj0/KFku7k="
    ];
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

  # Auto-upgrade: daily fetch, no auto-reboot (review before rebooting on Nvidia)
  system.autoUpgrade = {
    enable = true;
    dates = "04:00";
    flake = toString ./.;
    flags = [
      "--update-input"
      "nixpkgs"
      "--commit-lock-file"
    ];
    allowReboot = false;
  };

  virtualisation.libvirtd.enable = true;

  system.stateVersion = "24.05";
}
