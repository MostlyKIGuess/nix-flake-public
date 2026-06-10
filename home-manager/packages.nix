{ pkgs, mostlyk-zed,helium, ... }:
{
  home.packages = with pkgs; [
    # CLI utilities
    fastfetch
    ncdu
    duf
    tree
    which
    trash-cli
    yazi
    bat
    fd
    ripgrep
    eza
    zoxide
    bc
    jq
    nix-prefetch-git
    pkgs.appimage-run # not on unstable-small
    cachix
    tldr
    glow

    # Build tools
    gcc
    clang-tools

    # Archives
    zip
    xz
    unzip
    p7zip

    # Media
    ffmpeg
    vlc
    obs-studio
    spotify
    pavucontrol
    image-roll

    # Productivity / notes
    obsidian
    evince
    loupe
    foliate
    # pandoc
    typst

    # Communication
    signal-desktop
    vesktop # discord client
    element-desktop
    slack
    zulip

    # Development
    mostlyk-zed.packages.x86_64-linux.default
    helium.packages.x86_64-linux.default
    gh
    vscode
    kitty
    rerun
    code2prompt
    television
    python3Packages.jupytext
    uv
    gnome-text-editor

    # AI
    claude-code
    opencode
    codex

    # System / desktop
    nautilus
    xfce4-power-manager
    btop
    nvtopPackages.full
    sysstat
    lm_sensors
    ethtool
    pciutils
    usbutils
    htop
    gnome-boxes
    nwg-displays
    wl-clipboard
    grimblast
    wlogout
    quickshell
    qbittorrent
    blender

  ];
}
