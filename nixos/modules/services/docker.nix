{ pkgs, ... }:
{
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # Rootless mode: daemon runs as the user, not root.
  # Security +, but requires slirp4netns (handled by NixOS).
  # rootless = {
  #   enable = true;
  #   setSocketVariable = true; # Exports DOCKER_HOST automatically
  #   daemon.settings = {
  #     dns = [ "1.1.1.1" "8.8.8.8" ];
  #   };
  # };

  hardware.nvidia-container-toolkit.enable = true;

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;
  boot.kernel.sysctl."net.ipv6.ip_forward" = 1;

  environment.systemPackages = with pkgs; [
    docker-compose
    lazydocker
    passt
  ];
}
