{ ... }:
{
  services = {
    acpid.enable = true;

    power-profiles-daemon.enable = false;
    auto-cpufreq.enable = true;

    hardware.bolt.enable = true;

    logind.settings = {
      Login = {
        HandlePowerKey = "poweroff";
        HandleLidSwitch = "hibernate";
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
