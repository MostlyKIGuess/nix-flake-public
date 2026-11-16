{ config, pkgs, ... }:
let
  videoText = ./immich-video-text;
  videoTextImage = "localhost/immich-video-text:${
    builtins.substring 0 12 (builtins.hashFile "sha256" "${videoText}/Containerfile")
  }";
in
{
  services.immich = {
    enable = true;
    host = "0.0.0.0";
    machine-learning.enable = false;
  };

  virtualisation.oci-containers.containers.immich-machine-learning = {
    image = "ghcr.io/immich-app/immich-machine-learning:v${config.services.immich.package.version}-cuda";
    ports = [ "127.0.0.1:3003:3003" ];
    volumes = [ "/var/cache/immich-ml:/cache" ];
    extraOptions = [ "--device=nvidia.com/gpu=all" ];
  };

  systemd.services.immich-video-text = {
    description = "Transcribe and read on-screen text from Immich videos";
    after = [
      "immich-server.service"
      "podman-immich-machine-learning.service"
    ];
    path = [
      config.virtualisation.podman.package
      pkgs.coreutils
    ];
    restartIfChanged = false;
    preStart = ''
      mkdir -p /var/cache/immich-video-text/pip
      podman image exists ${videoTextImage} || podman build -t ${videoTextImage} \
        -v /var/cache/immich-video-text/pip:/root/.cache/pip ${videoText}
    '';
    script = ''
      deadline=$(date -d 07:00 +%s)
      [ "$deadline" -gt "$(date +%s)" ] || deadline=$(date -d 'tomorrow 07:00' +%s)
      exec podman run --rm --replace --name immich-video-text \
        --network host --device nvidia.com/gpu=all --cpu-shares 64 --log-driver passthrough \
        -e DEADLINE="$deadline" \
        -v /var/lib/immich-video-text:/data \
        -v /var/cache/immich-video-text:/cache \
        -v ${videoText}/video_text.py:/app/video_text.py:ro \
        ${videoTextImage}
    '';
    serviceConfig = {
      Nice = 19;
      IOSchedulingClass = "idle";
      TimeoutStartSec = "1h";
      RuntimeMaxSec = "6h10min";
    };
  };

  systemd.timers.immich-video-text = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "*-*-* 01:00";
  };

  systemd.tmpfiles.rules = [
    "d /var/cache/immich-ml 0750 root root -"
    "d /var/lib/immich-video-text 0700 root root -"
    "d /var/cache/immich-video-text 0700 root root -"
  ];

  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2283 ];
}
