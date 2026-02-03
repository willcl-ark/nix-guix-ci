{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.home-manager.url = "github:nix-community/home-manager/release-25.11";
  inputs.home-manager.inputs.nixpkgs.follows = "nixpkgs";

  outputs =
    {
      nixpkgs,
      disko,
      home-manager,
      ...
    }:
    let
      sshKeys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH988C5DbEPHfoCphoW23MWq9M6fmA4UTXREiZU0J7n0 will.hetzner@temp.com"
      ];
      stateVersion = "25.11";
      ciUser = "satoshi";
      bitcoinPath = "/data/bitcoin";
      ciPath = "/data/ci";

      commonSpecialArgs = {
        inherit
          sshKeys
          stateVersion
          ciUser
          bitcoinPath
          ciPath
          ;
      };

      commonModules = [
        disko.nixosModules.disko
        home-manager.nixosModules.home-manager
        ./modules/base.nix
        ./modules/user.nix
        ./modules/bitcoin-ci.nix
      ];
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
      formatter.aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixfmt-tree;

      nixosConfigurations.guix-ci = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = commonSpecialArgs // {
          siteName = "hetzner-2776510";
        };
        modules = commonModules ++ [
          ./hosts/guix-ci/configuration.nix
          ./modules/guix.nix
        ];
      };

      nixosConfigurations.guix-ci-arm64 = nixpkgs.lib.nixosSystem {
        system = "aarch64-linux";
        specialArgs = commonSpecialArgs // {
          siteName = "prevps-10844";
        };
        modules = commonModules ++ [
          ./hosts/guix-ci-arm64/configuration.nix
          ./modules/guix.nix
        ];
      };

      nixosConfigurations.valgrind-fuzz = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = commonSpecialArgs // {
          siteName = "hetzner-2870284";
        };
        modules = commonModules ++ [
          ./hosts/valgrind-fuzz/configuration.nix
          ./modules/valgrind-fuzz.nix
        ];
      };
    };
}
