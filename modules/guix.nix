{
  pkgs,
  ciUser,
  bitcoinPath,
  ciPath,
  ...
}:
let
  sdkPath = "/data/sdk";
  sourcesPath = "/data/sources";
  cachePath = "/data/cache";
in
{
  services.guix = {
    enable = true;
    package = pkgs.guix;
  };

  systemd.tmpfiles.rules = [
    "d ${sdkPath} 0755 ${ciUser} users -"
    "d ${sourcesPath} 0755 ${ciUser} users -"
    "d ${cachePath} 0755 ${ciUser} users -"
    "L+ ${ciPath}/guix.cmake - - - - ${../scripts/guix.cmake}"
  ];

  systemd.services.bitcoin-sdk-download = {
    description = "Download Bitcoin macOS SDK";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig.ConditionPathExists = "!${sdkPath}/Xcode-26.1.1-17B100-extracted-SDK-with-libcxx-headers";
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      User = ciUser;
      WorkingDirectory = sdkPath;
      ExecStart = "${pkgs.bash}/bin/bash -c '${pkgs.curl}/bin/curl -fL https://bitcoincore.org/depends-sources/sdks/Xcode-26.1.1-17B100-extracted-SDK-with-libcxx-headers.tar | ${pkgs.gnutar}/bin/tar -xf - -C ${sdkPath}'";
    };
  };

  systemd.services.bitcoin-ci = {
    after = [
      "bitcoin-sdk-download.service"
      "guix-daemon.service"
    ];
    requires = [ "bitcoin-sdk-download.service" ];
    environment = {
      SDK_PATH = sdkPath;
      SOURCES_PATH = sourcesPath;
      BASE_CACHE = cachePath;
    };
    serviceConfig = {
      ExecStartPre = "+${pkgs.bash}/bin/bash -c 'chown -R ${ciUser}:users ${bitcoinPath} ${sdkPath} ${sourcesPath} ${cachePath}'";
      ExecStart = "${pkgs.cmake}/bin/ctest -S ${ciPath}/guix.cmake -VV";
      ReadWritePaths = [
        sdkPath
        sourcesPath
        cachePath
      ];
    };
  };
}
