{ ... }:
{
  xdg.configFile."sioyek/prefs_user.config".text = ''
    # Windows
    should_launch_new_window 1

    # UI
    ui_font "JetBrainsMono Nerd Font"
    font_size 14
    status_bar_font_size 12

    # Reading / navigation
    fit_to_page_width_ratio 0.90
    move_screen_ratio 0.80
    wheel_zoom_on_cursor 1

    # Search
    super_fast_search 1
    case_sensitive_search 0

    # TOC
    collapsed_toc 1
    flat_toc 0

    # Startup
    should_load_tutorial_when_no_other_file 0
    check_for_updates_on_startup 0
  '';
}
