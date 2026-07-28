{ ... }:
{
  imports = [
    ./daemon.nix
    ./audio.nix
    ./ssh.nix
    ./docker.nix
    ./gaming.nix
    ./media.nix
  ];

  services.cloudflare-warp.enable = true;
}
