{ pkgs, ... }:
{
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      nerd-fonts.fira-code
      meslo-lgs-nf
      noto-fonts
      noto-fonts-color-emoji
      roboto
      corefonts
      andika
      fantasque-sans-mono
      lato
    ];
    fontconfig.defaultFonts = {
      monospace = [ "JetBrainsMono Nerd Font Mono" ];
      sansSerif = [ "Roboto" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };
}
