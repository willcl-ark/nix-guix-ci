{ ... }:
{
  imports = [
    ./hardware.nix
    ./disk-config.nix
  ];

  boot.loader.grub = {
    device = "nodev";
    efiSupport = true;
    efiInstallAsRemovable = true;
  };
}
