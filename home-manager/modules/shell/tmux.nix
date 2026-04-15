{ pkgs, ... }:
{
  programs.tmux = {
    enable = true;
    plugins = with pkgs; [
      tmuxPlugins.sensible
      tmuxPlugins.vim-tmux-navigator
      tmuxPlugins.yank
    ];
    extraConfig = ''
      set-option -sa terminal-overrides ",xterm*:Tc"
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

      # Kanagawa colors
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
    '';
  };
}
