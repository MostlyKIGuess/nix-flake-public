{ config, ... }:
{
  programs.noctalia = {
    enable = true;
    systemd.enable = true;

    customPalettes.Mostlyk = {
      dark = {
        mPrimary = "#e1e2d5";
        mOnPrimary = "#1d1b1d";
        mSecondary = "#81a1c1";
        mOnSecondary = "#1d1b1d";
        mTertiary = "#a3be8c";
        mOnTertiary = "#1d1b1d";
        mError = "#d94a59";
        mOnError = "#1d1b1d";
        mSurface = "#1d1b1d";
        mOnSurface = "#e1e2d5";
        mSurfaceVariant = "#262427";
        mOnSurfaceVariant = "#e1e2d5";
        mOutline = "#000023";
        mShadow = "#120f18";
        mHover = "#2d2a2e";
        mOnHover = "#e1e2d5";
        terminal = {
          normal = {
            black = "#3b4252";
            red = "#bf616a";
            green = "#a3be8c";
            yellow = "#ebcb8b";
            blue = "#81a1c1";
            magenta = "#b48ead";
            cyan = "#88c0d0";
            white = "#e5e9f0";
          };
          bright = {
            black = "#4c566a";
            red = "#bf616a";
            green = "#a3be8c";
            yellow = "#ebcb8b";
            blue = "#81a1c1";
            magenta = "#b48ead";
            cyan = "#8fbcbb";
            white = "#eceff4";
          };
          foreground = "#d8dee9";
          background = "#212121";
          selectionFg = "#212121";
          selectionBg = "#d8dee9";
          cursor = "#ebcb8b";
          cursorText = "#b89858";
        };
      };
      light = {
        mPrimary = "#3a3a34";
        mOnPrimary = "#ffffff";
        mSecondary = "#1f6feb";
        mOnSecondary = "#ffffff";
        mTertiary = "#2ea043";
        mOnTertiary = "#ffffff";
        mError = "#d94a59";
        mOnError = "#ffffff";
        mSurface = "#ffffff";
        mOnSurface = "#1d1b1d";
        mSurfaceVariant = "#f3f2f5";
        mOnSurfaceVariant = "#3a3a3a";
        mOutline = "#b8b6bb";
        mShadow = "#000000";
        mHover = "#e6e4e8";
        mOnHover = "#1d1b1d";
        terminal = {
          normal = {
            black = "#1d1b1d";
            red = "#d94a59";
            green = "#2ea043";
            yellow = "#c99700";
            blue = "#1f6feb";
            magenta = "#7b2cbf";
            cyan = "#0ea5a5";
            white = "#d0d0c8";
          };
          bright = {
            black = "#5c5c5c";
            red = "#ff707f";
            green = "#4ad66d";
            yellow = "#e6c200";
            blue = "#4ea8de";
            magenta = "#9d4edd";
            cyan = "#22b8cf";
            white = "#ffffff";
          };
          foreground = "#1d1b1d";
          background = "#ffffff";
          selectionFg = "#ffffff";
          selectionBg = "#3a3a34";
          cursor = "#1d1b1d";
          cursorText = "#ffffff";
        };
      };
    };

    settings = {
      bar.widgets = {
        enabled = true;
        position = "top";
        layer = "top";
        reserve_space = true;
        auto_hide = false;
        smart_auto_hide = false;
        background_opacity = 0.93;
        border_width = 0.0;
        radius = 0;
        margin_edge = 8;
        margin_ends = 8;
        padding = 12;
        thickness = 34;
        widget_spacing = 10;
        capsule = false;
        capsule_radius = 0;
        contact_shadow = false;
        shadow = false;

        start = [ "active_window" "clock" "date" "caffeine" "audio_visualizer" ];
        center = [ "taskbar" ];
        end = [
          "tray"
          "notifications"
          "cpu"
          "network"
          "bluetooth"
          "volume"
          "brightness"
          "battery"
          "control-center"
        ];
      };

      widget = {
        active_window = {
          type = "active_window";
          max_length = 260.0;
          min_length = 80.0;
          title_scroll = "none";
        };
        audio_visualizer = {
          type = "audio_visualizer";
          width = 48.0;
          bands = 12;
          mirrored = true;
          centered = true;
          show_when_idle = true;
          color_1 = "primary";
          color_2 = "tertiary";
        };
        cpu = {
          type = "sysmon";
          stat = "cpu_usage";
        };
        date = {
          type = "clock";
          format = "{:%a, %d %b}";
        };
        taskbar = {
          type = "taskbar";
          group_by_workspace = true;
          scale = 1.1;
          focused_color = "outline_variant";
        };
      };

      shell = {
        avatar_path = "${config.home.homeDirectory}/.face";
        font_family = "JetBrainsMono Nerd Font";
        time_format = "{:%H:%M}";
        date_format = "%A, %x";
        telemetry_enabled = false;
        setup_wizard_enabled = false;
        external_ip_enabled = false;
        screen_time_enabled = false;
        shared_gl_context = true;
        corner_radius_scale = 0.0;

        clipboard_enabled = true;
        clipboard_history_max_entries = 1000;
        clipboard_confirm_clear_history = true;
        clipboard_auto_paste = "off";

        mpris.blacklist = [ "playerctld" ];

        animation = {
          enabled = true;
          speed = 1.0;
        };

        panel = {
          borders = false;
          shadow = false;
          transparency_mode = "solid";
          launcher_placement = "floating";
          launcher_position = "center";
          clipboard_placement = "floating";
          clipboard_position = "center";
          control_center_placement = "attached";
          session_placement = "attached";
        };
      };

      theme = {
        source = "custom";
        custom_palette = "Mostlyk";
        templates = {
          builtin_ids = [ "gtk3" "gtk4" "qt" "btop" ];
          community_ids = [ "discord" "vscode" "zed" ];
          enable_community_templates = true;
        };
      };

      system.monitor = {
        enabled = true;
        cpu_poll_seconds = 3.0;
        memory_poll_seconds = 3.0;
        network_poll_seconds = 5.0;
        disk_poll_seconds = 30.0;
        gpu_poll_seconds = 0.0;
      };

      wallpaper = {
        enabled = true;
        directory = "${config.home.homeDirectory}/Pictures/Wallpapers";
        fill_mode = "crop";
        transition = [ "fade" ];
        transition_duration = 400.0;
        transition_on_startup = false;
        automation.enabled = false;
      };

      notification = {
        enable_daemon = true;
        position = "top_right";
        layer = "top";
        background_opacity = 0.97;
        show_actions = true;
        show_app_name = true;
      };

      audio = {
        enable_overdrive = false;
        enable_sounds = false;
      };

      brightness = {
        enable_ddcutil = false;
        minimum_brightness = 0.0;
        sync_all_monitors = false;
      };

      backdrop.enabled = false;
      calendar.enabled = false;
      desktop_widgets.enabled = false;
      dock.enabled = false;
      hot_corners.enabled = false;
      plugins.auto_update = "none";
      weather = {
        enabled = false;
        effects = false;
      };
    };
  };
}
