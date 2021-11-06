locals {
  kubeconfig = "/cluster/.kube/config"

  masters = [for i in var.masters : merge(i, { node_type : "master" })]
  workers = [for i in var.workers : merge(i, { node_type : "worker" })]
}
