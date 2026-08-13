#!/usr/bin/env bash

set -Eeuo pipefail

setup_script_name="$(basename "$0")"
readonly setup_script_name
readonly dotfiles_root="${SERVER_SETUP_DOTFILES_ROOT:-$HOME/.dotfiles}"
readonly install_editor="${SERVER_SETUP_INSTALL_EDITOR:-1}"
readonly no_sudo_request="${SERVER_SETUP_NO_SUDO:-0}"
readonly local_binary_directory="$HOME/.local/bin"
readonly local_option_directory="$HOME/.local/opt"
readonly local_terminfo_directory="$HOME/.local/share/terminfo"

setup_temp_directory=""
sudoless_mode=0
check_only=0

log() {
    printf '[server-setup] %s\n' "$*"
}

warn() {
    printf '[server-setup] warning: %s\n' "$*" >&2
}

fail() {
    printf '[server-setup] error: %s\n' "$*" >&2
    exit 1
}

cleanup() {
    if [[ -n "$setup_temp_directory" && -d "$setup_temp_directory" ]]; then
        rm -rf -- "$setup_temp_directory"
    fi
}

report_failure() {
    local exit_status=$?
    printf '[server-setup] error: command failed at line %s with status %s\n' \
        "${BASH_LINENO[0]}" "$exit_status" >&2
    exit "$exit_status"
}

trap cleanup EXIT
trap report_failure ERR

usage() {
    cat <<EOF
Usage: $setup_script_name [--check | --no-sudo]

Install and configure the interactive shell tools used on Linux compute hosts.

With root or sudo the base tools come from the system package manager. With
neither, everything is installed under \$HOME/.local instead and no package
manager is needed.

Options:
  --check    Validate the host and managed configuration without changing it.
  --no-sudo  Install under \$HOME/.local even where sudo would work.
  --help     Show this help.

Environment:
  SERVER_SETUP_DOTFILES_ROOT   Dotfiles checkout. Default: \$HOME/.dotfiles
  SERVER_SETUP_INSTALL_EDITOR  Install Neovim when set to 1. Default: 1
  SERVER_SETUP_NO_SUDO         Same as --no-sudo when set to 1. Default: 0
  SERVER_SETUP_EZA_VERSION     eza release tag override.
  SERVER_SETUP_YAZI_VERSION    Yazi release tag override.
  SERVER_SETUP_UV_VERSION      uv release tag override.
  SERVER_SETUP_NVIM_VERSION    Neovim release tag override.
  SERVER_SETUP_ZOXIDE_VERSION  zoxide release tag override.
  SERVER_SETUP_FZF_VERSION     fzf release tag override.
  SERVER_SETUP_RIPGREP_VERSION ripgrep release tag override.
  SERVER_SETUP_TMUX_VERSION    tmux-appimage release tag override.
EOF
}

require_command() {
    local command_name="$1"
    command -v "$command_name" >/dev/null 2>&1 ||
        fail "required command is unavailable: $command_name"
}

run_privileged() {
    if (( EUID == 0 )); then
        "$@"
        return
    fi

    require_command sudo
    sudo "$@"
}

detect_privilege_mode() {
    [[ "$no_sudo_request" == "0" || "$no_sudo_request" == "1" ]] ||
        fail "SERVER_SETUP_NO_SUDO must be 0 or 1"

    if (( sudoless_mode == 1 )) || [[ "$no_sudo_request" == "1" ]]; then
        sudoless_mode=1
        log "sudoless mode: installing everything under $HOME/.local"
        return
    fi

    if (( EUID == 0 )); then
        return
    fi

    if ! command -v sudo >/dev/null 2>&1; then
        sudoless_mode=1
        log "sudo is unavailable: installing everything under $HOME/.local"
        return
    fi

    if sudo -n true 2>/dev/null; then
        return
    fi

    # sudo without cached credentials cannot be told apart from sudo the account
    # is not allowed to use, except by asking for a password. That is only worth
    # doing on a terminal, and only when something is about to be installed.
    if (( check_only == 0 )) && [[ -t 0 ]] && sudo -v; then
        return
    fi

    sudoless_mode=1
    log "no usable sudo: installing everything under $HOME/.local"
}

detect_architecture() {
    case "$(uname -m)" in
        x86_64)
            printf 'x86_64\n'
            ;;
        aarch64 | arm64)
            printf 'aarch64\n'
            ;;
        *)
            fail "unsupported CPU architecture: $(uname -m)"
            ;;
    esac
}

validate_host() {
    [[ "$(uname -s)" == "Linux" ]] || fail "only Linux hosts are supported"
    detect_architecture >/dev/null

    [[ "$install_editor" == "0" || "$install_editor" == "1" ]] ||
        fail "SERVER_SETUP_INSTALL_EDITOR must be 0 or 1"

    [[ -f "$dotfiles_root/home-manager/modules/shell/.zshrc" ]] ||
        fail "missing managed zsh configuration under $dotfiles_root"
    [[ -f "$dotfiles_root/home-manager/modules/shell/.p10k.zsh" ]] ||
        fail "missing Powerlevel10k configuration under $dotfiles_root"
    [[ -f "$dotfiles_root/home-manager/modules/shell/.tmux.conf" ]] ||
        fail "missing managed tmux configuration under $dotfiles_root"
    [[ -d "$dotfiles_root/home-manager/modules/shell/nvim" ]] ||
        fail "missing managed Neovim configuration under $dotfiles_root"

    if (( sudoless_mode == 1 )); then
        # None of these can be installed without a package manager, and every
        # download, archive and plugin checkout below needs them.
        require_command curl
        require_command git
        require_command tar
        return
    fi

    if ! command -v apt-get >/dev/null 2>&1 &&
        ! command -v dnf >/dev/null 2>&1 &&
        ! command -v pacman >/dev/null 2>&1; then
        fail "supported package manager not found: apt-get, dnf, or pacman"
    fi
}

install_system_packages() {
    log "installing system packages"

    if command -v apt-get >/dev/null 2>&1; then
        run_privileged env DEBIAN_FRONTEND=noninteractive apt-get update
        run_privileged env DEBIAN_FRONTEND=noninteractive apt-get install -y \
            ca-certificates curl fzf git ncurses-bin ripgrep tmux unzip xz-utils zsh
    elif command -v dnf >/dev/null 2>&1; then
        run_privileged dnf install -y \
            ca-certificates curl fzf git ncurses ripgrep tmux unzip xz zsh
    elif command -v pacman >/dev/null 2>&1; then
        run_privileged pacman -Syu --needed --noconfirm \
            ca-certificates curl fzf git ncurses ripgrep tmux unzip xz zsh
    else
        fail "supported package manager not found"
    fi
}

install_user_packages() {
    log "installing base tools under $HOME/.local"

    install_zsh
    install_fzf
    install_ripgrep
    install_tmux
}

latest_release_tag() {
    local repository="$1"
    local version_override="$2"
    local release_json
    local release_tag

    if [[ -n "$version_override" ]]; then
        release_tag="$version_override"
    else
        release_json="$(curl -fsSL --retry 5 \
            "https://api.github.com/repos/$repository/releases/latest")"
        release_tag="$(sed -n 's/.*"tag_name":[[:space:]]*"\([^"]*\)".*/\1/p' \
            <<<"$release_json")"
        [[ -n "$release_tag" ]] ||
            fail "could not resolve the latest release tag for $repository"
    fi

    [[ "$release_tag" =~ ^[A-Za-z0-9._-]+$ ]] ||
        fail "release tag contains unsupported characters: $release_tag"
    printf '%s\n' "$release_tag"
}

download_file() {
    local source_url="$1"
    local destination="$2"

    curl -fL --retry 5 --retry-all-errors --connect-timeout 20 \
        "$source_url" -o "$destination"
    [[ -s "$destination" ]] || fail "download produced an empty file: $source_url"
}

extract_zip() {
    local archive_path="$1"
    local destination="$2"

    if command -v unzip >/dev/null 2>&1; then
        unzip -q "$archive_path" -d "$destination"
        return
    fi

    # Yazi publishes a zip only, and unzip cannot be installed without a package
    # manager. python3 is the one extractor that is otherwise always around.
    command -v python3 >/dev/null 2>&1 ||
        fail "extracting $archive_path needs either unzip or python3"
    python3 -m zipfile -e "$archive_path" "$destination"
}

install_zsh() {
    command -v zsh >/dev/null 2>&1 && return

    local installer_path
    local installer_url

    installer_url="${SERVER_SETUP_ZSH_URL:-https://raw.githubusercontent.com/romkatv/zsh-bin/master/install}"
    installer_path="$setup_temp_directory/zsh-bin-install.sh"

    log "installing zsh from zsh-bin"
    download_file "$installer_url" "$installer_path"
    # A single -d keeps the installer non-interactive, and -e no stops it asking
    # about /etc/shells, which an unprivileged account cannot write to anyway.
    sh "$installer_path" -q -d "$HOME/.local" -e no
    command -v zsh >/dev/null 2>&1 ||
        fail "zsh installation completed without an executable on PATH"
}

install_fzf() {
    command -v fzf >/dev/null 2>&1 && return

    local architecture
    local release_tag
    local target
    local tool_directory

    architecture="$(detect_architecture)"
    case "$architecture" in
        x86_64)
            target="linux_amd64"
            ;;
        aarch64)
            target="linux_arm64"
            ;;
    esac

    release_tag="$(latest_release_tag junegunn/fzf "${SERVER_SETUP_FZF_VERSION:-}")"
    tool_directory="$setup_temp_directory/fzf"
    mkdir -p "$tool_directory"

    log "installing fzf $release_tag"
    download_file \
        "https://github.com/junegunn/fzf/releases/download/$release_tag/fzf-${release_tag#v}-$target.tar.gz" \
        "$tool_directory/fzf.tar.gz"
    tar -xzf "$tool_directory/fzf.tar.gz" -C "$tool_directory"
    [[ -f "$tool_directory/fzf" ]] || fail "fzf archive did not contain fzf"
    install -m 0755 "$tool_directory/fzf" "$local_binary_directory/fzf"
}

install_ripgrep() {
    command -v rg >/dev/null 2>&1 && return

    local architecture
    local release_tag
    local target
    local tool_directory

    architecture="$(detect_architecture)"
    release_tag="$(latest_release_tag BurntSushi/ripgrep \
        "${SERVER_SETUP_RIPGREP_VERSION:-}")"
    target="$architecture-unknown-linux-musl"
    tool_directory="$setup_temp_directory/ripgrep"
    mkdir -p "$tool_directory"

    log "installing ripgrep $release_tag"
    download_file \
        "https://github.com/BurntSushi/ripgrep/releases/download/$release_tag/ripgrep-$release_tag-$target.tar.gz" \
        "$tool_directory/ripgrep.tar.gz"
    tar -xzf "$tool_directory/ripgrep.tar.gz" -C "$tool_directory"
    [[ -f "$tool_directory/ripgrep-$release_tag-$target/rg" ]] ||
        fail "ripgrep archive did not contain rg"
    install -m 0755 "$tool_directory/ripgrep-$release_tag-$target/rg" \
        "$local_binary_directory/rg"
}

install_tmux() {
    command -v tmux >/dev/null 2>&1 && return

    local architecture
    local install_directory
    local ncurses_tool
    local release_tag
    local tool_directory

    architecture="$(detect_architecture)"
    if [[ "$architecture" != "x86_64" ]]; then
        warn "no prebuilt tmux is published for $architecture; install it separately"
        return
    fi

    release_tag="$(latest_release_tag nelsonenzo/tmux-appimage \
        "${SERVER_SETUP_TMUX_VERSION:-}")"
    tool_directory="$setup_temp_directory/tmux"
    install_directory="$local_option_directory/tmux-$release_tag"
    mkdir -p "$tool_directory"

    log "installing tmux $release_tag"
    download_file \
        "https://github.com/nelsonenzo/tmux-appimage/releases/download/$release_tag/tmux.appimage" \
        "$tool_directory/tmux.appimage"
    chmod +x "$tool_directory/tmux.appimage"
    # The AppImage is unpacked rather than run, because mounting one needs FUSE
    # and shared hosts rarely give unprivileged accounts that. The unpacked
    # binary has an rpath into its own lib directory, so it runs without AppRun.
    (cd "$tool_directory" && ./tmux.appimage --appimage-extract >/dev/null)
    [[ -x "$tool_directory/squashfs-root/usr/bin/tmux" ]] ||
        fail "tmux AppImage did not contain tmux"

    if [[ ! -d "$install_directory" ]]; then
        mv "$tool_directory/squashfs-root" "$install_directory"
    fi
    ln -sfn "$install_directory/usr/bin/tmux" "$local_binary_directory/tmux"

    # The same bundle carries the ncurses tools that validate_terminfo tells the
    # user to reach for.
    for ncurses_tool in infocmp tic; do
        command -v "$ncurses_tool" >/dev/null 2>&1 && continue
        ln -sfn "$install_directory/usr/bin/$ncurses_tool" \
            "$local_binary_directory/$ncurses_tool"
    done
}

install_eza() {
    command -v eza >/dev/null 2>&1 && return

    local architecture
    local release_tag
    local target
    local tool_directory

    architecture="$(detect_architecture)"
    release_tag="$(latest_release_tag eza-community/eza "${SERVER_SETUP_EZA_VERSION:-}")"
    target="$architecture-unknown-linux-gnu"
    tool_directory="$setup_temp_directory/eza"
    mkdir -p "$tool_directory"

    log "installing eza $release_tag"
    download_file \
        "https://github.com/eza-community/eza/releases/download/$release_tag/eza_$target.tar.gz" \
        "$tool_directory/eza.tar.gz"
    tar -xzf "$tool_directory/eza.tar.gz" -C "$tool_directory"
    [[ -x "$tool_directory/eza" ]] || fail "eza archive did not contain eza"
    install -m 0755 "$tool_directory/eza" "$local_binary_directory/eza"
}

install_yazi() {
    command -v yazi >/dev/null 2>&1 && command -v ya >/dev/null 2>&1 && return

    local architecture
    local release_tag
    local target
    local tool_directory

    architecture="$(detect_architecture)"
    release_tag="$(latest_release_tag sxyazi/yazi "${SERVER_SETUP_YAZI_VERSION:-}")"
    target="$architecture-unknown-linux-gnu"
    tool_directory="$setup_temp_directory/yazi"
    mkdir -p "$tool_directory"

    log "installing Yazi $release_tag"
    download_file \
        "https://github.com/sxyazi/yazi/releases/download/$release_tag/yazi-$target.zip" \
        "$tool_directory/yazi.zip"
    extract_zip "$tool_directory/yazi.zip" "$tool_directory"
    # Tested with -f rather than -x because the python fallback in extract_zip
    # drops the executable bit; the install calls below set it regardless.
    [[ -f "$tool_directory/yazi-$target/yazi" ]] ||
        fail "Yazi archive did not contain yazi"
    [[ -f "$tool_directory/yazi-$target/ya" ]] ||
        fail "Yazi archive did not contain ya"
    install -m 0755 "$tool_directory/yazi-$target/yazi" "$local_binary_directory/yazi"
    install -m 0755 "$tool_directory/yazi-$target/ya" "$local_binary_directory/ya"
}

install_uv() {
    command -v uv >/dev/null 2>&1 && command -v uvx >/dev/null 2>&1 && return

    local architecture
    local release_tag
    local target
    local tool_directory

    architecture="$(detect_architecture)"
    release_tag="$(latest_release_tag astral-sh/uv "${SERVER_SETUP_UV_VERSION:-}")"
    target="$architecture-unknown-linux-gnu"
    tool_directory="$setup_temp_directory/uv"
    mkdir -p "$tool_directory"

    log "installing uv $release_tag"
    download_file \
        "https://github.com/astral-sh/uv/releases/download/$release_tag/uv-$target.tar.gz" \
        "$tool_directory/uv.tar.gz"
    tar -xzf "$tool_directory/uv.tar.gz" -C "$tool_directory"
    [[ -x "$tool_directory/uv-$target/uv" ]] || fail "uv archive did not contain uv"
    [[ -x "$tool_directory/uv-$target/uvx" ]] || fail "uv archive did not contain uvx"
    install -m 0755 "$tool_directory/uv-$target/uv" "$local_binary_directory/uv"
    install -m 0755 "$tool_directory/uv-$target/uvx" "$local_binary_directory/uvx"
}

install_zoxide() {
    command -v zoxide >/dev/null 2>&1 && return

    local release_tag
    local installer_path

    release_tag="$(latest_release_tag ajeetdsouza/zoxide \
        "${SERVER_SETUP_ZOXIDE_VERSION:-}")"
    installer_path="$setup_temp_directory/zoxide-install.sh"

    log "installing zoxide $release_tag"
    download_file \
        "https://raw.githubusercontent.com/ajeetdsouza/zoxide/$release_tag/install.sh" \
        "$installer_path"
    bash "$installer_path"
    command -v zoxide >/dev/null 2>&1 ||
        fail "zoxide installation completed without an executable on PATH"
}

install_neovim() {
    [[ "$install_editor" == "0" ]] && return
    command -v nvim >/dev/null 2>&1 && return

    local architecture
    local archive_name
    local extracted_directory
    local install_directory
    local release_tag
    local tool_directory

    architecture="$(detect_architecture)"
    case "$architecture" in
        x86_64)
            archive_name="nvim-linux-x86_64.tar.gz"
            extracted_directory="nvim-linux-x86_64"
            ;;
        aarch64)
            archive_name="nvim-linux-arm64.tar.gz"
            extracted_directory="nvim-linux-arm64"
            ;;
    esac

    release_tag="$(latest_release_tag neovim/neovim "${SERVER_SETUP_NVIM_VERSION:-}")"
    tool_directory="$setup_temp_directory/neovim"
    install_directory="$local_option_directory/neovim-$release_tag"
    mkdir -p "$tool_directory"

    log "installing Neovim $release_tag"
    download_file \
        "https://github.com/neovim/neovim/releases/download/$release_tag/$archive_name" \
        "$tool_directory/neovim.tar.gz"
    tar -xzf "$tool_directory/neovim.tar.gz" -C "$tool_directory"
    [[ -x "$tool_directory/$extracted_directory/bin/nvim" ]] ||
        fail "Neovim archive did not contain nvim"

    if [[ ! -d "$install_directory" ]]; then
        mv "$tool_directory/$extracted_directory" "$install_directory"
    fi
    ln -sfn "$install_directory/bin/nvim" "$local_binary_directory/nvim"
}

clone_repository() {
    local repository_url="$1"
    local destination="$2"

    if [[ -d "$destination" ]]; then
        git -C "$destination" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
            fail "existing plugin directory is not a valid Git checkout: $destination"
        return
    fi

    git clone --depth 1 "$repository_url" "$destination"
}

backup_and_link() {
    local source_path="$1"
    local destination_path="$2"
    local backup_path

    [[ -e "$source_path" ]] || fail "managed configuration does not exist: $source_path"
    mkdir -p "$(dirname "$destination_path")"

    if [[ -L "$destination_path" ]] &&
        [[ "$(readlink -f "$destination_path")" == "$(readlink -f "$source_path")" ]]; then
        return
    fi

    if [[ -e "$destination_path" || -L "$destination_path" ]]; then
        backup_path="$destination_path.before-server-setup-$(date +%Y%m%d%H%M%S)"
        log "backing up $destination_path to $backup_path"
        mv "$destination_path" "$backup_path"
    fi

    ln -s "$source_path" "$destination_path"
}

install_shell_plugins() {
    local zsh_custom_directory="$HOME/.zsh_custom"

    mkdir -p "$zsh_custom_directory/plugins" "$zsh_custom_directory/themes"
    clone_repository https://github.com/romkatv/powerlevel10k.git \
        "$zsh_custom_directory/themes/powerlevel10k"
    clone_repository https://github.com/Aloxaf/fzf-tab.git \
        "$zsh_custom_directory/plugins/fzf-tab"
    clone_repository https://github.com/zsh-users/zsh-autosuggestions.git \
        "$zsh_custom_directory/plugins/zsh-autosuggestions"
    clone_repository https://github.com/zsh-users/zsh-syntax-highlighting.git \
        "$zsh_custom_directory/plugins/zsh-syntax-highlighting"
    clone_repository https://github.com/zsh-users/zsh-history-substring-search.git \
        "$zsh_custom_directory/plugins/zsh-history-substring-search"
    clone_repository https://github.com/tmux-plugins/tpm.git \
        "$HOME/.tmux/plugins/tpm"
}

install_managed_configuration() {
    local shell_directory="$dotfiles_root/home-manager/modules/shell"

    zsh -n "$shell_directory/.zshrc"
    backup_and_link "$shell_directory/.zshrc" "$HOME/.zshrc"
    backup_and_link "$shell_directory/.p10k.zsh" "$HOME/.p10k.zsh"
    backup_and_link "$shell_directory/.tmux.conf" "$HOME/.tmux.conf"
    backup_and_link "$shell_directory/nvim" "$HOME/.config/nvim"
}

validate_tmux_configuration() {
    local validation_socket="server-setup-validation-$$"

    tmux -L "$validation_socket" -f "$HOME/.tmux.conf" \
        new-session -d -s validation
    tmux -L "$validation_socket" kill-server
}

install_login_shell_hook() {
    local zsh_path="$1"
    local marker="# server-setup: start zsh for interactive login shells"
    local profile_path="$HOME/.profile"

    # bash reads .bash_profile in preference to .profile, so appending to
    # .profile when .bash_profile exists would have no effect.
    if [[ -e "$HOME/.bash_profile" ]]; then
        profile_path="$HOME/.bash_profile"
    fi

    if [[ -e "$profile_path" ]] && grep -qF "$marker" "$profile_path"; then
        return
    fi

    log "adding a zsh launcher to $profile_path"
    cat >>"$profile_path" <<EOF

$marker
if [ -d "$local_terminfo_directory" ]; then
    TERMINFO_DIRS="$local_terminfo_directory:\${TERMINFO_DIRS:-}"
    export TERMINFO_DIRS
fi
if [ -x "$zsh_path" ] && [ -t 1 ] && [ -z "\${ZSH_VERSION:-}" ]; then
    exec "$zsh_path" -l
fi
EOF
}

configure_default_shell() {
    local login_user
    local zsh_path

    login_user="$(id -un)"
    zsh_path="$(command -v zsh)"
    if [[ "${SHELL:-}" == "$zsh_path" ]]; then
        return
    fi

    # chsh only accepts shells listed in /etc/shells, which a $HOME/.local
    # install can never be, so the sudoless path changes the login profile
    # rather than the passwd entry.
    if (( sudoless_mode == 1 )); then
        install_login_shell_hook "$zsh_path"
        return
    fi

    if ! command -v chsh >/dev/null 2>&1; then
        warn "chsh is unavailable; set the login shell manually to $zsh_path"
        return
    fi

    if ! run_privileged chsh -s "$zsh_path" "$login_user"; then
        warn "could not change the login shell; run: sudo chsh -s $zsh_path $login_user"
    fi
}

validate_terminfo() {
    local term_name="${TERM:-}"

    [[ -n "$term_name" ]] || return 0
    command -v infocmp >/dev/null 2>&1 || return 0
    infocmp -- "$term_name" >/dev/null 2>&1 && return 0

    warn "this host has no terminfo entry for TERM=$term_name"
    warn "zsh cannot resolve key sequences for an unknown terminal; install the entry from the client with:"
    warn "  infocmp -x $term_name | ssh $(id -un)@$(uname -n) -- tic -x -o \\~/.terminfo /dev/stdin"
}

validate_shell_startup() {
    local startup_output=""

    startup_output="$(zsh -i -c exit 2>&1 </dev/null)" || true
    [[ -n "$startup_output" ]] || return 0

    warn "zsh wrote to the console while starting up, which trips the Powerlevel10k instant prompt:"
    printf '%s\n' "$startup_output" >&2
}

validate_shell_widgets() {
    local dangling_widgets=""
    local widget_name

    # A bindkey naming a widget that was never created with `zle -N` leaves a
    # dangling entry, which zsh-syntax-highlighting reports at every prompt.
    dangling_widgets="$(zsh -i -c '
        zmodload zsh/zleparameter 2>/dev/null || exit 0
        for widget_name in ${(k)widgets}; do
            [[ -n "${widgets[$widget_name]}" ]] || print -r -- "$widget_name"
        done' 2>/dev/null </dev/null)" || true
    [[ -n "$dangling_widgets" ]] || return 0

    warn "these keybindings name widgets that do not exist:"
    while IFS= read -r widget_name; do
        warn "  $widget_name"
    done <<<"$dangling_widgets"
    warn "zsh-syntax-highlighting reports each of these at every prompt"
}

validate_installation() {
    local required_commands=(curl eza fzf git rg tmux uv uvx ya yazi zoxide zsh)
    local command_name

    if [[ "$install_editor" == "1" ]]; then
        required_commands+=(nvim)
    fi

    for command_name in "${required_commands[@]}"; do
        require_command "$command_name"
    done

    zsh -n "$HOME/.zshrc"
    validate_tmux_configuration
    validate_terminfo
    validate_shell_startup
    validate_shell_widgets
}

main() {
    if (( $# > 1 )); then
        usage >&2
        exit 64
    fi

    case "${1:-}" in
        "")
            ;;
        --check)
            check_only=1
            ;;
        --no-sudo)
            sudoless_mode=1
            ;;
        --help)
            usage
            return
            ;;
        *)
            usage >&2
            exit 64
            ;;
    esac

    detect_privilege_mode
    validate_host
    if (( check_only == 1 )); then
        log "host and managed configuration passed preflight"
        return
    fi

    setup_temp_directory="$(mktemp -d)"
    # PATH comes first so a tool installed here is visible to the checks that
    # follow, and to the zoxide installer, which targets this directory.
    mkdir -p "$local_binary_directory" "$local_option_directory"
    export PATH="$local_binary_directory:$PATH"

    if (( sudoless_mode == 1 )); then
        install_user_packages
        # zsh-bin ships its own terminfo database, and every other ncurses
        # program, tmux above all, only looks at it when pointed there. Hosts
        # with no system database leave tmux unable to open a terminal at all.
        if [[ -d "$local_terminfo_directory" ]]; then
            export TERMINFO_DIRS="$local_terminfo_directory:${TERMINFO_DIRS:-}"
        fi
    else
        install_system_packages
    fi

    install_eza
    install_yazi
    install_uv
    install_zoxide
    install_neovim
    install_shell_plugins
    install_managed_configuration
    validate_installation
    configure_default_shell

    log "setup complete"
    log "start a new login session or run: exec zsh -l"
    log "inside tmux, press prefix + I once to install plugins"
}

main "$@"
