#!/bin/bash

trap "rm -vf $0 >&2" EXIT

# placeholder=enviroment - DO NOT REMOVE THIS LINE

if [ "$PROVISION_DEBUG" == true ]; then
  #exec 2>>/var/log/provision.log
  set -x
fi

func=$1_$2
date >&2
echo "Starting [$0 $@: func=$func $(id)]" >&2

function _()
{
  :
}

function _sudo()
{
    if [ -n "$PROVISION_SSH_PASSWORD" ]; then
        echo -n "$PROVISION_SSH_PASSWORD" | sudo -S  -p '' "$@"
    else
        sudo "$@"
    fi
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
##           Setup          ##
##############################

if [ -e /etc/os-release ]; then
    source /etc/os-release
fi

if ! jq --version &>/dev/null; then
    _sudo dnf install -y jq
fi

##############################
##     Auth: ssh/sudo       ##
##############################

SUDOERS_FILE="/etc/sudoers.d/${PROVISION_SSH_USER//./_}"
SUDOERS_FILE="${SUDOERS_FILE//\~/_}"
HOME_SSH_DIR="$HOME/.ssh"
AUTHORIZED_KEYS_FILE="$HOME_SSH_DIR/authorized_keys"

function load_ssh_key()
{
    export SSH_PRIVATE_KEY_DATA=$(base64 -d <<<$PROVISION_SSH_PRIVATE_KEY_DATA)
    export SSH_PUBLIC_KEY_DATA=$(ssh-keygen -yf /dev/stdin <<<$SSH_PRIVATE_KEY_DATA)
    export SSH_PUBLIC_KEY_DATA_ONLY=$(awk '{print $1 $2}' <<<$SSH_PUBLIC_KEY_DATA)
}

function ensure_ssh_key()
{
    if [ -z "$PROVISION_SSH_PRIVATE_KEY_DATA" ]; then
        return
    fi

    load_ssh_key

    if ! grep -q "$SSH_PUBLIC_KEY_DATA_ONLY" $AUTHORIZED_KEYS_FILE; then
        mkdir -p $HOME_SSH_DIR || true
        chmod 700 $HOME_SSH_DIR
        echo "$SSH_PUBLIC_KEY_DATA" >> $AUTHORIZED_KEYS_FILE
        chmod 600 $AUTHORIZED_KEYS_FILE
        chown $PROVISION_SSH_USER $AUTHORIZED_KEYS_FILE
    fi
}

function ensure_sudoers()
{
    local sudoers_entry="$PROVISION_SSH_USER ALL=(ALL) NOPASSWD: ALL"

    if ! _sudo grep -q "$sudoers_entry" $SUDOERS_FILE; then
        _sudo bash -xc "echo '$sudoers_entry' >> $SUDOERS_FILE"
    fi
}

function create_auth()
{
    ensure_ssh_key
    ensure_sudoers
    read_auth
}

function read_auth()
{
    local sudoers_id=$(_sudo md5sum $SUDOERS_FILE 2>/dev/null | awk '{print $1}') || true
    local authorized_keys_id=$(md5sum $AUTHORIZED_KEYS_FILE 2>/dev/null | awk '{print $1}') || true

    echo {
    echo '  "sudoers_id":' "\"$sudoers_id\"",
    echo '  "authorized_keys_id":' "\"$authorized_keys_id\""
    echo }
}

function update_auth()
{
    create_auth
}

function delete_auth()
{
  # do nothing
  echo {}
}

##############################
##         /ETC/HOSTS       ##
##############################

ETC_HOSTS_MARK="# Auto-generate by getupcloud/terraform-module-provisioner"
ETC_HOSTS_FILE=/etc/hosts

function create_etc_hosts()
{
    local PROVISION_DATA_ETC_HOSTS_JSON=$(base64 -d <<<$PROVISION_DATA_ETC_HOSTS)
    local ips=( $(jq '.|keys|.[]' -r <<<$PROVISION_DATA_ETC_HOSTS_JSON) )

    if [ ${#ips[*]} -eq 0 ]; then
        return
    fi

    for ip in $(sort -u <<<${ips[*]}); do
        local hosts=(
            $(jq -r ".\"$ip\"" <<<$PROVISION_DATA_ETC_HOSTS_JSON | sort -u)
        )

        local line="${ip} ${hosts[*]} ${ETC_HOSTS_MARK}"
        if grep -q "^\s*${ip}.*${ETC_HOSTS_MARK}\s*\$" $ETC_HOSTS_FILE; then
            sed -i -e "s|^\s*${ip//./\\.}.*${ETC_HOSTS_MARK}\s*\$|$line|" $ETC_HOSTS_FILE
        else
            echo >> $ETC_HOSTS_FILE
            echo "$ip ${hosts[*]} $ETC_HOSTS_MARK" >>$ETC_HOSTS_FILE
        fi
    done
}

function read_etc_hosts()
{
    local total=$(grep -v '^\s*#.*' $ETC_HOSTS_FILE | grep ".*${ETC_HOSTS_MARK}\$" | wc -l)
    local i=1
    echo {
    grep -v '^\s*#.*' $ETC_HOSTS_FILE | grep ".*${ETC_HOSTS_MARK}\$" | sed -e 's/#.*//' | tr -s ' ' | while read line; do
        ip=${line%% *}
        hosts=${line#* }
        echo -n "\"$ip\": \"$hosts\""
        (( i < total )) && echo , || echo
        let i=i+1
    done
    echo }
}

function update_etc_hosts()
{
    create_etc_hosts
}

function delete_etc_hosts()
{
  # do nothing
  echo {}
}

##############################
##         Packages         ##
##############################

function _dnf_update()
{
    dnf clean all -y
    dnf update -y
}

function _uninstall_packages()
{
  dnf remove -y "$@"
}

function _install_packages()
{
  if [ "$ID" == centos ] && [ "$VERSION_ID" == 8 ]; then
    dnf config-manager --set-enabled powertools
    dnf install -y epel-release
    dnf install -y "$@"
  elif [ "$ID" == centos ] && [ "$VERSION_ID" == 9 ]; then
    dnf config-manager --set-enabled crb
    dnf install -y epel-release epel-next-release
    dnf install -y "$@"
  fi
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
  if ! which dnf &>/dev/null; then
    echo {}
    return
  fi

  {
    # _dnf_update
    _uninstall_packages ${PROVISION_DATA_UNINSTALL_PACKAGES}
    _install_packages ${PROVISION_DATA_INSTALL_PACKAGES}
  } >&2

  _read_packages ${PROVISION_DATA_INSTALL_PACKAGES}
}

function read_packages()
{
  if ! which dnf &>/dev/null; then
    echo {}
    return
  fi

  _read_packages ${PROVISION_DATA_INSTALL_PACKAGES}
}

function update_packages()
{
  if ! which dnf &>/dev/null; then
    echo {}
    return
  fi

  create_packages
}

function delete_packages()
{
  # do nothing
  echo {}
}

##############################
##         Systemctl        ##
##############################

function _read_systemctl()
{
  local items=()

  for service in ${PROVISION_DATA_SYSTEMCTL_ENABLE} ${PROVISION_DATA_SYSTEMCTL_DISABLE}; do
    local status=$(systemctl is-enabled $service)
    if [ "$status" == "enabled" ]; then
      items+=( "\"$service\":true" )
    else
      items+=( "\"$service\":false" )
    fi
  done

  echo {
  join , "${items[@]}"
  echo }
}

function create_systemctl()
{
  {
    for service in ${PROVISION_DATA_SYSTEMCTL_ENABLE}; do
      systemctl enable $service
      systemctl start $service
    done

    for service in ${PROVISION_DATA_SYSTEMCTL_DISABLE}; do
      systemctl disable $service
      systemctl stop $service
    done
  } >&2

  _read_systemctl
  mkdir -p /var/log/journal
}

function read_systemctl()
{
  _read_systemctl
}

function update_systemctl()
{
  create_systemctl
}

function delete_systemctl()
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

function _wait_device_uuid()
{
  local device="$1"
  for i in {1..10}; do
    [ -z "$(lsblk -pno UUID $device)" ] || return
  done
}

# print fstab line for device ($1)
function _fstab_get_line()
{
  local device="$1"

  if ! [ -b "$device" ]; then
    echo "Invalid device: $device"
    exit 1
  fi

  local label=$(lsblk -pno LABEL $device)
  local uuid=$(lsblk -pno UUID $device)
  local partuuid=$(lsblk -pno PARTUUID $device)
  local partlabel=$(lsblk -pno PARTLABEL $device)

  grep -m1 -E '^[[:space:]]*('$device'|UUID='$uuid'|LABEL='$label'|PARTUUID='$partuid'|PARTLABEL='$partlabel')[[:space]]' /etc/fstab
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

  sed -i -E 's;^\s*('$device'|UUID='$uuid'|LABEL='$label'|PARTUUID='$partuuid'|PARTLABEL='$partlabel')\s.*;#\0;g' /etc/fstab
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
        else
          mkdir -p "$mountpoint"
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

        if [ "$format" == "true" ] && [ -n "$filesystem" ]; then
          if [ -n "$current_filesystem" ]; then
            echo "Already formated device: $device_name ($current_filesystem)" >&2
          else
            mkfs.$filesystem $filesystem_options $device_name
            _wait_device_uuid $device_name
          fi
        fi

        _remove_from_fstab $device_name
        _add_to_fstab $device_name $mountpoint $filesystem
        mount $mountpoint
    done

  systemctl daemon-reload
  sync
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


##
## Main
##

eval $func
