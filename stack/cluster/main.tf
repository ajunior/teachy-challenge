terraform {
  required_version = ">= 1.10" # For OpenTofu compatibility
  required_providers {
    kind = {
      source  = "tehcyx/kind"
      version = "~> 0.11"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path = kind_cluster.teachy.kubeconfig_path
  }
}

resource "helm_release" "calico_crds" {
  name       = "calico-crds"
  repository = "https://docs.tigera.io/calico/charts"
  chart      = "crd.projectcalico.org.v1"
  version    = "3.32.2"
}

locals {
  pod_subnet = "10.244.0.0/16"
}

resource "helm_release" "calico" {
  depends_on       = [helm_release.calico_crds]
  name             = "calico"
  repository       = "https://docs.tigera.io/calico/charts"
  chart            = "tigera-operator"
  version          = "3.32.2"
  namespace        = "tigera-operator"
  create_namespace = true
  values = [yamlencode({
    installation = {
      calicoNetwork = {
        ipPools = [{ cidr = local.pod_subnet }]
      }
    }
  })]
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
      pod_subnet          = local.pod_subnet
    }

    node { role = "control-plane" }
    node { role = "worker" }
    node { role = "worker" }
  }
}

resource "helm_release" "metrics_server" {
  depends_on = [helm_release.calico]
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.14.0"
  namespace  = "kube-system"
  set        = [{ name = "args[0]", value = "--kubelet-insecure-tls" }]
}
