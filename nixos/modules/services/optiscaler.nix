{ pkgs, lib, ... }:
let
  optiscaler = pkgs.stdenvNoCC.mkDerivation (finalAttrs: {
    pname = "optiscaler";
    version = "0.9.4";

    src = pkgs.fetchurl {
      url = "https://github.com/optiscaler/OptiScaler/releases/download/v${finalAttrs.version}/Optiscaler_${finalAttrs.version}-final.20260718._MM.7z";
      hash = "sha256-V1y034ZhFgk991r2B+N/1w4Q9RY+DyP9XIBBQugO8K0=";
    };

    nativeBuildInputs = [ pkgs.p7zip ];
    dontUnpack = true;
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      mkdir -p "$out/share/optiscaler"
      7z x -o"$out/share/optiscaler" "$src"
      runHook postInstall
    '';

    meta = {
      description = "DLSS/FSR/XeSS upscaler swapper, dropped into a Wine game folder";
      homepage = "https://github.com/optiscaler/OptiScaler";
      license = lib.licenses.unfree;
      sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
      platforms = lib.platforms.linux;
    };
  });

  optiscaler-install = pkgs.writeShellApplication {
    name = "optiscaler-install";
    runtimeInputs = with pkgs; [ coreutils findutils ];
    text = ''
      src="${optiscaler}/share/optiscaler"
      dll="dxgi.dll"
      dlss="y"
      target=""

      usage() {
        cat <<'EOF'
      Usage: optiscaler-install [--dll=NAME] [--dlss=y|n] <dir-with-game-exe>

        --dll=NAME   proxy name for OptiScaler.dll (default dxgi.dll). One of:
                     dxgi.dll winmm.dll version.dll dbghelp.dll d3d12.dll
                     wininet.dll winhttp.dll OptiScaler.asi
        --dlss=y|n   spoof an NVIDIA GPU so DLSS-only games expose an upscaler
                     for OptiScaler to serve with XeSS (default y)

      Unreal Engine games want <Codename>/Binaries/Win64, not the Engine folder.
      Never use this on a game with anti-cheat.
      EOF
      }

      for arg in "$@"; do
        case "$arg" in
          -h|--help) usage; exit 0 ;;
          --dll=*) dll="''${arg#*=}" ;;
          --dlss=*) dlss="''${arg#*=}" ;;
          -*) echo "unknown option: $arg" >&2; usage >&2; exit 1 ;;
          *) target="$arg" ;;
        esac
      done

      if [ -z "$target" ]; then usage >&2; exit 1; fi
      if [ ! -d "$target" ]; then echo "not a directory: $target" >&2; exit 1; fi
      target="$(realpath "$target")"
      if [ -z "$(find "$target" -maxdepth 1 -iname '*.exe' -print -quit)" ]; then
        echo "no .exe in $target -- point this at the folder holding the game executable" >&2
        exit 1
      fi

      backup="$target/.optiscaler-backup"
      mkdir -p "$backup"
      while IFS= read -r -d ''' rel; do
        if [ -f "$target/$rel" ] && [ ! -e "$backup/$rel" ]; then
          mkdir -p "$backup/$(dirname "$rel")"
          cp -a "$target/$rel" "$backup/$rel"
        fi
      done < <(find "$src" -mindepth 1 -type f -printf '%P\0')

      cp -r "$src/." "$target/"
      while IFS= read -r -d ''' rel; do
        chmod u+w "$target/$rel"
      done < <(find "$src" -mindepth 1 -printf '%P\0')

      rm -f "$target/setup_windows.bat"
      rm -f "$target/!! README_EXTRACT ALL FILES TO GAME FOLDER !!.txt"

      if ! out="$(cd "$target" && bash ./setup_linux.sh \
            --filename="$dll" --overwrite=y --using_nvidia=n --using_dlss="$dlss" 2>&1)"; then
        echo "$out" >&2
        exit 1
      fi

      echo "OptiScaler ${optiscaler.version} -> $target"
      echo "  overwritten game files backed up in $backup"
      echo "  uninstall with $target/remove_optiscaler.sh"
      echo
      echo "Add the Wine DLL override, or the game will never load it:"
      echo "  Lutris  Configure > Runner options > DLL overrides: ''${dll%.dll} = n,b"
      echo "  Steam   WINEDLLOVERRIDES=''${dll%.dll}=n,b %COMMAND%"
      echo
      echo "Insert opens the in-game overlay, Page Up/Down toggles the stats."
    '';
  };
in
{
  environment.systemPackages = [ optiscaler optiscaler-install ];
}
