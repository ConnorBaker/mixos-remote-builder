{
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./azure
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
      ForceCommand ${lib.getExe' pkgs.nix "nix-daemon"} --stdio
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
  };

  # wanted by nix-daemon
  mdev.rules =
    let
      inherit (config.users.nix) gid uid;
    in
    ''
      null ${toString uid}:${toString gid} 666
    '';

  # Members of groups are provided in the user config.
  # Groups have no notion of UIDs.
  groups = {
    root.id = 0;
    sshd.id = 1;
    nix.id = 2;
    nixbld.id = 3;
  };

  # Users have both user and group IDs.
  users = {
    root = {
      uid = 0;
      gid = config.groups.root.id;
      # nix user used for remote building, note that this user's shell must be
      # a real shell, not something like /bin/nologin
      shell = lib.getExe' pkgs.busybox "sh";
    };

    sshd = {
      # sshd user needed for privilege separation
      uid = 1;
      gid = config.groups.sshd.id;
      shell = lib.getExe' pkgs.busybox "nologin";
    };

    nix = {
      uid = 2;
      gid = config.groups.nix.id;
      # nix user used for remote building, note that this user's shell must be
      # a real shell, not something like /bin/nologin
      shell = lib.getExe' pkgs.busybox "sh";
    };
  };

  init = {
    dhcp = {
      action = "respawn";
      process = "${lib.getExe' pkgs.busybox "udhcpc"} -f -S";
    };

    sshd = {
      action = "respawn";
      process = lib.getExe' pkgs.openssh "sshd";
    };

    shell = {
      tty = "ttyS0";
      action = "askfirst";
      process = lib.getExe' pkgs.busybox "sh";
    };
  };
}
