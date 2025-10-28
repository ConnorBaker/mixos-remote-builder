{ lib, pkgs, ... }:
{
  imports = [
    ./azure.nix
  ];

  boot.kernel = pkgs.linuxKernel.manualConfig {
    inherit (pkgs.linux_6_12) src version;
    configfile = ./kernel2.config;
  };

  bin = [
    pkgs.openssh
    pkgs.nix
  ];

  etc = {
    "ntp.conf".source = pkgs.writeText "ntp.conf" ''
      server time.nist.gov
    '';

    # TODO(@connorbaker): Must log in through Azure console to seed /tmp/host_key and /tmp/authorized_keys until
    # automated (cloud-init?).
    "ssh/sshd_config".source = pkgs.writeText "sshd_config" ''
      HostKey /tmp/host_key
      AuthorizedKeysFile /tmp/authorized_keys
      PasswordAuthentication no
      StrictModes no
      SetEnv XDG_CACHE_HOME=/state NIX_STATE_DIR=/state/nix/var/nix

      # Recommended in https://github.com/nixos/nix/blob/b56e456b0df97b53fc889c441c6713c580bf4657/doc/manual/source/package-management/ssh-substituter.md#L44,
      # adapted to work with ssh-ng
      AllowAgentForwarding no
      AllowTcpForwarding no
      PermitTTY no
      PermitTunnel no
      X11Forwarding no
      ForceCommand nix-daemon --stdio
    '';

    "nix/nix.conf".source = pkgs.writeText "nix.conf" ''
      allow-import-from-derivation = false
      allowed-users = nix
      auto-allocate-uids = true
      auto-optimise-store = false
      builders-use-substitutes = true
      cores = 0
      experimental-features = auto-allocate-uids cgroups no-url-literals
      fsync-store-paths = true
      max-jobs = auto
      require-sigs = true
      sandbox = true
      sandbox-fallback = false
      ssl-cert-file = ${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt
      store = /state
      substituters = https://cache.nixos.org/
      system-features = nixos-test benchmark big-parallel kvm uid-range
      trusted-public-keys = cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=
      trusted-users = nix
      use-cgroups = true
    '';

    "passwd".source = pkgs.writeText "passwd" (
      lib.concatLines [
        # nix user used for remote building, note that this user's shell must be
        # a real shell, not something like /bin/nologin
        "nix:x:0:0:nix:/:/bin/sh"

        # sshd user needed for privilege separation
        "sshd:x:1:1:sshd:/var/empty:/bin/nologin"
      ]
    );

    "group".source = pkgs.writeText "group" ''
      nix:x:0:nix
      sshd:x:1:sshd
      nixbld:x:2:
    '';

    # wanted by nix-daemon
    "mdev.conf".source = pkgs.writeText "mdev.conf" ''
      null 0:0 666
    '';
  };

  init = {
    dhcp = {
      action = "respawn";
      process = "/bin/udhcpc -f -S";
    };

    sshd = {
      action = "respawn";
      process = "/bin/sshd";
    };

    shell = {
      tty = "ttyS0";
      action = "askfirst";
      process = "/bin/sh";
    };
  };
}
