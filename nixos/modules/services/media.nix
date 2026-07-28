{ lib, ... }:
{
  services = {
    sonarr = {
      enable = true;
      group = "media";
    };
    radarr = {
      enable = true;
      group = "media";
      openFirewall = false;
      settings.server.bindAddress = "127.0.0.1";
    };
    prowlarr.enable = true;
    flaresolverr.enable = true;
    jellyfin.enable = true;
  };

  systemd.services = {
    sonarr = {
      wantedBy = lib.mkForce [ ];

      # Sonarr needs access to the library inside the user's home directory.
      serviceConfig.ProtectHome = lib.mkForce false;
    };
    radarr = {
      wantedBy = lib.mkForce [ ];

      # Radarr needs access to the library inside the user's home directory.
      serviceConfig.ProtectHome = lib.mkForce false;
    };
    prowlarr = {
      wantedBy = lib.mkForce [ ];
      wants = [ "flaresolverr.service" ];
      after = [ "flaresolverr.service" ];
    };
    flaresolverr = {
      wantedBy = lib.mkForce [ ];
      partOf = [ "prowlarr.service" ];
    };
    jellyfin.wantedBy = lib.mkForce [ ];
  };

  users = {
    groups.media.gid = 982;
    users = {
      mostlyk.extraGroups = [ "media" ];
      jellyfin.extraGroups = [ "media" ];
    };
  };

  systemd.tmpfiles.rules = [
    "a+ /home/mostlyk - - - - mask::x,g:media:x"
    "d /home/mostlyk/tv 2775 mostlyk media - -"
    "A+ /home/mostlyk/tv - - - - mask::rwX,g:media:rwX,d:mask::rwx,d:g:media:rwx"
    "d /home/mostlyk/movies 2775 mostlyk media - -"
    "A+ /home/mostlyk/movies - - - - mask::rwX,g:media:rwX,d:mask::rwx,d:g:media:rwx"
  ];

  # Expose Jellyfin only through the Wi-Fi/LAN interface.
  networking.firewall.interfaces.wlp4s0 = {
    allowedTCPPorts = [
      8096 # HTTP
      8920 # HTTPS
    ];
    allowedUDPPorts = [
      1900 # DLNA discovery
      7359 # Client discovery
    ];
  };
}
