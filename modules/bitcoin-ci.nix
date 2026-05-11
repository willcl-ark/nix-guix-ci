{
  pkgs,
  lib,
  siteName,
  ciUser,
  bitcoinPath,
  ciPath,
  ...
}:
{
  systemd.tmpfiles.rules = [
    "d ${bitcoinPath} 0755 ${ciUser} users -"
    "d ${ciPath} 0755 ${ciUser} users -"
    "L+ ${bitcoinPath}/CTestCustom.cmake - - - - ${../scripts/CTestCustom.cmake}"
  ];

  systemd.services.bitcoin-repo-setup = {
    description = "Clone Bitcoin repository";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!${bitcoinPath}/.git";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = ciUser;
      WorkingDirectory = bitcoinPath;
      ExecStart = "${pkgs.bash}/bin/bash -c 'tmpdir=\$(mktemp -d) && ${pkgs.git}/bin/git clone https://github.com/bitcoin/bitcoin.git \"\$tmpdir\" && mv \"\$tmpdir\"/.git ${bitcoinPath}/ && mv \"\$tmpdir\"/* ${bitcoinPath}/ 2>/dev/null && rm -rf \"\$tmpdir\"'";
    };
  };

  systemd.services.bitcoin-ci = {
    description = "Bitcoin CI";
    wantedBy = [ "multi-user.target" ];
    after = [ "bitcoin-repo-setup.service" ];
    requires = [ "bitcoin-repo-setup.service" ];
    environment = {
      SITE_NAME = siteName;
      BITCOIN_PATH = bitcoinPath;
      PATH = lib.mkForce "/run/current-system/sw/bin:/run/wrappers/bin";
    };
    serviceConfig = {
      Type = "simple";
      User = ciUser;
      WorkingDirectory = bitcoinPath;
      ExecStopPost = "${pkgs.bash}/bin/bash -c 'if [ \"$SERVICE_RESULT\" != \"success\" ]; then sleep 300; fi'";
      Restart = "always";
      RestartSec = "0";
      ReadWritePaths = [ bitcoinPath ];
    };
  };
}
