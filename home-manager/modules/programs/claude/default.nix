{ config, lib, ... }:
let
  here = "${config.home.homeDirectory}/.dotfiles/home-manager/modules/programs/claude";
  link = path: config.lib.file.mkOutOfStoreSymlink "${here}/${path}";
  skills = lib.attrNames (lib.filterAttrs (_: type: type == "directory") (builtins.readDir ./skills));
in
{
  home.file = lib.listToAttrs (map
    (name: lib.nameValuePair ".claude/skills/${name}" { source = link "skills/${name}"; })
    skills) // {
    ".claude/agents/researcher.md".source = link "agents/researcher.md";
    ".claude/krish-llm.md".source = link "krish-llm.md";
  };

  xdg.configFile."opencode/agents/researcher.md".source = link "opencode/researcher.md";
}
