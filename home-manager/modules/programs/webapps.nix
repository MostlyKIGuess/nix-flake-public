{ ... }:
{
  # Web apps launched in Helium's app mode (chromeless standalone windows).
  xdg.desktopEntries = {
    whatsapp = {
      name = "WhatsApp";
      exec = "helium --app=https://web.whatsapp.com";
      icon = "whatsapp";
      categories = [ "Network" "InstantMessaging" ];
      settings.StartupWMClass = "web.whatsapp.com";
    };

    rrc-zulip = {
      name = "RRC Zulip";
      exec = "helium --app=https://rrc-iiith.zulipchat.com";
      icon = "zulip";
      categories = [ "Network" "InstantMessaging" ];
      settings.StartupWMClass = "rrc-iiith.zulipchat.com";
    };
  };
}
