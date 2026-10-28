{ pkgs, inputs, ... }:
let
  herdr = "${inputs.herdr.packages.x86_64-linux.default}/bin/herdr";
  jq = "${pkgs.jq}/bin/jq";
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
