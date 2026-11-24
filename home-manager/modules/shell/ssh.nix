{ config, lib, ... }:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;
    settings = {
      "*" = {
        ForwardAgent = lib.mkForce false;
        HashKnownHosts = lib.mkForce true;
        AddKeysToAgent = "yes";
        ServerAliveInterval = 60;
        ServerAliveCountMax = 10;
        Compression = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "auto";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
        SetEnv.TERM = "xterm-256color";
      };

      "github.com" = {
        User = "git";
        HostName = "github.com";
        IdentityFile = "${config.home.homeDirectory}/.ssh/id_mostlyk";
        IdentitiesOnly = true;
      };

      "phoenix" = {
        User = "krish.pandya";
        HostName = "phoenix.rrcx.tk";
        ForwardX11 = true;
        ForwardAgent = true;
      };
      "orion" = {
        User = "krish.pandya";
        HostName = "orion.rrcx.tk";
        ForwardX11 = true;
        ForwardAgent = true;
      };

      "phoenix-intoponav" = {
        User = "intoponav";
        HostName = "phoenix.rrcx.tk";
        ForwardX11 = true;
        ForwardAgent = true;
      };

      "spectre.rrcx.tk" = {
        User = "onyx";
        HostName = "spectre.rrcx.tk";
      };

      "aur.archlinux.org" = {
        User = "aur";
        IdentityFile = "${config.home.homeDirectory}/.ssh/aur";
      };

      "gitlab.gnome.org" = {
        User = "git";
        IdentityFile = "${config.home.homeDirectory}/.ssh/id_mostlyk";
      };

      "oj-test.iiit.ac.in" = {
        User = "root";
        IdentityFile = "${config.home.homeDirectory}/.ssh/id_mostlyk";
      };
    };
  };

  services.ssh-agent.enable = true;
}
