{ ... }:
let
  addon = slug: {
    install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
    installation_mode = "normal_installed";
  };
in
{
  programs.firefox = {
    enable = true;
    configPath = ".mozilla/firefox";
    policies = {
      DisableTelemetry = true;
      DisablePocket = true;
      DontCheckDefaultBrowser = true;
      Preferences = {
        # restore previous session on startup
        "browser.startup.page" = { Value = 3; Status = "default"; };
      };
      ExtensionSettings = {
        "uBlock0@raymondhill.net" = addon "ublock-origin";
        "addon@darkreader.org" = addon "darkreader";
        "sponsorBlocker@ajay.app" = addon "sponsorblock";
        "{d7742d87-e61d-4b78-b8a1-b469842139fa}" = addon "vimium-ff";
        "{a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad}" = addon "refined-github-";
      };
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "x-scheme-handler/http" = "firefox.desktop";
      "x-scheme-handler/https" = "firefox.desktop";
      "text/html" = "firefox.desktop";
    };
  };
}
