#!/usr/bin/env bash

set -Eeuo pipefail

setup_script_name="$(basename "$0")"
readonly setup_script_name
readonly dotfiles_root="${SERVER_SETUP_DOTFILES_ROOT:-$HOME/.dotfiles}"
readonly install_editor="${SERVER_SETUP_INSTALL_EDITOR:-1}"
readonly local_binary_directory="$HOME/.local/bin"
readonly local_option_directory="$HOME/.local/opt"

setup_temp_directory=""

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
Usage: $setup_script_name [--check]

Install and configure the interactive shell tools used on Linux compute hosts.

Options:
  --check  Validate the host and managed configuration without changing it.
  --help   Show this help.

Environment:
  SERVER_SETUP_DOTFILES_ROOT   Dotfiles checkout. Default: \$HOME/.dotfiles
  SERVER_SETUP_INSTALL_EDITOR  Install Neovim when set to 1. Default: 1
  SERVER_SETUP_EZA_VERSION     eza release tag override.
  SERVER_SETUP_YAZI_VERSION    Yazi release tag override.
  SERVER_SETUP_UV_VERSION      uv release tag override.
  SERVER_SETUP_NVIM_VERSION    Neovim release tag override.
  SERVER_SETUP_ZOXIDE_VERSION  zoxide release tag override.
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
            ca-certificates curl fzf git ripgrep tmux unzip xz-utils zsh
    elif command -v dnf >/dev/null 2>&1; then
        run_privileged dnf install -y \
            ca-certificates curl fzf git ripgrep tmux unzip xz zsh
    elif command -v pacman >/dev/null 2>&1; then
        run_privileged pacman -Syu --needed --noconfirm \
            ca-certificates curl fzf git ripgrep tmux unzip xz zsh
    else
        fail "supported package manager not found"
    fi
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
    unzip -q "$tool_directory/yazi.zip" -d "$tool_directory"
    [[ -x "$tool_directory/yazi-$target/yazi" ]] ||
        fail "Yazi archive did not contain yazi"
    [[ -x "$tool_directory/yazi-$target/ya" ]] ||
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

configure_default_shell() {
    local login_user
    local zsh_path

    login_user="$(id -un)"
    zsh_path="$(command -v zsh)"
    if [[ "${SHELL:-}" == "$zsh_path" ]]; then
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
}

main() {
    local check_only=0

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
        --help)
            usage
            return
            ;;
        *)
            usage >&2
            exit 64
            ;;
    esac

    validate_host
    if (( check_only == 1 )); then
        log "host and managed configuration passed preflight"
        return
    fi

    setup_temp_directory="$(mktemp -d)"
    install_system_packages
    export PATH="$local_binary_directory:$PATH"
    mkdir -p "$local_binary_directory" "$local_option_directory"

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
