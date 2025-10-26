> [!IMPORTANT]
>
> All credit for setting this up goes to @jmbaur -- thank you!

# MixOS-based Nix Remote Builder

This is an example of how one could build a MixOS-based Nix remote builder machine. This is adapted to work with qemu, with the SSH keys seeded into the machine via qemu's fw_cfg, but could be adapted to a cloud service by whatever cloud-native tooling there is to do the same sort of thing.

1. ssh-keygen -t ed25519 -C mixos-builder-server -N "" -f /tmp/server_ssh_key
1. ssh-keygen -t ed25519 -C mixos-builder-client -N "" -f /tmp/client_ssh_key
1. nix build .#mixosConfigurations.remote-builder.config.system.build.all
1. qemu-system-x86_64 -nographic -enable-kvm -smp 4 -m 4G -kernel ./result/bzImage -initrd ./result/initrd -append "quiet console=ttyS0,115200" -fw_cfg name=opt/ssh_key,file=/tmp/server_ssh_key -fw_cfg name=opt/authorized_keys_file,file=/tmp/client_ssh_key.pub -device e1000,netdev=net0 -netdev user,id=net0,hostfwd=tcp::8022-:22
1. nix build nixpkgs#hello -j0 --builders 'ssh-ng://nix@localhost:8022?ssh-key=/tmp/client_ssh_key x86_64-linux - 1 1 nixos-test,benchmark,big-parallel,kvm -'
