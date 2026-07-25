{ config, ... }:
{
  programs.noctalia = {
    enable = true;
    systemd.enable = true;

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
        radius = 12;
        margin_edge = 8;
        margin_ends = 8;
        padding = 12;
        thickness = 34;
        widget_spacing = 10;
        capsule = false;
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

        clipboard_enabled = true;
        clipboard_history_max_entries = 1000;
        clipboard_confirm_clear_history = true;
        clipboard_auto_paste = "off";

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
      plugins.auto_update = false;
      weather = {
        enabled = false;
        effects = false;
      };
    };
  };
}
