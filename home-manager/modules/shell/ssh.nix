{ config, lib, ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    matchBlocks = {
      "*" = {
        forwardAgent = lib.mkForce false;
        hashKnownHosts = lib.mkForce true;
        addKeysToAgent = "yes";
        serverAliveInterval = 60;
        serverAliveCountMax = 10;
        compression = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "auto";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
        setEnv.TERM = "xterm-256color";
      };

      "github.com" = {
        user = "git";
        hostname = "github.com";
        identityFile = "${config.home.homeDirectory}/.ssh/id_mostlyk";
        identitiesOnly = true;
      };

      "phoenix" = {
        user = "krish.pandya";
        hostname = "phoenix.rrcx.tk";
        forwardX11 = true;
        forwardAgent = true;
      };
      "orion" = {
        user = "krish.pandya";
        hostname = "orion.rrcx.tk";
        forwardX11 = true;
        forwardAgent = true;
      };

      "phoenix-intoponav" = {
        user = "intoponav";
        hostname = "phoenix.rrcx.tk";
        forwardX11 = true;
        forwardAgent = true;
      };

      "spectre.rrcx.tk" = {
        user = "onyx";
        hostname = "spectre.rrcx.tk";
      };

      "aur.archlinux.org" = {
        user = "aur";
        identityFile = "${config.home.homeDirectory}/.ssh/aur";
      };

      "gitlab.gnome.org" = {
        user = "git";
        identityFile = "${config.home.homeDirectory}/.ssh/id_mostlyk";
      };

      "oj-test.iiit.ac.in" = {
        user = "root";
        identityFile = "${config.home.homeDirectory}/.ssh/id_mostlyk";
      };

      "geotrust" = {
        hostname = "34.47.183.174";
        user = "krish";
        identityFile = "${config.home.homeDirectory}/.ssh/google_compute_engine";
      };
    };
  };

  services.ssh-agent.enable = true;
}
