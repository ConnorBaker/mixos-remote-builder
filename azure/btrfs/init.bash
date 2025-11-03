#shellcheck shell=bash

_log() {
  if (($# != 2)); then
    echo "_log: missing function name and message" >&2
    exit 1
  fi
  echo "[$(date)][${1:?}] ${2:?}"
}

setupBtrfsMntFsVolume() {
  log() { _log "setupBtrfsMntFsVolume" "$@"; }
  local -ar disks=(
    "/dev/nvme0n1"
    "/dev/nvme1n1"
  )

  log "Creating Btrfs volume"
  for disk in "${disks[@]}"; do
    log "Processing $disk"

    log "Wiping disk"
    sgdisk --zap-all "$disk"

    log "Creating GPT"
    parted --script "$disk" mklabel gpt mkpart primary 0% 100%
  done

  log "Waiting for device nodes to appear"
  # TODO(@connorbaker): fix
  sleep 2

  log "Formatting disks"
  # Don't TRIM because it's slow.
  mkfs.btrfs --force --label fs --data raid0 --nodiscard "${disks[@]}"

  log "Done!"
}

setupBtrfsMntFsVolume
