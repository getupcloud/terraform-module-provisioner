terraform {
  required_providers {
    #kubectl = {
    #  source  = "gavinbunney/kubectl"
    #  version = "~> 1"
    #}

    shell = {
      source  = "scottwinkler/shell"
      version = "~> 1"
    }
  }
}

provider "shell" {
  enable_parallelism = true
}

