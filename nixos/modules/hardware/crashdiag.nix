{ ... }:
{
  boot.kernel.sysctl = {
    "kernel.panic_on_oops" = 1;
    "kernel.panic" = 20;
  };

  services.journald.settings.Journal = {
    SyncIntervalSec = "20s";
  };
}
