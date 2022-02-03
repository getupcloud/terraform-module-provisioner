#!/bin/bash

export SSHPASS="$SSH_PASSWORD"

[ "$PROVISION_DEBUG" == true ] && set -x

{
  echo SSH wrapper[$#]: $@

  if [ "$PROVISION_DEBUG" == true ] ; then
    echo "Hostname: "
    sshpass -e ssh $SSH_OPTIONS -i $SSH_PRIVATE_KEY $SSH_USER@$SSH_HOST 'hostname && date && uptime'

    echo -----
    echo "SSH_HOST                = $SSH_HOST"
    echo "SSH_USER                = $SSH_USER"
    echo "SSH_PASSWORD            = ${SSH_PASSWORD//?/\*}"
    echo "SSH_BASTION_HOST        = $SSH_BASTION_HOST"
    echo "SSH_BASTION_USER        = $SSH_BASTION_USER"
    echo "SSH_BASTION_PASSWORD    = $SSH_BASTION_PASSWORD"
    echo "SSH_BASTION_PRIVATE_KEY = ${SSH_BASTION_PRIVATE_KEY//?/\*}"

    echo -----
fi
} >&2

set -- $@

SSH_OPTIONS="-o StrictHostKeyChecking=off -o IdentityAgent=none"
COMMAND=$1
shift

function make_envs()
{
    for v in "${!PROVISION_@}"; do
        echo "export $v=${!v@Q}"
    done
    for v in "${!SSH_@}"; do
        echo "export PROVISION_$v=${!v@Q}"
    done
}

# insert env vars and send script to remote host t oexecute
sed -e "/^# placeholder=enviroment.*/r "<(make_envs) $COMMAND \
    | sshpass -e ssh $SSH_OPTIONS -i $SSH_PRIVATE_KEY $SSH_USER@$SSH_HOST -- "script=\$(mktemp) && cat >\$script && bash \$script $*"
