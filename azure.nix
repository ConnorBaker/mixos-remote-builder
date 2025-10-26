{ config, pkgs, ... }:
{
  # bin = [ pkgs.util-linux pkgs.dosfstools pkgs.udftools pkgs.gnuparted pkgs.python3 ];

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
            CopyFiles=$(pwd)/mixos.efi:/EFI/boot/boot${pkgs.stdenv.hostPlatform.efiArch}.efi
            EOF

            efi_size=$(stat --format=%s mixos.efi)
            max_size=$((150 * 1024 * 1024))
            if $((efi_size > max_size)); then
              nixErrorLog "mixos UKI has exceeded max size"
              exit 1
            fi

            systemd-repart \
              --dry-run=no \
              --definitions=$(pwd) \
              --architecture=${systemdArch} \
              --sector-size=512 \
              --empty=create \
              --size=150M \
              mixos.raw

            qemu-img convert -f raw -o subformat=fixed,force_size -O vpc mixos.raw $out
          ''
      )
      {
      };
}
