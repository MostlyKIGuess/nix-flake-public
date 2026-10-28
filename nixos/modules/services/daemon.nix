{ ... }:
{
  systemd.sleep.settings.Sleep.HibernateDelaySec = "45min";

  services = {
    acpid.enable = true;

    power-profiles-daemon.enable = false;
    auto-cpufreq = {
      enable = true;
      settings = {
        charger = {
          governor = "performance";
          turbo = "always";
        };
        battery = {
          governor = "powersave";
          turbo = "auto";
        };
      };
    };

    hardware.bolt.enable = true;

    logind.settings = {
      Login = {
        HandlePowerKey = "poweroff";
        HandleLidSwitch = "suspend-then-hibernate";
        HandleLidSwitchExternalPower = "suspend";
      };
    };

    upower = {
      enable = true;
      percentageLow = 20;
      percentageCritical = 10;
      percentageAction = 5;
      criticalPowerAction = "HybridSleep";
    };
  };
}
