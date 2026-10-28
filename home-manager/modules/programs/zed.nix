{ mostlyk-zed, ... }:
{
  programs.zed-editor = {
    enable = true;
    package = mostlyk-zed.packages.x86_64-linux.default;

    userSettings = {
      theme = {
        mode = "dark";
        light = "Noctalia Light";
        dark = "Noctalia Dark";
      };
      icon_theme = {
        mode = "system";
        light = "Zed (Default)";
        dark = "Zed (Default)";
      };
      rounded_selection = false;

      ui_font_size = 18.0;
      buffer_font_size = 16.0;
      buffer_font_family = "Fira Code";
      base_keymap = "VSCode";
      vim_mode = true;
      soft_wrap = "editor_width";
      hard_tabs = false;
      format_on_save = "off";
      colorize_brackets = true;
      code_lens = "on";
      semantic_tokens = "combined";
      diff_view_style = "split";
      cli_default_open_behavior = "new_window";
      scrollbar.axes.vertical = false;
      indent_guides.background_coloring = "disabled";
      global_lsp_settings.button = false;

      title_bar = {
        show_user_picture = true;
        show_user_menu = true;
        show_sign_in = true;
        show_onboarding_banner = true;
        show_project_items = true;
        show_branch_icon = false;
        show_menus = false;
      };

      collaboration_panel.dock = "left";
      project_panel.dock = "left";
      outline_panel.dock = "right";
      git_panel = {
        dock = "left";
        tree_view = false;
        sort_by_path = true;
      };

      terminal = {
        toolbar.breadcrumbs = false;
        font_family = "CaskaydiaCove Nerd Font Mono";
      };

      telemetry = {
        diagnostics = false;
        metrics = false;
      };

      show_edit_predictions = true;
      edit_predictions = {
        allow_data_collection = "no";
        provider = "copilot";
        mode = "subtle";
        copilot = {
          prediction_debounce = 50;
          enable_next_edit_suggestions = true;
        };
      };

      languages = {
        "C++".show_edit_predictions = true;
        Rust.show_edit_predictions = true;
        Typst.show_edit_predictions = true;
        Python.show_edit_predictions = true;
        Markdown.indent_guides.coloring = "fixed";
      };

      lsp.rust-analyzer.initialization_options.cargo.features = [ "rerun" ];

      image_viewer.unit = "binary";

      agent_servers = {
        codex-acp = {
          type = "registry";
          default_config_options = {
            mode = "agent-full-access";
            model = "gpt-5.6-sol";
            reasoning_effort = "high";
          };
          favorite_config_option_values.reasoning_effort = [ "high" ];
        };
        github-copilot-cli.type = "registry";
        claude-acp.type = "registry";
      };

      agent = {
        dock = "right";
        default_profile = "write";
        default_model = {
          provider = "Z-AI";
          model = "GLM-5.3";
          enable_thinking = false;
        };
      };

      language_models.openai_compatible.Z-AI = {
        api_url = "https://api.z.ai/api/coding/paas/v4";
        available_models = [
          {
            name = "GLM-5.3";
            max_tokens = 200000;
            max_output_tokens = 32000;
            max_completion_tokens = 200000;
            capabilities = {
              tools = true;
              images = false;
              parallel_tool_calls = false;
              prompt_cache_key = false;
            };
          }
        ];
      };
    };

    userKeymaps = [
      {
        context = "(VimControl && !menu)";
        bindings.j = [ "vim::Down" { display_lines = true; } ];
      }
      {
        context = "Workspace";
        bindings.alt-shift-o = [ "projects::OpenRemote" { from_existing_connection = false; } ];
      }
    ];

    userTasks = [
      {
        label = "Television File Finder";
        command = "zed \"$(tv files)\"";
        hide = "always";
        allow_concurrent_runs = true;
        use_new_terminal = true;
      }
      {
        label = "Compile and Run C";
        command = "gcc";
        args = [ "$ZED_FILE" "-o" "$ZED_STEM" "&&" "./$ZED_STEM" ];
        cwd = "$ZED_DIRNAME";
        use_new_terminal = false;
        allow_concurrent_runs = false;
        reveal = "always";
      }
      {
        label = "Compile and Run Cpp";
        command = "g++";
        args = [ "$ZED_FILE" "-o" "$ZED_STEM" "&&" "./$ZED_STEM" ];
        cwd = "$ZED_DIRNAME";
        use_new_terminal = false;
        allow_concurrent_runs = false;
        reveal = "always";
      }
      {
        label = "lazygit";
        command = "lazygit";
        use_new_terminal = false;
        allow_concurrent_runs = false;
        reveal = "always";
        reveal_target = "center";
        hide = "always";
      }
    ];
  };
}
