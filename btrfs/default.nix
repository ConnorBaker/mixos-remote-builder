{ lib, pkgs, ... }:
{
  boot.kernelModules = lib.mkAfter [ "btrfs" ];

  state = {
    enable = true;

    init = lib.getExe (
      pkgs.writeShellApplication {
        name = "btrfs-init";
        runtimeInputs = [
          pkgs.btrfs-progs
          pkgs.gptfdisk # sgdisk
          pkgs.parted
        ];
        text = lib.fileContents ./init.sh;
      }
    );

    fsType = "btrfs";

    options = [
      "defaults"
      "noatime"
    ];

    device = "/dev/nvme0n1";
  };
}
