{ lib, pkgs, ... }:
let
  addons = {
    "uBlock0@raymondhill.net" = "ublock-origin";
    "{446900e4-71c2-419f-a6a7-df9c091e268b}" = "bitwarden-password-manager";
    "contact@alphaxiv.org" = "alphaxiv";
    "clipper@obsidian.md" = "web-clipper-obsidian";
    "{a4c4eda4-fb84-4a84-b4a1-f7c1cbf2a1ad}" = "refined-github-";
    "idcac-pub@guus.ninja" = "istilldontcareaboutcookies";
    "{2766e9f7-7bf2-4c72-81b9-d119eb54c753}" = "remove-youtube-shorts";
    "leechblockng@proginosko.com" = "leechblock-ng";
  };

  removed = [
    "{3c078156-979c-498b-8990-85f7987dd929}"
    "sponsorBlocker@ajay.app"
    "jid1-BoFifL9Vbdl2zQ@jetpack"
    "{4f391a9e-8717-4ba6-a5b1-488a34931fcb}"
    "{74e326aa-c645-4495-9287-b6febc5565a7}"
    "{5dd8fd6e-0733-41a7-abc4-e19fba703de9}"
    "{709c6d79-20b9-430d-a8e9-f12583ac3b17}"
    "{f0eeb71a-e5d6-48e6-a818-568a6bef1bc0}"
    "{31a4c81b-add0-4ce4-b6e4-b54dcb0f4d1b}"
    "move_tabs_hotkeys@jmmerz.github"
    "chrome-gnome-shell@gnome.org"
    "firefox@tampermonkey.net"
    "{e4a8a97b-f2ed-450b-b12d-ee082ba24781}"
  ];
in
{
  programs.firefox = {
    enable = true;
    package = pkgs.firefox.override {
      extraAutoConfig = ''pref("general.config.sandbox_enabled", false);'';
    };
    autoConfig = builtins.readFile ./firefox-autoconfig.js;
    policies.ExtensionSettings =
      lib.mapAttrs
        (_: slug: {
          installation_mode = "normal_installed";
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/${slug}/latest.xpi";
        })
        addons
      // lib.genAttrs removed (_: { installation_mode = "blocked"; });
    policies.SearchEngines = {
      Default = "Brave Search";
      Add = [
        {
          Name = "Brave Search";
          URLTemplate = "https://search.brave.com/search?q={searchTerms}";
          SuggestURLTemplate = "https://search.brave.com/api/suggest?q={searchTerms}";
          IconURL = "https://cdn.search.brave.com/serp/v1/static/brand/12832ccf4a94a6fe2ecc75f7ee0df48677abeab018d165ce25b7414477384367-favicon-96x96.png";
          Method = "GET";
          Alias = "@brave";
        }
      ];
    };
  };
}
