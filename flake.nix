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
      ssh_keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIH988C5DbEPHfoCphoW23MWq9M6fmA4UTXREiZU0J7n0 will.hetzner@temp.com"
      ];
      stateVersion = "25.11";
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;

      nixosConfigurations.ax52 = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [
          disko.nixosModules.disko
          home-manager.nixosModules.home-manager
          ./hosts/ax52/configuration.nix
          (
            { pkgs, ... }:
            {
              boot.loader.grub = {
                efiSupport = true;
                efiInstallAsRemovable = true;
              };

              powerManagement = {
                enable = true;
                cpuFreqGovernor = "performance";
                powertop.enable = false;
              };

              services = {
                timesyncd.enable = false;
                acpid.enable = false;
                thermald.enable = false;
                power-profiles-daemon.enable = false;
                guix = {
                  enable = true;
                  package = pkgs.guix;
                };
                journald.extraConfig = ''
                  SystemMaxUse=500M
                  MaxRetentionSec=1month
                '';
                openssh = {
                  enable = true;
                  settings = {
                    PasswordAuthentication = false;
                    PermitRootLogin = "yes";
                    AllowTcpForwarding = "no";
                    X11Forwarding = false;
                  };
                };
                fail2ban = {
                  enable = true;
                  maxretry = 5;
                  bantime = "24h";
                };
              };

              nix.settings.experimental-features = [
                "nix-command"
                "flakes"
              ];

              time.timeZone = "UTC";

              environment.variables = {
                EDITOR = "nvim";
                VISUAL = "nvim";
                PAGER = "less";
              };

              environment.systemPackages = with pkgs; [
                bash
                bat
                cmake
                coreutils
                curl
                docker
                eza
                fd
                findutils
                git
                gnugrep
                gnused
                gnutar
                htop
                jq
                just
                magic-wormhole
                mosh
                neovim
                podman
                python3
                ripgrep
                time
                tmux
              ];

              networking.firewall = {
                enable = true;
                allowedTCPPorts = [ 22 ];
                allowPing = true;
              };

              security.sudo = {
                enable = true;
                wheelNeedsPassword = false;
              };

              users.users.root.openssh.authorizedKeys.keys = ssh_keys;

              users.users.satoshi = {
                isNormalUser = true;
                openssh.authorizedKeys.keys = ssh_keys;
                extraGroups = [ "wheel" ];
                home = "/home/satoshi";
              };

              home-manager.users.satoshi = {
                home.packages = with pkgs; [
                  direnv
                  fzf
                  starship
                  zoxide
                ];
                home.preferXdgDirectories = true;

                home.shellAliases = {
                  vim = "nvim";
                  ls = "eza";
                  ll = "eza -al";
                  ".." = "cd ..";
                };

                programs = {
                  bash.enable = true;
                  bash.bashrcExtra = "";

                  direnv = {
                    enable = true;
                    enableBashIntegration = true;
                    package = pkgs.direnv;
                    nix-direnv = {
                      enable = true;
                      package = pkgs.nix-direnv;
                    };
                  };

                  fzf = {
                    enable = true;
                    enableBashIntegration = true;
                  };

                  starship = {
                    enable = true;
                  };

                  zoxide = {
                    enable = true;
                    enableBashIntegration = true;
                  };

                  home-manager.enable = true;
                };

                home.stateVersion = stateVersion;
              };

              system.stateVersion = stateVersion;
            }
          )
        ];
      };
    };
}
