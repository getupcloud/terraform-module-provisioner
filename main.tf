resource "shell_script" "packages" {
  for_each = { for i in concat(local.masters, local.workers) : try(i.address, i.hostname) => i }

  interpreter = ["${path.module}/ssh-wrapper.sh"]

  lifecycle_commands {
    create = "provisioner.sh create packages"
    update = "provisioner.sh update packages"
    read   = "provisioner.sh read packages"
    delete = "provisioner.sh delete packages"
  }

  environment = {
    ssh_host                = try(each.value.address, each.value.hostname)
    ssh_user                = try(each.value.ssh_user, var.ssh_user)
    ssh_password            = try(each.value.ssh_password, var.ssh_password)
    ssh_private_key         = try(each.value.ssh_private_key, var.ssh_private_key)
    ssh_bastion_host        = var.ssh_bastion_host
    ssh_bastion_user        = var.ssh_bastion_user
    ssh_bastion_password    = var.ssh_bastion_password
    ssh_bastion_private_key = var.ssh_bastion_private_key

    PROVISION_DEBUG                   = var.provision_debug
    PROVISION_DATA_NODE_TYPE          = each.value.node_type
    PROVISION_DATA_INSTALL_PACKAGES   = join(" ", sort(var.install_packages))
    PROVISION_DATA_UNINSTALL_PACKAGES = join(" ", sort(var.uninstall_packages))
  }
}

resource "shell_script" "disks" {
  for_each = { for i in concat(local.masters, local.workers) : try(i.address, i.hostname) => i }

  interpreter = ["${path.module}/ssh-wrapper.sh"]

  lifecycle_commands {
    create = "provisioner.sh create disks"
    update = "provisioner.sh update disks"
    read   = "provisioner.sh read disks"
    delete = "provisioner.sh delete disks"
  }

  environment = {
    ssh_host                = try(each.value.address, each.value.hostname)
    ssh_user                = try(each.value.ssh_user, var.ssh_user)
    ssh_password            = try(each.value.ssh_password, var.ssh_password)
    ssh_private_key         = try(each.value.ssh_private_key, var.ssh_private_key)
    ssh_bastion_host        = var.ssh_bastion_host
    ssh_bastion_user        = var.ssh_bastion_user
    ssh_bastion_password    = var.ssh_bastion_password
    ssh_bastion_private_key = var.ssh_bastion_private_key

    PROVISION_DEBUG          = var.provision_debug
    PROVISION_DATA_NODE_TYPE = each.value.node_type
    PROVISION_DATA_DISKS     = base64encode(jsonencode(each.value.disks))
  }
}
