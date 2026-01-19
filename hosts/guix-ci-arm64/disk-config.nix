# QEMU ARM64 VM at prevps (Hetzner Cloud infrastructure)
#
# Two-disk layout:
#   - HC_Volume (10G): ESP only at /boot
#   - QEMU HARDDISK (152G): root + data
#
# Uses by-id paths because /dev/sd* names change between boot environments.
# Find with: ls -la /dev/disk/by-id/
{ lib, ... }:
{
  disko.devices = {
    disk.boot = {
      device = lib.mkDefault "/dev/disk/by-id/scsi-0HC_Volume_104432939";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          esp = {
            name = "ESP";
            size = "512M";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
            };
          };
        };
      };
    };
    disk.main = {
      device = lib.mkDefault "/dev/disk/by-id/scsi-0QEMU_QEMU_HARDDISK_109984918";
      type = "disk";
      content = {
        type = "gpt";
        partitions = {
          root = {
            name = "root";
            size = "50G";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
            };
          };
          data = {
            name = "data";
            size = "100%";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/data";
            };
          };
        };
      };
    };
  };
}
