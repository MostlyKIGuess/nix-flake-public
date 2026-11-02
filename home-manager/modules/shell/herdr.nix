{ pkgs, inputs, ... }:
let
  herdr = "${inputs.herdr.packages.x86_64-linux.default}/bin/herdr";
  jq = "${pkgs.jq}/bin/jq";

  moveWorkspace = pkgs.writeShellScript "herdr-move-workspace" ''
    ws=''${HERDR_ACTIVE_WORKSPACE_ID:-}
    [ -n "$ws" ] || exit 0
    request=$(${herdr} workspace list | ${jq} -c --arg ws "$ws" --arg dir "$1" '
      .result.workspaces | map(.workspace_id) as $ids
      | ($ids | index($ws)) as $i
      | select($i != null)
      | (if $dir == "up" then $i - 1 else $i + 2 end) as $to
      | select($to >= 0 and $to <= ($ids | length))
      | {id: "move", method: "workspace.move", params: {workspace_id: $ws, insert_index: $to}}')
    [ -n "$request" ] || exit 0
    printf '%s\n' "$request" | ${pkgs.socat}/bin/socat - UNIX-CONNECT:"$HERDR_SOCKET_PATH" >/dev/null
  '';
in
{
  xdg.configFile."herdr/config.toml".source = (pkgs.formats.toml { }).generate "herdr-config.toml" {
    onboarding = false;
    theme.name = "terminal";
    ui.toast.delivery = "system";
    ui.sound.enabled = true;

    keys = {
      split_horizontal = [ "prefix+minus" "prefix+double_quote" ];
      split_vertical = [ "prefix+v" "prefix+percent" "prefix+enter" ];
      previous_tab = [ "prefix+p" "alt+shift+h" ];
      next_tab = [ "prefix+n" "alt+shift+l" ];
      previous_workspace = "ctrl+alt+k";
      next_workspace = "ctrl+alt+j";
      command = [
        { key = "alt+shift+k"; type = "shell"; command = "${moveWorkspace} up"; description = "Move workspace up"; }
        { key = "alt+shift+j"; type = "shell"; command = "${moveWorkspace} down"; description = "Move workspace down"; }
      ];
    };
  };

  home.file.".claude/hooks/herdr-session.sh".source = pkgs.writeShellScript "herdr-session" ''
    [ "''${HERDR_ENV:-}" = 1 ] && [ -n "''${HERDR_PANE_ID:-}" ] || exit 0

    input=$(cat)
    field() { printf '%s' "$input" | ${jq} -r "$1 // empty"; }

    [ "$(field .hook_event_name)" = SessionStart ] || exit 0
    [ -z "$(field .agent_id)" ] || exit 0
    session_id=$(field .session_id)
    [ -n "$session_id" ] || exit 0

    args=(--source herdr:claude --agent claude --seq "$(date +%s%N)" --agent-session-id "$session_id")
    transcript_path=$(field .transcript_path)
    [ -z "$transcript_path" ] || args+=(--agent-session-path "$transcript_path")
    start_source=$(field .source)
    [ -z "$start_source" ] || args+=(--session-start-source "$start_source")

    exec ${herdr} pane report-agent-session "''${args[@]}" "$HERDR_PANE_ID"
  '';
}
