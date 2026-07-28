{ ... }:
{
  xdg.desktopEntries.element-iiith = {
    name = "Element (IIITH)";
    genericName = "School Matrix Client";
    comment = "Element profile for IIITH";
    exec = "element-desktop --profile iiith %u";
    icon = "element";
    terminal = false;
    categories = [
      "Network"
      "InstantMessaging"
      "Chat"
    ];
  };
}
