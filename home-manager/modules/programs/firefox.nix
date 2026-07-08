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
      "x-scheme-handler/chrome" = "firefox.desktop";
      "x-scheme-handler/about" = "firefox.desktop";
      "x-scheme-handler/unknown" = "firefox.desktop";
      "x-scheme-handler/mailto" = "firefox.desktop";
      "text/html" = "firefox.desktop";
      "application/xhtml+xml" = "firefox.desktop";

      "application/pdf" = "org.gnome.Evince.desktop";

      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "image/gif" = "org.gnome.Loupe.desktop";
      "image/webp" = "org.gnome.Loupe.desktop";
      "image/svg+xml" = "org.gnome.Loupe.desktop";
      "image/bmp" = "org.gnome.Loupe.desktop";
      "image/tiff" = "org.gnome.Loupe.desktop";
      "image/avif" = "org.gnome.Loupe.desktop";

      "x-scheme-handler/discord" = "vesktop.desktop";
      "x-scheme-handler/sgnl" = "signal.desktop";
      "x-scheme-handler/signalcaptcha" = "signal.desktop";
      "x-scheme-handler/slack" = "slack.desktop";
      "x-scheme-handler/magnet" = "org.qbittorrent.qBittorrent.desktop";
      "x-scheme-handler/claude-cli" = "claude-code-url-handler.desktop";
    };
  };
}
