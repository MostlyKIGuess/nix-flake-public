{ pkgs, mostlyk-zed, ... }:
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
    appimage-run
    cachix

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
    cliphist
    grimblast
    wlogout

  ];
}
