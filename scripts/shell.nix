{
  pkgs ? import <nixpkgs> { },
}:

pkgs.mkShell {
  packages = with pkgs; [
    cmake
    ninja
    gcc
    pkg-config
    python3
    ccache
    valgrind
  ];
  buildInputs = with pkgs; [
    boost
    libevent
    sqlite
    capnproto
    openssl
    zlib
  ];
}
