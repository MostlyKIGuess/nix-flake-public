{ ... }:
{
  services.openssh = {
    enable = false; # Uncomment to allow incoming SSH connections
    settings = {
      X11Forwarding = true;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
    };
    openFirewall = true;
  };
}
