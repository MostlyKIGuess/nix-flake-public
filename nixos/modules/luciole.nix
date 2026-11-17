{ inputs, ... }:
{
  imports = [ inputs.luciole.nixosModules.default ];

  programs.luciole.enable = true;
}
