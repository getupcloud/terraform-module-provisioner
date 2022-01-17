variable "nodes" {
  description = "List of nodes to provision"
  type        = list(any)
  default     = []

  # Example: [
  #   {
  #     node_type : "master",
  #     address : "1.2.3.10",
  #     hostname : "master-0",
  #     ssh_private_key : "./master_private_key",
  #     disks : {
  #       etcd : {
  #         device : "/dev/disk1",
  #         mountpoint : "/var/lib/etcd",
  #         filesystem : "ext4"
  #         format : false
  #       },
  #       kubelet : {
  #         device : "/dev/disk2",
  #         mountpoint : "/var/lib/kubelet",
  #         filesystem : "ext4"
  #         format : true
  #       }
  #       containers : {
  #         device : "/dev/disk3",
  #         mountpoint : "/var/lib/containers",
  #         filesystem : "xfs",
  #         filesystem_options : "-n ftype=1",
  #         format : true
  #       }
  #     }
  #   },
  #   {
  #     node_type : "infra",
  #     hostname : "infra-0",
  #     address : "1.2.3.20",
  #     ssh_private_key : "./infra_private_key",
  #     node_labels : { role : "infra" },
  #     node_taints : ["dedicated=infra:NoSchedule"]
  #   },
  #   {
  #     node_type : "app",
  #     hostname : "app-0",
  #     address : "1.2.3.30",
  #     ssh_private_key : ".vagrant/machines/app/virtualbox/private_key",
  #     node_labels : { role : "app" },
  #     node_taints : []
  #   }
  # ]
}

variable "ssh_user" {
  description = "SSH username"
  type        = string
}

variable "ssh_password" {
  description = "SSH password"
  type        = string
  default     = null
}

variable "ssh_private_key" {
  description = "Path for SSH private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "ssh_bastion_host" {
  description = "SSH password"
  type        = string
  default     = null
}

variable "ssh_bastion_user" {
  description = "SSH bastion username"
  type        = string
  default     = null
}

variable "ssh_bastion_password" {
  description = "SSH bastion password"
  type        = string
  default     = null
}

variable "ssh_bastion_private_key" {
  description = "Path for SSH bastion private key"
  type        = string
  default     = "~/.ssh/id_rsa"
}

variable "custom_provisioner" {
  description = "Path for custom provisioner script"
  type        = string
  default     = null
}

variable "install_packages" {
  description = "Packages to install on nodes"
  type        = list(string)
  default = [
    "chrony",
    "conntrack-tools",
    "git",
    "iproute-tc",
    "jq",
    "moreutils",
    "netcat",
    "NetworkManager",
    "python3-openshift",
    "python3-passlib",
    "python3-pip",
    "python3-pyOpenSSL",
    "python3-virtualenv",
    "strace",
    "tcpdump"
  ]
}

variable "uninstall_packages" {
  description = "Packages to install on nodes"
  type        = list(string)
  default = [
    "firewalld",
    "ntpd"
  ]
}

variable "etc_hosts" {
  description = "Entries to add to /etc/hosts on each node, Example: {\"1.1.1.1\":\"example.com example.io\"}"
  type        = map(string)
  default     = {}
}

variable "provision_debug" {
  description = "Print debug messages into /var/log/provision.log"
  type        = bool
  default     = false
}
