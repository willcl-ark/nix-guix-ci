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
      ciUser = "satoshi";
      sdkPath = "/data/sdk";
      sourcesPath = "/data/sources";
      cachePath = "/data/cache";
      bitcoinPath = "/data/bitcoin";
      ciPath = "/data/ci";

      mkBitcoinCiHost =
        { system, hostConfig, siteName }:
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
                  "d ${sdkPath} 0755 ${ciUser} users -"
                  "d ${sourcesPath} 0755 ${ciUser} users -"
                  "d ${cachePath} 0755 ${ciUser} users -"
                  "d ${bitcoinPath} 0755 ${ciUser} users -"
                  "d ${ciPath} 0755 ${ciUser} users -"
                  "L+ ${ciPath}/guix.cmake - - - - ${./scripts/guix.cmake}"
                  "L+ ${bitcoinPath}/CTestConfig.cmake - - - - ${./scripts/CTestConfig.cmake}"
                ];

                systemd.services.bitcoin-sdk-download = {
                  description = "Download Bitcoin macOS SDK";
                  wantedBy = [ "multi-user.target" ];
                  unitConfig.ConditionPathExists = "!${sdkPath}/Xcode-15.0-15A240d-extracted-SDK-with-libcxx-headers";
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    User = ciUser;
                    WorkingDirectory = sdkPath;
                    ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.curl}/bin/curl -fL https://bitcoincore.org/depends-sources/sdks/Xcode-15.0-15A240d-extracted-SDK-with-libcxx-headers.tar | ${pkgs.gnutar}/bin/tar -xf - -C ${sdkPath}'";
                  };
                };

                systemd.services.bitcoin-repo-setup = {
                  description = "Clone Bitcoin repository";
                  wantedBy = [ "multi-user.target" ];
                  unitConfig.ConditionPathExists = "!${bitcoinPath}/.git";
                  serviceConfig = {
                    Type = "oneshot";
                    RemainAfterExit = true;
                    User = ciUser;
                    WorkingDirectory = bitcoinPath;
                    ExecStart = "${pkgs.bash}/bin/bash -c 'tmpdir=\$(mktemp -d) && ${pkgs.git}/bin/git clone https://github.com/bitcoin/bitcoin.git \"\$tmpdir\" && mv \"\$tmpdir\"/.git ${bitcoinPath}/ && mv \"\$tmpdir\"/* ${bitcoinPath}/ 2>/dev/null; rm -rf \"\$tmpdir\"'";
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
                    SITE_NAME = siteName;
                    BITCOIN_PATH = bitcoinPath;
                    SDK_PATH = sdkPath;
                    SOURCES_PATH = sourcesPath;
                    BASE_CACHE = cachePath;
                    PATH = lib.mkForce "/run/current-system/sw/bin:/run/wrappers/bin";
                  };
                  serviceConfig = {
                    Type = "simple";
                    User = ciUser;
                    WorkingDirectory = bitcoinPath;
                    ExecStartPre = "+${pkgs.bash}/bin/bash -c 'chown -R ${ciUser}:users ${bitcoinPath} ${sdkPath} ${sourcesPath} ${cachePath}'";
                    ExecStart = "${pkgs.cmake}/bin/ctest -S ${ciPath}/guix.cmake -VV";
                    ExecStopPost = "${pkgs.bash}/bin/bash -c 'if [ \"$SERVICE_RESULT\" != \"success\" ]; then sleep 300; fi'";
                    Restart = "always";
                    RestartSec = "0";
                    ReadWritePaths = [
                      bitcoinPath
                      sdkPath
                      sourcesPath
                      cachePath
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

                environment.systemPackages = [
                  pkgs.bash
                  pkgs.bat
                  pkgs.cmake
                  pkgs.coreutils
                  pkgs.curl
                  pkgs.docker
                  pkgs.eza
                  pkgs.fd
                  pkgs.findutils
                  pkgs.git
                  pkgs.gnugrep
                  pkgs.gnumake
                  pkgs.gnused
                  pkgs.gnutar
                  pkgs.htop
                  pkgs.jq
                  pkgs.just
                  pkgs.magic-wormhole
                  pkgs.mosh
                  pkgs.neovim
                  pkgs.podman
                  pkgs.python3
                  pkgs.ripgrep
                  pkgs.time
                  pkgs.tmux
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

                users.users.${ciUser} = {
                  isNormalUser = true;
                  openssh.authorizedKeys.keys = ssh_keys;
                  extraGroups = [ "wheel" ];
                  home = "/home/${ciUser}";
                };

                home-manager.users.${ciUser} = {
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
                        safe.directory = bitcoinPath;
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
        siteName = "hetzner-2776510";
      };

      nixosConfigurations.guix-ci-arm64 = mkBitcoinCiHost {
        system = "aarch64-linux";
        hostConfig = ./hosts/guix-ci-arm64/configuration.nix;
        siteName = "prevps-10844";
      };
    };
}
