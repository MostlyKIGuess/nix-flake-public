{ ... }:
{
  services.openssh = {
    enable = true; # Uncomment to allow incoming SSH connections
    settings = {
      X11Forwarding = true;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
    openFirewall = true;
  };
}
