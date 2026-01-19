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

      mkBitcoinCiHost =
        { system, hostConfig }:
        nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            disko.nixosModules.disko
            home-manager.nixosModules.home-manager
            hostConfig
            (
              { pkgs, lib, ... }:
              {
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

                systemd.tmpfiles.rules = [
                  "d /data/sdk 0755 satoshi users -"
                  "d /data/sources 0755 satoshi users -"
                  "d /data/cache 0755 satoshi users -"
                  "d /data/bitcoin 0755 satoshi users -"
                  "d /data/ci 0755 satoshi users -"
                  "L+ /data/ci/guix.cmake - - - - ${./scripts/guix.cmake}"
                  "L+ /data/bitcoin/CTestConfig.cmake - - - - ${./scripts/CTestConfig.cmake}"
                ];

                systemd.services.bitcoin-sdk-download = {
                  description = "Download Bitcoin macOS SDK";
                  wantedBy = [ "multi-user.target" ];
                  unitConfig.ConditionPathExists = "!/data/sdk/Xcode-15.0-15A240d-extracted-SDK-with-libcxx-headers";
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    User = "satoshi";
                    WorkingDirectory = "/data";
                    ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.curl}/bin/curl -fL https://bitcoincore.org/depends-sources/sdks/Xcode-15.0-15A240d-extracted-SDK-with-libcxx-headers.tar | ${pkgs.gnutar}/bin/tar -xf - -C /data/sdk'";
                  };
                };

                systemd.services.bitcoin-repo-setup = {
                  description = "Clone Bitcoin repository";
                  wantedBy = [ "multi-user.target" ];
                  unitConfig.ConditionPathExists = "!/data/bitcoin/.git";
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    User = "satoshi";
                    WorkingDirectory = "/data";
                    ExecStart = "${pkgs.bash}/bin/bash -c 'tmpdir=\$(mktemp -d) && ${pkgs.git}/bin/git clone https://github.com/bitcoin/bitcoin.git \"\$tmpdir\" && mv \"\$tmpdir\"/.git /data/bitcoin/ && mv \"\$tmpdir\"/* /data/bitcoin/ 2>/dev/null; rm -rf \"\$tmpdir\"'";
                  };
                };

                systemd.services.bitcoin-ci = {
                  description = "Bitcoin Guix CI";
                  wantedBy = [ "multi-user.target" ];
                  after = [
                    "bitcoin-sdk-download.service"
                    "bitcoin-repo-setup.service"
                    "guix-daemon.service"
                  ];
                  requires = [
                    "bitcoin-sdk-download.service"
                    "bitcoin-repo-setup.service"
                  ];
                  environment = {
                    SDK_PATH = "/data/sdk";
                    SOURCES_PATH = "/data/sources";
                    BASE_CACHE = "/data/cache";
                    PATH = lib.mkForce "/run/current-system/sw/bin:/run/wrappers/bin";
                  };
                  serviceConfig = {
                    Type = "simple";
                    User = "satoshi";
                    WorkingDirectory = "/data/bitcoin";
                    ExecStartPre = "+${pkgs.bash}/bin/bash -c 'chown -R satoshi:users /data/bitcoin /data/sdk /data/sources /data/cache'";
                    ExecStart = "${pkgs.cmake}/bin/ctest -S /data/ci/guix.cmake -VV";
                    ExecStopPost = "${pkgs.bash}/bin/bash -c 'if [ \"$SERVICE_RESULT\" != \"success\" ]; then sleep 300; fi'";
                    Restart = "always";
                    RestartSec = "0";
                    ReadWritePaths = [
                      "/data/bitcoin"
                      "/data/sdk"
                      "/data/sources"
                      "/data/cache"
                    ];
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
                  gnumake
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

                    git = {
                      enable = true;
                      settings = {
                        user.name = "Satoshi Nakamoto";
                        user.email = "satoshi@bitcoin.org";
                        safe.directory = "/data/bitcoin";
                      };
                    };

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
    in
    {
      formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixfmt-tree;
      formatter.aarch64-linux = nixpkgs.legacyPackages.aarch64-linux.nixfmt-tree;

      nixosConfigurations.guix-ci = mkBitcoinCiHost {
        system = "x86_64-linux";
        hostConfig = ./hosts/guix-ci/configuration.nix;
      };

      nixosConfigurations.guix-ci-arm64 = mkBitcoinCiHost {
        system = "aarch64-linux";
        hostConfig = ./hosts/guix-ci-arm64/configuration.nix;
      };
    };
}
