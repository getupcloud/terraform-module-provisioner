#!/bin/bash

if [ "$PROVISION_DEBUG" == true ]; then
  exec 2>>/var/log/provision.log
  set -x
fi

func=$1_$2
date >&2
echo "Starting [$0 $@: func=$func]" >&2

function _()
{
  :
}

## Join parameters $2... using separator $1
## $1: separator
## $2...: values to join
function join()
{
  local IFS="$1"
  shift
  echo "$*"
}

##############################
##         Packages         ##
##############################

function _yum_update()
{
    yum clean all -y
    yum update -y
}

function _uninstall_packages()
{
  yum remove -y "$@"
}

function _install_packages()
{
  yum install -y --enablerepo=powertools epel-release
  yum install -y --enablerepo=powertools "$@"
}

function _read_packages()
{
  local items=()

  for package; do
    if rpm -q $package &>/dev/null; then
      items+=( "\"$package\":true" )
    else
      items+=( "\"$package\":false" )
    fi
  done

  echo {
  join , "${items[@]}"
  echo }
}

function create_packages()
{
  {
    _yum_update
    _uninstall_packages ${PROVISION_DATA_UNINSTALL_PACKAGES}
    _install_packages ${PROVISION_DATA_INSTALL_PACKAGES}
  } >&2

  _read_packages ${PROVISION_DATA_INSTALL_PACKAGES}
}

function read_packages()
{
  _read_packages ${PROVISION_DATA_INSTALL_PACKAGES}
}

function update_packages()
{
  create_packages
}

function delete_packages()
{
  # do nothing
  echo {}
}

##############################
##           Disks          ##
##############################

function _resolve_device_name()
{
  local device="$1"

  if [ -b "$device" ]; then
    echo $device
    return
  fi

  if [[ $device =~ /^UUID=/ ]]; then
    local uuid=${device#*=}
    lsblk -pnlo UUID,NAME | awk "/^$uuid /{print \$2}"
    return
  elif [[ $device =~ /^PARTUUID=/ ]]; then
    local uuid=${device#*=}
    lsblk -pnlo PARTUUID,NAME | awk "/^$uuid /{print \$2}"
    return
  elif [[ $device =~ /^LABEL=/ ]]; then
    local label=${#*=}
    lsblk -pnlo LABEL,NAME | awk "/^$label /{print \$2}"
    return
  elif [[ $device =~ /^PARTLABEL=/ ]]; then
    local label=${#*=}
    lsblk -pnlo PARTLABEL,NAME | awk "/^$label /{print \$2}"
    return
  fi

  echo Device not found: $device >&2
  return 1
}


# print fstab line for device ($1)
function _fstab_get_line()
{
  local device=$(readlink $1)

  if ! [ -b "$device" ]; then
    echo "Invalid device: $device"
    exit 1
  fi

  local label=$(lsblk -pno LABEL $device)
  local uuid=$(lsblk -pno UUID $device)
  local partuuid=$(lsblk -pno PARTUUID $device)
  local partlabel=$(lsblk -pno PARTLABEL $device)

  grep -m1 -E "^[[:space:]]*($1|$device|UUID=$uuid|LABEL=$label|PARTUUID=$partuid|PARTLABEL=$partlabel)[[:space:]]" /etc/fstab
}

# check if device ($1) is in /etc/fstab
# return 0 if found
# return 1 if not found
function _fstab_has_device()
{
  local device=$1

  if ! [ -b "$device" ]; then
    echo "Invalid device: $device"
    exit 1
  fi

  local uuid=$(get_device_uuid $device)

  _fstab_get_line $device &>/dev/null
}

function _add_to_fstab()
{
  local device=$1
  local mountpoint="$2"
  local filesystem="$3"
  local mount_opts="${4:-}"

  local uuid=$(lsblk -pno UUID $device)
  local fstab_entry="UUID=$uuid ${mountpoint} ${filesystem} defaults,nofail${mount_opts:+,$mount_opts} 0 0"

  echo "$fstab_entry" >> /etc/fstab
}

function _remove_from_fstab()
{
  local device=$1
  local label=$(lsblk -pno LABEL $device)
  local uuid=$(lsblk -pno UUID $device)
  local partuuid=$(lsblk -pno PARTUUID $device)
  local partlabel=$(lsblk -pno PARTLABEL $device)

  sed -i -E "s;^[^\s#]*(UUID=$uuid|LABEL=$label|PARTUUID=$partuuid|PARTLABEL=$partlabel|$device)\s.*;#\0;g"  /etc/fstab
}

function _read_disks()
{
    export PROVISION_DATA_DISKS_JSON="$(base64 -d <<<$PROVISION_DATA_DISKS)"

    if [ "$(jq length <<<$PROVISION_DATA_DISKS_JSON)" -eq 0 ]; then
        echo {}
        return
    fi

    local items=()
    for disk_name in $(jq -r 'keys|.[]' <<<"$PROVISION_DATA_DISKS_JSON"); do
        unset device mountpoint filesystem
        local device mountpoint filesystem
        eval $(jq ".${disk_name}"'|to_entries|map("\(.key)=\"\(.value|tostring)\"")|.[]' -r <<<$PROVISION_DATA_DISKS_JSON)

        if ! device_name=$(_resolve_device_name $device); then
          exit 1
        fi

        local current_mountpoint=$(lsblk -pno MOUNTPOINT "$device_name" || true)
        local current_filesystem=$(lsblk -pno FSTYPE "$device_name" || true)

        items+=(
            '"'${disk_name}'":{"device":"'${device}'","mountpoint":"'${current_mountpoint}'","filesystem":"'${current_filesystem}'"}'
        )
    done

  echo {
  join , "${items[@]}"
  echo }
}

function _create_disks()
{
    if grep -qw swap /etc/fstab ; then
        sed -i -E 's/^([^\s#]+.*\bswap\b.*)/#\0/g' /etc/fstab
    fi
    swapoff -a || true

    export PROVISION_DATA_DISKS_JSON="$(base64 -d <<<$PROVISION_DATA_DISKS)"
    if [ "$(jq length <<<$PROVISION_DATA_DISKS_JSON)" -eq 0 ]; then
        return
    fi

    for disk_name in $(jq -r 'keys|.[]' <<<"$PROVISION_DATA_DISKS_JSON"); do
        unset device mountpoint filesystem filesystem_options format
        eval $(jq ".${disk_name}"'|to_entries|map("\(.key)=\"\(.value|tostring)\"")|.[]' -r <<<$PROVISION_DATA_DISKS_JSON)

        if ! device_name=$(_resolve_device_name $device); then
          exit 1
        fi

        local current_mountpoint=$(lsblk -pno MOUNTPOINT "$device_name" || true)
        local current_filesystem=$(lsblk -pno FSTYPE "$device_name" || true)

        if [ "$disk_name" == containers ]; then
            systemctl stop docker containerd &>/dev/null || true
        fi

        if [ -d "$current_mountpoint" ] && [ "$current_mountpoint" != "$mountpoint" ]; then
          umount "$current_mountpoint"
        fi

        if [ -d "$mountpoint" ]; then
          umount $mountpoint 2>/dev/null || true
        fi

        if [ "$disk_name" == containers ]; then
            if ! [ -d "$mountpoint" ]; then
              mkdir "$mountpoint"
            fi

            for i in docker containerd; do
              umount /var/lib/$i 2>/dev/null || true
              if [ -d /var/lib/$i ]; then
                mv /var/lib/$i "$mountpoint"
              fi

              if ! [ -L /var/lib/$i ]; then
                ln -s "$mountpoint/$i" /var/lib/$i
              fi
            done
        fi

        if [ "$format" == "true" ]; then
            if [ -n "$filesystem" ] && [ "$filesystem" != "$current_filesystem" ]; then
                mkfs.$filesystem $filesystem_options $device_name
            fi
        fi

        _remove_from_fstab $device_name
        _add_to_fstab $device_name $mountpoint $filesystem $mount_options
        mount $mountpoint
    done

  systemctl daemon-reload
}

function create_disks()
{
  status=0
  _create_disks
  _read_disks
  exit $status
}

function read_disks()
{
  status=0
  _read_disks
  exit $status
}

function update_disks()
{
  create_disks
  exit $status
}

function delete_disks()
{
  # do nothing
  echo {}
}

eval $func
