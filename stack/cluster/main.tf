terraform {
  required_version = ">= 1.10" # For OpenTofu compatibility
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.11"
    }
  }
}

resource "kind_cluster" "teachy" {
  name            = "teachy"
  node_image      = var.node_image
  wait_for_ready  = false
  kubeconfig_path = abspath("${path.root}/../../kubeconfig")

  kind_config {
    kind        = "Cluster"
    api_version = "kind.x-k8s.io/v1alpha4"
    networking {
      disable_default_cni = true
      pod_subnet          = "192.168.0.0/16"
    }

    node { role = "control-plane" }
    node { role = "worker" }
    node { role = "worker" }
  }
}
