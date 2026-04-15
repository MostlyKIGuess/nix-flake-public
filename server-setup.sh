#!/usr/bin/env bash

set -e

# 1. dependencies
echo "Installing system packages..."
if command -v apt-get &> /dev/null; then
    sudo apt-get update || echo "Warning: apt-get update had errors, continuing anyway..."
    sudo apt-get install -y zsh tmux ripgrep curl git unzip build-essential tar cmake gettext ninja-build
elif command -v dnf &> /dev/null; then
    sudo dnf install -y zsh tmux ripgrep curl git unzip gcc tar cmake gettext ninja-build
elif command -v pacman &> /dev/null; then
    sudo pacman -Sy --noconfirm zsh tmux ripgrep curl git unzip base-devel tar cmake gettext ninja
else
    echo "Unsupported package manager. Please install dependencies manually."
fi

# 2. Zoxide
if ! command -v zoxide &> /dev/null; then
    echo "Installing zoxide..."
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    export PATH="$HOME/.local/bin:$PATH"
fi

# 3. eza
if ! command -v eza &> /dev/null; then
    echo "Installing eza..."
    EZA_VERSION=$(curl -s "https://api.github.com/repos/eza-community/eza/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    if [ -n "$EZA_VERSION" ]; then
        curl -LO "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-musl.tar.gz"
        tar xzf eza_x86_64-unknown-linux-musl.tar.gz
        if [ -d "/usr/local/bin" ]; then
            sudo mv eza /usr/local/bin/eza
            sudo chmod +x /usr/local/bin/eza
        else
            sudo mv eza /usr/bin/eza
            sudo chmod +x /usr/bin/eza
        fi
        rm eza_x86_64-unknown-linux-musl.tar.gz
    fi
fi

# 4. fzf
if [ ! -d "$HOME/.fzf" ]; then
    echo "Installing fzf..."
    git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    ~/.fzf/install --all
fi

# 5. yazi
if ! command -v yazi &> /dev/null; then
    echo "Installing yazi..."
    YAZI_VERSION=$(curl -s "https://api.github.com/repos/sxyazi/yazi/releases/latest" | grep -Po '"tag_name": "v\K[^"]*')
    if [ -n "$YAZI_VERSION" ]; then
        curl -LO "https://github.com/sxyazi/yazi/releases/latest/download/yazi-x86_64-unknown-linux-musl.zip"
        unzip yazi-x86_64-unknown-linux-musl.zip
        if [ -d "/usr/local/bin" ]; then
            sudo mv yazi-x86_64-unknown-linux-musl/yazi yazi-x86_64-unknown-linux-musl/ya /usr/local/bin/
        else
            sudo mv yazi-x86_64-unknown-linux-musl/yazi yazi-x86_64-unknown-linux-musl/ya /usr/bin/
        fi
        rm -rf yazi-x86_64-unknown-linux-musl yazi-x86_64-unknown-linux-musl.zip
    fi
fi

# 6. uv
if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    curl -LO "https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-unknown-linux-musl.tar.gz"
    tar xzf uv-x86_64-unknown-linux-musl.tar.gz
    if [ -d "/usr/local/bin" ]; then
        sudo mv uv-x86_64-unknown-linux-musl/uv uv-x86_64-unknown-linux-musl/uvx /usr/local/bin/
    else
        sudo mv uv-x86_64-unknown-linux-musl/uv uv-x86_64-unknown-linux-musl/uvx /usr/bin/
    fi
    rm -rf uv-x86_64-unknown-linux-musl uv-x86_64-unknown-linux-musl.tar.gz
fi

# 7. nvim from Source
if ! command -v nvim &> /dev/null; then
    echo "Installing Neovim from source..."
    rm -rf /tmp/neovim
    git clone https://github.com/neovim/neovim /tmp/neovim
    cd /tmp/neovim
    git checkout stable
    make CMAKE_BUILD_TYPE=RelWithDebInfo
    sudo make install
    cd -
    rm -rf /tmp/neovim
fi

# 8.  tmux
echo "Setting up tmux..."
cat << 'TMUXEOF' > "$HOME/.tmux.conf"
# Plugins
set -g @plugin 'tmux-plugins/tpm'
set -g @plugin 'tmux-plugins/tmux-sensible'
set -g @plugin 'christoomey/vim-tmux-navigator'
set -g @plugin 'tmux-plugins/tmux-yank'

# Kanagawa Status Bar Theme
set -g status-style "bg=#1f1f28,fg=#dcd7ba"
set -g window-status-current-style "bg=#76946a,fg=#1f1f28,bold"
set -g window-status-style "bg=#2a2a37,fg=#717c7c"
set -g pane-active-border-style "fg=#76946a"
set -g pane-border-style "fg=#c0a36e"
set -g message-style "bg=#2d4f67,fg=#c8c093"
set -g message-command-style "bg=#2d4f67,fg=#c8c093"

set -g status-left " #S "
set -g status-right " %H:%M %d-%b-%y "
set -g window-status-format " #I:#W "
set -g window-status-current-format " #I:#W "

# Config
set-option -sa terminal-overrides ",xterm*:Tc"
set -g default-terminal "screen-256color"
set-option -g default-shell /usr/bin/zsh
set -g mouse on

set-window-option -g mode-keys vi
bind-key -T copy-mode-vi v   send-keys -X begin-selection
bind-key -T copy-mode-vi C-v send-keys -X rectangle-toggle
bind-key -T copy-mode-vi y   send-keys -X copy-selection-and-cancel

bind '"' split-window -v -c "#{pane_current_path}"
bind %   split-window -h -c "#{pane_current_path}"
bind Enter split-window -h -c "#{pane_current_path}"

set -g base-index 1
set -g pane-base-index 1
set-window-option -g pane-base-index 1
set-option -g renumber-windows on

bind -n M-H previous-window
bind -n M-L next-window

run '~/.tmux/plugins/tpm/tpm'
TMUXEOF

if [ ! -d "$HOME/.tmux/plugins/tpm" ]; then
    git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
fi

# 9. LazyVim
echo "Setting up Neovim configuration (LazyVim)..."
if [ ! -d "$HOME/.config/nvim" ]; then
    git clone https://github.com/LazyVim/starter ~/.config/nvim
    rm -rf ~/.config/nvim/.git
fi

# 10. Zsh Plugins
echo "Setting up Zsh and plugins..."
ZSH_CUSTOM="$HOME/.zsh_custom"
mkdir -p "$ZSH_CUSTOM/plugins"
mkdir -p "$ZSH_CUSTOM/themes"

[ ! -d "$ZSH_CUSTOM/themes/powerlevel10k" ] && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$ZSH_CUSTOM/themes/powerlevel10k"
[ ! -d "$ZSH_CUSTOM/plugins/fzf-tab" ] && git clone https://github.com/Aloxaf/fzf-tab "$ZSH_CUSTOM/plugins/fzf-tab"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ] && git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ] && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
[ ! -d "$ZSH_CUSTOM/plugins/zsh-history-substring-search" ] && git clone https://github.com/zsh-users/zsh-history-substring-search.git "$ZSH_CUSTOM/plugins/zsh-history-substring-search"

# 11. .zshrc
if [ -f "$HOME/.dotfiles/home-manager/modules/shell/.zshrc" ]; then
    cp "$HOME/.dotfiles/home-manager/modules/shell/.zshrc" "$HOME/.zshrc_base"

    cat << 'ZSHRCEOF' > "$HOME/.zshrc"
# Ensure local bin is in PATH for zoxide and other tools
export PATH="$HOME/.local/bin:$PATH"

# Powerlevel10k theme
source ~/.zsh_custom/themes/powerlevel10k/powerlevel10k.zsh-theme

# Load plugins FIRST before user config so keybinds to widgets don't fail
source ~/.zsh_custom/plugins/fzf-tab/fzf-tab.plugin.zsh
source ~/.zsh_custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh_custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.zsh_custom/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh

# Base config
source ~/.zshrc_base
ZSHRCEOF
fi

if [ -f "$HOME/.dotfiles/home-manager/modules/shell/.p10k.zsh" ]; then
    ln -sf "$HOME/.dotfiles/home-manager/modules/shell/.p10k.zsh" "$HOME/.p10k.zsh"
fi

# default shell
if [ "$SHELL" != "$(which zsh)" ]; then
    echo "Changing default shell to zsh..."
    chsh -s "$(which zsh)" || echo "Please change your shell to zsh manually using 'chsh -s \$(which zsh)'"
fi

echo "Setup complete! Please log out and log back in, or run 'zsh' to start using your new environment."
echo "Note: Press 'Prefix + I' in tmux to install tmux plugins the first time you open it."
