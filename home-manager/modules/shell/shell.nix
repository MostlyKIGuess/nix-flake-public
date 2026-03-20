{ pkgs, lib, ... }:
{
  imports = [
    ./neovim.nix
    ./tmux.nix
    ./direnv.nix
    ./ssh.nix
  ];

  home.packages = with pkgs; [
    zsh-powerlevel10k
    zsh-history-substring-search
    fzf
    zsh-fzf-tab
    eza
    zoxide
    tmux
    devenv
  ];

  programs.git.enable = true;
  home.file.".gitconfig".source = ./.gitconfig;

  programs.gh = {
    enable = true;
    gitCredentialHelper.enable = true;
  };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    historySubstringSearch.enable = true;

    initContent = ''
      source ${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k/powerlevel10k.zsh-theme
      source ~/.p10k.zsh
    '' + builtins.readFile ./.zshrc;

    plugins = [
      { name = "fzf-tab"; src = pkgs.zsh-fzf-tab; }
    ];
  };

  home.file.".p10k.zsh".source = ./.p10k.zsh;

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.ghostty = {
    enable = true;
    enableZshIntegration = true;
    installBatSyntax = true;
    installVimSyntax = true;
    settings = {
      font-family = "JetBrainsMono Nerd Font";
      font-size = 20;
      window-padding-x = 5;
      window-padding-y = 5;
      cursor-style-blink = true;
      working-directory = "home";
      window-inherit-working-directory = "false";
    };
  };

  programs.kitty = {
    enable = true;
    font.size = lib.mkForce 20;
    font.name = lib.mkForce "JetBrainsMono Nerd Font";
    shellIntegration.enableZshIntegration = true;
    settings = {
      enable_audio_bell = false;
      window_padding_width = 5;
      copy_on_select = true;
      clipboard_control = "write-clipboard read-clipboard write-primary read-primary";
      active_border_color = "None";
      cursor_trail = "1";
      include = "themes/noctalia.conf";
    };
  };
}
