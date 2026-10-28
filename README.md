# mostlyk's NixOS dotfiles

NixOS on two laptops with [niri](https://github.com/YaLTeR/niri) and [Noctalia Shell](https://github.com/noctalia-dev/noctalia-shell).

| host | machine |
|---|---|
| `og` | ASUS, AMD CPU + NVIDIA dGPU (PRIME offload) |
| `bunny` | HP, Intel Core Ultra 7 255H |

## Use

```bash
git clone https://github.com/MostlyKIGuess/nix-flake-public.git ~/.dotfiles
sudo nixos-rebuild switch --flake ~/.dotfiles#og   # first build
rebuild                                            # after that
```

Both hosts are called `mostlyk`, so always name the host (`-H og` with `nh`).

To use it on your machine, swap in your own `hardware-configuration.nix`, your
username for `mostlyk`, your monitors in `home-manager/modules/niri/settings.nix`
and your hosts in `home-manager/modules/shell/ssh.nix`.

## Layout

- `hosts/<name>/`: per-machine config
- `nixos/`: shared system config
- `home-manager/`: niri, shell, programs, Noctalia

## Notes

- My Claude Code skills and notes in `home-manager/modules/programs/claude/` are private and encrypted with git-crypt, so your clone only has ciphertext. The flake builds fine without them. Write your own there, or remove `./claude` from `home-manager/modules/programs/default.nix`.
- If you don't want to trust my cachix, [zed-nix-cache](https://github.com/MostlyKIGuess/zed-nix-cache/) shows how to set up your own.
- `server-setup.sh` sets up the shell and tmux on Ubuntu, Fedora or Arch servers, with or without sudo. See `--help`.
- A public nix flake was on my Bingo 2026 list, so here we are :D
