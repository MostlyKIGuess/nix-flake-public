{ ... }:
{
  xdg.desktopEntries.signal = {
    name = "Signal";
    genericName = "Messenger";
    exec = "signal-desktop --password-store=gnome-libsecret %U";
    icon = "signal-desktop";
    terminal = false;
    categories = [ "Network" "InstantMessaging" ];
  };
}
