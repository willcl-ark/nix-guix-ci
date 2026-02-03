{
  pkgs,
  sshKeys,
  stateVersion,
  ...
}:
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

  environment.systemPackages = [
    pkgs.bash
    pkgs.bat
    pkgs.cmake
    pkgs.coreutils
    pkgs.curl
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
    pkgs.neovim
    pkgs.python3
    pkgs.ripgrep
    pkgs.time
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

  users.users.root.openssh.authorizedKeys.keys = sshKeys;

  system.stateVersion = stateVersion;
}
