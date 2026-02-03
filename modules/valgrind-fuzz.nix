{
  pkgs,
  ciUser,
  bitcoinPath,
  ciPath,
  ...
}:
let
  qaAssetsPath = "/data/qa-assets";
  buildPath = "/data/build";
  shellFile = pkgs.writeText "shell.nix" ''
    let pkgs = import ${pkgs.path} {}; in
    pkgs.mkShell {
      packages = with pkgs; [ cmake ninja gcc pkg-config python3 ccache valgrind ];
      buildInputs = with pkgs; [ boost libevent sqlite capnproto openssl zlib ];
    }
  '';
in
{
  systemd.tmpfiles.rules = [
    "d ${qaAssetsPath} 0755 ${ciUser} users -"
    "d ${buildPath} 0755 ${ciUser} users -"
    "L+ ${ciPath}/valgrind-fuzz.cmake - - - - ${../scripts/valgrind-fuzz.cmake}"
    "L+ ${bitcoinPath}/CMakeUserPresets.json - - - - ${../scripts/CMakeUserPresets.json}"
    "L+ ${ciPath}/shell.nix - - - - ${../scripts/shell.nix}"
  ];

  systemd.services.bitcoin-qa-assets-setup = {
    description = "Clone qa-assets repository";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!${qaAssetsPath}/.git";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = ciUser;
      WorkingDirectory = qaAssetsPath;
      ExecStart = "${pkgs.bash}/bin/bash -c 'tmpdir=\$(mktemp -d) && ${pkgs.git}/bin/git clone https://github.com/bitcoin-core/qa-assets.git \"\$tmpdir\" && mv \"\$tmpdir\"/.git ${qaAssetsPath}/ && mv \"\$tmpdir\"/* ${qaAssetsPath}/ 2>/dev/null && rm -rf \"\$tmpdir\"'";
    };
  };

  systemd.services.bitcoin-ci = {
    after = [ "bitcoin-qa-assets-setup.service" ];
    requires = [ "bitcoin-qa-assets-setup.service" ];
    environment = {
      QA_ASSETS_PATH = qaAssetsPath;
    };
    serviceConfig = {
      ExecStartPre = "+${pkgs.bash}/bin/bash -c 'chown -R ${ciUser}:users ${bitcoinPath} ${qaAssetsPath} ${buildPath}'";
      ExecStart = "${pkgs.nix}/bin/nix-shell -I nixpkgs=${pkgs.path} ${shellFile} --run '${pkgs.cmake}/bin/ctest -S ${ciPath}/valgrind-fuzz.cmake -VV'";
      ReadWritePaths = [
        buildPath
        qaAssetsPath
      ];
    };
  };

  home-manager.users.${ciUser}.programs.git.settings.safe.directory = [ qaAssetsPath ];
}
