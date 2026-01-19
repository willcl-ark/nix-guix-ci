{ ... }:
{
  imports = [
    ./hardware.nix
    ./disk-config.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = false;
  boot.loader.efi.efiSysMountPoint = "/boot";

  # UEFI auto-detect fails on this host, so we use startup.nsh as fallback.
  # UEFI shell executes startup.nsh automatically when other boot options fail.
  systemd.tmpfiles.rules = [
    "f /boot/startup.nsh 0644 root root - FS0:\\EFI\\BOOT\\BOOTAA64.EFI"
  ];
}
