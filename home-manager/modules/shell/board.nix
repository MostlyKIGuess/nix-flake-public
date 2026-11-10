{ pkgs, ... }:
let
  boardServer = pkgs.writers.writePython3Bin "board-server"
    {
      libraries = with pkgs.python3Packages; [ anthropic boto3 botocore ];
      flakeIgnore = [ "E501" ];
    }
    (builtins.readFile ./board-server.py);

  boardHelpers = ''
    board_window() {
      niri msg --json windows | jq -c 'first(.[] | select((.app_id // "") | test("^(board$|chrom(e|ium)-127\\.0\\.0\\.1)")))'
    }
    workspace_output() {
      niri msg --json workspaces | jq -r --argjson id "$1" '.[] | select(.id == $id) | .output'
    }
    last_workspace() {
      niri msg --json workspaces | jq -r --arg output "$1" '[.[] | select(.output == $output) | .idx] | max'
    }
    active_workspace() {
      niri msg --json workspaces | jq -r --arg output "$1" '.[] | select(.output == $output and .is_active) | .idx'
    }
    move_window() {
      niri msg action move-window-to-workspace --window-id "$1" --focus false "$2"
    }
    workspace_is_active() {
      niri msg --json workspaces | jq -e --argjson id "$1" '.[] | select(.id == $id) | .is_active' > /dev/null
    }
    window_x() {
      niri msg --json windows | jq -r --argjson id "$1" '.[] | select(.id == $id) | .layout.tile_pos_in_workspace_view[0] // 0'
    }
    slide_right() {
      local start
      start=$(window_x "$1")
      niri msg action move-floating-window --id "$1" --x=+4000
      jq -n --argjson end "$(window_x "$1")" --argjson start "$start" '$end - $start | floor'
    }
    hide_window() {
      local offset
      offset=$(slide_right "$1")
      sleep 0.25
      move_window "$1" "$(last_workspace "$2")"
      niri msg action move-floating-window --id "$1" --x=-"$offset"
    }
    show_window() {
      local offset
      offset=$(slide_right "$1")
      move_window "$1" "$2"
      niri msg action move-floating-window --id "$1" --x=-"$offset"
      niri msg action focus-window --id "$1"
    }
  '';

  board = pkgs.writeShellApplication {
    name = "board";
    runtimeInputs = with pkgs; [ coreutils jq libnotify ];
    text = ''
      ${boardHelpers}
      window=$(board_window)
      if [ -z "$window" ]; then
        tokenfile="''${XDG_RUNTIME_DIR:?}/board/token"
        if [ ! -r "$tokenfile" ]; then
          notify-send -u critical "Board" "The board service is not running. Check: systemctl --user status board"
          exit 1
        fi
        exec chromium --user-data-dir="$HOME/.local/share/board-browser" --class=board \
          --app="http://127.0.0.1:4199/?token=$(cat "$tokenfile")"
      fi
      id=$(jq -r '.id' <<< "$window")
      workspace=$(jq -r '.workspace_id' <<< "$window")
      output=$(workspace_output "$workspace")
      if [ "$(jq -r '.is_focused' <<< "$window")" = true ]; then
        hide_window "$id" "$output"
      elif workspace_is_active "$workspace"; then
        niri msg action focus-window --id "$id"
      else
        show_window "$id" "$(active_workspace "$output")"
      fi
    '';
  };

  boardShot = pkgs.writeShellApplication {
    name = "board-shot";
    runtimeInputs = with pkgs; [ coreutils grim jq slurp libnotify ];
    text = ''
      ${boardHelpers}
      pending="''${XDG_RUNTIME_DIR:?}/board/pending"
      if [ ! -d "$pending" ]; then
        notify-send -u critical "Board" "The board service is not running. Check: systemctl --user status board"
        exit 1
      fi
      window=$(board_window)
      if [ -n "$window" ]; then
        id=$(jq -r '.id' <<< "$window")
        workspace=$(jq -r '.workspace_id' <<< "$window")
        output=$(workspace_output "$workspace")
        home=$(active_workspace "$output")
        if workspace_is_active "$workspace"; then
          bring_back() {
            show_window "$id" "$home"
          }
          trap bring_back EXIT
          hide_window "$id" "$output"
          sleep 0.2
        fi
      fi
      region=$(slurp) || exit 0
      grim -g "$region" "$pending/$(date +%s%N).png"
      notify-send -t 2000 "Board" "Screenshot attached to your next message"
    '';
  };
in
{
  home.packages = [ board boardShot pkgs.libsecret ];

  systemd.user.services.board = {
    Unit.Description = "Side window for Claude Code and Bedrock";
    Install.WantedBy = [ "default.target" ];
    Service = {
      ExecStart = "${boardServer}/bin/board-server";
      Environment = [
        "BOARD_HTML=${./board.html}"
        "BOARD_SECRET_TOOL=${pkgs.libsecret}/bin/secret-tool"
        "PATH=${pkgs.poppler-utils}/bin"
      ];
      Restart = "on-failure";
    };
  };
}
