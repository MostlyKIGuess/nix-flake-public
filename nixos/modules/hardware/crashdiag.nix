{ ... }:
{
  boot.kernel.sysctl = {
    "kernel.panic_on_oops" = 1;
    "kernel.panic" = 20;
  };

  services.journald.extraConfig = ''
    SyncIntervalSec=20s
  '';
}
