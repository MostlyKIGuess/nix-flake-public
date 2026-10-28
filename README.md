# mostlyk's NixOS dotfiles

NixOS configuration for two laptops running niri (Wayland compositor) with
Noctalia Shell.

## Hosts

| flake output | machine | hardware |
|---|---|---|
| `og` | ASUS | AMD Zen CPU, AMD iGPU + NVIDIA dGPU on PRIME offload |
| `bunny` | HP | Intel Core Ultra 7 255H (Arrow Lake-H), Arc 140T iGPU, LUKS on ext4 |

Both set `networking.hostName = "mostlyk"`, so `nixos-rebuild` and `nh` cannot
infer which one to build. Always name the host explicitly, or use the `rebuild`
alias each host defines for itself.

Shared configuration lives in `nixos/` and `home-manager/`. Anything that
differs between the two machines lives in `hosts/<name>/`. The host name is
passed to both the NixOS and home-manager module trees as a `host` special
argument, which is how `home-manager/modules/niri/settings.nix` picks the right
display mode and render node.

## Customising for your machine

See Structure below for where to make changes. At a minimum, you will need to:

1. Replace `hosts/<name>/hardware-configuration.nix` with your own (run `nixos-generate-config`).
2. Update your flake path in `nixos/default.nix` with where you cloned this repo. (ideally keeping ~/.dotfiles pattern means just swapping mostlyk for your username would work).
3. Update GPU bus IDs in `hosts/og/nvidia.nix`.
4. Update monitor names/resolutions in `home-manager/modules/niri/settings.nix`.
5. Update SSH hosts in `home-manager/modules/shell/ssh.nix`.
6. Change `networking.hostName` in `nixos/default.nix`.
7. Set your username everywhere `mostlyk` appears (a future improvement: extract this to a variable).

### Random notes

- Making a public nix flake was in my Bingo 2026 list, so here we are. The stack and config is bound to change based on what I like next, but noctalia and this setup has been pretty nice for me :D
- In case you don't feel safe having my cachix, you can check out [zed-nix-cache](https://github.com/MostlyKIGuess/zed-nix-cache/) for the setup and add your own as well, it does help to have the best build times.

## Stack

| layer | choice |
|---|---|
| OS | NixOS (nixos-unstable) |
| WM | [niri](https://github.com/YaLTeR/niri) via [niri-flake](https://github.com/sodiboo/niri-flake) |
| Shell / bar / lock | [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell) |
| Terminal |  Ghostty |
| Editor | Neovim (LazyVim) + Zed |
| Theme | Kanagawa (managed by Noctalia) |


## Usage

```bash
# Clone
git clone https://github.com/MostlyKIGuess/nix-flake-public.git ~/.dotfiles
cd ~/.dotfiles

# First build (name the host: og or bunny)
sudo nixos-rebuild switch --flake .#og

# Subsequent rebuilds (using nh)
nh os switch ~/.dotfiles -H og

# or the per-host alias, which fills in the -H for you
rebuild

# Home-manager only
nh home switch
```

## Linux compute hosts

`server-setup.sh` configures an Ubuntu, Fedora, or Arch Linux compute host on
x86_64 or aarch64. It installs command-line tools into `~/.local`, installs the
Zsh and tmux plugins, and links the managed shell, tmux, Powerlevel10k, and
Neovim configurations from this checkout.

The script backs up an existing managed destination before replacing it with a
symlink. Backups use the suffix `.before-server-setup-YYYYmmddHHMMSS`.

```bash
git clone https://github.com/MostlyKIGuess/nix-flake-public.git ~/.dotfiles
bash ~/.dotfiles/server-setup.sh --check
bash ~/.dotfiles/server-setup.sh
```

Set `SERVER_SETUP_INSTALL_EDITOR=0` to omit Neovim on short-lived compute
instances. Release tag environment variables documented by `--help` can pin
standalone tool downloads.

### Accounts without sudo

On a host where the account has neither root nor sudo, the script installs
everything under `~/.local` and never touches the package manager. It detects
this by itself; `--no-sudo` (or `SERVER_SETUP_NO_SUDO=1`) forces the same path
where sudo would otherwise work.

```bash
bash ~/.dotfiles/server-setup.sh --no-sudo
```

Zsh comes from [zsh-bin](https://github.com/romkatv/zsh-bin), tmux from the
[tmux-appimage](https://github.com/nelsonenzo/tmux-appimage) bundle, unpacked
rather than mounted so no FUSE is needed. fzf and ripgrep come from their own
release binaries. The host must already have `curl`, `git`, and `tar`.


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
├── hosts/
│   ├── og/                      # ASUS: hardware-configuration, nvidia, pstate, zenpower
│   └── bunny/                   # HP: hardware-configuration, intel
├── nixos/
│   ├── default.nix              # shared system config
│   └── modules/
│       ├── hardware/            # bootloader, firmware, graphics, nvme tooling
│       ├── services/            # audio, docker, gaming, ssh, daemon
│       ├── niri/                # system-level niri + GDM
│       ├── fonts.nix            # single consolidated font declaration
│       └── brave.nix
└── home-manager/
    ├── home.nix                 # HM entry point
    ├── packages.nix             # user packages
    └── modules/
        ├── niri/                # binds, settings, rules
        ├── shell/               # zsh, nvim, tmux, direnv, ssh
        ├── programs/            # signal, zathura
        └── noctalia.nix         # Noctalia Shell settings
```
