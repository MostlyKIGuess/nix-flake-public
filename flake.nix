{
  description = "mostlyk's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    niri-flake = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia-shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    mostlyk-zed.url = "github:mostlykiguess/zed-nix-cache";
  };

  outputs = inputs @ { self, nixpkgs, home-manager, niri-flake, noctalia, mostlyk-zed, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.mostlyk = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs; };
        modules = [
          ./nixos/configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = { inherit inputs mostlyk-zed; };
            home-manager.users.mostlyk = { ... }: {
              imports = [
                ./home-manager/home.nix
                niri-flake.homeModules.niri
                noctalia.homeModules.default
              ];
            };
          }
        ];
      };

      # nix fmt
      formatter.${system} = pkgs.nixpkgs-fmt;

      # nix develop
      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          nixpkgs-fmt # formatter
          deadnix # dead code finder
          statix # nix anti-pattern linter
          nil # nix LSP
        ];
        shellHook = ''
          exec zsh
          echo "my dots dev shell :3 wohohohohoh WELCOMEEE - run 'deadnix .' or 'statix check .'"
        '';
      };

      # nix flake check (dry-build the system)
      checks.${system}.build =
        self.nixosConfigurations.mostlyk.config.system.build.toplevel;
    };
}
