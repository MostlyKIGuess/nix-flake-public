{ pkgs, ... }:
let
  dictateStream = pkgs.writers.writePython3Bin "dictate-stream"
    {
      libraries = with pkgs.python3Packages; [ websockets httpx ];
      flakeIgnore = [ "E501" ];
    }
    (builtins.readFile ./dictate-stream.py);

  dictate = pkgs.writeShellApplication {
    name = "dictate";
    runtimeInputs = with pkgs; [ pipewire curl jq wl-clipboard wtype libnotify coreutils gum ];
    text = ''
      state="''${XDG_RUNTIME_DIR:?}/dictate"
      audio="$state/audio.wav"
      transcriptfile="$state/transcript.txt"
      notificationfile="$state/transcript.notification"
      log="$state/stream.log"
      pidfile="$state/pid"
      choice="$HOME/.config/dictate/backend"

      replace=()
      fail() {
        notify-send "''${replace[@]}" -u critical "Dictation" "$1"
        echo "dictate: $1" >&2
        exit 1
      }

      backend=groq
      [ -s "$choice" ] && backend=$(cat "$choice")
      keyfile="$HOME/.config/''${backend%-stream}/key"

      if [ "''${1:-}" = config ]; then
        picked=$(gum choose --header "Dictation backend (now: $backend)" \
          "groq            Whisper large-v3-turbo, after you stop" \
          "deepgram        Nova-3, after you stop" \
          "groq-stream     Whisper, types each phrase at the cursor after a pause" \
          "deepgram-stream Nova-3, types at the cursor while you speak") || exit 0
        mkdir -p "$(dirname "$choice")"
        echo "''${picked%% *}" > "$choice"
        echo "dictate: using ''${picked%% *}"
        exit 0
      fi

      transcribe() {
        local key
        key=$(tr -d '\n' < "$keyfile")
        case "$backend" in
          groq)
            printf 'Authorization: Bearer %s\n' "$key" \
              | curl -sS --fail-with-body -H @- -F file=@"$audio" \
                  -F model=whisper-large-v3-turbo -F response_format=json \
                  https://api.groq.com/openai/v1/audio/transcriptions ;;
          deepgram)
            printf 'Authorization: Token %s\n' "$key" \
              | curl -sS --fail-with-body -H @- -H 'Content-Type: audio/wav' --data-binary @"$audio" \
                  'https://api.deepgram.com/v1/listen?model=nova-3&smart_format=true' ;;
          *) echo "unknown backend $backend" ;;
        esac
      }

      parse() {
        case "$backend" in
          groq) jq -er '.text | sub("^\\s+"; "")' ;;
          deepgram) jq -er '.results.channels[0].alternatives[0].transcript' ;;
        esac
      }

      if [ ! -f "$pidfile" ]; then
        [ -r "$keyfile" ] || fail "no ''${backend%-stream} key at $keyfile"
        mkdir -p "$state"
        rm -f "$audio" "$transcriptfile" "$notificationfile" "$state/transcript.live"
        if [[ "$backend" == *-stream ]]; then
          ${dictateStream}/bin/dictate-stream "''${backend%-stream}" "$keyfile" "$transcriptfile" 2> "$log" &
        else
          pw-record --rate 16000 --channels 1 "$audio" &
          notify-send -t 2000 "Dictation ($backend)" "Recording, press again to stop"
        fi
        echo $! > "$pidfile"
        exit 0
      fi

      pid=$(cat "$pidfile")
      rm -f "$pidfile"
      [ -s "$notificationfile" ] && replace=(-r "$(cat "$notificationfile")")
      start=$(date +%s%N)
      kill -INT "$pid" 2>/dev/null || fail "recorder $pid was not running"
      for _ in $(seq 200); do
        kill -0 "$pid" 2>/dev/null || break
        sleep 0.1
      done
      kill -0 "$pid" 2>/dev/null && fail "$backend did not finish within 20 s"

      if [[ "$backend" == *-stream ]]; then
        [ -f "$transcriptfile" ] || fail "stream failed: $(tail -n 3 "$log")"
        transcript=$(cat "$transcriptfile")
      else
        [ -s "$audio" ] || fail "recording is empty"
        response=$(transcribe) || fail "$backend request failed: $response"
        transcript=$(parse <<< "$response") || fail "unexpected $backend response: $response"
      fi
      elapsed=$(( ($(date +%s%N) - start) / 1000000 ))
      [[ "$transcript" =~ [[:alnum:]] ]] || fail "no speech heard"

      printf '%s' "$transcript" | wl-copy
      done_title="Dictation copied"
      [[ "$backend" == *-stream ]] && done_title="Dictation typed and copied"
      notify-send "''${replace[@]}" -t 3000 "$done_title ($backend, ''${elapsed} ms)" "$transcript"
    '';
  };
in
{
  home.packages = [ dictate ];
}
