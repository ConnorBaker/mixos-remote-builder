{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./btrfs
    ./ready
  ];

  boot.kernelModules = lib.mkBefore [
    "hv_vmbus"
    "hv_storvsc"
    "hv_netvsc"
    "hv_utils"
    "nvme"
    "pci-hyperv"
  ];

  system.build.vhd =
    pkgs.callPackage
      (
        {
          dosfstools,
          qemu,
          runCommand,
          mtools,
          systemdUkify,
          util-linux,
        }:

        let
          systemdArch =
            {
              "x64" = "x86-64";
              "aa64" = "arm64";
            }
            .${pkgs.stdenv.hostPlatform.efiArch};
        in
        runCommand "mixos.vhd"
          {
            nativeBuildInputs = [
              dosfstools
              mtools
              qemu
              systemdUkify
              util-linux
            ];
          }
          ''
            ukify build \
              --efi-arch=${pkgs.stdenv.hostPlatform.efiArch} \
              --uname=${config.boot.kernel.version} \
              --stub=${pkgs.systemd}/lib/systemd/boot/efi/linux${pkgs.stdenv.hostPlatform.efiArch}.efi.stub \
              --initrd=${config.system.build.initrd}/initrd \
              --linux=${config.boot.kernel}/${pkgs.stdenv.hostPlatform.linux-kernel.target} \
              --cmdline="console=ttyS0,115200 panic=-1 debug" \
              --os-release="ID=mixos" \
              --json=pretty \
              --no-sign-kernel \
              --output=mixos.efi

            cat >esp.conf <<EOF
            [Partition]
            Type=esp
            Format=vfat
            Label=mixos
            CopyFiles=$PWD/mixos.efi:/EFI/boot/boot${pkgs.stdenv.hostPlatform.efiArch}.efi
            EOF

            efi_size=$(stat --format=%s mixos.efi)
            KiB=1024
            MiB=$((1024 * KiB))

            # Azure requires the size of VHDs to be a while number in mebibytes
            azure_vhd_alignment=$((1 * MiB))

            # Extra space for bookkeeping and filesystem data (4 MiB)
            pad_size=$((4 * MiB))
            padded_efi_size=$((pad_size + efi_size + azure_vhd_alignment - efi_size % azure_vhd_alignment))

            systemd-repart \
              --dry-run=no \
              --definitions=$PWD \
              --architecture=${systemdArch} \
              --sector-size=512 \
              --empty=create \
              --size=''${padded_efi_size}B \
              mixos.raw

            qemu-img convert -f raw -o subformat=fixed,force_size -O vpc mixos.raw $out
          ''
      )
      {
      };
}
