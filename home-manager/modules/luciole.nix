{ config, osConfig, lib, host, ... }:
{
  programs.noctalia.settings.theme.templates.user.luciole = lib.mkIf (host == "bunny") {
    input_path = "${osConfig.programs.luciole.package}/share/luciole/templates/colors.toml";
    output_path = "${config.xdg.configHome}/luciole/colors.toml";
  };
}
