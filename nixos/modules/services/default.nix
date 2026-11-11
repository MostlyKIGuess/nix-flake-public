{ ... }:
{
  imports = [
    ./daemon.nix
    ./audio.nix
    ./ssh.nix
    ./podman.nix
    ./gaming.nix
    ./optiscaler.nix
    ./media.nix
    ./kanata.nix
    ./warp.nix
    ./tailscale.nix
  ];
}
