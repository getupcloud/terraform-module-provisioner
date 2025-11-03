resource "shell_script" "auth" {
  for_each = { for i in local.nodes : try(i.address, i.hostname) => i }

  interpreter = ["${path.module}/ssh-wrapper.sh"]

  lifecycle_commands {
    create = "${path.module}/provisioner.sh create auth"
    update = "${path.module}/provisioner.sh update auth"
    read   = "${path.module}/provisioner.sh read auth"
    delete = "${path.module}/provisioner.sh delete auth"
  }

  environment = {
    SSH_HOST                     = try(each.value.address, each.value.hostname)
    SSH_USER                     = try(each.value.ssh_user, var.ssh_user)
    SSH_PASSWORD                 = try(each.value.ssh_password, var.ssh_password)
    SSH_PRIVATE_KEY              = try(each.value.ssh_private_key, var.ssh_private_key)
    SSH_PRIVATE_KEY_DATA         = filebase64(try(each.value.ssh_private_key, var.ssh_private_key))
    SSH_BASTION_HOST             = var.ssh_bastion_host
    SSH_BASTION_USER             = var.ssh_bastion_user
    SSH_BASTION_PASSWORD         = var.ssh_bastion_password
    SSH_BASTION_PRIVATE_KEY      = var.ssh_bastion_private_key
    SSH_BASTION_PRIVATE_KEY_DATA = var.ssh_bastion_private_key != "" ? filebase64(var.ssh_bastion_private_key) : ""

    PROVISION_DEBUG          = var.provision_debug
    PROVISION_DATA_NODE_TYPE = each.value.node_type
    PROVISION_DATA_DISKS     = base64encode(jsonencode(each.value.disks))
  }
}

resource "shell_script" "disks" {
  for_each   = { for i in local.nodes : try(i.address, i.hostname) => i }
  depends_on = [shell_script.auth]

  interpreter = ["${path.module}/ssh-wrapper.sh"]

  lifecycle_commands {
    create = "${path.module}/provisioner.sh create disks"
    update = "${path.module}/provisioner.sh update disks"
    read   = "${path.module}/provisioner.sh read disks"
    delete = "${path.module}/provisioner.sh delete disks"
  }

  environment = {
    SSH_HOST                     = try(each.value.address, each.value.hostname)
    SSH_USER                     = try(each.value.ssh_user, var.ssh_user)
    SSH_PASSWORD                 = try(each.value.ssh_password, var.ssh_password)
    SSH_PRIVATE_KEY              = try(each.value.ssh_private_key, var.ssh_private_key)
    SSH_PRIVATE_KEY_DATA         = filebase64(try(each.value.ssh_private_key, var.ssh_private_key))
    SSH_BASTION_HOST             = var.ssh_bastion_host
    SSH_BASTION_USER             = var.ssh_bastion_user
    SSH_BASTION_PASSWORD         = var.ssh_bastion_password
    SSH_BASTION_PRIVATE_KEY      = var.ssh_bastion_private_key
    SSH_BASTION_PRIVATE_KEY_DATA = var.ssh_bastion_private_key != "" ? filebase64(var.ssh_bastion_private_key) : ""
    SUDO                         = try(each.value.sudo_password, var.sudo_password) != "" ? "SUDO_ASKPASS=/usr/local/bin/sudopass sudo -A" : "sudo"
    SUDO_PASSWORD                = try(each.value.sudo_password, var.sudo_password)

    PROVISION_DEBUG          = var.provision_debug
    PROVISION_DATA_NODE_TYPE = each.value.node_type
    PROVISION_DATA_DISKS     = base64encode(jsonencode(each.value.disks))
  }
}

resource "shell_script" "packages" {
  for_each   = { for i in local.nodes : try(i.hostname, i.address) => i }
  depends_on = [shell_script.disks]

  interpreter = ["${path.module}/ssh-wrapper.sh"]

  lifecycle_commands {
    create = "${path.module}/provisioner.sh create packages"
    update = "${path.module}/provisioner.sh update packages"
    read   = "${path.module}/provisioner.sh read packages"
    delete = "${path.module}/provisioner.sh delete packages"
  }

  environment = {
    SSH_HOST                     = try(each.value.address, each.value.hostname)
    SSH_USER                     = try(each.value.ssh_user, var.ssh_user)
    SSH_PASSWORD                 = try(each.value.ssh_password, var.ssh_password)
    SSH_PRIVATE_KEY              = try(each.value.ssh_private_key, var.ssh_private_key)
    SSH_PRIVATE_KEY_DATA         = filebase64(try(each.value.ssh_private_key, var.ssh_private_key))
    SSH_BASTION_HOST             = var.ssh_bastion_host
    SSH_BASTION_USER             = var.ssh_bastion_user
    SSH_BASTION_PASSWORD         = var.ssh_bastion_password
    SSH_BASTION_PRIVATE_KEY      = var.ssh_bastion_private_key
    SSH_BASTION_PRIVATE_KEY_DATA = var.ssh_bastion_private_key != "" ? filebase64(var.ssh_bastion_private_key) : ""
    SUDO                         = try(each.value.sudo_password, var.sudo_password) != "" ? "SUDO_ASKPASS=/usr/local/bin/sudopass sudo -A" : "sudo"
    SUDO_PASSWORD                = try(each.value.sudo_password, var.sudo_password)

    PROVISION_DEBUG                   = var.provision_debug
    PROVISION_DATA_NODE_TYPE          = each.value.node_type
    PROVISION_DATA_INSTALL_PACKAGES   = join(" ", sort(var.install_packages))
    PROVISION_DATA_UNINSTALL_PACKAGES = join(" ", sort(var.uninstall_packages))
  }
}

resource "shell_script" "systemctl" {
  for_each   = { for i in local.nodes : try(i.hostname, i.address) => i }
  depends_on = [shell_script.packages]

  interpreter = ["${path.module}/ssh-wrapper.sh"]

  lifecycle_commands {
    create = "${path.module}/provisioner.sh create systemctl"
    update = "${path.module}/provisioner.sh update systemctl"
    read   = "${path.module}/provisioner.sh read systemctl"
    delete = "${path.module}/provisioner.sh delete systemctl"
  }

  environment = {
    SSH_HOST                     = try(each.value.address, each.value.hostname)
    SSH_USER                     = try(each.value.ssh_user, var.ssh_user)
    SSH_PASSWORD                 = try(each.value.ssh_password, var.ssh_password)
    SSH_PRIVATE_KEY              = try(each.value.ssh_private_key, var.ssh_private_key)
    SSH_PRIVATE_KEY_DATA         = filebase64(try(each.value.ssh_private_key, var.ssh_private_key))
    SSH_BASTION_HOST             = var.ssh_bastion_host
    SSH_BASTION_USER             = var.ssh_bastion_user
    SSH_BASTION_PASSWORD         = var.ssh_bastion_password
    SSH_BASTION_PRIVATE_KEY      = var.ssh_bastion_private_key
    SSH_BASTION_PRIVATE_KEY_DATA = var.ssh_bastion_private_key != "" ? filebase64(var.ssh_bastion_private_key) : ""
    SUDO                         = try(each.value.sudo_password, var.sudo_password) != "" ? "SUDO_ASKPASS=/usr/local/bin/sudopass sudo -A" : "sudo"
    SUDO_PASSWORD                = try(each.value.sudo_password, var.sudo_password)

    PROVISION_DEBUG                  = var.provision_debug
    PROVISION_DATA_NODE_TYPE         = each.value.node_type
    PROVISION_DATA_SYSTEMCTL_ENABLE  = join(" ", sort(var.systemctl_enable))
    PROVISION_DATA_SYSTEMCTL_DISABLE = join(" ", sort(var.systemctl_disable))
  }
}

resource "shell_script" "etc_hosts" {
  for_each   = { for i in local.nodes : try(i.address, i.hostname) => i }
  depends_on = [shell_script.packages]

  interpreter = ["${path.module}/ssh-wrapper.sh"]

  lifecycle_commands {
    create = "${path.module}/provisioner.sh create etc_hosts"
    update = "${path.module}/provisioner.sh update etc_hosts"
    read   = "${path.module}/provisioner.sh read etc_hosts"
    delete = "${path.module}/provisioner.sh delete etc_hosts"
  }

  environment = {
    SSH_HOST                     = try(each.value.address, each.value.hostname)
    SSH_USER                     = try(each.value.ssh_user, var.ssh_user)
    SSH_PASSWORD                 = try(each.value.ssh_password, var.ssh_password)
    SSH_PRIVATE_KEY              = try(each.value.ssh_private_key, var.ssh_private_key)
    SSH_PRIVATE_KEY_DATA         = filebase64(try(each.value.ssh_private_key, var.ssh_private_key))
    SSH_BASTION_HOST             = var.ssh_bastion_host
    SSH_BASTION_USER             = var.ssh_bastion_user
    SSH_BASTION_PASSWORD         = var.ssh_bastion_password
    SSH_BASTION_PRIVATE_KEY      = var.ssh_bastion_private_key
    SSH_BASTION_PRIVATE_KEY_DATA = var.ssh_bastion_private_key != "" ? filebase64(var.ssh_bastion_private_key) : ""
    SUDO                         = try(each.value.sudo_password, var.sudo_password) != "" ? "SUDO_ASKPASS=/usr/local/bin/sudopass sudo -A" : "sudo"
    SUDO_PASSWORD                = try(each.value.sudo_password, var.sudo_password)

    PROVISION_DEBUG          = var.provision_debug
    PROVISION_DATA_NODE_TYPE = each.value.node_type
    PROVISION_DATA_ETC_HOSTS = base64encode(jsonencode(var.etc_hosts))
  }
}
