#!/bin/bash

[ "$PROVISION_DEBUG" == true ] && set -x

func=$1_$2
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
#
## print device UUID
#function _get_device_uuid()
#{
#  local device=$(readlink $1)
#
#  if ! [ -b "$device" ]; then
#    echo "Invalid device: $device"
#    exit 1
#  fi
#
#  local uuid=$(lsblk -no UUID $device | tr -d ' \n')
#
#  if [ -z "$uuid" ]; then
#    echo Unable to find UUID for device: $device
#    exit 1
#  fi
#
#  echo $uuid
#}
#
## print device mount point
#function _get_device_mount_point()
#{
#  local device=$(readlink $1)
#
#  if ! _fstab_has_device $device; then
#    return
#  fi
#
#  awk '{print $2}' /etc/fstab
#}
#
## print device fstype
#function _get_device_fstype()
#{
#  local device=$(readlink $1)
#
#  if ! _fstab_has_device $device; then
#    return
#  fi
#
#  awk "//{print \$3}" /etc/fstab
#}
#
## print fstab line for device
#function _fstab_get_line()
#{
#  local device=$(readlink $1)
#
#  if ! [ -b "$device" ]; then
#    echo "Invalid device: $device"
#    exit 1
#  fi
#
#  local uuid=$(get_device_uuid $device)
#
#  grep -m1 -E "^($1|$device|UUID=$uuid)" /etc/fstab
#}
#
## return 0 if found
## return 1 if not found
#function _fstab_has_device()
#{
#  local device=$(readlink $1)
#
#  if ! [ -b "$device" ]; then
#    echo "Invalid device: $device"
#    exit 1
#  fi
#
#  local uuid=$(get_device_uuid $device)
#
#  _fstab_get_line &>/dev/null
#}
#
#
#function _add_to_fstab()
#{
#  local device=$(readlink $1)
#  local mount_point="$2"
#  local fstype="$3"
#  local mount_opts="$4"
#
#  local uuid=$(get_device_uuid $device)
#  local fstab_entry="UUID=$uuid ${mount_point} ${fstype} defaults,nofail${mount_opts:+,$mount_opts} 0 0"
#
#  echo "$fstab_entry" >> /etc/fstab
#  mount ${mount_point}
#
#}
#
#function _mount()
#{
#  local device=$(readlink $1)
#  local mount_point="$2"
#
#  if ! _fstab_has_device $device $mount_point; then
#    
#  else
#  fi
#
#  if ! [ -d "$mount_point" ]; then
#    mkdir $mount_point
#  fi
#
#  local fstab_entry="UUID=$uuid ${mount_point} ${fstype} defaults,nofail${mount_opts:+,$mount_opts} 0 0"
#
#  echo "$fstab_entry" >> /etc/fstab
#  mount ${mount_point}
#}

function _read_disks()
{
    if lsblk -pno MOUNTPOINT | grep -q '^/var/lib/containers$'; then
      items+=( "\"varlibcontainers\":true" )
    else
      items+=( "\"varlibcontainers\":false" )
      echo Missing dedicated device for mount point: /var/lib/containers 2>&1
      status=1
    fi

    if [ "$PROVISION_DATA_NODE_TYPE" == master ]; then
      if lsblk -pno MOUNTPOINT | grep -q '^/var/lib/etcd$'; then
        items+=( "\"varlibetcd\":true" )
      else
        items+=( "\"varlibetcd\":false" )
        echo Missing dedicated device for mount point: /var/lib/etcd 2>&1
        status=1
      fi
    fi

  echo {
  join , "${items[@]}"
  echo }
}

function create_disks()
{
  local items=()
  local status=0

  {
    systemctl stop docker containerd &>/dev/null || true

    if ! [ -d /var/lib/containers ]; then
      mkdir /var/lib/containers
    fi

    for i in docker containerd; do
      if [ -d /var/lib/$i ]; then
        mv /var/lib/$i /var/lib/containers/
      fi

      if ! [ -L /var/lib/$i ]; then
        ln -s /var/lib/containers/$i /var/lib/$i
      fi
    done

    if grep -qw swap /etc/fstab ; then
        sed -i -e 's/\(.*[[:space:]]swap[[:space:]].*\)/#\1/g' /etc/fstab
    fi
    swapoff -a || true
  } >&2

  _read_disks
  exit $status
}

function read_disks()
{
  _read_disks
}

function update_disks()
{
  create_disks
}

function delete_disks()
{
  # do nothing
  echo {}
}

eval $func
