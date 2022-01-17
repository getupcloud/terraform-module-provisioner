locals {
  kubeconfig = "/cluster/.kube/config"

  nodes = [for i in var.nodes : merge({ node_type : "worker", disks : {} }, i)]
}
