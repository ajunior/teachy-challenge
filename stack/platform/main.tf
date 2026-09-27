terraform {
  required_version = ">= 1.10" # For OpenTofu compatibility
  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 3.3"
    }
  }
}

provider "helm" {
  kubernetes = {
    config_path = abspath("${path.root}/../../kubeconfig")
  }
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "91.7.1"
  namespace        = "monitoring"
  create_namespace = true
  timeout          = 600
  values = [yamlencode({
    prometheus = {
      prometheusSpec = {
        serviceMonitorSelectorNilUsesHelmValues = false
        podMonitorSelectorNilUsesHelmValues     = false
        ruleSelectorNilUsesHelmValues           = false
      }
    }
    grafana = {
      additionalDataSources = [{
        name = "Loki"
        uid  = "loki"
        type = "loki"
        url  = "http://loki.monitoring:3100"
      }]
    }
    kubeEtcd              = { enabled = false }
    kubeScheduler         = { enabled = false }
    kubeControllerManager = { enabled = false }
    kubeProxy             = { enabled = false }
  })]
}

resource "helm_release" "loki" {
  depends_on = [helm_release.kube_prometheus_stack]
  name       = "loki"
  repository = "https://grafana.github.io/helm-charts"
  chart      = "loki"
  version    = "7.3.0"
  namespace  = "monitoring"
  timeout    = 600
  values     = [file("${path.module}/values/loki.yaml")]
}
