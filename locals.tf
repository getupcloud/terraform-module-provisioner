locals {
  kubeconfig = "/cluster/.kube/config"

  masters = [for i in var.masters : merge({ node_type : "master", disks : {} }, i)]
  workers = [for i in var.workers : merge({ node_type : "worker", disks : {} }, i)]
}
