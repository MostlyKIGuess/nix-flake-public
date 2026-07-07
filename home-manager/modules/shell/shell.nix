{ pkgs, ... }:
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
    zsh-fzf-tab
    devenv
  ];

  programs.git = {
    enable = true;
    signing.format = null;
    settings = {
      user.name = "mostlykiguess";
      user.email = "bruvistrue93@gmail.com";
      init.defaultBranch = "main";
      core.editor = "nvim";
      core.whitespace = "fix,-indent-with-non-tab,trailing-space,cr-at-eol";
    };
  };

  programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      navigate = true;
      side-by-side = true;
      line-numbers = true;
    };
  };
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
      theme = "noctalia";
      font-family = "JetBrainsMono Nerd Font";
      font-size = 20;
      window-padding-x = 2;
      window-padding-y = 5;
      cursor-style-blink = true;
      working-directory = "~/";
      window-inherit-working-directory = "false";
      tab-inherit-working-directory = "false";
    };
  };
}
