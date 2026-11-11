{
  description = "mostlyk's NixOS configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-26.05";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # sodiboo/niri-flake stalled on 2026-08-06 still asserting libdisplay-info
    # 0.2.0, which nixpkgs has since replaced with a stub that throws. This fork
    # bumps the assert to 0.3.0 and follows niri to the niri-wm org.
    niri-flake = {
      url = "github:epireyn/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia";
    };

    mostlyk-zed.url = "github:mostlykiguess/zed-nix-cache";

    herdr = {
      url = "github:herdrdev/herdr";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs @ { self, nixpkgs, home-manager, niri-flake, noctalia, mostlyk-zed, ... }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};

      # Host name here is the flake output name (og / bunny), not
      # networking.hostName. Both machines answer to "mostlyk".
      mkHost = host: nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = { inherit inputs host; };
        modules = [
          ./nixos # shared
          ./hosts/${host} # machine-specific
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "backup";
            home-manager.extraSpecialArgs = { inherit inputs mostlyk-zed host; };
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
    in
    {
      nixosConfigurations = {
        og = mkHost "og"; # ASUS, AMD + NVIDIA
        bunny = mkHost "bunny"; # HP, Intel Arrow Lake-H
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
          echo "my dots dev shell :3 wohohohohoh WELCOMEEE - run 'deadnix .' or 'statix check .'"
          exec zsh
        '';
      };

      # nix flake check (dry-build both systems)
      checks.${system} = {
        og = self.nixosConfigurations.og.config.system.build.toplevel;
        bunny = self.nixosConfigurations.bunny.config.system.build.toplevel;
      };
    };
}
