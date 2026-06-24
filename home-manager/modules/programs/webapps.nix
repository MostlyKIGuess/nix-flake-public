{ pkgs, ... }:
let
  papirusApps = "${pkgs.papirus-icon-theme}/share/icons/Papirus/128x128/apps";
in
{
  xdg.desktopEntries = {
    whatsapp = {
      name = "WhatsApp";
      exec = "helium --app=https://web.whatsapp.com";
      icon = "${papirusApps}/whatsapp.svg";
      categories = [ "Network" "InstantMessaging" ];
      settings.StartupWMClass = "chrome-web.whatsapp.com__-Default";
    };

    rrc-zulip = {
      name = "RRC Zulip";
      exec = "helium --app=https://rrc-iiith.zulipchat.com";
      icon = "${papirusApps}/zulip.svg";
      categories = [ "Network" "InstantMessaging" ];
      settings.StartupWMClass = "chrome-rrc-iiith.zulipchat.com__-Default";
    };
  };
}
