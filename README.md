# mostlyk's NixOS dotfiles

NixOS configuration for an AMD + Nvidia laptop running **niri** (Wayland compositor) with **Noctalia Shell**.

## Customising for your machine

See Structure below for where to make changes. At a minimum, you will need to:

1. Replace `nixos/hardware-configuration.nix` with your own (run `nixos-generate-config`).
2. Update your flake path in `configuration.nix` with where you cloned this repo. (ideally keeping ~/.dotfiles pattern means just swapping mostlyk for your username would work).
3. Update GPU bus IDs in `nixos/modules/hardware/nvidia.nix`.
4. Update monitor names/resolutions in `home-manager/modules/niri/settings.nix`.
5. Update SSH hosts in `home-manager/modules/shell/ssh.nix`.
6. Change `networking.hostName` in `nixos/configuration.nix`.
7. Set your username everywhere `mostlyk` appears (a future improvement: extract this to a variable).


### Random Notes

- Making a public nix flake was in my Bingo 2026 list, so here we are. The stack and config is bound to change based on what I like next, but noctalia and this setup has been pretty nice for me :D
- In case you don't feel safe having my cachix, you can check out [zed-nix-cache](https://github.com/MostlyKIGuess/zed-nix-cache/) for the setup and add your own as well, it does help to have the best build times.

## Stack

| layer | choice |
|---|---|
| OS | NixOS (nixos-unstable) |
| WM | [niri](https://github.com/YaLTeR/niri) via [niri-flake](https://github.com/sodiboo/niri-flake) |
| Shell / bar / lock | [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) |
| Terminal | Kitty + Ghostty |
| Editor | Neovim (LazyVim) + Zed |
| Theme | Kanagawa (managed by Noctalia) |


## Usage

```bash
# Clone
git clone https://github.com/mostlykiguess/pubic-flake ~/.dotfiles
cd ~/.dotfiles

# First build
sudo nixos-rebuild switch --flake .#mostlyk

# Subsequent rebuilds (using nh)
nh os switch

# Home-manager only
nh home switch
```

## Developer tooling

```bash
nix develop        # drop into shell with nixpkgs-fmt, deadnix, statix, nil
nix fmt .            # format all .nix files
nix flake check    # dry-build the system
deadnix .          # find dead code
statix check .     # lint for anti-patterns
```

## Structure

```
.
├── flake.nix
├── nixos/
│   ├── configuration.nix        # host config entry point
│   ├── hardware-configuration.nix # COPY THIS FROM YOUR SYSTEM
│   └── modules/
│       ├── hardware/            # nvidia, amd pstate, zenpower
│       ├── services/            # audio, docker, gaming, ssh, daemon
│       ├── niri/                # system-level niri + GDM
│       ├── fonts.nix            # single consolidated font declaration
│       └── packages.nix         # system packages
└── home-manager/
    ├── home.nix                 # HM entry point
    ├── packages.nix             # user packages
    └── modules/
        ├── niri/                # binds, settings, rules
        ├── shell/               # zsh, nvim, tmux, direnv, ssh, kitty
        ├── programs/            # signal, zathura
        └── noctalia.nix         # Noctalia Shell settings
```
