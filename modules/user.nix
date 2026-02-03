{
  pkgs,
  sshKeys,
  ciUser,
  bitcoinPath,
  stateVersion,
  ...
}:
{
  users.users.${ciUser} = {
    isNormalUser = true;
    openssh.authorizedKeys.keys = sshKeys;
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
          safe.directory = [ bitcoinPath ];
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
}
