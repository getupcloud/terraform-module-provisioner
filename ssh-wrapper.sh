#!/bin/bash

[ "$PROVISION_DEBUG" == true ] && set -x

{
  echo SSH wrapper[$#]: $@

  if [ "$PROVISION_DEBUG" == true ] ; then
    echo "Hostname: "
    ssh $SSH_OPTIONS -i $ssh_private_key $ssh_user@$ssh_host hostname

    echo "ssh -i $ssh_private_key $ssh_user@$ssh_host uptime: "
    ssh $SSH_OPTIONS -i $ssh_private_key $ssh_user@$ssh_host uptime

    echo -----
    echo ssh_host                = $ssh_host
    echo ssh_user                = $ssh_user
    echo ssh_password            = $ssh_password
    echo ssh_bastion_host        = $ssh_bastion_host
    echo ssh_bastion_user        = $ssh_bastion_user
    echo ssh_bastion_password    = $ssh_bastion_password
    echo ssh_bastion_private_key = $ssh_bastion_private_key

    echo -----
fi
} >&2

set -- $@

SSH_OPTIONS="-o StrictHostKeyChecking=off -o IdentityAgent=none"
shfile=$(mktemp -u)
envfile=$(mktemp -u)
COMMAND=$1
shift

cat $COMMAND | ssh $SSH_OPTIONS -i $ssh_private_key $ssh_user@$ssh_host tee $shfile >/dev/null
{
  for v in "${!PROVISION_DATA@}"; do
    echo $v=${!v@Q}
  done
} | ssh $SSH_OPTIONS -i $ssh_private_key $ssh_user@$ssh_host -- tee $envfile >/dev/null

ssh $SSH_OPTIONS -i $ssh_private_key $ssh_user@$ssh_host -- sudo bash --noprofile -c "'set -e; source $envfile; source $shfile $@; rm -f $envfile $shfile'"
