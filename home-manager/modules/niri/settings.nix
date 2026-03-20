{ pkgs, config, ... }:
{
  programs.niri.settings = {
    outputs = {
      "eDP-2" = {
        mode = { width = 1920; height = 1080; refresh = 144.0; };
        position = { x = 0; y = 0; };
      };
      "HDMI-A-1" = {
        mode = { width = 1920; height = 1080; refresh = 100.0; };
        position = { x = 1920; y = 0; };
      };
    };

    input = {
      keyboard = {
        xkb.layout = "us";
        numlock = true;
      };
      touchpad = {
        tap = true;
        natural-scroll = true;
      };
      mouse.enable = true;
      trackpoint.enable = true;
      focus-follows-mouse = {
        enable = true;
        max-scroll-amount = "0.0%";
      };
    };

    prefer-no-csd = true;

    layout = {
      gaps = 10;
      center-focused-column = "never";

      preset-column-widths = [
        { proportion = 0.33333; }
        { proportion = 0.5; }
        { proportion = 0.66667; }
      ];

      default-column-width.proportion = 0.5;

      focus-ring.enable = false;

      border = {
        enable = true;
        width = 2;
        active.color = "#cba6f7";
        inactive.color = "#505050";
        urgent.color = "#9b0000";
      };

      shadow.enable = false;
    };

    hotkey-overlay.skip-at-startup = true;

    environment = {
      SSH_AUTH_SOCK = "/run/user/1000/keyring/ssh";
      NIXOS_OZONE_WL = "1";
      XDG_CURRENT_DESKTOP = "niri";
      XDG_SESSION_DESKTOP = "niri";
      QT_QPA_PLATFORMTHEME = "gtk3";
    };

    spawn-at-startup = [
      { command = [ "swww-daemon" ]; }
      { command = [ "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1" ]; }
      { command = [ "xwayland-satellite" ]; }
      { command = [ "wl-paste" "--type" "text" "--watch" "cliphist" "store" ]; }
      { command = [ "wl-paste" "--type" "image" "--watch" "cliphist" "store" ]; }
    ];

    screenshot-path = "~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png";

    animations.slowdown = 1.0;

    overview = {
      zoom = 0.5;
      workspace-shadow.enable = false;
    };

    gestures.hot-corners.enable = false;

    debug.honor-xdg-activation-with-invalid-serial = true;
  };
}
